'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),{randomUUID}=require('node:crypto');
if(process.env.GCLOUD_PROJECT!=='demo-themepark-fyp'||process.env.FIRESTORE_EMULATOR_HOST!=='127.0.0.1:8080')throw Error('Intelligence checks require isolated fixtures.');
const admin=require('../../functions/node_modules/firebase-admin');if(!admin.apps.length)admin.initializeApp({projectId:process.env.GCLOUD_PROJECT});const db=admin.firestore(),{FieldValue}=admin.firestore,{createParkIntelligenceHandlers}=require('../../functions/src/park_intelligence');
test('recommendations use the authenticated visitor’s preferences and actual star ratings only',async()=>{
 const uid='intelligence-'+randomUUID(),other='other-'+randomUUID(),calls=[],ai={async call(operation,data){calls.push({operation,data});return{recommendations:[]};}},handlers=createParkIntelligenceHandlers({db,FieldValue,ai});
 await db.doc('visitors/'+uid).set({parkInterests:['Family rides'],foodPreferences:['Vegetarian'],heightCm:130});await db.doc('attractionRatings/'+uid).set({ownerUid:uid,attractionId:'fixture-ride',stars:5});await db.doc('attractionRatings/'+other).set({ownerUid:other,attractionId:'other-private-ride',stars:1});
 const request={auth:{uid,token:{email_verified:true}},data:{uid:other,interests:['not-trusted']}};await handlers.recommendations(request);assert.deepEqual(calls[0].data.interests,['Family rides']);assert.deepEqual(calls[0].data.ratings,[{attractionId:'fixture-ride',rating:5}]);assert.equal(calls[0].data.heightCm,130);
 await assert.rejects(handlers.saveLandmark(request),e=>e.code==='permission-denied');await assert.rejects(handlers.anomalies(request),e=>e.code==='permission-denied');await assert.rejects(handlers.assistant({...request,auth:null}),e=>e.code==='unauthenticated');
});
test('landmark results disclose a confirmed location, never private reference features',async()=>{
 const uid='landmark-'+randomUUID(),placeId='location-'+randomUUID(),handlers=createParkIntelligenceHandlers({db,FieldValue,ai:{async call(operation,data){if(operation==='landmark_features')return{points:[[1,2]],descriptors:'private-fixture-features',rows:1,width:400,height:300,previewBase64:'fixture-preview'};if(operation==='recognize_landmark'){const selected=data.references.find(r=>r.placeId===placeId);assert.equal(selected.features.previewBase64,undefined);return{matched:true,id:selected.id,placeId,inliers:25};}throw Error('unexpected');}}});await db.doc('attractions/'+placeId).set({name:'Fixture landmark',status:'open'});
 const staff=data=>({auth:{uid,token:{email_verified:true,admin:true}},data});const saved=await handlers.saveLandmark(staff({placeId,name:'Landmark reference',imageBase64:'isolated-image'}));const result=await handlers.recognizeLandmark({auth:{uid,token:{email_verified:true}},data:{imageBase64:'isolated-camera-image'}});assert.equal(result.name,'Fixture landmark');assert.equal(JSON.stringify(result).includes('private-fixture-features'),false);await handlers.setLandmarkActive(staff({id:saved.id,active:false}));assert.equal((await db.doc('landmarkReferences/'+saved.id).get()).data().active,false);
});

test('crowd monitoring is staff-only and aggregates queue demand and pass journeys without visitor identities',async()=>{
 const suffix=randomUUID(),uid='crowd-operator-'+suffix,a='crowd-a-'+suffix,b='crowd-b-'+suffix,pass='private-pass-'+suffix,person='private-person-'+suffix,now=new Date('2100-06-12T04:00:00Z');
 const handlers=createParkIntelligenceHandlers({db,FieldValue,clock:()=>now,ai:{async call(operation,data){assert.equal(operation,'queue_density');return{size:2,values:[0,0,0,0],queuePlaces:data.points.reduce((n,p)=>n+p.weight,0)};}}});
 const request=(staff=true)=>({auth:{uid,token:{email_verified:true,admin:staff}},data:{days:1}});
 await assert.rejects(handlers.crowd(request(false)),e=>e.code==='permission-denied');await assert.rejects(handlers.crowd({...request(),data:{days:900}}),e=>e.code==='invalid-argument');
 for(const [id,name,mapX]of [[a,'First '+suffix,.2],[b,'Second '+suffix,.8]])await db.doc('attractions/'+id).set({name,category:'Family rides',status:'open',minHeightCm:0,mapX,mapY:.5});
 await db.doc('attractionSlots/crowd-'+suffix).set({attractionId:a,startsAt:new Date('2100-06-12T03:55:00Z'),endsAt:new Date('2100-06-12T04:10:00Z'),capacity:10,bookedCount:9,confirmedCount:8});
 for(const [id,attractionId,minutes,ticketId]of [['one',a,-90,pass],['two',b,-30,pass],['guest',a,-25,'another-private-pass-'+suffix]])await db.doc('rideAdmissions/crowd-'+id+'-'+suffix).set({ownerUid:person,ticketId,attractionId,createdAt:new Date(now.getTime()+minutes*60000)});
 const result=await handlers.crowd(request()),first=result.attractions.find(p=>p.id===a);assert.equal(first.confirmed,8);assert.equal(first.capacity,10);assert.equal(first.level,'busy');assert.equal(first.visits,2);
 assert.equal(result.hourly.find(h=>h.hour===11).visits>=2,true);assert.equal(result.flows.find(f=>f.from==='First '+suffix&&f.to==='Second '+suffix).count,1);
 assert.equal(JSON.stringify(result).includes(person),false);assert.equal(JSON.stringify(result).includes(pass),false);
});
