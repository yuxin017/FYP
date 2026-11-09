'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),{randomUUID}=require('node:crypto');
if(process.env.GCLOUD_PROJECT!=='demo-themepark-fyp'||process.env.FIRESTORE_EMULATOR_HOST!=='127.0.0.1:8080')throw Error('Photo checks require the isolated fixture database.');
const admin=require('../../functions/node_modules/firebase-admin');if(!admin.apps.length)admin.initializeApp({projectId:process.env.GCLOUD_PROJECT});
const db=admin.firestore(),{FieldValue}=admin.firestore,{createPhotoHandlers}=require('../../functions/src/photos');
const now=new Date('2088-10-04T04:00:00Z');
async function fixture(){
  const uid='photo-'+randomUUID(),staff='staff-'+randomUUID(),calls=[];
  await db.doc('visitors/'+uid).set({fullName:'Photo fixture visitor',email:uid+'@example.test',loyaltyPoints:1000});
  const feature=[1,...Array(127).fill(0)];
  const ai={async call(operation,data){calls.push(operation);if(operation==='enroll')return{feature,score:.99};if(operation==='prepare_photo')return{originalBase64:'isolated-original',previewBase64:'isolated-watermarked-preview',width:1200,height:800,faces:[{feature,box:[.1,.1,.2,.2]}]};if(operation==='match_faces')return{matches:data.templates.some(t=>t.uid===uid)?[{uid,score:.93,box:[.1,.1,.2,.2]}]:[]};if(operation==='render_photo')return{imageBase64:'isolated-rendered-copy',width:1200,height:800};throw Error('Unknown fixture operation');}};
  const handlers=createPhotoHandlers({db,FieldValue,ai,clock:()=>now}),auth=(user,staffAccess=false)=>({uid:user,token:{admin:staffAccess,email_verified:true,email:user+'@example.test',auth_time:Math.floor(now.getTime()/1000)}});
  const user=data=>({auth:auth(uid),data}),operator=data=>({auth:auth(staff,true),data});
  async function upload(){return handlers.upload(operator({title:'Park adventure',takenAt:now.toISOString(),requestId:randomUUID(),imageBase64:'isolated-photo-input'}));}
  async function matched(){await handlers.enroll(user({consent:true,imageBase64:'isolated-selfie-input'}));return upload();}
  return{uid,staff,handlers,user,operator,upload,matched,calls};
}
test('photo upload requires staff; verified enrolment creates a private, consented matching profile',async()=>{
  const f=await fixture();await assert.rejects(f.handlers.upload(f.user({})),e=>e.code==='permission-denied');
  await assert.rejects(f.handlers.enroll(f.user({consent:false,imageBase64:'selfie'})),e=>e.code==='invalid-argument');
  const result=await f.matched();assert.equal(result.matched,1);
  assert.equal((await db.doc('faceProfiles/'+f.uid).get()).data().enabled,true);
  assert.equal((await db.doc('photoMatches/'+result.photoId+'_'+f.uid).get()).data().ownerUid,f.uid);
  assert.equal((await db.doc('faceTemplates/'+f.uid).get()).data().feature.length,128);
  await f.handlers.disable(f.user({}));
});
test('a digital purchase is idempotent, awards correct net points and retains no card details',async()=>{
  const f=await fixture(),{photoId}=await f.matched(),cart={items:[{photoId,format:'digital',edits:{filter:'warm'}}],pointsUsed:100,promoCode:''};
  await assert.rejects(f.handlers.download(f.user({photoId})),e=>e.code==='permission-denied');
  const quote=await f.handlers.quote(f.user(cart));assert.equal(quote.totalMinor,2400);
  const request=f.user({...cart,requestId:randomUUID(),expectedTotalMinor:2400,cardNumber:'never-persist-this-fixture'});
  const [a,b]=await Promise.all([f.handlers.checkout(request),f.handlers.checkout(request)]);assert.equal(a.orderId,b.orderId);
  const order=(await db.doc('photoOrders/'+a.orderId).get()).data();assert.equal(order.pointsEarned,24);assert.equal(order.items[0].previewBase64,undefined);assert.equal(JSON.stringify(order).includes('never-persist'),false);
  assert.equal((await db.doc('visitors/'+f.uid).get()).data().loyaltyPoints,924);
  assert.equal((await db.collection('photoOrders').where('ownerUid','==',f.uid).get()).size,1);
  assert.equal((await f.handlers.download(f.user({photoId}))).imageBase64,'isolated-rendered-copy');
  await f.handlers.disable(f.user({}));assert.equal((await db.doc('faceTemplates/'+f.uid).get()).exists,false);assert.equal((await db.doc('photoMatches/'+photoId+'_'+f.uid).get()).exists,false);
  assert.equal((await f.handlers.download(f.user({photoId}))).imageBase64,'isolated-rendered-copy');
});
test('another visitor cannot purchase or download someone else’s matched photo, and hidden matches remain hidden',async()=>{
  const f=await fixture(),{photoId}=await f.matched();
  const outsider=f.user({items:[{photoId,format:'digital'}],pointsUsed:0});outsider.auth.uid='outsider-'+randomUUID();
  await db.doc('visitors/'+outsider.auth.uid).set({loyaltyPoints:0});await assert.rejects(f.handlers.quote(outsider),e=>e.code==='permission-denied');
  await f.handlers.hide(f.user({photoId}));assert.equal((await f.handlers.recheck(f.operator({photoId}))).matched,0);
  await assert.rejects(f.handlers.quote(f.user({items:[{photoId,format:'digital'}]})),e=>e.code==='permission-denied');await f.handlers.disable(f.user({}));
});
test('print collection validates a private QR, staff access and physical collection stages',async()=>{
  const f=await fixture(),{photoId}=await f.matched(),data={items:[{photoId,format:'print',edits:{filter:'mono'}}],pointsUsed:0};
  const quote=await f.handlers.quote(f.user(data)),order=await f.handlers.checkout(f.user({...data,requestId:randomUUID(),expectedTotalMinor:quote.totalMinor})),code='PK1:'+order.orderId+':'+order.kioskCode;
  await assert.rejects(f.handlers.download(f.user({photoId})),e=>e.code==='permission-denied');
  await assert.rejects(f.handlers.kioskRetrieve(f.user({code})),e=>e.code==='permission-denied');
  const request=await f.handlers.kioskRetrieve(f.operator({code}));assert.equal(request.images.length,1);assert.equal(request.status,'ready');
  await assert.rejects(f.handlers.kioskEditSource(f.user({requestId:order.orderId,photoId})),e=>e.code==='permission-denied');
  assert.equal((await f.handlers.kioskEditSource(f.operator({requestId:order.orderId,photoId}))).imageBase64,'isolated-original');
  await f.handlers.kioskSaveEdits(f.operator({requestId:order.orderId,photoId,edits:{filter:'vivid',intensity:.5}}));
  assert.equal((await f.handlers.kioskRetrieve(f.operator({code}))).images[0].edits.filter,'vivid');
  await assert.rejects(f.handlers.kioskStatus(f.operator({requestId:order.orderId,status:'collected'})),e=>e.code==='failed-precondition');
  await f.handlers.kioskStatus(f.operator({requestId:order.orderId,status:'spooled'}));
  await assert.rejects(f.handlers.kioskSaveEdits(f.operator({requestId:order.orderId,photoId,edits:{}})),e=>e.code==='failed-precondition');
  await f.handlers.kioskStatus(f.operator({requestId:order.orderId,status:'collected'}));
  await assert.rejects(f.handlers.kioskRetrieve(f.operator({code})),e=>e.code==='failed-precondition');await f.handlers.disable(f.user({}));
});
test('stale prices, invalid edits and upload request reuse are rejected without creating purchases',async()=>{
  const f=await fixture(),{photoId}=await f.matched();
  await assert.rejects(f.handlers.quote(f.user({items:[{photoId,format:'digital',edits:{crop:{x:.9,y:0,width:.8,height:.8}}}]})),e=>e.code==='invalid-argument');
  await assert.rejects(f.handlers.checkout(f.user({items:[{photoId,format:'digital'}],requestId:randomUUID(),expectedTotalMinor:1})),e=>e.code==='failed-precondition');
  assert.equal((await db.collection('photoOrders').where('ownerUid','==',f.uid).get()).size,0);
  const data={title:'Another photo',takenAt:now.toISOString(),requestId:randomUUID(),imageBase64:'isolated-photo-one'};await f.handlers.upload(f.operator(data));await assert.rejects(f.handlers.upload(f.operator({...data,imageBase64:'isolated-photo-two'})),e=>e.code==='already-exists');await f.handlers.disable(f.user({}));
});
test('photo codes work without biometric consent and print quantity/size are priced by the server',async()=>{
  const f=await fixture(),upload=await f.upload();
  await f.handlers.claim(f.user({code:'PP1:'+upload.claimCode}));assert.equal((await db.doc('faceTemplates/'+f.uid).get()).exists,false);
  await f.handlers.favorite(f.user({photoId:upload.photoId,favorite:true}));
  const quote=await f.handlers.quote(f.user({items:[{photoId:upload.photoId,format:'print',quantity:2,printSize:'8x10',finish:'matte'}],pointsUsed:0}));assert.equal(quote.totalMinor,9000);
  await f.handlers.disable(f.user({}));assert.equal((await db.doc('photoMatches/'+upload.photoId+'_'+f.uid).get()).data().source,'photo-code');
});
test('a multi-photo purchase keeps previews outside the Firestore order document',async()=>{
  const f=await fixture(),items=[];
  for(let index=0;index<6;index++){
    const photoId='large-'+randomUUID();items.push({photoId,format:'digital'});
    await db.doc('parkPhotos/'+photoId).set({title:'Album '+index,status:'active',previewBase64:'A'.repeat(200000),takenAt:now});
    await db.doc('photoMatches/'+photoId+'_'+f.uid).set({ownerUid:f.uid,photoId,hidden:false});
  }
  const result=await f.handlers.checkout(f.user({items,requestId:randomUUID(),expectedTotalMinor:15000}));
  const order=(await db.doc('photoOrders/'+result.orderId).get()).data();assert.ok(JSON.stringify(order).length<100000);
  assert.equal((await db.collection('photoOrderPreviews').where('orderId','==',result.orderId).get()).size,6);
});
test('archiving removes gallery availability and blocks new purchases, while restoring preserves the match',async()=>{
  const f=await fixture(),{photoId}=await f.matched();
  await f.handlers.archive(f.operator({photoId,archived:true}));
  assert.equal((await db.doc('photoMatches/'+photoId+'_'+f.uid).get()).data().available,false);
  await assert.rejects(f.handlers.quote(f.user({items:[{photoId,format:'digital'}]})),e=>e.code==='permission-denied');
  await f.handlers.archive(f.operator({photoId,archived:false}));
  assert.equal((await db.doc('photoMatches/'+photoId+'_'+f.uid).get()).data().available,true);
  assert.equal((await f.handlers.quote(f.user({items:[{photoId,format:'digital'}]}))).totalMinor,2500);
  await f.handlers.disable(f.user({}));
});
