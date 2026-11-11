'use strict';
const {randomBytes,createHash}=require('node:crypto');
const {HttpsError}=require('firebase-functions/v2/https');
const fail=(code,message)=>{throw new HttpsError(code,message);};
const asDate=value=>value?.toDate?.()??new Date(value);
function createParkLocationHandlers({db,ai,venue,clock=()=>new Date()}){
 async function caller(request,staff=false){
  const uid=request.auth?.uid,token=request.auth?.token;
  if(!uid||token?.email_verified!==true)fail('unauthenticated','Sign in using a verified account.');
  if(staff&&token.admin!==true)fail('permission-denied','This action requires administrator access.');
  const [security,access]=await db.getAll(db.doc('accountSecurity/'+uid),db.doc('visitorAccess/'+uid));
  if(security.data()?.closing||security.data()?.revokedBefore>=(token.auth_time??0))fail('unauthenticated','Your session has ended.');
  if(access.exists&&access.data().status!=='active')fail('permission-denied','This account is restricted. Please contact support.');
  return uid;
 }
 async function start(request){
  const uid=await caller(request);
  if(request.data.consent!==true)fail('invalid-argument','Confirm location sharing before starting.');
  const now=clock(),sessionId=randomBytes(24).toString('hex');
  await db.doc('parkLocations/'+uid).set({ownerUid:uid,sessionId,active:true,expiresAt:new Date(now.getTime()+120000)});
  return{sessionId};
 }
 async function update(request){
  const uid=await caller(request),d=request.data,now=clock(),observed=asDate(d.observedAt);
  if(!/^[a-f0-9]{48}$/.test(d.sessionId||'')||!Number.isFinite(d.latitude)||!Number.isFinite(d.longitude)||!Number.isFinite(d.accuracy)||d.accuracy<0||d.accuracy>80||!['gps','situm'].includes(d.source)||!Number.isFinite(observed.getTime())||now-observed>60000||observed-now>10000)fail('invalid-argument','A recent location accurate to 80 metres or better is required.');
  if(d.latitude<venue.south||d.latitude>venue.north||d.longitude<venue.west||d.longitude>venue.east)fail('failed-precondition','You are outside the campus area. Location sharing is available when you arrive.');
  return db.runTransaction(async tx=>{
   const ref=db.doc('parkLocations/'+uid),old=(await tx.get(ref)).data();
   if(!old?.active||old.sessionId!==d.sessionId)fail('failed-precondition','Location sharing has stopped or started on another device.');
   if(old.updatedAt&&now-asDate(old.updatedAt)<20000)return{updated:false};
   if(old.observedAt&&observed<=asDate(old.observedAt))return{updated:false};
   const fields={ownerUid:uid,latitude:d.latitude,longitude:d.longitude,accuracy:d.accuracy,source:d.source,observedAt:observed,updatedAt:now};
   const sampleId=createHash('sha256').update(uid+'\0'+Math.floor(now.getTime()/60000)).digest('hex');
   tx.set(ref,{...fields,sessionId:d.sessionId,active:true,expiresAt:new Date(now.getTime()+120000)});
   tx.set(db.doc('parkLocationSamples/'+sampleId),{...fields,expiresAt:new Date(now.getTime()+86400000)});
   return{updated:true,expiresAt:new Date(now.getTime()+120000).toISOString()};
  });
 }
 async function stop(request){
  const uid=await caller(request),ref=db.doc('parkLocations/'+uid);
  await db.runTransaction(async tx=>{const old=(await tx.get(ref)).data();if(old?.sessionId===request.data.sessionId)tx.set(ref,{ownerUid:uid,sessionId:old.sessionId,active:false,expiresAt:clock()});});
  return{stopped:true};
 }
 async function density(request){
  await caller(request);const now=clock(),rows=await db.collection('parkLocations').where('expiresAt','>',now).limit(5001).get();
  if(rows.size>5000)fail('resource-exhausted','Live crowd information is busy. Please try again shortly.');
  // Aggregate before KDE; the worker never receives IDs or precise positions.
  const cells=new Map();let count=0;
  for(const doc of rows.docs){const d=doc.data();if(!d.active||!Number.isFinite(d.latitude)||d.accuracy>80)continue;
   const x=(d.longitude-venue.west)/(venue.east-venue.west),y=(venue.north-d.latitude)/(venue.north-venue.south);if(x<0||x>1||y<0||y>1)continue;
   const col=Math.min(31,Math.floor(x*32)),row=Math.min(31,Math.floor(y*32)),key=col+','+row;
   const cell=cells.get(key)??{x:(col+.5)/32,y:(row+.5)/32,weight:0};cell.weight++;cells.set(key,cell);count++;
  }
  let grid;try{grid=await ai.call('queue_density',{points:[...cells.values()]});}catch(_){fail('unavailable','Live crowd information is temporarily unavailable.');}
  const {queuePlaces,...result}=grid;
  return{...result,source:'Shared live visitor locations',visitorCount:count,updatedAt:now.toISOString(),expiresAfterSeconds:120};
 }
 async function summary(request){
  await caller(request,true);const now=clock(),start=new Date(now.getTime()-86400000);
  const [grid,samples]=await Promise.all([density(request),db.collection('parkLocationSamples').where('updatedAt','>=',start).limit(15001).get()]);
  if(samples.size>15000)fail('resource-exhausted','Movement information is busy. Please try again shortly.');
  const hours=Array.from({length:24},(_,hour)=>({hour,people:new Set()})),journeys=new Map(),flows=new Map();
  for(const doc of samples.docs){const d=doc.data();if(!d.ownerUid||!d.updatedAt)continue;const when=asDate(d.updatedAt);if(when>now)continue;
   hours[new Date(when.getTime()+8*3600000).getUTCHours()].people.add(d.ownerUid);
   if(!journeys.has(d.ownerUid))journeys.set(d.ownerUid,[]);
   const col=Math.min(3,Math.max(0,Math.floor((d.longitude-venue.west)/(venue.east-venue.west)*4))),row=Math.min(3,Math.max(0,Math.floor((venue.north-d.latitude)/(venue.north-venue.south)*4)));
   journeys.get(d.ownerUid).push({time:when.getTime(),zone:String.fromCharCode(65+row)+(col+1)});
  }
  for(const entries of journeys.values()){entries.sort((a,b)=>a.time-b.time);for(let i=1;i<entries.length;i++){const a=entries[i-1],b=entries[i];if(a.zone===b.zone||b.time-a.time>5*60000)continue;const key=a.zone+'-'+b.zone;flows.set(key,{from:a.zone,to:b.zone,count:(flows.get(key)?.count??0)+1});}}
  return{density:grid,hourly:hours.map(h=>({hour:h.hour,visitors:h.people.size})),flows:[...flows.values()].sort((a,b)=>b.count-a.count).slice(0,10),retentionHours:24,updatedAt:now.toISOString()};
 }
 return{start,update,stop,density,summary};
}
module.exports={createParkLocationHandlers};
