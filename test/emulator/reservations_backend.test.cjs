const assert=require('node:assert/strict');
const {test}=require('node:test');
const crypto=require('node:crypto');
const admin=require('../../functions/node_modules/firebase-admin');
const {createReservationHandlers}=require('../../functions/src/reservations');
const project=process.env.GCLOUD_PROJECT;
if(!['demo-fyp-module1','demo-themepark-fyp'].includes(project)||!['127.0.0.1:8832','127.0.0.1:8080'].includes(process.env.FIRESTORE_EMULATOR_HOST))throw Error('Only the isolated local test database is allowed');
if(!admin.apps.length)admin.initializeApp({projectId:project});
const db=admin.firestore(),Timestamp=admin.firestore.Timestamp;
const prefix='booking-'+crypto.randomUUID();
const date=new Date(Date.now()+8*3600000);date.setUTCDate(date.getUTCDate()+1);
const day=date.toISOString().slice(0,10),now=new Date(`${day}T09:20:00+08:00`);
const handlers=createReservationHandlers({db,FieldValue:admin.firestore.FieldValue,clock:()=>now});
const stamp=(hour,minute)=>Timestamp.fromDate(new Date(`${day}T${String(hour).padStart(2,'0')}:${String(minute).padStart(2,'0')}:00+08:00`));
const auth=(uid)=>({uid,token:{email:`${uid}@example.com`,email_verified:true,auth_time:Math.floor(Date.now()/1000)}});
const request=(uid,slotId,ticketId,requestId=crypto.randomUUID())=>({auth:auth(uid),data:{slotId,ticketId,requestId}});
const cancellation=(uid,reservationId,requestId=crypto.randomUUID())=>({auth:auth(uid),data:{reservationId,requestId}});
async function fixture(label,{capacity=10,count=0,height=170,minHeight=100,status='open',ticketStatus='valid',ticketDay=day}={}){
 const uid=prefix+'-'+label,attractionId=uid+'-ride',slotId=uid+'-slot',ticketId=uid+'-ticket';
 await db.collection('visitors').doc(uid).set({fullName:'Reservation tester',heightCm:height});
 await db.collection('tickets').doc(ticketId).set({ownerUid:uid,visitDate:ticketDay,status:ticketStatus});
 await db.collection('attractions').doc(attractionId).set({name:'Ride '+label,status,minHeightCm:minHeight});
 await db.collection('attractionSlots').doc(slotId).set({attractionId,startsAt:stamp(10,0),endsAt:stamp(10,15),capacity,bookedCount:count,confirmedCount:count});
 return {uid,attractionId,slotId,ticketId};
}
const reason=(value)=>error=>error.details?.reason===value;

test('an assigned guest can reserve using the real purchaser-owned ticket schema',async()=>{
 const f=await fixture('assigned-guest');await db.collection('tickets').doc(f.ticketId).update({ownerUid:'another-purchaser',purchaserUid:'another-purchaser',guestEmail:`${f.uid}@example.com`,orderId:'real-order-reference',version:2});
 assert.equal((await handlers.reserveSlot(request(f.uid,f.slotId,f.ticketId))).status,'confirmed');
});
test('suspended, revoked, closing and unverified sessions cannot mutate reservation capacity',async()=>{
 for(const [label,collection,data,expected] of [['suspended','visitorAccess',{status:'suspended'},'account-restricted'],['revoked','accountSecurity',{revokedBefore:Math.floor(Date.now()/1000)},'session-ended'],['closing','accountSecurity',{closing:true},'session-ended']]){
  const f=await fixture(label);await db.collection(collection).doc(f.uid).set(data);await assert.rejects(handlers.reserveSlot(request(f.uid,f.slotId,f.ticketId)),reason(expected));assert.equal((await db.collection('attractionSlots').doc(f.slotId).get()).data().bookedCount,0);
 }
 const f=await fixture('unverified');const call=request(f.uid,f.slotId,f.ticketId);call.auth.token.email_verified=false;await assert.rejects(handlers.reserveSlot(call),reason('email-not-verified'));
});

const futureDay = new Date(date.getTime() + 86400000).toISOString().slice(0, 10);
function automaticId(attractionId, visitDate, time = '10:00') {
  const startsAt = Date.parse(visitDate + 'T' + time + ':00+08:00');
  return 'auto_' + attractionId + '_' + visitDate + '_' + startsAt;
}

test('matching future ticket creates an automatic window without a published schedule', async () => {
  const f = await fixture('future-auto', {ticketDay: futureDay});
  await db.collection('attractions').doc(f.attractionId).update({reservationCapacity: 24});
  const slotId = automaticId(f.attractionId, futureDay);
  const ref = db.collection('attractionSlots').doc(slotId);
  assert.equal((await ref.get()).exists, false);

  const call = request(f.uid, slotId, f.ticketId);
  const result = await handlers.reserveSlot(call);
  assert.deepEqual(await handlers.reserveSlot(call), result);
  const saved = (await ref.get()).data();
  assert.equal(saved.capacity, 24);
  assert.equal(saved.bookedCount, 1);
  assert.equal(saved.endsAt.toMillis() - saved.startsAt.toMillis(), 900000);
  assert.equal((await db.collection('reservations').doc(result.reservationId).get()).data().visitDate, futureDay);

  await handlers.cancelReservation(cancellation(f.uid, result.reservationId));
  assert.equal((await ref.get()).data().bookedCount, 0);
});

test('a wrong-date ticket or a closed attraction cannot materialize a return window', async () => {
  const f = await fixture('auto-ineligible');
  const slotId = automaticId(f.attractionId, futureDay);
  const ref = db.collection('attractionSlots').doc(slotId);
  await assert.rejects(handlers.reserveSlot(request(f.uid, slotId, f.ticketId)), reason('ticket-ineligible'));
  await db.collection('tickets').doc(f.ticketId).update({visitDate: futureDay});
  await db.collection('attractions').doc(f.attractionId).update({status: 'closed'});
  await assert.rejects(handlers.reserveSlot(request(f.uid, slotId, f.ticketId)), reason('ride-unavailable'));
  assert.equal((await ref.get()).exists, false);
});

test('automatic bookings cannot create a second window over an existing legacy time', async () => {
  const f = await fixture('auto-overlap-legacy');
  const slotId = automaticId(f.attractionId, day);
  await assert.rejects(handlers.reserveSlot(request(f.uid, slotId, f.ticketId)), reason('slot-unavailable'));
  assert.equal((await db.collection('attractionSlots').doc(slotId).get()).exists, false);
  assert.equal((await handlers.reserveSlot(request(f.uid, f.slotId, f.ticketId))).status, 'confirmed');
});

test('a map-only place cannot acquire a reservation window', async () => {
  const f = await fixture('map-only', {ticketDay: futureDay});
  const slotId = automaticId(f.attractionId, futureDay);
  for (const category of ['Dining', 'Facilities', 'Shops', 'Restaurant']) {
    await db.collection('attractions').doc(f.attractionId).update({category});
    await assert.rejects(handlers.reserveSlot(request(f.uid, slotId, f.ticketId)), reason('ride-unavailable'));
  }
  assert.equal((await db.collection('attractionSlots').doc(slotId).get()).exists, false);
});

test('concurrent first bookings for an automatic window respect its one-place capacity', async () => {
  const first = await fixture('auto-race-first', {ticketDay: futureDay});
  const second = await fixture('auto-race-second', {ticketDay: futureDay});
  await db.collection('attractions').doc(first.attractionId).update({reservationCapacity: 1});
  const slotId = automaticId(first.attractionId, futureDay);
  const results = await Promise.allSettled([
    handlers.reserveSlot(request(first.uid, slotId, first.ticketId)),
    handlers.reserveSlot(request(second.uid, slotId, second.ticketId)),
  ]);
  assert.equal(results.filter(result => result.status === 'fulfilled').length, 1);
  assert.equal(results.find(result => result.status === 'rejected').reason.details.reason, 'slot-full');
  assert.equal((await db.collection('attractionSlots').doc(slotId).get()).data().bookedCount, 1);
});

test('valid and used admission tickets create persisted reservations; retries consume one place',async()=>{
 for(const status of ['valid','used']){
  const f=await fixture('persist-'+status,{ticketStatus:status});const call=request(f.uid,f.slotId,f.ticketId);
  const first=await handlers.reserveSlot(call),again=await handlers.reserveSlot(call);assert.deepEqual(again,first);
  const reservation=(await db.collection('reservations').doc(first.reservationId).get()).data();assert.equal(reservation.ownerUid,f.uid);assert.equal(reservation.status,'confirmed');assert.ok(reservation.createdAt.toDate());
  const slot=(await db.collection('attractionSlots').doc(f.slotId).get()).data();assert.equal(slot.bookedCount,1);assert.equal(slot.confirmedCount,1);
 }
});
test('two visitors competing for the final place produce exactly one reservation',async()=>{
 const f=await fixture('final-place',{capacity:1}),other=await fixture('final-place-other');
 const outcomes=await Promise.allSettled([handlers.reserveSlot(request(f.uid,f.slotId,f.ticketId)),handlers.reserveSlot(request(other.uid,f.slotId,other.ticketId))]);
 assert.equal(outcomes.filter(r=>r.status==='fulfilled').length,1);assert.equal(outcomes.filter(r=>r.status==='rejected'&&r.reason.details.reason==='slot-full').length,1);
 assert.equal((await db.collection('attractionSlots').doc(f.slotId).get()).data().bookedCount,1);
});
test('same visitor racing different attractions at overlapping times gets only one booking',async()=>{
 const f=await fixture('overlap'),other=await fixture('overlap-other');
 const outcomes=await Promise.allSettled([handlers.reserveSlot(request(f.uid,f.slotId,f.ticketId)),handlers.reserveSlot(request(f.uid,other.slotId,f.ticketId))]);
 assert.equal(outcomes.filter(r=>r.status==='fulfilled').length,1);assert.equal(outcomes.find(r=>r.status==='rejected').reason.details.reason,'time-overlap');
});
test('different attractions with adjacent return windows are allowed; a second active booking for one ride is denied',async()=>{
 const f=await fixture('adjacent'),other=await fixture('adjacent-other');
 await db.collection('attractionSlots').doc(other.slotId).update({startsAt:stamp(10,15),endsAt:stamp(10,30)});
 await handlers.reserveSlot(request(f.uid,f.slotId,f.ticketId));await handlers.reserveSlot(request(f.uid,other.slotId,f.ticketId));
 const later=f.slotId+'-later';await db.collection('attractionSlots').doc(later).set({attractionId:f.attractionId,startsAt:stamp(11,0),endsAt:stamp(11,15),capacity:10,bookedCount:0,confirmedCount:0});
 await assert.rejects(handlers.reserveSlot(request(f.uid,later,f.ticketId)),reason('attraction-already-booked'));
});
test('cancellation releases capacity once, is private, and permits a new booking for the ride',async()=>{
 const f=await fixture('cancel');const booked=await handlers.reserveSlot(request(f.uid,f.slotId,f.ticketId));
 await assert.rejects(handlers.cancelReservation(cancellation('another-visitor',booked.reservationId)),reason('reservation-owner'));
 const call=cancellation(f.uid,booked.reservationId);await handlers.cancelReservation(call);await handlers.cancelReservation(call);await handlers.cancelReservation(cancellation(f.uid,booked.reservationId));
 let slot=(await db.collection('attractionSlots').doc(f.slotId).get()).data();assert.equal(slot.bookedCount,0);assert.equal(slot.confirmedCount,0);
 const next=await handlers.reserveSlot(request(f.uid,f.slotId,f.ticketId));assert.notEqual(next.reservationId,booked.reservationId);
 slot=(await db.collection('attractionSlots').doc(f.slotId).get()).data();assert.equal(slot.bookedCount,1);
});
test('request IDs are scoped to visitor and operation and cannot be reused for different inputs',async()=>{
 const f=await fixture('requests'),other=await fixture('requests-other'),requestId=crypto.randomUUID();
 const first=await handlers.reserveSlot(request(f.uid,f.slotId,f.ticketId,requestId));
 await assert.rejects(handlers.reserveSlot(request(f.uid,other.slotId,f.ticketId,requestId)),reason('request-mismatch'));
 await handlers.reserveSlot(request(other.uid,f.slotId,other.ticketId,requestId));
 await handlers.cancelReservation(cancellation(f.uid,first.reservationId,requestId));
});
test('closed, deleted, retired, full, past and out-of-hours sessions cannot be reserved',async()=>{
 for(const [label,change,expected] of [
  ['closed',{ride:{status:'closed'}},'ride-unavailable'],['deleted',{ride:{deletedAt:Timestamp.now()}},'ride-unavailable'],
  ['retired',{slot:{retired:true}},'ride-unavailable'],['full',{slot:{bookedCount:10,confirmedCount:10}},'slot-full'],
  ['past',{slot:{startsAt:stamp(8,0),endsAt:stamp(8,15)}},'slot-unavailable'],['outside',{slot:{startsAt:stamp(19,30),endsAt:stamp(19,45)}},'slot-unavailable'],
 ]){
  const f=await fixture(label);if(change.ride)await db.collection('attractions').doc(f.attractionId).update(change.ride);if(change.slot)await db.collection('attractionSlots').doc(f.slotId).update(change.slot);
  await assert.rejects(handlers.reserveSlot(request(f.uid,f.slotId,f.ticketId)),reason(expected));
 }
});
test('ticket ownership/date/status, guest identity and height are checked server-side',async()=>{
 for(const [label,options,expected] of [['height',{height:90},'height-ineligible'],['cancelled-ticket',{ticketStatus:'cancelled'},'ticket-ineligible'],['wrong-date',{ticketDay:'2000-01-01'},'ticket-ineligible']]){
  const f=await fixture(label,options);await assert.rejects(handlers.reserveSlot(request(f.uid,f.slotId,f.ticketId)),reason(expected));
 }
 const f=await fixture('foreign-ticket'),other=await fixture('ticket-owner');await assert.rejects(handlers.reserveSlot(request(f.uid,f.slotId,other.ticketId)),reason('ticket-owner'));
 await db.collection('tickets').doc(f.ticketId).update({guestEmail:'someone-else@example.com'});await assert.rejects(handlers.reserveSlot(request(f.uid,f.slotId,f.ticketId)),reason('ticket-guest'));
});

test('malformed ticket dates fail closed and a valid multi-day ticket covers the visit',async()=>{
 for(const [label,change] of [['invalid-day',{visitDate:'2026-02-31'}],['invalid-until',{validUntil:123}],['invalid-format',{visitDate:'1'}]]) {
  const f=await fixture(label);await db.collection('tickets').doc(f.ticketId).update(change);
  await assert.rejects(handlers.reserveSlot(request(f.uid,f.slotId,f.ticketId)),reason('ticket-ineligible'));
 }
 const f=await fixture('multi-day');
 await db.collection('tickets').doc(f.ticketId).update({visitDate:'2020-01-01',validUntil:day});
 const result=await handlers.reserveSlot(request(f.uid,f.slotId,f.ticketId));assert.equal(result.status,'confirmed');
});

test('completed requests replay even if a linked record is subsequently removed by trusted tools',async()=>{
 const f=await fixture('replay-retained'),call=request(f.uid,f.slotId,f.ticketId);
 const first=await handlers.reserveSlot(call);
 await db.collection('attractionSlots').doc(f.slotId).delete();
 assert.deepEqual(await handlers.reserveSlot(call),first);
 const g=await fixture('cancel-retained'),booked=await handlers.reserveSlot(request(g.uid,g.slotId,g.ticketId)),cancel=cancellation(g.uid,booked.reservationId);
 const cancelled=await handlers.cancelReservation(cancel);await db.collection('reservations').doc(booked.reservationId).delete();
 assert.deepEqual(await handlers.cancelReservation(cancel),cancelled);
});
test('live queue thresholds are revalidated; a non-offered start is rejected',async()=>{
 const f=await fixture('cadence',{capacity:200,count:50});
 await db.collection('attractionSlots').doc(f.slotId).update({startsAt:stamp(9,45),endsAt:stamp(10,0)});
 await assert.rejects(handlers.reserveSlot(request(f.uid,f.slotId,f.ticketId)),reason('queue-changed'));
 await db.collection('attractionSlots').doc(f.slotId).update({bookedCount:49,confirmedCount:49});
 await handlers.reserveSlot(request(f.uid,f.slotId,f.ticketId));assert.equal((await db.collection('attractionSlots').doc(f.slotId).get()).data().confirmedCount,50);
});
test('unauthenticated callers, injected identities/groups and checked-in cancellation are rejected',async()=>{
 const f=await fixture('inputs');await assert.rejects(handlers.reserveSlot({data:{slotId:f.slotId,ticketId:f.ticketId,requestId:crypto.randomUUID()}}),reason('sign-in-required'));
 await assert.rejects(handlers.reserveSlot({auth:auth(f.uid),data:{...request(f.uid,f.slotId,f.ticketId).data,ownerUid:'someone-else',quantity:4}}),reason('invalid-input'));
 const saved=await handlers.reserveSlot(request(f.uid,f.slotId,f.ticketId));await db.collection('reservations').doc(saved.reservationId).update({status:'checked_in'});
 await assert.rejects(handlers.cancelReservation(cancellation(f.uid,saved.reservationId)),reason('already-checked-in'));
});
