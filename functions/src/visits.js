'use strict';
const {HttpsError}=require('firebase-functions/v2/https');
const fail=(code,message)=>{throw new HttpsError(code,message);};
const identifier=value=>typeof value==='string'&&/^[A-Za-z0-9_-]{1,160}$/.test(value);
const date=value=>value?.toDate?.();
const categories=['Queue experience','Staff service','Ride experience','Accessibility'];
function createVisitHandlers({db,FieldValue,clock=()=>new Date()}){
  function context(request){
    if(!request.auth?.uid||request.auth.token?.email_verified!==true)fail('unauthenticated','Please sign in with a verified account.');
    if(!identifier(request.data?.reservationId))fail('invalid-argument','Choose a valid attraction reservation.');
    return db.collection('reservations').doc(request.data.reservationId);
  }
  async function open(tx,uid){
    const [access,security]=await tx.getAll(db.doc('visitorAccess/'+uid),db.doc('accountSecurity/'+uid));
    if(access.exists&&access.data().status!=='active')fail('permission-denied','This visitor account is restricted. Please contact support.');
    if(security.data()?.closing)fail('permission-denied','This account is being closed.');
  }
  async function checkIn(request){
    const ref=context(request);
    if(request.auth.token.admin!==true)fail('permission-denied','An administrator must scan attraction entrance passes.');
    return db.runTransaction(async tx=>{
      const saved=await tx.get(ref),r=saved.data();
      if(!r)fail('not-found','Attraction pass not found.');
      await open(tx,r.ownerUid);
      if(r.status==='checked_in')return{reservationId:ref.id,status:r.status,points:r.earnedPoints??0,alreadyCheckedIn:true};
      if(r.status!=='confirmed')fail('failed-precondition','This attraction pass is no longer available for entry.');
      const now=clock(),start=date(r.startsAt),end=date(r.endsAt);
      if(!start||!end||now<start||now>=end)fail('failed-precondition','Entry is available only during the return window on this pass.');
      const slotRef=db.doc('attractionSlots/'+r.slotId),profileRef=db.doc('visitors/'+r.ownerUid),queueRef=db.doc('attractionQueueGuards/'+r.attractionId),userRef=db.doc('reservationGuards/'+r.ownerUid),eventRef=db.doc('loyaltyEvents/ride_'+ref.id);
      const [session,profile,ride,ticket,settings,queue,user,event]=await tx.getAll(slotRef,profileRef,db.doc('attractions/'+r.attractionId),db.doc('tickets/'+r.ticketId),db.doc('parkSettings/loyalty'),queueRef,userRef,eventRef);
      const slot=session.data(),pass=ticket.data(),owner=profile.data();
      if(!owner||!slot||ride.data()?.status!=='open')fail('failed-precondition','The visitor or attraction is unavailable.');
      if(!pass||!['valid','used'].includes(pass.status)||pass.visitDate>r.visitDate||(pass.validUntil??pass.visitDate)<r.visitDate)fail('failed-precondition','The admission ticket no longer covers this visit.');
      let organisedGuest=false;
      if(identifier(r.groupId)&&identifier(r.memberId)){
        const [group,member]=await tx.getAll(db.doc('groups/'+r.groupId),db.doc('groupMembers/'+r.groupId+'_'+r.memberId)),m=member.data();
        organisedGuest=m?.isGuest===true&&m.ownerUid===r.ownerUid&&m.ticketId===r.ticketId&&pass.ownerUid===r.ownerUid&&group.data()?.ownerUid===r.ownerUid;
      }
      if(!organisedGuest&&((pass.guestEmail&&pass.guestEmail.toLowerCase()!==String(owner.email??'').toLowerCase())||(!pass.guestEmail&&pass.ownerUid!==r.ownerUid)))fail('permission-denied','The admission ticket is assigned to another visitor.');
      const remaining=slot.confirmedCount??slot.bookedCount;
      if(!Number.isInteger(remaining)||remaining<1||remaining>slot.bookedCount)fail('failed-precondition','The attraction queue needs an administrator review.');
      const configured=settings.data()?.ridePoints??10,points=Number.isInteger(configured)&&configured>=0&&configured<=10000?configured:10;
      const balance=owner.loyaltyPoints??0;
      if(!Number.isInteger(balance)||balance<0)fail('failed-precondition','The visitor points balance needs an administrator review.');
      tx.update(ref,{status:'checked_in',checkedInAt:FieldValue.serverTimestamp(),checkedInBy:request.auth.uid,earnedPoints:event.exists?event.data().delta:points});
      tx.update(slotRef,{confirmedCount:remaining-1});
      if(!event.exists&&points>0){
        tx.create(eventRef,{ownerUid:r.ownerUid,kind:'ride',sourceId:ref.id,title:r.attractionName,delta:points,createdAt:FieldValue.serverTimestamp()});
        tx.update(profileRef,{loyaltyPoints:balance+points,lastLoyaltyEventId:eventRef.id});
      }
      for(const [guard,snapshot]of [[queueRef,queue],[userRef,user]])tx.set(guard,{revision:(snapshot.data()?.revision??0)+1,updatedAt:FieldValue.serverTimestamp()});
      tx.create(db.doc('rideAdmissions/'+ref.id),{ownerUid:r.ownerUid,ticketId:r.ticketId,reservationId:ref.id,attractionId:r.attractionId,attractionName:r.attractionName,actorUid:request.auth.uid,createdAt:FieldValue.serverTimestamp()});
      return{reservationId:ref.id,status:'checked_in',points,alreadyCheckedIn:false};
    });
  }
  async function rate(request){
    const ref=context(request),data=request.data;
    if(!Number.isInteger(data.stars)||data.stars<1||data.stars>5||!Array.isArray(data.categories)||data.categories.some(v=>!categories.includes(v))||data.categories.length>4||typeof data.message!=='string'||data.message.length>500||typeof data.anonymous!=='boolean')fail('invalid-argument','Choose a rating from one to five stars and review your feedback.');
    if(data.photoBase64!==undefined&&(typeof data.photoBase64!=='string'||data.photoBase64.length>280000||!data.photoBase64.startsWith('/9j/')))fail('invalid-argument','Choose a JPEG photo smaller than 200 KB.');
    return db.runTransaction(async tx=>{
      const saved=await tx.get(ref),r=saved.data();
      if(!r||r.ownerUid!==request.auth.uid)fail('permission-denied','Choose your own attraction visit.');
      await open(tx,r.ownerUid);
      if(r.status!=='checked_in'||!date(r.endsAt)||date(r.endsAt)>clock())fail('failed-precondition','You can rate an attraction after completing your visit.');
      const ratingRef=db.doc('attractionRatings/'+ref.id),rideRef=db.doc('attractions/'+r.attractionId);
      const [prior,ride,security]=await tx.getAll(ratingRef,rideRef,db.doc('accountSecurity/'+r.ownerUid));
      if(security.data()?.revokedBefore>=(request.auth.token.auth_time??0))fail('unauthenticated','Your session has ended. Please sign in again.');
      if(prior.exists)return{reservationId:ref.id,submitted:true,alreadySubmitted:true};
      if(!ride.exists)fail('not-found','This attraction is no longer available.');
      const count=ride.data().ratingCount??0,average=ride.data().ratingAverage??0;
      if(!Number.isInteger(count)||count<0||!Number.isFinite(average)||average<0||average>5)fail('failed-precondition','Attraction ratings need an administrator review.');
      tx.create(ratingRef,{ownerUid:r.ownerUid,attractionId:r.attractionId,reservationId:ref.id,stars:data.stars,categories:[...new Set(data.categories)],message:data.message.trim(),anonymous:data.anonymous,createdAt:FieldValue.serverTimestamp()});
      if(data.photoBase64)tx.create(db.doc('attractionRatingAttachments/'+ref.id),{ownerUid:r.ownerUid,imageBase64:data.photoBase64,createdAt:FieldValue.serverTimestamp()});
      tx.update(rideRef,{ratingCount:count+1,ratingAverage:(average*count+data.stars)/(count+1)});
      tx.update(ref,{ratedAt:FieldValue.serverTimestamp(),ratingStars:data.stars});
      return{reservationId:ref.id,submitted:true,alreadySubmitted:false};
    });
  }
  return{checkIn,rate};
}
module.exports={createVisitHandlers};
