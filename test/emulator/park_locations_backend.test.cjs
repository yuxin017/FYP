'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),{randomUUID}=require('node:crypto');
if(process.env.GCLOUD_PROJECT!=='demo-themepark-fyp'||process.env.FIRESTORE_EMULATOR_HOST!=='127.0.0.1:8080')throw Error('Location checks require isolated fixtures.');
const admin=require('../../functions/node_modules/firebase-admin');if(!admin.apps.length)admin.initializeApp({projectId:process.env.GCLOUD_PROJECT});const db=admin.firestore();
const {createParkLocationHandlers}=require('../../functions/src/park_locations'),{createPrivateRecordCleanup}=require('../../server/private_record_cleanup.cjs');
function fixture(t){
 const uid='location-'+randomUUID(),calls=[],venue={north:2,south:1,east:4,west:3};let now=new Date('2099-01-01T04:00:00Z');
 const handlers=createParkLocationHandlers({db,venue,clock:()=>now,ai:{async call(operation,data){calls.push({operation,data});return{size:2,values:[0,1,1,0],queuePlaces:data.points.reduce((n,p)=>n+p.weight,0)};}}});
 const request=(data={},staff=false)=>({auth:{uid,token:{email_verified:true,admin:staff,auth_time:Math.floor(now.getTime()/1000)}},data});
 const fix=sessionId=>({sessionId,latitude:1.9,longitude:3.1,accuracy:8,source:'gps',observedAt:now.toISOString(),uid:'other-not-trusted'});
 t.after(async()=>{const rows=await db.collection('parkLocationSamples').where('ownerUid','==',uid).get();const batch=db.batch();for(const doc of rows.docs)batch.delete(doc.ref);batch.delete(db.doc('parkLocations/'+uid));await batch.commit();});
 return{uid,handlers,request,fix,calls,advance(ms){now=new Date(now.getTime()+ms);},clock:()=>now};
}
test('location sharing requires consent, verified identity, a current accurate fix and the selected venue boundary',async t=>{
 const f=fixture(t);await assert.rejects(f.handlers.start(f.request({consent:false})),e=>e.code==='invalid-argument');await assert.rejects(f.handlers.start({auth:null,data:{consent:true}}),e=>e.code==='unauthenticated');
 const {sessionId}=await f.handlers.start(f.request({consent:true}));
 for(const patch of [{accuracy:81},{latitude:0},{source:'indooratlas'},{source:'invented-wifi'},{observedAt:'2000-01-01'},{observedAt:'2200-01-01'}])await assert.rejects(f.handlers.update(f.request({...f.fix(sessionId),...patch})));
 assert.equal((await f.handlers.update(f.request(f.fix(sessionId)))).updated,true);assert.equal((await db.doc('parkLocations/'+f.uid).get()).data().ownerUid,f.uid);
 assert.equal((await f.handlers.update(f.request(f.fix(sessionId)))).updated,false);
});
test('stopping or replacing a location session blocks late updates and stale stop requests cannot stop a newer session',async t=>{
 const f=fixture(t),a=await f.handlers.start(f.request({consent:true}));await f.handlers.update(f.request(f.fix(a.sessionId)));await f.handlers.stop(f.request(a));f.advance(30000);
 await assert.rejects(f.handlers.update(f.request(f.fix(a.sessionId))),e=>e.code==='failed-precondition');
 const b=await f.handlers.start(f.request({consent:true}));await f.handlers.stop(f.request(a));assert.equal((await f.handlers.update(f.request(f.fix(b.sessionId)))).updated,true);
});
test('KDE and movement responses disclose aggregates only, expire live fixes and count people once per hour',async t=>{
 const f=fixture(t),session=await f.handlers.start(f.request({consent:true}));await f.handlers.update(f.request(f.fix(session.sessionId)));
 const grid=await f.handlers.density(f.request());assert.equal(grid.visitorCount,1);assert.equal(grid.source,'Shared live visitor locations');assert.equal(grid.queuePlaces,undefined);assert.equal(JSON.stringify(grid).includes(f.uid),false);assert.deepEqual(Object.keys(f.calls[0].data.points[0]).sort(),['weight','x','y']);
 f.advance(61000);assert.equal((await f.handlers.update(f.request({...f.fix(session.sessionId),latitude:1.1,longitude:3.9}))).updated,true);
 await assert.rejects(f.handlers.summary(f.request()),e=>e.code==='permission-denied');const report=await f.handlers.summary(f.request({},true));assert.equal(report.hourly.find(h=>h.hour===12).visitors,1);assert.equal(report.flows.find(x=>x.from==='A1'&&x.to==='D4').count,1);assert.equal(JSON.stringify(report).includes(f.uid),false);
 f.advance(121000);assert.equal((await f.handlers.density(f.request())).visitorCount,0);
 f.advance(86400000);const expired=await f.handlers.summary(f.request({},true));assert.equal(expired.flows.length,0);
 await createPrivateRecordCleanup({db,clock:f.clock})();assert.equal((await db.doc('parkLocations/'+f.uid).get()).exists,false);
});
