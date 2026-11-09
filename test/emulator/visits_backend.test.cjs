'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),{randomUUID}=require('node:crypto');
if(process.env.GCLOUD_PROJECT!=='demo-themepark-fyp'||process.env.FIRESTORE_EMULATOR_HOST!=='127.0.0.1:8080')throw Error('Visit checks require the isolated local fixture project.');
const admin=require('../../functions/node_modules/firebase-admin');
if(!admin.apps.length)admin.initializeApp({projectId:process.env.GCLOUD_PROJECT});
const db=admin.firestore(),{Timestamp,FieldValue}=admin.firestore;
const {createVisitHandlers}=require('../../functions/src/visits');
let now=new Date('2088-10-04T04:00:00Z');
const handlers=createVisitHandlers({db,FieldValue,clock:()=>now});
async function fixture(){
  now=new Date('2088-10-04T04:00:00Z');const id=randomUUID(),uid='visit-'+id;
  const reservation={ownerUid:uid,ticketId:id,attractionId:id,slotId:id,status:'confirmed',visitDate:'2088-10-04',attractionName:'River Rapids',startsAt:Timestamp.fromDate(now),endsAt:Timestamp.fromDate(new Date(now.getTime()+900000))};
  await Promise.all([db.doc('reservations/'+id).set(reservation),db.doc('visitors/'+uid).set({email:uid+'@example.com',loyaltyPoints:40}),db.doc('tickets/'+id).set({ownerUid:uid,status:'valid',visitDate:reservation.visitDate}),db.doc('attractions/'+id).set({name:'River Rapids',status:'open'}),db.doc('attractionSlots/'+id).set({capacity:10,bookedCount:1,confirmedCount:1})]);
  const request={auth:{uid:'staff',token:{admin:true,email_verified:true}},data:{reservationId:id}};
  const rating={auth:{uid,token:{email_verified:true,auth_time:Math.floor(now.getTime()/1000)}},data:{reservationId:id,stars:4,categories:['Ride experience'],message:'A lovely ride',anonymous:true}};
  return{id,uid,request,rating};
}
test('concurrent entrance scans admit once, preserve capacity and award one real points event',async()=>{
  const f=await fixture();const results=await Promise.all([handlers.checkIn(f.request),handlers.checkIn(f.request)]);
  assert.equal(results.filter(r=>!r.alreadyCheckedIn).length,1);
  assert.equal((await db.doc('visitors/'+f.uid).get()).data().loyaltyPoints,50);
  assert.equal((await db.doc('attractionSlots/'+f.id).get()).data().confirmedCount,0);
  assert.equal((await db.doc('attractionSlots/'+f.id).get()).data().bookedCount,1);
  assert.equal((await db.doc('loyaltyEvents/ride_'+f.id).get()).data().delta,10);
});
test('visitors, cancelled passes, early/late scans and restricted accounts cannot be admitted',async()=>{
  const f=await fixture();await assert.rejects(handlers.checkIn({...f.request,auth:{uid:f.uid,token:{email_verified:true}}}),e=>e.code==='permission-denied');
  now=new Date('2088-10-04T03:59:59Z');await assert.rejects(handlers.checkIn(f.request),e=>e.code==='failed-precondition');
  now=new Date('2088-10-04T04:15:00Z');await assert.rejects(handlers.checkIn(f.request),e=>e.code==='failed-precondition');
  now=new Date('2088-10-04T04:05:00Z');await db.doc('visitorAccess/'+f.uid).set({status:'suspended'});await assert.rejects(handlers.checkIn(f.request),e=>e.code==='permission-denied');
  await db.doc('visitorAccess/'+f.uid).delete();await db.doc('reservations/'+f.id).update({status:'cancelled'});await assert.rejects(handlers.checkIn(f.request),e=>e.code==='failed-precondition');
  assert.equal((await db.doc('visitors/'+f.uid).get()).data().loyaltyPoints,40);
});
test('ratings require ownership and a completed visit; replay cannot inflate the public average',async()=>{
  const f=await fixture();await assert.rejects(handlers.rate(f.rating),e=>e.code==='failed-precondition');
  await handlers.checkIn(f.request);await assert.rejects(handlers.rate(f.rating),e=>e.code==='failed-precondition');
  now=new Date('2088-10-04T04:16:00Z');await assert.rejects(handlers.rate({...f.rating,auth:{uid:'stranger',token:{email_verified:true}}}),e=>e.code==='permission-denied');
  await Promise.all([handlers.rate(f.rating),handlers.rate(f.rating)]);
  const ride=(await db.doc('attractions/'+f.id).get()).data();assert.equal(ride.ratingCount,1);assert.equal(ride.ratingAverage,4);
  assert.equal((await db.doc('attractionRatings/'+f.id).get()).data().anonymous,true);
  await assert.rejects(handlers.rate({...f.rating,data:{...f.rating.data,stars:9}}),e=>e.code==='invalid-argument');
});
test('assigned admission tickets remain usable only by their verified guest',async()=>{
  const f=await fixture();await db.doc('tickets/'+f.id).update({ownerUid:'purchaser',guestEmail:f.uid+'@example.com'});
  assert.equal((await handlers.checkIn(f.request)).status,'checked_in');
  const other=await fixture();await db.doc('tickets/'+other.id).update({guestEmail:'someone-else@example.com'});
  await assert.rejects(handlers.checkIn(other.request),e=>e.code==='permission-denied');
});
test('organiser-owned group guest passes can enter without pretending the guest is the organiser’s account',async()=>{
  const f=await fixture(),groupId='guest-group-'+f.id,memberId='guest-member-'+f.id;
  await db.doc('groups/'+groupId).set({ownerUid:f.uid,memberUids:[f.uid]});await db.doc('groupMembers/'+groupId+'_'+memberId).set({groupId,memberId,ownerUid:f.uid,isGuest:true,ticketId:f.id});
  await db.doc('reservations/'+f.id).update({groupId,memberId});await db.doc('tickets/'+f.id).update({guestEmail:'actual-guest@example.test'});
  assert.equal((await handlers.checkIn(f.request)).status,'checked_in');
  const other=await fixture();await db.doc('reservations/'+other.id).update({groupId,memberId});await db.doc('tickets/'+other.id).update({guestEmail:'another-guest@example.test'});
  await assert.rejects(handlers.checkIn(other.request),e=>e.code==='permission-denied');
});
