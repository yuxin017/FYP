'use strict';
const {test,after}=require('node:test'),assert=require('node:assert/strict'),{randomUUID}=require('node:crypto');
if(process.env.GCLOUD_PROJECT!=='demo-themepark-fyp'||process.env.FIRESTORE_EMULATOR_HOST!=='127.0.0.1:8080')throw Error('Queue checks require isolated fixtures.');
const admin=require('../../functions/node_modules/firebase-admin');if(!admin.apps.length)admin.initializeApp({projectId:process.env.GCLOUD_PROJECT});const db=admin.firestore(),{FieldValue}=admin.firestore,{createQueueJobs}=require('../../functions/src/queue_jobs');
after(async()=>{await db.doc('parkSettings/loyalty').delete();});
test('first missed return window keeps points and still releases capacity exactly once',async()=>{
 const prefix=randomUUID(),now=new Date('2092-01-02T05:00:00Z'),uid='missed-'+prefix,slotId='missed-slot-'+prefix,reservationId='missed-reservation-'+prefix;
 await db.doc('parkSettings/loyalty').set({noShowEnabled:true,noShowPenalty:20,noShowEffectiveAt:new Date('2092-01-01T00:00:00Z')});await db.doc('visitors/'+uid).set({loyaltyPoints:7});await db.doc('attractionSlots/'+slotId).set({bookedCount:2,confirmedCount:2});
 const data={ownerUid:uid,attractionId:'missed-attraction-'+prefix,attractionName:'Fixture ride',slotId,status:'confirmed',createdAt:new Date('2092-01-02T00:00:00Z'),endsAt:new Date('2092-01-02T04:00:00Z')};
 await db.doc('reservations/'+reservationId).set(data);await db.doc('reservations/old-'+prefix).set({...data,createdAt:new Date('2091-12-01T00:00:00Z')});
 const jobs=createQueueJobs({db,FieldValue,clock:()=>now});await Promise.all([jobs.processNoShows(),jobs.processNoShows()]);
 const missed=(await db.doc('reservations/'+reservationId).get()).data();assert.equal(missed.status,'no_show');assert.equal(missed.penaltyPoints,0);assert.equal(missed.noShowCount,1);assert.equal(missed.noShowThreshold,2);assert.equal((await db.doc('reservations/old-'+prefix).get()).data().status,'confirmed');assert.equal((await db.doc('visitors/'+uid).get()).data().loyaltyPoints,7);assert.equal((await db.doc('loyaltyEvents/no_show_'+reservationId).get()).exists,false);assert.equal((await db.doc('attractionSlots/'+slotId).get()).data().confirmedCount,1);
 await jobs.processNoShows();assert.equal((await db.doc('attractionSlots/'+slotId).get()).data().confirmedCount,1);
 assert.equal((await db.doc('noShowCounters/'+uid).get()).data().noShowCount,1);
});

test('concurrent repeated misses count once each and cap deductions at the available balance',async()=>{
 const prefix=randomUUID(),uid='repeated-'+prefix,slotId='repeated-slot-'+prefix,now=new Date('2092-01-02T05:00:00Z');
 await db.doc('parkSettings/loyalty').set({noShowEnabled:true,noShowPenalty:20,noShowThreshold:2,noShowEffectiveAt:new Date('2092-01-01T00:00:00Z')});
 await db.doc('visitors/'+uid).set({loyaltyPoints:27});await db.doc('attractionSlots/'+slotId).set({confirmedCount:3});
 const refs=[0,1,2].map(i=>db.doc('reservations/repeated-'+prefix+'-'+i));
 for(const ref of refs)await ref.set({ownerUid:uid,attractionId:'ride-'+prefix,attractionName:'Fixture ride',slotId,status:'confirmed',createdAt:new Date('2092-01-02T00:00:00Z'),endsAt:new Date('2092-01-02T04:00:00Z')});
 const jobs=()=>createQueueJobs({db,FieldValue,clock:()=>now});await Promise.all([jobs().processNoShows(),jobs().processNoShows()]);
 const results=(await db.getAll(...refs)).map(s=>s.data());assert.deepEqual(results.map(r=>r.noShowCount).sort(),[1,2,3]);assert.deepEqual(results.map(r=>r.penaltyPoints).sort((a,b)=>a-b),[0,7,20]);
 assert.equal((await db.doc('visitors/'+uid).get()).data().loyaltyPoints,0);assert.equal((await db.doc('attractionSlots/'+slotId).get()).data().confirmedCount,0);assert.equal((await db.doc('noShowCounters/'+uid).get()).data().noShowCount,3);
 const events=await db.collection('loyaltyEvents').where('ownerUid','==',uid).get();assert.equal(events.size,2);assert.equal(events.docs.reduce((sum,d)=>sum+d.data().delta,0),-27);
 await jobs().processNoShows();assert.equal((await db.doc('noShowCounters/'+uid).get()).data().noShowCount,3);assert.equal((await db.doc('visitors/'+uid).get()).data().loyaltyPoints,0);
});

test('a new policy starts a fresh missed-reservation count and honours its configured threshold',async()=>{
 const prefix=randomUUID(),uid='reset-'+prefix,slotId='reset-slot-'+prefix,effective=new Date('2092-01-02T00:00:00Z');
 await db.doc('parkSettings/loyalty').set({noShowEnabled:true,noShowPenalty:10,noShowThreshold:3,noShowEffectiveAt:effective});await db.doc('visitors/'+uid).set({loyaltyPoints:50});await db.doc('attractionSlots/'+slotId).set({confirmedCount:3});await db.doc('noShowCounters/'+uid).set({ownerUid:uid,noShowCount:9,policyEffectiveAt:new Date('2092-01-01T00:00:00Z')});
 const jobs=createQueueJobs({db,FieldValue,clock:()=>new Date('2092-01-03T00:00:00Z')});
 for(let i=1;i<=3;i++){
  const ref=db.doc('reservations/reset-'+prefix+'-'+i);await ref.set({ownerUid:uid,attractionId:'ride-'+prefix,attractionName:'Fixture ride',slotId,status:'confirmed',createdAt:effective,endsAt:new Date('2092-01-02T04:00:00Z')});await jobs.processNoShows();const saved=(await ref.get()).data();assert.equal(saved.noShowCount,i);assert.equal(saved.penaltyPoints,i===3?10:0);
 }
 assert.equal((await db.doc('visitors/'+uid).get()).data().loyaltyPoints,40);
});
