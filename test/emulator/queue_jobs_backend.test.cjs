'use strict';
const {test,after}=require('node:test'),assert=require('node:assert/strict'),{randomUUID}=require('node:crypto');
if(process.env.GCLOUD_PROJECT!=='demo-themepark-fyp'||process.env.FIRESTORE_EMULATOR_HOST!=='127.0.0.1:8080')throw Error('Queue checks require isolated fixtures.');
const admin=require('../../functions/node_modules/firebase-admin');if(!admin.apps.length)admin.initializeApp({projectId:process.env.GCLOUD_PROJECT});const db=admin.firestore(),{FieldValue}=admin.firestore,{createQueueJobs}=require('../../functions/src/queue_jobs');
after(async()=>{await db.doc('parkSettings/loyalty').delete();});
test('missed return windows settle once, never make balances negative, and exclude old policy periods',async()=>{
 const prefix=randomUUID(),now=new Date('2092-01-02T05:00:00Z'),uid='missed-'+prefix,slotId='missed-slot-'+prefix,reservationId='missed-reservation-'+prefix;
 await db.doc('parkSettings/loyalty').set({noShowEnabled:true,noShowPenalty:20,noShowEffectiveAt:new Date('2092-01-01T00:00:00Z')});await db.doc('visitors/'+uid).set({loyaltyPoints:7});await db.doc('attractionSlots/'+slotId).set({bookedCount:2,confirmedCount:2});
 const data={ownerUid:uid,attractionId:'missed-attraction-'+prefix,attractionName:'Fixture ride',slotId,status:'confirmed',createdAt:new Date('2092-01-02T00:00:00Z'),endsAt:new Date('2092-01-02T04:00:00Z')};
 await db.doc('reservations/'+reservationId).set(data);await db.doc('reservations/old-'+prefix).set({...data,createdAt:new Date('2091-12-01T00:00:00Z')});
 const jobs=createQueueJobs({db,FieldValue,clock:()=>now});await Promise.all([jobs.processNoShows(),jobs.processNoShows()]);
 assert.equal((await db.doc('reservations/'+reservationId).get()).data().status,'no_show');assert.equal((await db.doc('reservations/old-'+prefix).get()).data().status,'confirmed');assert.equal((await db.doc('visitors/'+uid).get()).data().loyaltyPoints,0);assert.equal((await db.doc('loyaltyEvents/no_show_'+reservationId).get()).data().delta,-7);assert.equal((await db.doc('attractionSlots/'+slotId).get()).data().confirmedCount,1);
 await jobs.processNoShows();assert.equal((await db.doc('attractionSlots/'+slotId).get()).data().confirmedCount,1);
});
