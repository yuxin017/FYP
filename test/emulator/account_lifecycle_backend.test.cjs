'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),{randomUUID}=require('node:crypto');
if(process.env.GCLOUD_PROJECT!=='demo-themepark-fyp'||process.env.FIRESTORE_EMULATOR_HOST!=='127.0.0.1:8080')throw Error('Account lifecycle checks require isolated fixtures.');
const admin=require('../../functions/node_modules/firebase-admin');if(!admin.apps.length)admin.initializeApp({projectId:process.env.GCLOUD_PROJECT});
const db=admin.firestore(),{FieldValue}=admin.firestore,{createAccountLifecycle}=require('../../functions/src/account_lifecycle');
const lifecycle=createAccountLifecycle({db,FieldValue});
test('past return windows cannot permanently block account closure',async()=>{const uid='past-closure-'+randomUUID();await db.doc('reservations/'+uid).set({ownerUid:uid,status:'confirmed',endsAt:new Date('2020-01-01')});await lifecycle.beginClosure(uid,new Date());assert.equal((await db.doc('accountSecurity/'+uid).get()).data().closing,true);});
test('an organiser cannot close an account while non-riding members still hold its group reservation',async()=>{
  const id=randomUUID(),uid='closing-'+id;
  await db.doc('groupBookings/'+id).set({ownerUid:uid,memberUids:['another-member'],reservationIds:[id]});
  await db.doc('reservations/'+id).set({ownerUid:'another-member',groupBookingId:id,status:'confirmed'});
  await assert.rejects(lifecycle.beginClosure(uid,new Date()),e=>e.code==='active-reservation');
  assert.equal((await db.doc('accountSecurity/'+uid).get()).exists,false);
  await db.doc('reservations/'+id).update({status:'cancelled'});await lifecycle.beginClosure(uid,new Date());assert.equal((await db.doc('accountSecurity/'+uid).get()).data().closing,true);
});
test('group cleanup transfers ownership, revokes invitations and removes the deleted visitor’s guests and location',async()=>{
  const id=randomUUID(),uid='closing-'+id,next='remaining-'+id;
  await db.doc('groups/'+id).set({ownerUid:uid,memberUids:[uid,next],inviteCode:'old-invitation'});
  for(const [member,owner]of [[uid,uid],[next,next],['guest',uid]])await db.doc('groupMembers/'+id+'_'+member).set({groupId:id,ownerUid:owner,memberId:member});
  await db.doc('groupLocations/'+id).set({groupId:id,ownerUid:uid,latitude:3,longitude:101});await db.doc('groupInvites/'+id).set({groupId:id});
  await lifecycle.cleanupGroups(uid);await lifecycle.cleanupGroups(uid);
  const group=(await db.doc('groups/'+id).get()).data();assert.equal(group.ownerUid,next);assert.deepEqual(group.memberUids,[next]);assert.equal(group.inviteCode,'');
  const members=await db.collection('groupMembers').where('groupId','==',id).get();assert.equal(members.size,1);assert.equal(members.docs[0].data().ownerUid,next);
  assert.equal((await db.doc('groupLocations/'+id).get()).exists,false);assert.equal((await db.doc('groupInvites/'+id).get()).exists,false);
});
