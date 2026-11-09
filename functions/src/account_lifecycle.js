'use strict';
function createAccountLifecycle({db,FieldValue}) { return {
  async beginClosure(uid, now) {
    const store=db;
    return store.runTransaction(async tx=>{
      const security=store.doc('accountSecurity/'+uid),saved=await tx.get(security);
      const owned=await tx.get(store.collection('reservations').where('ownerUid','==',uid));
      const groups=await tx.get(store.collection('groupBookings').where('ownerUid','==',uid));
      const activeReservation=r=>r.status==='confirmed'&&(!r.endsAt?.toDate||r.endsAt.toDate()>now);
      let active=owned.docs.some(d=>activeReservation(d.data()));
      for(const booking of groups.docs){
        const members=await tx.get(store.collection('reservations').where('groupBookingId','==',booking.id));
        active ||= members.docs.some(d=>activeReservation(d.data()));
      }
      if(active)throw Object.assign(Error('Active attraction reservations'),{code:'active-reservation'});
      tx.set(security,{...saved.data(),closing:true,closingAt:now});
      tx.set(store.doc('accountClosures/'+uid),{status:'deleting',updatedAt:now},{merge:true});
    });
  },
  async cleanupGroups(uid) {
    const store=db;
    const memberships=await store.collection('groupMembers').where('ownerUid','==',uid).get();
    const owned=await store.collection('groups').where('ownerUid','==',uid).get();
    const ids=new Set([...memberships.docs.map(d=>d.data().groupId),...owned.docs.map(d=>d.id)]);
    for(const id of ids)await store.runTransaction(async tx=>{
      const ref=store.doc('groups/'+id),saved=await tx.get(ref);if(!saved.exists)return;
      const group=saved.data(),remaining=group.memberUids.filter(value=>value!==uid);
      const [members,locations,invites]=await Promise.all([
        tx.get(store.collection('groupMembers').where('groupId','==',id)),
        tx.get(store.collection('groupLocations').where('groupId','==',id)),
        tx.get(store.collection('groupInvites').where('groupId','==',id)),
      ]);
      const erase=remaining.length===0;
      for(const collection of [members,locations])for(const d of collection.docs)if(erase||d.data().ownerUid===uid)tx.delete(d.ref);
      if(erase){for(const d of invites.docs)tx.delete(d.ref);tx.delete(ref);}
      else{
        const nextOwner=group.ownerUid===uid?remaining[0]:group.ownerUid;
        // An old organiser's invitation is invalidated when ownership changes.
        if(group.ownerUid===uid)for(const d of invites.docs)tx.delete(d.ref);
        tx.update(ref,{ownerUid:nextOwner,memberUids:remaining,...(group.ownerUid===uid?{inviteCode:'',inviteExpiresAt:new Date(0)}:{}),updatedAt:FieldValue.serverTimestamp()});
      }
    });
  },
}; }
module.exports={createAccountLifecycle};
