'use strict';
const {test,after}=require('node:test'),assert=require('node:assert/strict'),{randomUUID}=require('node:crypto');
if(process.env.GCLOUD_PROJECT!=='demo-themepark-fyp'||process.env.FIRESTORE_EMULATOR_HOST!=='127.0.0.1:8080')throw Error('Management checks require the isolated database.');
const admin=require('../../functions/node_modules/firebase-admin');if(!admin.apps.length)admin.initializeApp({projectId:process.env.GCLOUD_PROJECT});const db=admin.firestore(),{FieldValue}=admin.firestore,{createParkManagementHandlers}=require('../../functions/src/park_management');
const now=new Date('2090-03-08T04:00:00Z');
after(async()=>{await db.doc('parkSettings/loyalty').delete();await db.doc('parkSettings/weather').delete();});
function fixture(){const uid='management-'+randomUUID(),staff='operator-'+randomUUID(),handlers=createParkManagementHandlers({db,FieldValue,clock:()=>now,fetchWeather:async()=>({ok:true,json:async()=>({current:{time:'2090-03-08T12:00',precipitation:4.5,temperature_2m:27,weather_code:63}})})});const request=(data={},isAdmin=true)=>({auth:{uid:isAdmin?staff:uid,token:{email_verified:true,admin:isAdmin,auth_time:Math.floor(now/1000)}},data});return{uid,handlers,request};}
test('administrator policies validate prices, dates and discounts and cannot be set by visitors',async()=>{
 const f=fixture(),d={code:'SAVE_'+randomUUID().slice(0,8).toUpperCase(),name:'Photo savings',description:'Park memories',type:'percent',value:20,scopes:['photos'],startsAt:'2090-03-01T00:00:00Z',endsAt:'2090-04-01T00:00:00Z',active:true,public:true};
 await assert.rejects(f.handlers.saveCampaign(f.request(d,false)),e=>e.code==='permission-denied');await assert.rejects(f.handlers.saveCampaign(f.request({...d,value:101})),e=>e.code==='invalid-argument');
 await f.handlers.saveCampaign(f.request(d));await db.doc('campaigns/'+d.code).update({usageCount:3});await f.handlers.saveCampaign(f.request({...d,name:'Updated savings'}));assert.equal((await db.doc('campaigns/'+d.code).get()).data().usageCount,3);
 await assert.rejects(f.handlers.savePhotoSettings(f.request({digitalPriceMinor:-5,printPriceMinor:3500,bundlePriceMinor:5000})),e=>e.code==='invalid-argument');
 await f.handlers.saveLoyalty(f.request({purchasePointsPerRinggit:2,ridePoints:15,noShowPenalty:5,noShowEnabled:true}));assert.equal((await db.doc('parkSettings/loyalty').get()).data().ridePoints,15);
 const reward={name:'Park reward',benefit:'A benefit at the counter',pointsCost:100,validityDays:30,terms:['One use.'],instructions:['Present at the counter.'],active:true};
 for(const category of ['dining','shopping','photo']){const saved=await f.handlers.saveReward(f.request({...reward,category}));assert.equal((await db.doc('rewardCatalogue/'+saved.id).get()).data().category,category);}
 await assert.rejects(f.handlers.saveReward(f.request({...reward,category:'food'})),e=>e.code==='invalid-argument');
});
test('weather uses configured actual coordinates and grants one voucher per eligible visitor per day',async()=>{
 const f=fixture();await db.doc('parkSettings/weather').delete();assert.deepEqual(await f.handlers.runWeather(),{configured:false});
 await assert.rejects(f.handlers.saveWeather(f.request({enabled:true,latitude:null,longitude:null})),e=>e.code==='invalid-argument');
 await f.handlers.saveWeather(f.request({enabled:true,latitude:3.1,longitude:101.7,parkName:'Fixture park',rainThresholdMm:2,voucherBenefit:'Complimentary hot drink',validityDays:14}));await f.handlers.runWeather();
 await db.doc('tickets/weather-'+f.uid).set({ownerUid:f.uid,version:2,status:'valid',visitDate:'2090-03-08',validUntil:'2090-03-08',createdAt:new Date('2090-03-01T00:00:00Z')});
 await db.doc('visitors/'+f.uid).set({fullName:'Weather fixture'});
 await f.handlers.runWeather();const automatic=await db.collection('compensationGrants').where('ownerUid','==',f.uid).get();assert.equal(automatic.size,1);
 const [a,b]=await Promise.all([f.handlers.claimWeather(f.request({},false)),f.handlers.claimWeather(f.request({},false))]);assert.equal(a.voucherId,b.voucherId);assert.equal((await db.doc('rewardVouchers/'+a.voucherId).get()).data().pointsCost,0);
 const outsider=f.request({},false);outsider.auth.uid='no-ticket-'+randomUUID();await assert.rejects(f.handlers.claimWeather(outsider),e=>e.code==='failed-precondition');
});
test('reports aggregate actual confirmations, admission dates and top products',async()=>{
 const f=fixture(),start='2091-01-01T00:00:00Z',end='2091-01-02T00:00:00Z',before=await f.handlers.report(f.request({start,end}));await db.doc('orders/report-'+f.uid).set({ownerUid:f.uid,status:'completed',totalMinor:12500,createdAt:new Date(start),items:[{packageName:'Family pass',unitPriceMinor:12500}]});await db.doc('photoOrders/report-'+f.uid).set({ownerUid:f.uid,status:'confirmed',totalMinor:2500,createdAt:new Date(start),items:[{title:'Castle photo',priceMinor:2500,quantity:1}]});
 await db.doc('admissions/report-'+f.uid).set({ownerUid:f.uid,createdAt:new Date(start)});
 await db.doc('rewardVouchers/report-'+f.uid).set({ownerUid:f.uid,status:'used',issuedAt:new Date(start),usedAt:new Date(start)});
 const result=await f.handlers.report(f.request({start,end}));assert.equal(result.summary.revenueMinor,before.summary.revenueMinor+15000);assert.equal(result.summary.parkAdmissions,before.summary.parkAdmissions+1);assert.equal(result.topProducts[0].name,'Family pass');
 await assert.rejects(f.handlers.report(f.request({start,end},false)),e=>e.code==='permission-denied');
 assert.equal(result.summary.vouchersIssued,before.summary.vouchersIssued+1);assert.equal(result.summary.vouchersRedeemed,before.summary.vouchersRedeemed+1);assert.equal(result.summary.voucherUseEvents,before.summary.voucherUseEvents+1);
});

test('automatic weather benefits ignore late purchases and accounts closing or suspended',async()=>{
 const f=fixture(),suffix=randomUUID();await db.doc('parkSettings/weather').delete();await db.doc('parkWeather/2090-03-08').delete();
 await f.handlers.saveWeather(f.request({enabled:true,latitude:3.1,longitude:101.7,parkName:'Fixture park',rainThresholdMm:2,voucherBenefit:'Hot drink',validityDays:14}));
 const owners=['eligible','late','closing','suspended'].map(name=>({name,uid:'weather-'+name+'-'+suffix}));
 for(const p of owners){await db.doc('visitors/'+p.uid).set({fullName:'Weather '+p.name});await db.doc('tickets/'+p.uid).set({ownerUid:p.uid,version:2,status:'valid',visitDate:'2090-03-08',validUntil:'2090-03-08',createdAt:new Date(p.name==='late'?'2090-03-08T04:00:01Z':'2090-03-01T00:00:00Z')});}
 await db.doc('accountSecurity/'+owners[2].uid).set({closing:true});await db.doc('visitorAccess/'+owners[3].uid).set({status:'suspended'});
 await Promise.all([f.handlers.runWeather(),f.handlers.runWeather()]);
 for(const p of owners){const grants=await db.collection('compensationGrants').where('ownerUid','==',p.uid).get();assert.equal(grants.size,p.name==='eligible'?1:0);}
 await f.handlers.runWeather();assert.equal((await db.collection('compensationGrants').where('ownerUid','==',owners[0].uid).get()).size,1);
 assert.equal((await db.doc('parkWeather/2090-03-08').get()).data().benefitCursor,undefined);
});
