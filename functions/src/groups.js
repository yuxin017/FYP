'use strict';
const crypto=require('node:crypto');
const {HttpsError}=require('firebase-functions/v2/https');
const {dayKey,offered,bookingPolicy:p}=require('./reservations');
const hash=value=>crypto.createHash('sha256').update(value).digest('hex');
const fail=(code,message)=>{throw new HttpsError(code,message);};
const identifier=value=>typeof value==='string'&&/^[A-Za-z0-9_-]{1,160}$/.test(value);
const instant=value=>value?.toDate?.();
const memberKey=(group,member)=>group+'_'+member;
function createGroupHandlers({db,FieldValue,clock=()=>new Date()}){
  function caller(request){if(!request.auth?.uid||request.auth.token?.email_verified!==true)fail('unauthenticated','Sign in with a verified account.');return request.auth.uid;}
  function dataId(value){if(!identifier(value))fail('invalid-argument','Choose a valid group or ticket.');return value;}
  async function permitted(tx,uid,token){
    const [a,s]=await tx.getAll(db.doc('visitorAccess/'+uid),db.doc('accountSecurity/'+uid));
    if(a.exists&&a.data().status!=='active')fail('permission-denied','This account is restricted. Please contact support.');
    if(s.data()?.closing||(token&&s.data()?.revokedBefore>=(token.auth_time??0)))fail('unauthenticated','Your session has ended. Please sign in again.');
  }
  function requireMember(group,uid){if(!group||!group.memberUids?.includes(uid))fail('permission-denied','This group is unavailable to your account.');}
  function leader(group,uid){requireMember(group,uid);if(group.ownerUid!==uid)fail('permission-denied','Only the group organiser can make this change.');}
  const activeReservation=r=>r.status==='confirmed'&&(!instant(r.endsAt)||instant(r.endsAt)>clock());
  function form(data,previousDay){
    if(typeof data.name!=='string'||data.name.trim().length<2||data.name.trim().length>60||typeof data.description!=='string'||data.description.length>300||!p.validDay(data.visitDate)||(data.visitDate<dayKey(clock())&&data.visitDate!==previousDay)||data.visitDate>dayKey(new Date(clock().getTime()+365*86400000))||!['castle','family','friends','adventure'].includes(data.icon))fail('invalid-argument','Enter a group name, icon and a visit date within the next year.');
    return{name:data.name.trim(),description:data.description.trim(),visitDate:data.visitDate,icon:data.icon};
  }
  async function automaticTicket(tx,uid,email,day){
    const owned=await tx.get(db.collection('tickets').where('ownerUid','==',uid));
    const assigned=email?await tx.get(db.collection('tickets').where('guestEmail','==',email.toLowerCase())):{docs:[]};
    const candidates=[...new Map([...owned.docs,...assigned.docs].map(d=>[d.id,d])).values()].filter(d=>ticketFits(d.data(),uid,email,day,false));
    return candidates.length===1?candidates[0].id:null;
  }
  async function create(request){
    const uid=caller(request),data=form(request.data);dataId(request.data.requestId);
    const groupId=hash(uid+'\0'+request.data.requestId),ref=db.doc('groups/'+groupId),code=crypto.randomBytes(16).toString('hex');
    return db.runTransaction(async tx=>{
      await permitted(tx,uid,request.auth.token);const [old,profile]=await tx.getAll(ref,db.doc('visitors/'+uid));
      if(old.exists){if(JSON.stringify(data)!==JSON.stringify(Object.fromEntries(Object.keys(data).map(k=>[k,old.data()[k]]))))fail('already-exists','This request was used for a different group.');return{groupId};}
      if(!profile.exists)fail('failed-precondition','Complete your visitor profile first.');
      const memberships=await tx.get(db.collection('groups').where('memberUids','array-contains',uid));if(memberships.size>=20)fail('resource-exhausted','You can belong to up to 20 groups.');
      const ticketId=await automaticTicket(tx,uid,request.auth.token.email,data.visitDate);
      tx.create(ref,{...data,ownerUid:uid,memberUids:[uid],inviteCode:code,inviteExpiresAt:new Date(clock().getTime()+86400000),createdAt:FieldValue.serverTimestamp(),updatedAt:FieldValue.serverTimestamp()});
      tx.create(db.doc('groupMembers/'+memberKey(groupId,uid)),{groupId,memberId:uid,ownerUid:uid,displayName:profile.data().fullName??'Visitor',avatarBase64:profile.data().profilePhotoBase64??null,isGuest:false,ticketId,createdAt:FieldValue.serverTimestamp()});
      tx.create(db.doc('groupInvites/'+hash(code)),{groupId,expiresAt:new Date(clock().getTime()+86400000)});
      return{groupId};
    });
  }
  async function join(request){
    const uid=caller(request),code=String(request.data.code??'').trim().replace(/^TPGROUP1:/,'').toLowerCase();
    if(!/^[a-f0-9]{32}$/.test(code))fail('invalid-argument','Enter a valid group invitation code.');
    return db.runTransaction(async tx=>{
      await permitted(tx,uid,request.auth.token);const invite=await tx.get(db.doc('groupInvites/'+hash(code))),details=invite.data();
      if(!details||!instant(details.expiresAt)||instant(details.expiresAt)<=clock())fail('not-found','This invitation has expired. Ask the organiser for a new one.');
      const ref=db.doc('groups/'+details.groupId),[saved,profile]=await tx.getAll(ref,db.doc('visitors/'+uid)),group=saved.data();
      if(!group||group.inviteCode!==code)fail('not-found','This invitation is no longer available.');
      if(group.memberUids.includes(uid))return{groupId:ref.id};
      const currentMembers=await tx.get(db.collection('groupMembers').where('groupId','==',ref.id));
      if(currentMembers.size>=20)fail('resource-exhausted','This group is full.');
      if(!profile.exists)fail('failed-precondition','Complete your visitor profile before joining.');
      const memberships=await tx.get(db.collection('groups').where('memberUids','array-contains',uid));if(memberships.size>=20)fail('resource-exhausted','You can belong to up to 20 groups.');
      const ticketId=await automaticTicket(tx,uid,request.auth.token.email,group.visitDate);
      tx.update(ref,{memberUids:[...group.memberUids,uid],updatedAt:FieldValue.serverTimestamp()});
      tx.create(db.doc('groupMembers/'+memberKey(ref.id,uid)),{groupId:ref.id,memberId:uid,ownerUid:uid,displayName:profile.data().fullName??'Visitor',avatarBase64:profile.data().profilePhotoBase64??null,isGuest:false,ticketId,createdAt:FieldValue.serverTimestamp()});
      return{groupId:ref.id};
    });
  }
  async function update(request){
    const uid=caller(request),groupId=dataId(request.data.groupId);
    return db.runTransaction(async tx=>{
      await permitted(tx,uid,request.auth.token);const ref=db.doc('groups/'+groupId),saved=await tx.get(ref),group=saved.data();leader(group,uid);
      const values=form(request.data,group.visitDate);
      if(group.visitDate!==values.visitDate){const reservations=await tx.get(db.collection('reservations').where('groupId','==',groupId));if(reservations.docs.some(d=>activeReservation(d.data())))fail('failed-precondition','Cancel upcoming group reservations before changing the visit date.');}
      tx.update(ref,{...values,updatedAt:FieldValue.serverTimestamp()});return{groupId};
    });
  }
  async function invite(request){
    const uid=caller(request),groupId=dataId(request.data.groupId),code=crypto.randomBytes(16).toString('hex');
    return db.runTransaction(async tx=>{await permitted(tx,uid,request.auth.token);const ref=db.doc('groups/'+groupId),saved=await tx.get(ref);leader(saved.data(),uid);
      tx.delete(db.doc('groupInvites/'+hash(saved.data().inviteCode)));
      tx.update(ref,{inviteCode:code,inviteExpiresAt:new Date(clock().getTime()+86400000),updatedAt:FieldValue.serverTimestamp()});tx.create(db.doc('groupInvites/'+hash(code)),{groupId,expiresAt:new Date(clock().getTime()+86400000)});return{code,expiresAt:new Date(clock().getTime()+86400000).toISOString()};});
  }
  async function addGuest(request){
    const uid=caller(request),groupId=dataId(request.data.groupId),name=request.data.name,height=request.data.heightCm;
    if(typeof name!=='string'||name.trim().length<2||name.trim().length>80||!Number.isInteger(height)||height<0||height>250)fail('invalid-argument','Enter the guest name and height in centimetres.');
    dataId(request.data.requestId);const memberId='guest_'+hash(uid+'\0'+request.data.requestId).slice(0,32);
    return db.runTransaction(async tx=>{await permitted(tx,uid,request.auth.token);const group=await tx.get(db.doc('groups/'+groupId));leader(group.data(),uid);const members=await tx.get(db.collection('groupMembers').where('groupId','==',groupId)),ref=db.doc('groupMembers/'+memberKey(groupId,memberId)),old=await tx.get(ref);if(old.exists)return{memberId};if(members.size>=20)fail('resource-exhausted','This group is full.');tx.create(ref,{groupId,memberId,ownerUid:uid,displayName:name.trim(),heightCm:height,isGuest:true,ticketId:null,createdAt:FieldValue.serverTimestamp()});return{memberId};});
  }
  async function editGuest(request){
    const uid=caller(request),groupId=dataId(request.data.groupId),memberId=dataId(request.data.memberId),name=request.data.name,height=request.data.heightCm;
    if(typeof name!=='string'||name.trim().length<2||name.trim().length>80||!Number.isInteger(height)||height<0||height>250)fail('invalid-argument','Enter the guest name and height in centimetres.');
    return db.runTransaction(async tx=>{
      await permitted(tx,uid,request.auth.token);const group=await tx.get(db.doc('groups/'+groupId));leader(group.data(),uid);
      const ref=db.doc('groupMembers/'+memberKey(groupId,memberId)),saved=await tx.get(ref);if(saved.data()?.isGuest!==true)fail('invalid-argument','Choose a guest member. App users manage their own profile.');
      const reservations=await tx.get(db.collection('reservations').where('groupId','==',groupId));if(reservations.docs.some(d=>d.data().memberId===memberId&&activeReservation(d.data())))fail('failed-precondition','Cancel the guest’s upcoming reservation before changing their details.');
      tx.update(ref,{displayName:name.trim(),heightCm:height,updatedAt:FieldValue.serverTimestamp()});return{saved:true};
    });
  }
  function ticketFits(ticket,uid,email,day,guest){
    if(!ticket||!['valid','used'].includes(ticket.status)||!p.validDay(ticket.visitDate)||!p.validDay(ticket.validUntil??ticket.visitDate)||ticket.visitDate>day||(ticket.validUntil??ticket.visitDate)<day)return false;
    if(guest)return ticket.ownerUid===uid&&!ticket.guestEmail;
    return ticket.guestEmail?ticket.guestEmail.toLowerCase()===String(email??'').toLowerCase():ticket.ownerUid===uid;
  }
  async function tickets(request){
    const uid=caller(request),groupId=dataId(request.data.groupId),memberId=dataId(request.data.memberId);
    const group=(await db.doc('groups/'+groupId).get()).data();requireMember(group,uid);
    const member=(await db.doc('groupMembers/'+memberKey(groupId,memberId)).get()).data();if(!member||(!member.isGuest&&member.ownerUid!==uid)||(member.isGuest&&group.ownerUid!==uid))fail('permission-denied','Each app user links their own ticket. The organiser links guest tickets.');
    const owned=await db.collection('tickets').where('ownerUid','==',uid).get(),assigned=request.auth.token.email?await db.collection('tickets').where('guestEmail','==',request.auth.token.email.toLowerCase()).get():{docs:[]};
    const options=new Map([...owned.docs,...assigned.docs].map(d=>[d.id,d]));
    return{tickets:[...options.values()].filter(d=>ticketFits(d.data(),uid,request.auth.token.email,group.visitDate,member.isGuest)).map(d=>({id:d.id,label:d.data().packageName??'Admission ticket',guestName:d.data().guestName??'',visitDate:d.data().visitDate,validUntil:d.data().validUntil??d.data().visitDate}))};
  }
  async function link(request){
    const uid=caller(request),groupId=dataId(request.data.groupId),memberId=dataId(request.data.memberId),ticketId=dataId(String(request.data.ticketId??'').replace(/^TP1:/,''));
    return db.runTransaction(async tx=>{await permitted(tx,uid,request.auth.token);const group=(await tx.get(db.doc('groups/'+groupId))).data();requireMember(group,uid);const ref=db.doc('groupMembers/'+memberKey(groupId,memberId)),[member,pass]=await tx.getAll(ref,db.doc('tickets/'+ticketId)),m=member.data();
      if(!m||(!m.isGuest&&m.ownerUid!==uid)||(m.isGuest&&group.ownerUid!==uid))fail('permission-denied','Each app user links their own ticket. The organiser links guest tickets.');
      if(!ticketFits(pass.data(),uid,request.auth.token.email,group.visitDate,m.isGuest))fail('failed-precondition','Choose an eligible admission ticket for this visitor and visit date.');
      const members=await tx.get(db.collection('groupMembers').where('groupId','==',groupId));if(members.docs.some(d=>d.id!==ref.id&&d.data().ticketId===ticketId))fail('already-exists','This ticket is already linked to another member.');
      const active=await tx.get(db.collection('reservations').where('groupId','==',groupId));if(active.docs.some(d=>d.data().memberId===memberId&&activeReservation(d.data())))fail('failed-precondition','Cancel this member’s upcoming group reservation before changing their ticket.');
      tx.update(ref,{ticketId,updatedAt:FieldValue.serverTimestamp()});return{linked:true};
    });
  }
  async function remove(request){
    const uid=caller(request),groupId=dataId(request.data.groupId),memberId=dataId(request.data.memberId);
    return db.runTransaction(async tx=>{await permitted(tx,uid,request.auth.token);const ref=db.doc('groups/'+groupId),saved=await tx.get(ref),g=saved.data();requireMember(g,uid);if(uid!==g.ownerUid&&uid!==memberId)fail('permission-denied','Only the organiser can remove another member.');if(memberId===g.ownerUid)fail('failed-precondition','The organiser must delete the group instead of leaving it.');const memberRef=db.doc('groupMembers/'+memberKey(groupId,memberId)),m=await tx.get(memberRef);if(!m.exists)return{removed:true};const bookings=await tx.get(db.collection('reservations').where('groupId','==',groupId));if(bookings.docs.some(d=>d.data().memberId===memberId&&activeReservation(d.data())))fail('failed-precondition','Cancel the upcoming group reservation before removing this member.');tx.delete(memberRef);tx.delete(db.doc('groupLocations/'+memberKey(groupId,memberId)));if(!m.data().isGuest)tx.update(ref,{memberUids:g.memberUids.filter(id=>id!==memberId),updatedAt:FieldValue.serverTimestamp()});return{removed:true};});
  }
  async function erase(request){
    const uid=caller(request),groupId=dataId(request.data.groupId);return db.runTransaction(async tx=>{await permitted(tx,uid,request.auth.token);const ref=db.doc('groups/'+groupId),saved=await tx.get(ref);leader(saved.data(),uid);const [members,locations,bookings,invites]=await Promise.all([tx.get(db.collection('groupMembers').where('groupId','==',groupId)),tx.get(db.collection('groupLocations').where('groupId','==',groupId)),tx.get(db.collection('reservations').where('groupId','==',groupId)),tx.get(db.collection('groupInvites').where('groupId','==',groupId))]);if(bookings.docs.some(d=>activeReservation(d.data())))fail('failed-precondition','Cancel upcoming group reservations before deleting the group.');for(const collection of [members,locations,invites])for(const d of collection.docs)tx.delete(d.ref);tx.delete(ref);return{deleted:true};});
  }
  async function location(request){
    const uid=caller(request),groupId=dataId(request.data.groupId),v=request.data;
    if(v.sharing!==false&&(!Number.isFinite(v.latitude)||v.latitude< -90||v.latitude>90||!Number.isFinite(v.longitude)||v.longitude< -180||v.longitude>180||!Number.isFinite(v.accuracy)||v.accuracy<0||v.accuracy>10000))fail('invalid-argument','A valid device location is required.');
    return db.runTransaction(async tx=>{await permitted(tx,uid,request.auth.token);const g=(await tx.get(db.doc('groups/'+groupId))).data();requireMember(g,uid);const ref=db.doc('groupLocations/'+memberKey(groupId,uid));if(v.sharing===false)tx.delete(ref);else tx.set(ref,{groupId,ownerUid:uid,latitude:v.latitude,longitude:v.longitude,accuracy:v.accuracy,source:'device',updatedAt:FieldValue.serverTimestamp(),expiresAt:new Date(clock().getTime()+120000)});return{sharing:v.sharing!==false};});
  }
  async function reserve(request){
    const uid=caller(request),groupId=dataId(request.data.groupId),slotId=dataId(request.data.slotId),requestId=dataId(request.data.requestId),selection=request.data.memberIds;
    if(requestId.length<16||!Array.isArray(selection)||!selection.length||selection.length>20||new Set(selection).size!==selection.length||selection.some(v=>!identifier(v)))fail('invalid-argument','Select between one and twenty group members.');
    const bookingId=hash(uid+'\0group\0'+requestId),bundle=db.doc('groupBookings/'+bookingId),automatic=p.automaticWindow(slotId),slotRef=db.doc('attractionSlots/'+slotId),initial=automatic?null:await slotRef.get();
    const attractionId=dataId(automatic?.attractionId??initial?.data()?.attractionId),fingerprint=JSON.stringify({groupId,slotId,members:[...selection].sort()});
    return db.runTransaction(async tx=>{
      await permitted(tx,uid,request.auth.token);const [saved,old]=await tx.getAll(db.doc('groups/'+groupId),bundle),group=saved.data();leader(group,uid);if(old.exists){if(old.data().fingerprint!==fingerprint)fail('already-exists','This request belongs to a different group reservation.');return{bookingId,status:old.data().status};}
      const memberDocs=await tx.getAll(...selection.map(id=>db.doc('groupMembers/'+memberKey(groupId,id))));
      const members=memberDocs.map(d=>d.data());if(members.some(m=>!m?.ticketId))fail('failed-precondition','Link a valid ticket for every selected member first.');
      if(new Set(members.map(m=>m.ticketId)).size!==members.length)fail('failed-precondition','Each guest needs a separate admission ticket.');
      const [session,rideDoc]=await tx.getAll(slotRef,db.doc('attractions/'+attractionId)),ride=rideDoc.data(),stored=session.data(),materialize=automatic&&(!stored||(stored.retired&&stored.bookedCount===0)),slot=materialize?{...automatic,capacity:ride?.reservationCapacity??10,bookedCount:0,confirmedCount:0}:stored;
      if(!slot||!ride||ride.deletedAt||ride.status!=='open'||p.nonRideCategory.test(ride.category)||slot.retired||slot.attractionId!==attractionId||!p.validWindow(slot)||instant(slot.startsAt)<=clock()||dayKey(instant(slot.startsAt))!==group.visitDate)fail('failed-precondition','Choose an open attraction and a future return window on the group visit date.');
      const start=instant(slot.startsAt),end=instant(slot.endsAt);
      if(automatic&&stored&&(instant(stored.startsAt)?.getTime()!==instant(automatic.startsAt).getTime()||instant(stored.endsAt)?.getTime()!==instant(automatic.endsAt).getTime()))fail('failed-precondition','This return window has changed. Refresh the available times.');
      const queues=await tx.get(db.collection('attractionSlots').where('attractionId','==',attractionId));
      if(materialize&&queues.docs.some(d=>d.id!==slotId&&(!d.data().retired||d.data().bookedCount>0)&&instant(d.data().startsAt)<end&&start<instant(d.data().endsAt)))fail('failed-precondition','This return time has changed. Choose another.');
      if(!offered(slot,p.queueSize(queues.docs,group.visitDate,clock())))fail('failed-precondition','The queue changed. Refresh the return times.');
      const counts=p.counters(slot);if(counts.bookedCount+members.length>counts.capacity)fail('resource-exhausted','There are not enough places for the whole group at this time.');
      const locks=new Map();for(const m of members){
        await permitted(tx,m.ownerUid,m.ownerUid===uid?request.auth.token:null);
        const [pass,profile]=await tx.getAll(db.doc('tickets/'+m.ticketId),db.doc('visitors/'+m.ownerUid));
        if(!ticketFits(pass.data(),m.ownerUid,profile.data()?.email,group.visitDate,m.isGuest))fail('failed-precondition',m.displayName+' needs a valid admission ticket for this visit.');
        const height=m.isGuest?m.heightCm:profile.data()?.heightCm;
        if(!Number.isInteger(ride.minHeightCm)||ride.minHeightCm<0||(ride.minHeightCm>0&&(!Number.isInteger(height)||height<ride.minHeightCm)))fail('failed-precondition',m.displayName+' does not meet the attraction height requirement.');
        const existing=await tx.get(db.collection('reservations').where(m.isGuest?'ticketId':'ownerUid','==',m.isGuest?m.ticketId:m.ownerUid));
        for(const booking of existing.docs){const r=booking.data();if(!['confirmed','checked_in'].includes(r.status))continue;const a=instant(r.startsAt),b=instant(r.endsAt);if(!a||!b)fail('failed-precondition','A member’s existing reservation needs an administrator review.');if(dayKey(a)!==group.visitDate)continue;if(r.attractionId===attractionId||start<b&&a<end)fail('already-exists',m.displayName+' already has this attraction or an overlapping return time.');}
        for(const path of ['reservationGuards/'+m.ownerUid,'ticketReservationGuards/'+m.ticketId])if(!locks.has(path))locks.set(path,await tx.get(db.doc(path)));
      }
      const queueRef=db.doc('attractionQueueGuards/'+attractionId),queueLock=await tx.get(queueRef);locks.set(queueRef.path,queueLock);
      const reservationIds=members.map(m=>hash(bookingId+'\0'+m.memberId));
      members.forEach((m,i)=>tx.create(db.doc('reservations/'+reservationIds[i]),{ownerUid:m.ownerUid,groupId,groupName:group.name,groupBookingId:bookingId,memberId:m.memberId,guestName:m.displayName,ticketId:m.ticketId,attractionId,attractionName:ride.name,slotId,status:'confirmed',visitDate:group.visitDate,startsAt:slot.startsAt,endsAt:slot.endsAt,createdAt:FieldValue.serverTimestamp(),requestId}));
      const updated={bookedCount:counts.bookedCount+members.length,confirmedCount:counts.confirmedCount+members.length};if(materialize)tx.set(slotRef,{...slot,...updated});else tx.update(slotRef,updated);
      for(const [path,snapshot]of locks)tx.set(db.doc(path),{revision:(snapshot.data()?.revision??0)+1,updatedAt:FieldValue.serverTimestamp()});
      tx.create(bundle,{groupId,ownerUid:uid,memberUids:[...new Set(members.map(m=>m.ownerUid))],reservationIds,attractionId,attractionName:ride.name,startsAt:slot.startsAt,endsAt:slot.endsAt,status:'confirmed',fingerprint,createdAt:FieldValue.serverTimestamp()});
      return{bookingId,status:'confirmed'};
    });
  }
  async function cancel(request){
    const uid=caller(request),bookingId=dataId(request.data.bookingId),ref=db.doc('groupBookings/'+bookingId);
    return db.runTransaction(async tx=>{await permitted(tx,uid,request.auth.token);const saved=await tx.get(ref),b=saved.data();if(!b||b.ownerUid!==uid)fail('permission-denied','Only the organiser can cancel this group booking.');if(b.status==='cancelled')return{cancelled:true};if(instant(b.endsAt)&&instant(b.endsAt)<=clock())fail('failed-precondition','This group return window has ended. Open the entrance passes to view its history.');const reservations=await tx.getAll(...b.reservationIds.map(id=>db.doc('reservations/'+id)));if(reservations.some(d=>d.data()?.status==='checked_in'))fail('failed-precondition','A group that has checked in cannot be cancelled.');const confirmed=reservations.filter(d=>d.data()?.status==='confirmed'),slots=new Map(),guards=new Map();for(const r of confirmed){const v=r.data();if(!slots.has(v.slotId))slots.set(v.slotId,{saved:await tx.get(db.doc('attractionSlots/'+v.slotId)),count:0});slots.get(v.slotId).count++;for(const path of ['reservationGuards/'+v.ownerUid,'attractionQueueGuards/'+v.attractionId])if(!guards.has(path))guards.set(path,await tx.get(db.doc(path)));}for(const [slotId,{saved:s,count}]of slots){const c=p.counters(s.data());if(c.bookedCount<count||c.confirmedCount<count)fail('failed-precondition','The queue needs an administrator review.');tx.update(db.doc('attractionSlots/'+slotId),{bookedCount:c.bookedCount-count,confirmedCount:c.confirmedCount-count});}for(const r of confirmed)tx.update(r.ref,{status:'cancelled',cancelledAt:FieldValue.serverTimestamp()});for(const [path,s]of guards)tx.set(db.doc(path),{revision:(s.data()?.revision??0)+1,updatedAt:FieldValue.serverTimestamp()});tx.update(ref,{status:'cancelled',cancelledAt:FieldValue.serverTimestamp()});return{cancelled:true};});
  }
  return{create,join,update,invite,addGuest,editGuest,tickets,link,remove,erase,location,reserve,cancel};
}
module.exports={createGroupHandlers};
