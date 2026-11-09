'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),{randomUUID}=require('node:crypto');
if(process.env.GCLOUD_PROJECT!=='demo-themepark-fyp'||process.env.FIRESTORE_EMULATOR_HOST!=='127.0.0.1:8080')throw Error('Group checks require the isolated fixture database.');
const admin=require('../../functions/node_modules/firebase-admin');if(!admin.apps.length)admin.initializeApp({projectId:process.env.GCLOUD_PROJECT});
const db=admin.firestore(),{FieldValue,Timestamp}=admin.firestore,{createGroupHandlers}=require('../../functions/src/groups');
const now=new Date('2088-10-04T01:20:00Z'),handlers=createGroupHandlers({db,FieldValue,clock:()=>now});
const auth=uid=>({uid,token:{email:uid+'@example.com',email_verified:true,auth_time:Math.floor(now.getTime()/1000)}});
const call=(uid,data)=>({auth:auth(uid),data});
async function fixture(capacity=4){
  const owner='group-'+randomUUID(),guest='member-'+randomUUID(),ride='ride-'+randomUUID(),day='2088-10-04',slot='slot-'+randomUUID();
  for(const uid of [owner,guest])await db.doc('visitors/'+uid).set({fullName:uid,email:uid+'@example.com',heightCm:170});
  const result=await handlers.create(call(owner,{name:'Park Friends',description:'A day together',visitDate:day,icon:'friends',requestId:randomUUID()})),groupId=result.groupId;
  const code=(await db.doc('groups/'+groupId).get()).data().inviteCode;
  await handlers.join(call(guest,{code}));
  for(const uid of [owner,guest]){await db.doc('tickets/'+uid).set({ownerUid:uid,status:'valid',visitDate:day});await handlers.link(call(uid,{groupId,memberId:uid,ticketId:uid}));}
  await db.doc('attractions/'+ride).set({name:'River Rapids',status:'open',category:'Water rides',minHeightCm:100});
  await db.doc('attractionSlots/'+slot).set({attractionId:ride,startsAt:Timestamp.fromDate(new Date('2088-10-04T02:00:00Z')),endsAt:Timestamp.fromDate(new Date('2088-10-04T02:15:00Z')),capacity,bookedCount:0,confirmedCount:0});
  return{owner,guest,ride,slot,groupId,code};
}
test('group invitations, ownership and per-member ticket linking cannot be forged',async()=>{
  const f=await fixture();await assert.rejects(handlers.link(call(f.owner,{groupId:f.groupId,memberId:f.guest,ticketId:f.owner})),e=>e.code==='permission-denied');
  await assert.rejects(handlers.update(call(f.guest,{groupId:f.groupId,name:'Changed',description:'',visitDate:'2088-10-04',icon:'castle'})),e=>e.code==='permission-denied');
  await handlers.invite(call(f.owner,{groupId:f.groupId}));await assert.rejects(handlers.join(call('stranger',{code:f.code})),e=>e.code==='not-found');
});
test('insufficient capacity or one ineligible member produces no partial group reservation',async()=>{
  const f=await fixture(1),data={groupId:f.groupId,slotId:f.slot,memberIds:[f.owner,f.guest],requestId:randomUUID()};
  await assert.rejects(handlers.reserve(call(f.owner,data)),e=>e.code==='resource-exhausted');assert.equal((await db.doc('attractionSlots/'+f.slot).get()).data().bookedCount,0);
  await db.doc('attractionSlots/'+f.slot).update({capacity:4});await db.doc('visitors/'+f.guest).update({heightCm:80});
  await assert.rejects(handlers.reserve(call(f.owner,data)),e=>e.code==='failed-precondition');assert.equal((await db.collection('reservations').where('groupId','==',f.groupId).get()).size,0);
});
test('atomic group booking and cancellation are idempotent and protect overlapping member times',async()=>{
  const f=await fixture(),data={groupId:f.groupId,slotId:f.slot,memberIds:[f.owner,f.guest],requestId:randomUUID()};
  const result=await handlers.reserve(call(f.owner,data));assert.deepEqual(await handlers.reserve(call(f.owner,data)),result);assert.equal((await db.doc('attractionSlots/'+f.slot).get()).data().bookedCount,2);
  assert.equal((await db.collection('reservations').where('groupId','==',f.groupId).get()).size,2);
  await assert.rejects(handlers.reserve(call(f.owner,{...data,requestId:randomUUID()})),e=>e.code==='already-exists');
  await assert.rejects(handlers.remove(call(f.owner,{groupId:f.groupId,memberId:f.guest})),e=>e.code==='failed-precondition');
  await handlers.cancel(call(f.owner,{bookingId:result.bookingId}));await handlers.cancel(call(f.owner,{bookingId:result.bookingId}));assert.equal((await db.doc('attractionSlots/'+f.slot).get()).data().bookedCount,0);
  await handlers.remove(call(f.owner,{groupId:f.groupId,memberId:f.guest}));assert.deepEqual((await db.doc('groups/'+f.groupId).get()).data().memberUids,[f.owner]);
});
test('only current members can share their own valid location and stop sharing removes it',async()=>{
  const f=await fixture();await assert.rejects(handlers.location(call('outsider',{groupId:f.groupId,latitude:3,longitude:101,accuracy:5})),e=>e.code==='permission-denied');
  await handlers.location(call(f.guest,{groupId:f.groupId,uid:f.owner,latitude:3,longitude:101,accuracy:5}));
  assert.equal((await db.doc('groupLocations/'+f.groupId+'_'+f.guest).get()).data().ownerUid,f.guest);
  await handlers.location(call(f.guest,{groupId:f.groupId,sharing:false}));assert.equal((await db.doc('groupLocations/'+f.groupId+'_'+f.guest).get()).exists,false);
});
test('a group and an individual racing for the same capacity cannot partially overbook',async()=>{
  const {createReservationHandlers}=require('../../functions/src/reservations');
  const individual=createReservationHandlers({db,FieldValue,clock:()=>now}),f=await fixture(2),uid='individual-'+randomUUID();
  await db.doc('visitors/'+uid).set({fullName:'Another visitor',email:uid+'@example.com',heightCm:170});await db.doc('tickets/'+uid).set({ownerUid:uid,status:'valid',visitDate:'2088-10-04'});
  const result=await Promise.allSettled([handlers.reserve(call(f.owner,{groupId:f.groupId,slotId:f.slot,memberIds:[f.owner,f.guest],requestId:randomUUID()})),individual.reserveSlot(call(uid,{slotId:f.slot,ticketId:uid,requestId:randomUUID()}))]);
  assert.equal(result.filter(r=>r.status==='fulfilled').length,1);
  const expected=result[0].status==='fulfilled'?2:1;
  assert.equal((await db.doc('attractionSlots/'+f.slot).get()).data().bookedCount,expected);
  assert.equal((await db.collection('reservations').where('slotId','==',f.slot).get()).size,expected);
});
