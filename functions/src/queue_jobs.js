'use strict';
const {FieldPath}=require('firebase-admin/firestore');
function createQueueJobs({db,FieldValue,clock=()=>new Date()}){
  let cursor;
  async function processNoShows(){
    const policy=(await db.doc('parkSettings/loyalty').get()).data(),effective=policy?.noShowEffectiveAt?.toDate?.();
    if(!policy?.noShowEnabled||!effective)return{processed:0};
    let query=db.collection('reservations').where('status','==','confirmed').orderBy(FieldPath.documentId());if(cursor)query=query.startAfter(cursor);
    const batch=await query.limit(100).get();cursor=batch.size===100?batch.docs.at(-1).id:undefined;let processed=0;
    for(const candidate of batch.docs){const old=candidate.data();if(!old.endsAt?.toDate||old.endsAt.toDate()>clock()||!old.createdAt?.toDate||old.createdAt.toDate()<effective)continue;
      const done=await db.runTransaction(async tx=>{
        const saved=await tx.get(candidate.ref),r=saved.data();if(!r||r.status!=='confirmed'||r.endsAt.toDate()>clock())return false;
        const slotRef=db.doc('attractionSlots/'+r.slotId),profileRef=db.doc('visitors/'+r.ownerUid),eventRef=db.doc('loyaltyEvents/no_show_'+saved.id),userRef=db.doc('reservationGuards/'+r.ownerUid),queueRef=db.doc('attractionQueueGuards/'+r.attractionId);
        const counterRef=db.doc('noShowCounters/'+r.ownerUid);
        const [slot,profile,event,user,queue,security,currentPolicy,counter]=await tx.getAll(slotRef,profileRef,eventRef,userRef,queueRef,db.doc('accountSecurity/'+r.ownerUid),db.doc('parkSettings/loyalty'),counterRef);
        const p=currentPolicy.data(),activeAt=p?.noShowEffectiveAt?.toDate?.();if(!p?.noShowEnabled||!activeAt||r.createdAt.toDate()<activeAt||security.data()?.closing)return false;
        const balance=profile.data()?.loyaltyPoints??0,penalty=p.noShowPenalty??0,threshold=p.noShowThreshold??2,count=slot.data()?.confirmedCount??slot.data()?.bookedCount;
        if(!profile.exists||!Number.isInteger(balance)||balance<0||!Number.isInteger(penalty)||penalty<0||penalty>10000||!Number.isInteger(threshold)||threshold<2||threshold>20||!Number.isInteger(count)||count<1)return false;
        // This private document serializes concurrent misses for one visitor.
        // Capacity guards are separate because other booking flows replace them.
        const previous=counter.data(),samePolicy=previous?.policyEffectiveAt?.toDate?.().getTime()===activeAt.getTime();
        const priorCount=samePolicy&&Number.isSafeInteger(previous.noShowCount)&&previous.noShowCount>=0?previous.noShowCount:0;
        const noShowCount=Math.min(priorCount+1,Number.MAX_SAFE_INTEGER);
        const deducted=!event.exists&&noShowCount>=threshold?Math.min(balance,penalty):0;
        tx.update(candidate.ref,{status:'no_show',noShowAt:FieldValue.serverTimestamp(),penaltyPoints:deducted,noShowCount,noShowThreshold:threshold});tx.update(slotRef,{confirmedCount:count-1});
        tx.set(counterRef,{ownerUid:r.ownerUid,policyEffectiveAt:activeAt,noShowCount,updatedAt:FieldValue.serverTimestamp()});
        if(deducted){tx.create(eventRef,{ownerUid:r.ownerUid,kind:'no_show',sourceId:saved.id,title:r.attractionName,delta:-deducted,createdAt:FieldValue.serverTimestamp()});tx.update(profileRef,{loyaltyPoints:balance-deducted,lastLoyaltyEventId:eventRef.id});}
        for(const [ref,snapshot]of [[userRef,user],[queueRef,queue]])tx.set(ref,{revision:(snapshot.data()?.revision??0)+1,updatedAt:FieldValue.serverTimestamp()});return true;
      });if(done)processed++;
    }
    return{processed};
  }
  return{processNoShows};
}
module.exports={createQueueJobs};
