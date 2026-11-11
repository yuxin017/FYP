'use strict';
const crypto=require('node:crypto'),{HttpsError}=require('firebase-functions/v2/https'),{promotionPrice,recordPromotion}=require('./promotion_pricing');
const fail=(code,message)=>{throw new HttpsError(code,message);},validId=v=>typeof v==='string'&&/^[\w-]{1,100}$/.test(v),day=d=>new Date(d.getTime()+8*3600000).toISOString().slice(0,10),reference=(id,date)=>'TP-'+date.replaceAll('-','').slice(2)+'-'+id.slice(0,8).toUpperCase();
function createTicketPromotionHandlers({db,FieldValue,exchangeRates,clock=()=>new Date()}){
  const currency=d=>d.paymentCurrency??'MYR';
  const basket=(d,total)=>crypto.createHash('sha256').update(JSON.stringify({lines:d.lines,guests:d.guests,pointsUsed:d.pointsUsed??0,promoCode:d.promoCode??'',total,paymentCurrency:currency(d)})).digest('hex');
  function input(request){const d=request.data;if(!request.auth?.uid||request.auth.token?.email_verified!==true)fail('unauthenticated','Sign in with a verified account.');if(!d||!/^[a-f0-9]{48}$/.test(d.requestId)||!Array.isArray(d.lines)||!d.lines.length||d.lines.length>5||!Array.isArray(d.guests)||d.guests.length<1||d.guests.length>10||!Number.isInteger(d.pointsUsed??0)||(d.pointsUsed??0)<0||(d.pointsUsed??0)%100!==0)fail('invalid-argument','Review your selected passes and guest details.');return d;}
  async function price(tx,request){
    const d=input(request),uid=request.auth.uid,[profile,access,security,loyalty]=await tx.getAll(db.doc('visitors/'+uid),db.doc('visitorAccess/'+uid),db.doc('accountSecurity/'+uid),db.doc('parkSettings/loyalty'));
    if(!profile.exists)fail('failed-precondition','Complete your visitor profile first.');if(access.exists&&access.data().status!=='active')fail('permission-denied','This account is restricted. Please contact support.');if(security.data()?.closing||security.data()?.revokedBefore>=(request.auth.token.auth_time??0))fail('unauthenticated','Your session has ended.');
    const items=[],lineIds=new Set(),guests=new Set();let subtotal=0;
    for(const line of d.lines){
      if(!validId(line.id)||lineIds.has(line.id)||!validId(line.packageId)||typeof line.visitDate!=='string'||!/^\d{4}-\d{2}-\d{2}$/.test(line.visitDate)||!Number.isInteger(line.adults)||!Number.isInteger(line.children)||line.adults<0||line.children<0||line.adults+line.children<1||line.adults+line.children>10)fail('invalid-argument','Review the pass quantities and visit date.');lineIds.add(line.id);
      const visit=new Date(line.visitDate+'T00:00:00Z'),today=day(clock());if(!Number.isFinite(visit.getTime())||visit.toISOString().slice(0,10)!==line.visitDate||line.visitDate<today||visit>new Date(today+'T00:00:00Z').getTime()+365*86400000)fail('invalid-argument','Choose a valid visit date within the next year.');
      const saved=await tx.get(db.doc('ticketPackages/'+line.packageId)),p=saved.data(),duration=p?.durationDays??1;
      if(!p||p.active!==true||p.currency!=='MYR'||!Number.isInteger(p.priceMinor)||p.priceMinor<1||p.priceMinor>10000000||!Number.isInteger(p.childPriceMinor??p.priceMinor)||!Number.isInteger(duration)||duration<1||duration>366||line.packageName!==p.name||line.adultPriceMinor!==p.priceMinor||line.childPriceMinor!==(p.childPriceMinor??p.priceMinor)||line.durationDays!==duration)fail('failed-precondition','A selected pass or price has changed. Review the cart again.');
      const rows=d.guests.filter(g=>g.lineId===line.id);if(rows.length!==line.adults+line.children||rows.filter(g=>g.type==='adult').length!==line.adults||rows.filter(g=>g.type==='child').length!==line.children)fail('invalid-argument','Add each guest to the correct pass.');
      for(const guest of rows){if(!validId(guest.id)||guests.has(guest.id)||typeof guest.fullName!=='string'||guest.fullName.trim().length<2||guest.fullName.length>100||typeof guest.email!=='string'||guest.email.length>254||!/^\S+@\S+\.\S+$/.test(guest.email))fail('invalid-argument','Complete each guest’s name and email.');guests.add(guest.id);const amount=guest.type==='child'?(p.childPriceMinor??p.priceMinor):p.priceMinor;subtotal+=amount;items.push({packageId:saved.id,packageName:p.name,visitDate:line.visitDate,validUntil:new Date(visit.getTime()+(duration-1)*86400000).toISOString().slice(0,10),durationDays:duration,ticketType:guest.type,guestName:guest.fullName.trim(),guestEmail:guest.email.trim().toLowerCase(),unitPriceMinor:amount});}
    }
    if(items.length!==d.guests.length||items.length>10)fail('invalid-argument','Review your guest list.');
    const promotion=await promotionPrice({db,tx,code:d.promoCode??'',scope:'tickets',subtotal,uid,now:clock()}),balance=profile.data().loyaltyPoints??0,maxPoints=promotion.offer?.allowPoints===false?0:Math.floor(Math.min(balance,subtotal-promotion.discountMinor)/100)*100,used=d.pointsUsed??0,rate=loyalty.data()?.purchasePointsPerRinggit??1;
    if(!Number.isInteger(balance)||balance<0||used>maxPoints)fail('failed-precondition','Review your points. This promotion may not allow points, or your balance has changed.');if(!Number.isInteger(rate)||rate<0||rate>100)fail('failed-precondition','Points earning rules need an administrator review.');
    return{items,subtotalMinor:subtotal,discountMinor:promotion.discountMinor,pointsUsed:used,totalMinor:subtotal-promotion.discountMinor-used,maxPoints,allowPoints:promotion.offer?.allowPoints!==false,profile,balance,rate,promotion};
  }
  const fields=v=>({subtotalMinor:v.subtotalMinor,discountMinor:v.discountMinor,pointsUsed:v.pointsUsed,totalMinor:v.totalMinor,maxPoints:v.maxPoints,allowPoints:v.allowPoints,currency:'MYR'});
  async function quote(request){
    const d=input(request),code=currency(d);if(!['MYR','USD','SGD','CNY','EUR'].includes(code))fail('invalid-argument','Choose a supported payment currency.');
    const rates=code==='MYR'?null:exchangeRates?await exchangeRates(request):fail('unavailable','Currency conversion is temporarily unavailable.');
    const rate=code==='MYR'?1:rates.rates[code];if(!Number.isFinite(rate)||rate<=0)fail('unavailable','Currency conversion is temporarily unavailable.');
    return db.runTransaction(async tx=>{
      const value=await price(tx,request),paymentTotalMinor=Math.round(value.totalMinor*rate);
      if(code==='MYR')return{...fields(value),paymentCurrency:code,paymentTotalMinor,exchangeRate:1};
      const ref=db.collection('ticketCurrencyQuotes').doc(),expiresAt=new Date(clock().getTime()+15*60000);
      tx.create(ref,{ownerUid:request.auth.uid,basket:basket(d,value.totalMinor),paymentCurrency:code,paymentTotalMinor,exchangeRate:rate,exchangeRateDate:rates.asOf,expiresAt});
      return{...fields(value),paymentCurrency:code,paymentTotalMinor,exchangeRate:rate,exchangeRateDate:rates.asOf,currencyQuoteId:ref.id,quoteExpiresAt:expiresAt.toISOString()};
    });
  }
  async function checkout(request){
    const d=input(request),uid=request.auth.uid;if(!['card','fpx','touch-go','apple-pay','nfc'].includes(d.paymentMethod)||typeof d.clientFingerprint!=='string'||!/^[a-f0-9]{64}$/.test(d.clientFingerprint)||!/^$|^\d{4}$/.test(d.cardLast4??''))fail('invalid-argument','Review the payment option.');
    const code=currency(d);if(!['MYR','USD','SGD','CNY','EUR'].includes(code))fail('invalid-argument','Choose a supported payment currency.');
    const ref=db.doc('orders/'+d.requestId),fingerprint=crypto.createHash('sha256').update(JSON.stringify({lines:d.lines,guests:d.guests,pointsUsed:d.pointsUsed??0,promoCode:d.promoCode??'',expectedTotalMinor:d.expectedTotalMinor,paymentMethod:d.paymentMethod,cardLast4:d.cardLast4??'',...(code!=='MYR'?{paymentCurrency:code,currencyQuoteId:d.currencyQuoteId,paymentTotalMinor:d.paymentTotalMinor}:{})})).digest('hex');
    return db.runTransaction(async tx=>{const previous=await tx.get(ref);if(previous.exists){if(previous.data().ownerUid!==uid||previous.data().serverFingerprint!==fingerprint)fail('already-exists','This checkout reference belongs to another order.');return{orderId:ref.id};}
      const value=await price(tx,request);if(value.totalMinor!==d.expectedTotalMinor)fail('failed-precondition','The promotion or prices changed. Apply the promotion again before confirming.');
      let conversion={paymentCurrency:'MYR',paymentTotalMinor:value.totalMinor,exchangeRate:1};
      if(code!=='MYR'){
        if(!validId(d.currencyQuoteId))fail('invalid-argument','Review the currency quote before confirming.');
        const quote=(await tx.get(db.doc('ticketCurrencyQuotes/'+d.currencyQuoteId))).data();
        if(!quote||quote.ownerUid!==uid||quote.paymentCurrency!==code||quote.basket!==basket(d,value.totalMinor)||quote.expiresAt.toDate()<=clock()||quote.paymentTotalMinor!==d.paymentTotalMinor)fail('failed-precondition','Your currency quote has expired or the booking changed. Review the total again before confirming.');
        conversion={paymentCurrency:code,paymentTotalMinor:quote.paymentTotalMinor,exchangeRate:quote.exchangeRate,exchangeRateDate:quote.exchangeRateDate};
      }
      const ticketIds=value.items.map((_,i)=>d.requestId+'_'+(i+1)),visitDate=d.lines[0].visitDate;
      const safeLines=d.lines.map(l=>({id:l.id,packageId:l.packageId,packageName:l.packageName,visitDate:l.visitDate,adults:l.adults,children:l.children,adultPriceMinor:l.adultPriceMinor,childPriceMinor:l.childPriceMinor,durationDays:l.durationDays,category:l.category==='annual'?'annual':'day',imageAsset:l.category==='annual'?'assets/images/ticketing/annual-pass.png':'assets/images/ticketing/castle.png'}));
      tx.create(ref,{...conversion,version:2,ownerUid:uid,requestId:ref.id,fingerprint:d.clientFingerprint,serverFingerprint:fingerprint,packageId:d.lines[0].packageId,packageName:d.lines.length===1?d.lines[0].packageName:'Theme Park Tickets',visitDate,quantity:value.items.length,ticketIds,items:value.items,lineItems:safeLines,subtotalMinor:value.subtotalMinor,discountMinor:value.discountMinor,pointsUsed:value.pointsUsed,totalMinor:value.totalMinor,loyaltyEarnRate:value.rate,promoCode:d.promoCode??'',paymentMethod:d.paymentMethod,cardLast4:d.paymentMethod==='card'?(d.cardLast4??''):'',currency:'MYR',status:'completed',displayCode:reference(ref.id,visitDate),createdAt:FieldValue.serverTimestamp()});
      for(let i=0;i<value.items.length;i++){const item=value.items[i],displayCode=reference(ref.id,item.visitDate)+'-'+String(i+1).padStart(2,'0');tx.create(db.doc('tickets/'+ticketIds[i]),{...item,item,version:2,index:i,ownerUid:uid,purchaserUid:uid,orderId:ref.id,displayCode,currency:'MYR',status:'valid',createdAt:FieldValue.serverTimestamp()});tx.create(db.doc('ticketReferences/'+displayCode),{ticketId:ticketIds[i],ownerUid:uid,guestEmail:item.guestEmail});}
      if(value.pointsUsed)tx.update(value.profile.ref,{loyaltyPoints:value.balance-value.pointsUsed,lastRedemptionOrderId:ref.id});recordPromotion(tx,value.promotion,uid,ref.id,FieldValue);return{orderId:ref.id};
    });
  }
  return{quote,checkout};
}
module.exports={createTicketPromotionHandlers};
