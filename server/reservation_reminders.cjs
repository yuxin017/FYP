'use strict';
const crypto=require('node:crypto');
const {createRequire}=require('node:module'),path=require('node:path');
const requireFunctions=createRequire(path.join(__dirname,'../functions/package.json'));
const {FieldPath}=requireFunctions('firebase-admin/firestore');
const {HttpsError}=requireFunctions('firebase-functions/v2/https');
const hash=value=>crypto.createHash('sha256').update(value).digest('hex');
const fail=(code,message)=>{throw new HttpsError(code,message);};
const date=value=>value?.toDate?.();
const origins=new Set(['http://localhost:5173','http://127.0.0.1:5173','https://themeparksmartmanagement.web.app','https://themeparksmartmanagement.firebaseapp.com']);
function subscription(value){
 if(!value||typeof value!=='object'||Array.isArray(value))fail('invalid-argument','Allow browser notifications and try again.');
 let endpoint;try{endpoint=new URL(value.endpoint);}catch(_){fail('invalid-argument','Choose a valid browser notification service.');}
 const host=endpoint.hostname;
 if(endpoint.protocol!=='https:'||endpoint.username||endpoint.password||endpoint.hash||endpoint.port||endpoint.href.length>4096||!(host==='fcm.googleapis.com'||host==='updates.push.services.mozilla.com'||host==='web.push.apple.com'||/^[a-z0-9-]+\.notify\.windows\.com$/.test(host)))fail('invalid-argument','This browser notification service is unsupported.');
 const keys=value.keys;
 if(!keys||typeof keys.p256dh!=='string'||typeof keys.auth!=='string'||!/^[\w-]{87}$/.test(keys.p256dh)||!/^[\w-]{22}$/.test(keys.auth))fail('invalid-argument','Renew browser notifications on this device.');
 try{crypto.ECDH.convertKey(Buffer.from(keys.p256dh,'base64url'),'prime256v1');}catch(_){fail('invalid-argument','Renew browser notifications on this device.');}
 return{endpoint:endpoint.href,keys:{p256dh:keys.p256dh,auth:keys.auth}};
}
function createReservationReminders({db,FieldValue,webPush,clock=()=>new Date()}){
 let configuration,cursor;
 const deviceKey=(uid,id)=>hash(uid+'\0'+id),requestKey=(uid,device,id)=>hash(uid+'\0'+device+'\0'+id);
 async function ready(){
  if(configuration)return configuration;
  const ref=db.doc('serverConfiguration/reminders');
  configuration=await db.runTransaction(async tx=>{
   const old=await tx.get(ref);if(old.exists)return old.data();
   const keys=webPush.generateVAPIDKeys(),value={...keys,subject:'https://themeparksmartmanagement.web.app',createdAt:FieldValue.serverTimestamp()};tx.create(ref,value);return value;
  });return configuration;
 }
 async function caller(request){
  const uid=request.auth?.uid,token=request.auth?.token;
  if(!uid||token?.email_verified!==true)fail('unauthenticated','Sign in with a verified account to manage reminders.');
  const [security,access]=await db.getAll(db.doc('accountSecurity/'+uid),db.doc('visitorAccess/'+uid));
  if(security.data()?.closing||access.exists&&access.data().status!=='active')fail('permission-denied','This account cannot receive reminders.');
  return uid;
 }
 function deviceId(data){if(!/^[a-f0-9]{48}$/.test(data?.deviceId??''))fail('invalid-argument','Choose this device again.');return data.deviceId;}
 async function settings(request){await caller(request);return{publicKey:(await ready()).publicKey};}
 async function register(request){
  const uid=await caller(request),id=deviceId(request.data),push=subscription(request.data.subscription),origin=request.data.origin;
  if(!origins.has(origin))fail('invalid-argument','Open the park application at its normal address.');
  const ref=db.doc('reminderDevices/'+deviceKey(uid,id)),endpointHash=hash(push.endpoint);
  await db.runTransaction(async tx=>{
   const [existing,devices,previous]=await Promise.all([tx.get(ref),tx.get(db.collection('reminderDevices').where('ownerUid','==',uid)),tx.get(db.collection('reminderDevices').where('endpointHash','==',endpointHash))]);
   if(!(existing.data()?.status==='active'&&date(existing.data().expiresAt)>clock())&&devices.docs.filter(d=>d.data().status==='active'&&date(d.data().expiresAt)>clock()).length>=10)fail('resource-exhausted','Turn off reminders on an unused device before adding another.');
   for(const old of previous.docs)if(old.id!==ref.id)tx.update(old.ref,{status:'inactive',updatedAt:FieldValue.serverTimestamp()});
   tx.set(ref,{ownerUid:uid,deviceId:id,subscription:push,endpointHash,origin,authTime:request.auth.token.auth_time??0,status:'active',expiresAt:new Date(clock().getTime()+30*86400000),updatedAt:FieldValue.serverTimestamp()});
  });return{enabled:true};
 }
 async function unregister(request){
  const uid=await caller(request),id=deviceId(request.data),ref=db.doc('reminderDevices/'+deviceKey(uid,id));
  await db.runTransaction(async tx=>{const saved=await tx.get(ref);if(saved.exists)tx.update(ref,{status:'inactive',updatedAt:FieldValue.serverTimestamp()});});return{enabled:false};
 }
 async function preference(request){
  const uid=await caller(request),data=request.data,device=deviceId(data),id=data.reservationId;
  if(typeof id!=='string'||!/^[\w-]{1,160}$/.test(id)||typeof data.enabled!=='boolean')fail('invalid-argument','Choose a valid reservation reminder.');
  const ref=db.doc('reservationReminderRequests/'+requestKey(uid,device,id));
  await db.runTransaction(async tx=>{
   const [booking,target,old]=await tx.getAll(db.doc('reservations/'+id),db.doc('reminderDevices/'+deviceKey(uid,device)),ref),b=booking.data();
   if(!b||b.ownerUid!==uid)fail('permission-denied','This reservation is unavailable.');
   if(data.enabled&&(b.status!=='confirmed'||!date(b.startsAt)||date(b.startsAt)<=clock()))fail('failed-precondition','Only upcoming confirmed reservations can have reminders.');
   if(data.enabled&&(target.data()?.status!=='active'||date(target.data().expiresAt)<=clock()))fail('failed-precondition','Allow notifications on this device first.');
   if(data.enabled&&(old.data()?.sentAt||['sent','sending'].includes(old.data()?.status)))return;
   tx.set(ref,{ownerUid:uid,deviceId:device,reservationId:id,status:data.enabled?'pending':'disabled',nextAt:new Date(Math.max(clock().getTime(),date(b.startsAt).getTime()-15*60000)),expiresAt:new Date(date(b.startsAt).getTime()+86400000),attempts:old.data()?.attempts??0,updatedAt:FieldValue.serverTimestamp()},{merge:true});
  });return{enabled:data.enabled};
 }
 async function processDue(){
  const keys=await ready(),now=clock();let accepted=0;
  // Recover interrupted sends. The worker and browser both deduplicate retries.
  const interrupted=await db.collection('reservationReminderRequests').where('status','==','sending').limit(50).get();
  for(const row of interrupted.docs)if(date(row.data().leaseUntil)<=now)await db.runTransaction(async tx=>{const current=await tx.get(row.ref);if(current.data()?.status==='sending'&&date(current.data().leaseUntil)<=now)tx.update(row.ref,{status:'pending'});});
  let query=db.collection('reservationReminderRequests').where('status','==','pending').orderBy(FieldPath.documentId());if(cursor)query=query.startAfter(cursor);
  const rows=await query.limit(100).get();cursor=rows.size===100?rows.docs.at(-1).id:undefined;
  for(const row of rows.docs){if(date(row.data().nextAt)>now)continue;
   const claim=await db.runTransaction(async tx=>{
    const snapshot=await tx.get(row.ref),r=snapshot.data();if(r?.status!=='pending'||!date(r.nextAt)||date(r.nextAt)>clock())return null;
    const deviceRef=db.doc('reminderDevices/'+deviceKey(r.ownerUid,r.deviceId));
    const [booking,device,security,access]=await tx.getAll(db.doc('reservations/'+r.reservationId),deviceRef,db.doc('accountSecurity/'+r.ownerUid),db.doc('visitorAccess/'+r.ownerUid)),b=booking.data(),d=device.data(),s=security.data();
    if(b?.ownerUid!==r.ownerUid||b.status!=='confirmed'||!date(b.startsAt)||!date(b.endsAt)||date(b.startsAt)<=clock()||d?.status!=='active'||!date(d.expiresAt)||date(d.expiresAt)<=clock()||s?.closing||s?.revokedBefore>=d.authTime||access.exists&&access.data().status!=='active'){
     tx.update(row.ref,{status:'cancelled',updatedAt:FieldValue.serverTimestamp()});return null;
    }
    const claimId=crypto.randomBytes(16).toString('hex'),attempts=(r.attempts??0)+1;
    tx.update(row.ref,{status:'sending',claimId,attempts,leaseUntil:new Date(clock().getTime()+30000),updatedAt:FieldValue.serverTimestamp()});
    const time=value=>new Intl.DateTimeFormat('en-MY',{timeZone:'Asia/Kuala_Lumpur',hour:'2-digit',minute:'2-digit',hour12:false}).format(date(value));
    return{claimId,attempts,deviceRef,subscription:d.subscription,payload:{id:row.id,deviceId:r.deviceId,reservationId:r.reservationId,title:'Your attraction reservation',body:`${b.attractionName??'Your attraction'}: return between ${time(b.startsAt)} and ${time(b.endsAt)}.`,url:d.origin+'/?reservationReminder='+encodeURIComponent(r.reservationId),expiresAt:date(b.startsAt).getTime()},ttl:Math.max(1,Math.floor((date(b.startsAt)-clock())/1000))};
   });if(!claim)continue;
   let outcome='sent',errorStatus;
   try{await webPush.sendNotification(claim.subscription,JSON.stringify(claim.payload),{vapidDetails:{subject:keys.subject,publicKey:keys.publicKey,privateKey:keys.privateKey},TTL:claim.ttl,urgency:'high',topic:row.id.slice(0,32),timeout:10000});accepted++;}
   catch(error){errorStatus=error.statusCode;outcome=[404,410].includes(errorStatus)||claim.attempts>=3?'failed':'pending';}
   await db.runTransaction(async tx=>{const current=await tx.get(row.ref);if(current.data()?.status!=='sending'||current.data().claimId!==claim.claimId)return;tx.update(row.ref,{status:outcome,...(outcome==='sent'?{sentAt:FieldValue.serverTimestamp()}:{}),nextAt:new Date(clock().getTime()+60000),updatedAt:FieldValue.serverTimestamp()});if([404,410].includes(errorStatus))tx.update(claim.deviceRef,{status:'inactive'});});
  }
  return{accepted};
 }
 return{ready,settings,register,unregister,preference,processDue};
}
module.exports={createReservationReminders,subscription};
