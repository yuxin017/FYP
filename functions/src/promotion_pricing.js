'use strict';
const {createHash}=require('node:crypto'),{HttpsError}=require('firebase-functions/v2/https');
const fail=message=>{throw new HttpsError('failed-precondition',message);};
async function promotionPrice({db,tx,code,scope,subtotal,uid,now}){
  if(!code)return{discountMinor:0};
  if(typeof code!=='string'||!/^[A-Z0-9_-]{2,32}$/.test(code))fail('Enter a valid promotion code.');
  const ref=db.doc('campaigns/'+code),usageRef=db.doc('campaignRedemptions/'+createHash('sha256').update(uid+'\0'+code).digest('hex'));
  const [saved,used]=await tx.getAll(ref,usageRef),offer=saved.data(),usage=used.data()?.count??0;
  if(!offer||offer.active!==true||!offer.scopes?.includes(scope)||!offer.startsAt?.toDate||!offer.endsAt?.toDate||offer.startsAt.toDate()>now||offer.endsAt.toDate()<=now)fail('This promotion is unavailable or has expired.');
  if(subtotal<(offer.minimumMinor??0))fail('The order does not meet this promotion’s minimum spend.');
  if(usage>=(offer.perUserLimit??1)||(offer.totalUsageLimit>0&&(offer.usageCount??0)>=offer.totalUsageLimit))fail('This promotion has reached its redemption limit.');
  const raw=offer.type==='percent'?Math.floor(subtotal*offer.value/100):offer.type==='fixed'?offer.value:NaN;
  if(!Number.isInteger(raw)||raw<0)fail('This promotion needs an administrator review.');
  return{discountMinor:Math.min(subtotal,raw,offer.maximumDiscountMinor>0?offer.maximumDiscountMinor:subtotal),ref,usageRef,offer,usage};
}
function recordPromotion(tx,promotion,uid,sourceId,FieldValue){
  if(!promotion.ref)return;
  tx.update(promotion.ref,{usageCount:(promotion.offer.usageCount??0)+1,updatedAt:FieldValue.serverTimestamp()});
  tx.set(promotion.usageRef,{ownerUid:uid,campaignId:promotion.ref.id,count:promotion.usage+1,lastSourceId:sourceId,updatedAt:FieldValue.serverTimestamp()});
}
module.exports={promotionPrice,recordPromotion};
