'use strict';
const crypto=require('node:crypto'),{HttpsError}=require('firebase-functions/v2/https');
const {promotionPrice,recordPromotion}=require('./promotion_pricing');
const {FieldPath}=require('firebase-admin/firestore');
const hash=value=>crypto.createHash('sha256').update(value).digest('hex');
const fail=(code,message)=>{throw new HttpsError(code,message);};
const identifier=value=>typeof value==='string'&&/^[A-Za-z0-9_-]{1,160}$/.test(value);
const formats=['digital','print','bundle'];
function photoEdits(value={}){
  if(!value||typeof value!=='object'||Array.isArray(value)||Object.keys(value).some(k=>!['filter','rotation','crop','beauty','brightness','sticker','intensity'].includes(k)))fail('invalid-argument','Review the photo edits.');
  const result={filter:value.filter??'original',rotation:value.rotation??0,beauty:value.beauty??0,brightness:value.brightness??0,intensity:value.intensity??1};
  if(!Number.isFinite(result.intensity)||result.intensity<0||result.intensity>1)fail('invalid-argument','Review the filter intensity.');
  if(!['original','warm','cool','vintage','mono','vivid'].includes(result.filter)||![0,90,180,270].includes(result.rotation)||!Number.isFinite(result.beauty)||result.beauty<0||result.beauty>.5||!Number.isFinite(result.brightness)||Math.abs(result.brightness)>.3)fail('invalid-argument','Review the photo filter and enhancement settings.');
  if(value.crop){const c=value.crop;if(!['x','y','width','height'].every(k=>Number.isFinite(c[k]))||c.x<0||c.y<0||c.width<.1||c.height<.1||c.x+c.width>1.001||c.y+c.height>1.001)fail('invalid-argument','Choose a crop inside the photo.');result.crop={x:c.x,y:c.y,width:c.width,height:c.height};}
  if(value.sticker){const s=value.sticker;if(!['heart','star','smile'].includes(s.type)||!['x','y','scale'].every(k=>Number.isFinite(s[k]))||Math.min(s.x,s.y)<0||Math.max(s.x,s.y)>1||s.scale<.04||s.scale>.3)fail('invalid-argument','Review the photo sticker.');result.sticker={type:s.type,x:s.x,y:s.y,scale:s.scale};}
  return result;
}
function createPhotoHandlers({db,FieldValue,ai,mailReady=()=>false,clock=()=>new Date()}){
  const workerId=crypto.randomUUID();
  function caller(request,staff=false){if(!request.auth?.uid||request.auth.token?.email_verified!==true)fail('unauthenticated','Please sign in with a verified account.');if(staff&&request.auth.token.admin!==true)fail('permission-denied','Photo management is available to park staff.');return request.auth.uid;}
  function id(value){if(!identifier(value))fail('invalid-argument','Choose a valid photo or purchase reference.');return value;}
  async function access(tx,uid,token){const [a,s]=await tx.getAll(db.doc('visitorAccess/'+uid),db.doc('accountSecurity/'+uid));if(a.exists&&a.data().status!=='active')fail('permission-denied','This account is restricted. Please contact support.');if(s.data()?.closing||(token&&s.data()?.revokedBefore>=(token.auth_time??0)))fail('unauthenticated','Your session has ended. Please sign in again.');}
  async function infer(operation,data){try{return await ai.call(operation,data);}catch(error){if(/setup|models are unavailable|service stopped|AI service/i.test(error.message??''))fail('unavailable','Photo processing is temporarily unavailable. Please contact the photo counter or try again later.');fail('failed-precondition',error.message||'Photo processing is unavailable. Please retry.');}}
  const matchRef=(photoId,uid)=>db.doc('photoMatches/'+photoId+'_'+uid);
  const entitlementRef=(photoId,uid)=>db.doc('photoEntitlements/'+hash(uid+'\0'+photoId));
  async function matchPhoto(photoId,onlyUid){
    const [photo,vectors,templates]=await Promise.all([db.doc('parkPhotos/'+photoId).get(),db.doc('photoVectors/'+photoId).get(),db.collection('faceTemplates').where('enabled','==',true).get()]);
    if(!photo.exists||photo.data().status!=='active'||!vectors.exists)return{matched:0};
    const candidates=templates.docs.filter(d=>d.data().model==='sface-2021dec').map(d=>({uid:d.id,feature:d.data().feature}));
    const result=await infer('match_faces',{faces:vectors.data().faces,templates:candidates});
    const unique=new Map(result.matches.filter(m=>!onlyUid||m.uid===onlyUid).map(m=>[m.uid,m]));
    let matched=0;
    for(const [uid,match]of unique){
      const saved=await db.runTransaction(async tx=>{
        const [template,security,profile,existing,current]=await tx.getAll(db.doc('faceTemplates/'+uid),db.doc('accountSecurity/'+uid),db.doc('visitors/'+uid),matchRef(photoId,uid),db.doc('parkPhotos/'+photoId));
        if(template.data()?.enabled!==true||security.data()?.closing||!profile.exists||current.data()?.status!=='active')return false;
        if(existing.data()?.hidden)return false;
        tx.set(matchRef(photoId,uid),{ownerUid:uid,photoId,title:current.data().title,attractionName:current.data().attractionName??'',takenAt:current.data().takenAt,previewBase64:current.data().previewBase64,score:match.score,source:existing.data()?.source==='photo-code'?'photo-code':'face',favorite:existing.data()?.favorite===true,hidden:false,matchedAt:FieldValue.serverTimestamp()});return true;
      });if(saved)matched++;
    }
    if(!onlyUid)await db.doc('parkPhotos/'+photoId).update({matchedVisitorCount:matched,lastMatchedAt:FieldValue.serverTimestamp()});
    return{matched};
  }
  async function enroll(request){
    const uid=caller(request);if(request.data.consent!==true)fail('invalid-argument','Agree to use your selfie for park photo matching.');
    if(Math.abs(clock().getTime()/1000-(request.auth.token.auth_time??0))>300)fail('failed-precondition','Confirm your password before setting up face recognition.');
    const result=await infer('enroll',{imageBase64:request.data.imageBase64});
    await db.runTransaction(async tx=>{await access(tx,uid,request.auth.token);const profile=await tx.get(db.doc('visitors/'+uid));if(!profile.exists)fail('failed-precondition','Complete your visitor profile first.');
      tx.set(db.doc('faceTemplates/'+uid),{ownerUid:uid,enabled:true,model:'sface-2021dec',feature:result.feature,updatedAt:FieldValue.serverTimestamp()});
      tx.set(db.doc('faceProfiles/'+uid),{ownerUid:uid,enabled:true,enrolledAt:FieldValue.serverTimestamp(),model:'sface-2021dec',matchingStatus:'queued'});
      tx.set(db.doc('photoMatchingJobs/'+uid),{ownerUid:uid,status:'queued',cursor:null,createdAt:FieldValue.serverTimestamp()});
      tx.update(db.doc('visitors/'+uid),{faceRecognitionConsent:true,faceRecognitionEnabled:true});
    });
    return{enabled:true,matching:'queued'};
  }
  async function disable(request){
    const uid=caller(request);
    await db.runTransaction(async tx=>{await access(tx,uid,request.auth.token);const profile=await tx.get(db.doc('visitors/'+uid));tx.delete(db.doc('faceTemplates/'+uid));tx.delete(db.doc('photoMatchingJobs/'+uid));tx.set(db.doc('faceProfiles/'+uid),{ownerUid:uid,enabled:false,updatedAt:FieldValue.serverTimestamp()});if(profile.exists)tx.update(profile.ref,{faceRecognitionConsent:false,faceRecognitionEnabled:false});});
    const matches=await db.collection('photoMatches').where('ownerUid','==',uid).get();
    for(let i=0;i<matches.docs.length;i+=400){const batch=db.batch();for(const doc of matches.docs.slice(i,i+400))if(doc.data().source!=='photo-code')batch.delete(doc.ref);await batch.commit();}
    return{enabled:false};
  }
  async function upload(request){
    const uid=caller(request,true),data=request.data,title=data.title?.trim(),taken=new Date(data.takenAt);
    if(typeof title!=='string'||title.length<2||title.length>100||Number.isNaN(taken.getTime())||taken>new Date(clock().getTime()+300000))fail('invalid-argument','Enter a photo title and its actual capture time.');
    id(data.requestId);if(data.attractionId)id(data.attractionId);
    if(typeof data.imageBase64!=='string'||data.imageBase64.length>12000000)fail('invalid-argument','Choose a photo smaller than 8 MB.');
    const fingerprint=hash(JSON.stringify({title,takenAt:taken.toISOString(),attractionId:data.attractionId??'',imageHash:hash(data.imageBase64)}));
    const photoId=hash(uid+'\0'+data.requestId),ref=db.doc('parkPhotos/'+photoId),prior=await ref.get(),claimCode=crypto.randomBytes(16).toString('hex');
    if(prior.exists){if(prior.data().fingerprint!==fingerprint)fail('already-exists','This upload reference belongs to another photo.');return{photoId,claimCode:prior.data().claimCode,matched:prior.data().matchedVisitorCount??0,alreadyUploaded:true};}
    const prepared=await infer('prepare_photo',{imageBase64:data.imageBase64});
    const attraction=data.attractionId?await db.doc('attractions/'+data.attractionId).get():null;
    await db.runTransaction(async tx=>{await access(tx,uid,request.auth.token);const old=await tx.get(ref);if(old.exists){if(old.data().fingerprint!==fingerprint)fail('already-exists','This upload reference belongs to another photo.');return;}
      tx.create(ref,{title,takenAt:taken,attractionId:data.attractionId??'',attractionName:attraction?.data()?.name??'',photographerUid:uid,status:'active',previewBase64:prepared.previewBase64,width:prepared.width,height:prepared.height,faceCount:prepared.faces.length,matchedVisitorCount:0,fingerprint,claimCode,createdAt:FieldValue.serverTimestamp()});
      tx.create(db.doc('photoCodes/'+hash(claimCode)),{photoId,expiresAt:new Date(clock().getTime()+86400000)});
      tx.create(db.doc('photoOriginals/'+photoId),{imageBase64:prepared.originalBase64,createdAt:FieldValue.serverTimestamp()});
      tx.create(db.doc('photoVectors/'+photoId),{faces:prepared.faces,model:'sface-2021dec',createdAt:FieldValue.serverTimestamp()});
    });
    const persisted=await ref.get();return{photoId,claimCode:persisted.data().claimCode,...await matchPhoto(photoId)};
  }
  async function recheck(request){caller(request,true);return matchPhoto(id(request.data.photoId));}
  async function archive(request){
    const uid=caller(request,true),photoId=id(request.data.photoId);
    if(typeof request.data.archived!=='boolean')fail('invalid-argument','Choose whether to archive this photo.');
    const ref=db.doc('parkPhotos/'+photoId);
    await db.runTransaction(async tx=>{await access(tx,uid,request.auth.token);const photo=await tx.get(ref);if(!photo.exists)fail('not-found','Photo not found.');tx.update(ref,{status:request.data.archived?'archived':'active',updatedAt:FieldValue.serverTimestamp()});});
    const matches=await db.collection('photoMatches').where('photoId','==',photoId).get();
    for(const match of matches.docs)await db.runTransaction(async tx=>{const [photo,current]=await tx.getAll(ref,match.ref);if(current.exists)tx.update(match.ref,{available:photo.data()?.status==='active'});});
    return{saved:true};
  }
  async function hide(request){const uid=caller(request),photoId=id(request.data.photoId),ref=matchRef(photoId,uid);return db.runTransaction(async tx=>{await access(tx,uid,request.auth.token);const saved=await tx.get(ref);if(!saved.exists||saved.data().ownerUid!==uid)fail('not-found','Photo match not found.');tx.update(ref,{hidden:true});tx.set(db.doc('photoMatchReviews/'+photoId+'_'+uid),{ownerUid:uid,photoId,reason:'not-me',createdAt:FieldValue.serverTimestamp(),status:'open'});return{hidden:true};});}
  async function favorite(request){const uid=caller(request),photoId=id(request.data.photoId);if(typeof request.data.favorite!=='boolean')fail('invalid-argument','Choose a favorite setting.');const ref=matchRef(photoId,uid);return db.runTransaction(async tx=>{await access(tx,uid,request.auth.token);const saved=await tx.get(ref);if(!saved.exists)fail('not-found','This photo is unavailable in your gallery.');tx.update(ref,{favorite:request.data.favorite});return{saved:true};});}
  async function claim(request){const uid=caller(request),code=String(request.data.code??'').trim().replace(/^PP1:/,'').toLowerCase();if(!/^[a-f0-9]{32}$/.test(code))fail('invalid-argument','Enter the photo code from the photographer.');return db.runTransaction(async tx=>{await access(tx,uid,request.auth.token);const lookup=await tx.get(db.doc('photoCodes/'+hash(code))),value=lookup.data();if(!value||value.expiresAt.toDate()<=clock())fail('not-found','This photo code is invalid or has expired. Ask the photo counter for help.');const photo=await tx.get(db.doc('parkPhotos/'+value.photoId));if(photo.data()?.status!=='active')fail('not-found','This photo is unavailable.');tx.set(matchRef(value.photoId,uid),{ownerUid:uid,photoId:value.photoId,title:photo.data().title,attractionName:photo.data().attractionName??'',takenAt:photo.data().takenAt,previewBase64:photo.data().previewBase64,source:'photo-code',hidden:false,favorite:false,matchedAt:FieldValue.serverTimestamp()});return{photoId:value.photoId};});}
  function cart(data){
    if(data.deliveryEmail!==undefined&&(typeof data.deliveryEmail!=='string'||data.deliveryEmail.length>254||!/^\S+@\S+\.\S+$/.test(data.deliveryEmail)))fail('invalid-argument','Enter a valid delivery email address.');
    if(!Array.isArray(data.items)||!data.items.length||data.items.length>10)fail('invalid-argument','Choose between one and ten photos.');
    const items=data.items.map(item=>{const format=formats.includes(item.format)?item.format:(()=>{fail('invalid-argument','Choose a photo format.');})(),quantity=item.quantity??1,printSize=item.printSize??'6x8',finish=item.finish??'glossy';if(!Number.isInteger(quantity)||quantity<1||quantity>10||format==='digital'&&quantity!==1||!['6x8','8x10'].includes(printSize)||!['glossy','matte'].includes(finish))fail('invalid-argument','Review the number of copies and print options.');return{photoId:id(item.photoId),format,quantity,printSize,finish,edits:photoEdits(item.edits)};});
    if(new Set(items.map(i=>i.photoId)).size!==items.length)fail('invalid-argument','Choose each photo once. Use a bundle for digital and printed copies.');
    if(!Number.isInteger(data.pointsUsed??0)||(data.pointsUsed??0)<0||(data.pointsUsed??0)%100!==0)fail('invalid-argument','Use points in multiples of 100.');return items;
  }
  async function price(tx,request,items){
    const uid=request.auth.uid;await access(tx,uid,request.auth.token);
    const [settings,profile,loyalty]=await tx.getAll(db.doc('parkSettings/photos'),db.doc('visitors/'+uid),db.doc('parkSettings/loyalty'));
    if(!profile.exists)fail('failed-precondition','Complete your visitor profile first.');
    const prices={digital:settings.data()?.digitalPriceMinor??2500,print:settings.data()?.printPriceMinor??3500,bundle:settings.data()?.bundlePriceMinor??5000};
    if(Object.values(prices).some(p=>!Number.isInteger(p)||p<1||p>1000000))fail('failed-precondition','Photo prices need an administrator review.');
    let subtotal=0;const snapshots=[];
    for(const item of items){const [photo,match,entitlement]=await tx.getAll(db.doc('parkPhotos/'+item.photoId),matchRef(item.photoId,uid),entitlementRef(item.photoId,uid));
      if(!photo.exists||photo.data().status!=='active'||(!entitlement.exists&&(!match.exists||match.data().hidden)))fail('permission-denied','Choose a photo from your own gallery.');
      if(entitlement.exists&&['digital','bundle'].includes(item.format))fail('already-exists','You already own a digital copy. Download it from Photo Purchase History.');
      const surcharge=item.printSize==='8x10'?(settings.data()?.largePrintSurchargeMinor??1000):0;
      if(!Number.isInteger(surcharge)||surcharge<0||surcharge>1000000)fail('failed-precondition','Print options need an administrator review.');
      const amount=item.format==='digital'?prices.digital:item.format==='print'?(prices.print+surcharge)*item.quantity:prices.bundle+prices.print*(item.quantity-1)+surcharge*item.quantity;subtotal+=amount;snapshots.push({...item,title:photo.data().title,attractionName:photo.data().attractionName??'',takenAt:photo.data().takenAt,priceMinor:amount,previewBase64:photo.data().previewBase64});
    }
    const promotion=await promotionPrice({db,tx,code:request.data.promoCode??'',scope:'photos',subtotal,uid,now:clock()});
    const used=request.data.pointsUsed??0,balance=profile.data().loyaltyPoints??0,maxPoints=promotion.offer?.allowPoints===false?0:Math.floor(Math.min(balance,subtotal-promotion.discountMinor)/100)*100;
    if(!Number.isInteger(balance)||balance<0||used>maxPoints)fail('failed-precondition','Your points balance has changed. Review the order again.');
    if(used&&promotion.offer?.allowPoints===false)fail('failed-precondition','This promotion cannot be combined with points.');
    const totalMinor=subtotal-promotion.discountMinor-used,rate=loyalty.data()?.purchasePointsPerRinggit??1;
    if(!Number.isInteger(rate)||rate<0||rate>1000)fail('failed-precondition','Points earning rules need an administrator review.');
    return{subtotalMinor:subtotal,discountMinor:promotion.discountMinor,pointsUsed:used,totalMinor,maxPoints,currency:'MYR',pointsEarned:Math.floor(totalMinor/100)*rate,promotion,profile,balance,items:snapshots};
  }
  function quoteFields(value){return{subtotalMinor:value.subtotalMinor,discountMinor:value.discountMinor,pointsUsed:value.pointsUsed,totalMinor:value.totalMinor,maxPoints:value.maxPoints,currency:value.currency,pointsEarned:value.pointsEarned};}
  async function quote(request){caller(request);const items=cart(request.data);return db.runTransaction(async tx=>quoteFields(await price(tx,request,items)));}
  async function checkout(request){
    const uid=caller(request),items=cart(request.data),requestId=id(request.data.requestId);if(requestId.length<16)fail('invalid-argument','A unique purchase reference is required.');
    const deliveryEmail=request.data.deliveryEmail??request.auth.token.email;
    const orderId=hash(uid+'\0photos\0'+requestId),ref=db.doc('photoOrders/'+orderId),fingerprint=JSON.stringify({items,pointsUsed:request.data.pointsUsed??0,promoCode:request.data.promoCode??'',deliveryEmail}),kioskCode=crypto.randomBytes(16).toString('hex');
    return db.runTransaction(async tx=>{
      await access(tx,uid,request.auth.token);const old=await tx.get(ref);if(old.exists){if(old.data().fingerprint!==fingerprint)fail('already-exists','This purchase reference belongs to a different order.');return{orderId,kioskCode:old.data().kioskCode??null};}
      const value=await price(tx,request,items);
      if(value.totalMinor!==request.data.expectedTotalMinor)fail('failed-precondition','Photo prices or discounts changed. Review the order again.');
      const printable=value.items.filter(i=>i.format!=='digital'),digital=value.items.filter(i=>i.format!=='print');
      const summaries=value.items.map(({previewBase64,...item})=>item);
      tx.create(ref,{ownerUid:uid,status:'confirmed',...quoteFields(value),items:summaries,promoCode:request.data.promoCode??'',fingerprint,deliveryEmail,kioskCode:printable.length?kioskCode:null,emailStatus:mailReady()?'queued':'pending',createdAt:FieldValue.serverTimestamp()});
      for(const item of value.items)tx.create(db.doc('photoOrderPreviews/'+orderId+'_'+item.photoId),{ownerUid:uid,orderId,photoId:item.photoId,previewBase64:item.previewBase64});
      for(const item of digital)tx.set(entitlementRef(item.photoId,uid),{ownerUid:uid,photoId:item.photoId,orderId,title:item.title,takenAt:item.takenAt,previewBase64:item.previewBase64,edits:item.edits,createdAt:FieldValue.serverTimestamp()});
      if(printable.length)tx.create(db.doc('kioskRequests/'+orderId),{ownerUid:uid,orderId,status:'ready',items:printable.map(({previewBase64,...item})=>item),codeHash:hash(kioskCode),createdAt:FieldValue.serverTimestamp()});
      if(value.pointsUsed)tx.create(db.doc('loyaltyEvents/photo_spend_'+orderId),{ownerUid:uid,kind:'photo_spent',sourceId:orderId,delta:-value.pointsUsed,createdAt:FieldValue.serverTimestamp()});
      if(value.pointsEarned)tx.create(db.doc('loyaltyEvents/photo_earn_'+orderId),{ownerUid:uid,kind:'photo',title:'Photo Purchase',sourceId:orderId,delta:value.pointsEarned,createdAt:FieldValue.serverTimestamp()});
      tx.update(value.profile.ref,{loyaltyPoints:value.balance-value.pointsUsed+value.pointsEarned,...(value.pointsEarned?{lastLoyaltyEventId:'photo_earn_'+orderId}:value.pointsUsed?{lastLoyaltyEventId:'photo_spend_'+orderId}:{})});
      recordPromotion(tx,value.promotion,uid,orderId,FieldValue);
      tx.create(db.doc('emailOutbox/photo_'+orderId),{ownerUid:uid,to:deliveryEmail,type:'photo-order',orderId,status:mailReady()?'queued':'pending_setup',createdAt:FieldValue.serverTimestamp()});
      return{orderId,kioskCode:printable.length?kioskCode:null};
    });
  }
  async function download(request){const uid=caller(request),photoId=id(request.data.photoId),entitled=await entitlementRef(photoId,uid).get();if(!entitled.exists||entitled.data().ownerUid!==uid)fail('permission-denied','Purchase a digital copy before downloading.');const original=await db.doc('photoOriginals/'+photoId).get();if(!original.exists)fail('not-found','This photo is unavailable. Please contact support.');const edits=photoEdits(request.data.edits??entitled.data().edits);return{...await infer('render_photo',{imageBase64:original.data().imageBase64,edits}),fileName:'ThemePark-'+photoId.slice(0,12)+'.jpg'};}
  async function adminOriginal(request){caller(request,true);const original=await db.doc('photoOriginals/'+id(request.data.photoId)).get();if(!original.exists)fail('not-found','Photo not found.');return{imageBase64:original.data().imageBase64};}
  async function kioskRetrieve(request){caller(request,true);const match=/^PK1:([a-f0-9]{64}):([a-f0-9]{32})$/.exec(String(request.data.code??'').trim());if(!match)fail('invalid-argument','Scan a valid photo collection QR.');const ref=db.doc('kioskRequests/'+match[1]),saved=await ref.get(),data=saved.data();if(!data||!crypto.timingSafeEqual(Buffer.from(data.codeHash),Buffer.from(hash(match[2]))))fail('not-found','Photo collection request not found.');if(data.status==='collected')fail('failed-precondition','This photo request has already been collected.');const images=[];for(const item of data.items){const original=await db.doc('photoOriginals/'+item.photoId).get();if(!original.exists)fail('not-found','A requested photo is unavailable. Please contact the photo counter.');images.push({...item,...await infer('render_photo',{imageBase64:original.data().imageBase64,edits:item.edits})});}return{requestId:ref.id,status:data.status,images};}
  async function kioskStatus(request){const uid=caller(request,true),requestId=id(request.data.requestId),status=request.data.status;if(!['spooled','collected'].includes(status))fail('invalid-argument','Choose a valid print status.');return db.runTransaction(async tx=>{const ref=db.doc('kioskRequests/'+requestId),saved=await tx.get(ref);if(!saved.exists)fail('not-found','Photo request not found.');if(saved.data().status==='collected')return{status:'collected'};if(status==='collected'&&saved.data().status!=='spooled')fail('failed-precondition','Send the photos to the printer before confirming collection.');tx.update(ref,{status,updatedAt:FieldValue.serverTimestamp(),lastActorUid:uid,...(status==='spooled'?{printAttempts:(saved.data().printAttempts??0)+1}:{collectedAt:FieldValue.serverTimestamp()})});return{status};});}
  async function refreshMatches(request){const uid=caller(request);return db.runTransaction(async tx=>{await access(tx,uid,request.auth.token);const template=await tx.get(db.doc('faceTemplates/'+uid));if(template.data()?.enabled!==true)fail('failed-precondition','Set up face recognition before finding your park photos.');const ref=db.doc('photoMatchingJobs/'+uid),old=await tx.get(ref);if(old.data()?.leaseUntil?.toDate?.()>clock())return{matching:'running'};tx.set(ref,{ownerUid:uid,status:'queued',cursor:null,createdAt:FieldValue.serverTimestamp()});tx.set(db.doc('faceProfiles/'+uid),{matchingStatus:'queued'},{merge:true});return{matching:'queued'};});}
  async function purchaseState(request){const uid=caller(request),requestId=id(request.data.requestId),orderId=hash(uid+'\0photos\0'+requestId),saved=await db.doc('photoOrders/'+orderId).get();if(!saved.exists)return{found:false};if(saved.data().ownerUid!==uid)fail('permission-denied','This purchase is unavailable.');return{found:true,orderId,status:saved.data().status,kioskCode:saved.data().kioskCode??null};}
  async function resendEmail(request){
    const uid=caller(request),orderId=id(request.data.orderId);
    return db.runTransaction(async tx=>{
      await access(tx,uid,request.auth.token);const ref=db.doc('photoOrders/'+orderId),outbox=db.doc('emailOutbox/photo_'+orderId),[saved,existing]=await tx.getAll(ref,outbox),order=saved.data(),job=existing.data();
      if(!order||order.ownerUid!==uid)fail('not-found','Photo order not found.');
      if(mailReady()&&(job?.status==='queued'||job?.status==='sending'&&job.startedAt?.toDate?.()>new Date(clock().getTime()-180000)))return{queued:true};
      if(job?.status==='sent'&&job.sentAt?.toDate?.()>new Date(clock().getTime()-60000))fail('failed-precondition','Your photo email was sent recently. Please wait a minute before resending.');
      tx.set(outbox,{ownerUid:uid,to:order.deliveryEmail??request.auth.token.email,type:'photo-order',orderId,status:mailReady()?'queued':'pending_setup',createdAt:FieldValue.serverTimestamp(),attempts:0});tx.update(ref,{emailStatus:mailReady()?'queued':'pending'});return{queued:mailReady()};
    });
  }
  async function kioskEditSource(request){caller(request,true);const requestId=id(request.data.requestId),photoId=id(request.data.photoId),saved=await db.doc('kioskRequests/'+requestId).get(),value=saved.data();if(!value||value.status!=='ready'||!value.items.some(item=>item.photoId===photoId))fail('failed-precondition','Choose a photo in a collection request that has not been printed.');const original=await db.doc('photoOriginals/'+photoId).get();if(!original.exists)fail('not-found','Photo not found.');return{imageBase64:original.data().imageBase64,edits:value.items.find(item=>item.photoId===photoId).edits};}
  async function kioskSaveEdits(request){const uid=caller(request,true),requestId=id(request.data.requestId),photoId=id(request.data.photoId),edits=photoEdits(request.data.edits);return db.runTransaction(async tx=>{const ref=db.doc('kioskRequests/'+requestId),saved=await tx.get(ref),value=saved.data();if(!value||value.status!=='ready'||!value.items.some(item=>item.photoId===photoId))fail('failed-precondition','This photo request is no longer available for editing.');tx.update(ref,{items:value.items.map(item=>item.photoId===photoId?{...item,edits}:item),lastEditorUid:uid,updatedAt:FieldValue.serverTimestamp()});return{saved:true};});}
  async function resolveReview(request){const uid=caller(request,true),reviewId=id(request.data.reviewId);await db.doc('photoMatchReviews/'+reviewId).update({status:'reviewed',reviewedBy:uid,reviewedAt:FieldValue.serverTimestamp()});return{saved:true};}
  async function runMatchingJobs(){
    const jobs=await db.collection('photoMatchingJobs').where('status','in',['queued','running']).limit(10).get();
    for(const candidate of jobs.docs){
      const job=await db.runTransaction(async tx=>{const current=await tx.get(candidate.ref),value=current.data();if(!value||!['queued','running'].includes(value.status)||value.leaseUntil?.toDate?.()>clock())return null;tx.update(candidate.ref,{status:'running',workerId,leaseUntil:new Date(clock().getTime()+90000)});return value;});
      if(!job)continue;
      try{
        let query=db.collection('parkPhotos').orderBy(FieldPath.documentId());if(job.cursor)query=query.startAfter(job.cursor);const batch=await query.limit(5).get();
        for(const photo of batch.docs)await matchPhoto(photo.id,candidate.id);
        await db.runTransaction(async tx=>{const [current,template]=await tx.getAll(candidate.ref,db.doc('faceTemplates/'+candidate.id));if(current.data()?.workerId!==workerId||template.data()?.enabled!==true)return;const complete=batch.size<5;tx.update(candidate.ref,{status:complete?'complete':'queued',cursor:batch.docs.at(-1)?.id??job.cursor,leaseUntil:new Date(0),updatedAt:FieldValue.serverTimestamp()});tx.set(db.doc('faceProfiles/'+candidate.id),{matchingStatus:complete?'complete':'running'},{merge:true});});
      }catch(_){await db.runTransaction(async tx=>{const current=await tx.get(candidate.ref);if(current.data()?.workerId!==workerId)return;tx.update(candidate.ref,{status:'failed',leaseUntil:new Date(0),updatedAt:FieldValue.serverTimestamp()});tx.set(db.doc('faceProfiles/'+candidate.id),{matchingStatus:'failed'},{merge:true});});}
      break;
    }
  }
  return{enroll,disable,upload,recheck,archive,hide,favorite,claim,quote,checkout,purchaseState,download,adminOriginal,kioskRetrieve,kioskStatus,kioskEditSource,kioskSaveEdits,resolveReview,refreshMatches,resendEmail,runMatchingJobs};
}
module.exports={createPhotoHandlers,photoEdits};
