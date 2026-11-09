'use strict';
const crypto=require('node:crypto'),{HttpsError}=require('firebase-functions/v2/https');
const fail=(code,message)=>{throw new HttpsError(code,message);};
const refId=value=>typeof value==='string'&&/^[A-Za-z0-9_-]{2,100}$/.test(value);
function integer(value,min,max,label){if(!Number.isInteger(value)||value<min||value>max)fail('invalid-argument',`Review ${label}.`);return value;}
function text(value,min,max,label){if(typeof value!=='string'||value.trim().length<min||value.trim().length>max)fail('invalid-argument',`Review ${label}.`);return value.trim();}
function timestamp(value,label){const date=new Date(value);if(!Number.isFinite(date.getTime()))fail('invalid-argument',`Choose ${label}.`);return date;}
const parkDay=date=>new Date(date.getTime()+8*3600000).toISOString().slice(0,10);
function createParkManagementHandlers({db,FieldValue,clock=()=>new Date(),fetchWeather=globalThis.fetch}){
  async function access(request,staff=true){
    const uid=request.auth?.uid,token=request.auth?.token;
    if(!uid||token?.email_verified!==true)fail('unauthenticated','Sign in using a verified account.');
    if(staff&&token.admin!==true)fail('permission-denied','This action requires administrator access.');
    const [a,s]=await db.getAll(db.doc('visitorAccess/'+uid),db.doc('accountSecurity/'+uid));
    if(a.exists&&a.data().status!=='active')fail('permission-denied','This account is restricted. Please contact support.');
    if(s.data()?.closing||s.data()?.revokedBefore>=(token.auth_time??0))fail('unauthenticated','Your session has ended. Please sign in again.');
    return uid;
  }
  async function audit(uid,action,subject){await db.collection('adminAudit').add({actorUid:uid,action,subject,createdAt:FieldValue.serverTimestamp()});}
  async function saveCampaign(request){
    const uid=await access(request),d=request.data,code=text(d.code,2,32,'the promotion code').toUpperCase();
    if(!/^[A-Z0-9_-]+$/.test(code))fail('invalid-argument','Use letters, numbers, underscores or hyphens for the code.');
    const startsAt=timestamp(d.startsAt,'a start date'),endsAt=timestamp(d.endsAt,'an end date');if(endsAt<=startsAt)fail('invalid-argument','End the promotion after its start date.');
    if(!['percent','fixed'].includes(d.type)||!Array.isArray(d.scopes)||!d.scopes.length||d.scopes.some(x=>!['photos','tickets'].includes(x)))fail('invalid-argument','Choose the promotion type and eligible purchases.');
    const fields={name:text(d.name,2,100,'the campaign name'),description:text(d.description??'',0,600,'the description'),code,type:d.type,value:integer(d.value,1,d.type==='percent'?100:1000000,'the discount'),scopes:[...new Set(d.scopes)],startsAt,endsAt,minimumMinor:integer(d.minimumMinor??0,0,100000000,'the minimum spend'),maximumDiscountMinor:integer(d.maximumDiscountMinor??0,0,100000000,'the discount limit'),perUserLimit:integer(d.perUserLimit??1,1,100,'the per-visitor limit'),totalUsageLimit:integer(d.totalUsageLimit??0,0,1000000,'the total redemption limit'),active:d.active===true,public:d.public===true,allowPoints:d.allowPoints!==false,updatedAt:FieldValue.serverTimestamp(),updatedBy:uid};
    await db.runTransaction(async tx=>{const ref=db.doc('campaigns/'+code),old=await tx.get(ref);tx.set(ref,{...fields,usageCount:old.data()?.usageCount??0,createdAt:old.data()?.createdAt??FieldValue.serverTimestamp()});});
    await audit(uid,'campaign_saved',code);return{saved:true,code};
  }
  async function saveLoyalty(request){
    const uid=await access(request),d=request.data;
    const fields={purchasePointsPerRinggit:integer(d.purchasePointsPerRinggit,0,100,'purchase points'),ridePoints:integer(d.ridePoints,0,10000,'attraction check-in points'),noShowPenalty:integer(d.noShowPenalty??0,0,10000,'missed reservation points'),noShowEnabled:d.noShowEnabled===true,updatedAt:FieldValue.serverTimestamp(),updatedBy:uid};
    await db.runTransaction(async tx=>{const ref=db.doc('parkSettings/loyalty'),old=await tx.get(ref);tx.set(ref,{...fields,noShowEffectiveAt:fields.noShowEnabled&&old.data()?.noShowEnabled!==true?clock():old.data()?.noShowEffectiveAt??clock()});});
    await audit(uid,'loyalty_rules_saved','loyalty');return{saved:true};
  }
  async function savePhotoSettings(request){
    const uid=await access(request),d=request.data,fields={};
    for(const key of ['digitalPriceMinor','printPriceMinor','bundlePriceMinor'])fields[key]=integer(d[key],1,1000000,'photo prices');
    fields.largePrintSurchargeMinor=integer(d.largePrintSurchargeMinor??1000,0,1000000,'large print pricing');
    fields.kioskName=text(d.kioskName??'Park Photo Kiosk',2,100,'the kiosk name');
    for(const [key,bound]of [['kioskLatitude',90],['kioskLongitude',180]]){if(d[key]!==null&&d[key]!==undefined&&(!Number.isFinite(d[key])||Math.abs(d[key])>bound))fail('invalid-argument','Enter the kiosk’s actual coordinates.');fields[key]=d[key]??null;}
    await db.doc('parkSettings/photos').set({...fields,updatedAt:FieldValue.serverTimestamp(),updatedBy:uid},{merge:true});await audit(uid,'photo_prices_saved','photos');return{saved:true};
  }
  async function saveReward(request){
    const uid=await access(request),d=request.data,id=d.id??crypto.randomUUID();if(!refId(id))fail('invalid-argument','Choose a valid reward.');
    if(!['dining','shopping','photo'].includes(d.category))fail('invalid-argument','Choose a reward category.');
    for(const key of ['terms','instructions'])if(!Array.isArray(d[key])||d[key].length>12||d[key].some(t=>typeof t!=='string'||t.length>300))fail('invalid-argument','Keep reward terms and instructions to twelve clear lines.');
    const fields={name:text(d.name,2,100,'the reward name'),subtitle:text(d.subtitle??'',0,200,'the subtitle'),benefit:text(d.benefit,2,200,'the reward benefit'),category:d.category,pointsCost:integer(d.pointsCost,1,1000000,'the points cost'),validityDays:integer(d.validityDays,1,365,'the reward validity'),sortOrder:integer(d.sortOrder??0,0,10000,'the reward order'),terms:d.terms,instructions:d.instructions,active:d.active===true,updatedAt:FieldValue.serverTimestamp(),updatedBy:uid};
    await db.doc('rewardCatalogue/'+id).set(fields,{merge:true});await audit(uid,'reward_saved',id);return{saved:true,id};
  }
  async function saveWeather(request){
    const uid=await access(request),d=request.data;
    for(const [key,bound]of [['latitude',90],['longitude',180]])if(d[key]!==null&&d[key]!==undefined&&(!Number.isFinite(d[key])||Math.abs(d[key])>bound))fail('invalid-argument','Enter the actual park location.');
    if(d.enabled===true&&(!Number.isFinite(d.latitude)||!Number.isFinite(d.longitude)))fail('invalid-argument','Set the park location before enabling weather compensation.');
    const fields={enabled:d.enabled===true,latitude:d.latitude??null,longitude:d.longitude??null,parkName:text(d.parkName??'Theme Park',2,100,'the park name'),rainThresholdMm:typeof d.rainThresholdMm==='number'&&d.rainThresholdMm>=.1&&d.rainThresholdMm<=100?d.rainThresholdMm:fail('invalid-argument','Choose a rain threshold from 0.1 to 100 mm.'),voucherBenefit:text(d.voucherBenefit??'Rainy-day park benefit',2,200,'the compensation benefit'),validityDays:integer(d.validityDays??30,1,365,'voucher validity'),updatedBy:uid,updatedAt:FieldValue.serverTimestamp()};
    await db.runTransaction(async tx=>{const ref=db.doc('parkSettings/weather'),old=await tx.get(ref);tx.set(ref,{...fields,effectiveAt:fields.enabled&&old.data()?.enabled!==true?clock():old.data()?.effectiveAt??clock()});});await audit(uid,'weather_rules_saved','weather');return{saved:true};
  }
  async function refreshWeather(request){await access(request);return runWeather();}
  async function runWeather(){
    const config=(await db.doc('parkSettings/weather').get()).data();
    if(!config?.enabled||!Number.isFinite(config.latitude)||!Number.isFinite(config.longitude))return{configured:false};
    const now=clock(),day=parkDay(now),ref=db.doc('parkWeather/'+day),old=(await ref.get()).data();
    if(old?.checkedAt?.toDate()>new Date(now.getTime()-15*60000))return{configured:true,cached:true,...await issueWeatherBenefits(day)};
    const uri=new URL('https://api.open-meteo.com/v1/forecast');uri.search=new URLSearchParams({latitude:String(config.latitude),longitude:String(config.longitude),current:'temperature_2m,precipitation,weather_code',timezone:'Asia/Kuala_Lumpur'});
    let value;try{const response=await fetchWeather(uri,{signal:AbortSignal.timeout(15000)});if(!response.ok)throw Error();value=(await response.json()).current;}catch(_){fail('unavailable','Weather information is temporarily unavailable. Please try again later.');}
    if(!Number.isFinite(value?.precipitation)||!Number.isFinite(value.temperature_2m))fail('unavailable','Weather data could not be verified.');
    const raining=value.precipitation>=config.rainThresholdMm,observed=new Date(value.time+(/Z|[+-]\d\d:\d\d$/.test(value.time)?'':'+08:00'));
    if(!Number.isFinite(observed.getTime())||Math.abs(now-observed)>90*60000)fail('unavailable','Weather data is out of date. Please try again later.');
    await db.runTransaction(async tx=>{const previous=await tx.get(ref),eligible=raining&&observed>=config.effectiveAt.toDate();tx.set(ref,{day,temperature:value.temperature_2m,precipitationMm:value.precipitation,weatherCode:value.weather_code,source:'Open-Meteo',observedAt:observed,checkedAt:now,rainQualified:previous.data()?.rainQualified===true||eligible,...(eligible&&!previous.data()?.rainQualified?{qualifiedAt:now,voucherBenefit:config.voucherBenefit,validityDays:config.validityDays}:{})},{merge:true});});
    return{configured:true,day,raining,...await issueWeatherBenefits(day)};
  }
  async function claimWeather(request){
    const uid=await access(request,false);return grantWeather(uid,parkDay(clock()));
  }
  async function grantWeather(uid,day,automatic=false){
    const grantId=crypto.createHash('sha256').update(uid+'\0rain\0'+day).digest('hex');
    return db.runTransaction(async tx=>{
      const ref=db.doc('compensationGrants/'+grantId),[grant,weather,tickets,profile,security,restriction]=await Promise.all([tx.get(ref),tx.get(db.doc('parkWeather/'+day)),tx.get(db.collection('tickets').where('ownerUid','==',uid)),tx.get(db.doc('visitors/'+uid)),tx.get(db.doc('accountSecurity/'+uid)),tx.get(db.doc('visitorAccess/'+uid))]);
      if(grant.exists)return{voucherId:grant.data().voucherId,alreadyGranted:true};
      if(!profile.exists||security.data()?.closing||(restriction.exists&&restriction.data().status!=='active')){if(automatic)return null;fail('failed-precondition','This account cannot collect a weather benefit.');}
      const rain=weather.data();if(!rain?.rainQualified)fail('failed-precondition','There is no weather compensation available for today.');
      if(!tickets.docs.some(t=>{const p=t.data();return p.version===2&&['valid','used'].includes(p.status)&&p.visitDate<=day&&p.validUntil>=day&&(!p.createdAt?.toDate||p.createdAt.toDate()<=rain.qualifiedAt.toDate());})){if(automatic)return null;fail('failed-precondition','A valid park ticket for today is required to collect this benefit.');}
      const voucherId='rain_'+grantId,expiresAt=new Date(rain.qualifiedAt.toDate().getTime()+rain.validityDays*86400000),reward={name:'Rainy-day Benefit',subtitle:'Thank you for visiting us',category:'shopping',benefit:rain.voucherBenefit,terms:['One use per visitor. Present this voucher to park staff.'],instructions:['Open this voucher at the participating counter.'],validityDays:rain.validityDays};
      tx.create(db.doc('rewardVouchers/'+voucherId),{ownerUid:uid,rewardId:'weather-'+day,reward,pointsCost:0,status:'available',issuedAt:FieldValue.serverTimestamp(),expiresAt,usedAt:null,usedBy:''});tx.create(ref,{ownerUid:uid,day,voucherId,createdAt:FieldValue.serverTimestamp()});return{voucherId,alreadyGranted:false};
    });
  }
  async function issueWeatherBenefits(day){
    const weather=(await db.doc('parkWeather/'+day).get()).data();if(!weather?.rainQualified)return{issued:0};
    const dispatch=db.doc('weatherDispatch/'+day);
    let query=db.collection('tickets').where('validUntil','>=',day).orderBy('validUntil').orderBy('__name__').limit(100);
    const cursor=(await dispatch.get()).data()?.cursor;if(cursor?.validUntil&&cursor?.id)query=query.startAfter(cursor.validUntil,cursor.id);
    const page=await query.get(),owners=[...new Set(page.docs.filter(d=>{const p=d.data();return p.version===2&&['valid','used'].includes(p.status)&&p.visitDate<=day&&typeof p.ownerUid==='string'&&p.ownerUid.length>0;}).map(d=>d.data().ownerUid))];
    let issued=0;for(let i=0;i<owners.length;i+=4){const results=await Promise.all(owners.slice(i,i+4).map(uid=>grantWeather(uid,day,true)));issued+=results.filter(r=>r&&!r.alreadyGranted).length;}
    const last=page.docs.at(-1);await dispatch.set({cursor:page.size===100?{validUntil:last.data().validUntil,id:last.id}:null,checkedAt:clock()});return{issued};
  }
  async function report(request){
    await access(request);const start=timestamp(request.data.start,'the report start date'),end=timestamp(request.data.end,'the report end date');
    if(end<=start||end-start>93*86400000)fail('invalid-argument','Choose a report period up to 93 days.');
    async function rows(name,field,fields){const result=await db.collection(name).where(field,'>=',start).where(field,'<',end).select(...fields).limit(10001).get();if(result.size>10000)fail('resource-exhausted','Choose a shorter report period.');return result.docs.map(d=>({id:d.id,...d.data()}));}
    const [orders,photos,admissions,reservations,visits,vouchers,voucherUses]=await Promise.all([rows('orders','createdAt',['ownerUid','totalMinor','status','items','createdAt']),rows('photoOrders','createdAt',['ownerUid','totalMinor','status','items','createdAt']),rows('admissions','createdAt',['ownerUid','createdAt']),rows('reservations','createdAt',['ownerUid','status','attractionName','createdAt']),rows('rideAdmissions','createdAt',['ownerUid','attractionId','attractionName','createdAt']),rows('rewardVouchers','issuedAt',['status']),rows('rewardVouchers','usedAt',['usedAt'])]);
    const daily=new Map(),products=new Map(),rideCounts=new Map();
    for(const order of [...orders.filter(o=>o.status==='completed'),...photos.filter(o=>o.status==='confirmed')]){
      const date=parkDay(order.createdAt.toDate()),entry=daily.get(date)??{day:date,revenueMinor:0,orders:0};entry.revenueMinor+=order.totalMinor??0;entry.orders++;daily.set(date,entry);
      for(const item of order.items??[]){const label=item.packageName??item.title??'Park purchase',p=products.get(label)??{name:label,quantity:0,revenueMinor:0};p.quantity+=item.quantity??1;p.revenueMinor+=item.priceMinor??item.unitPriceMinor??0;products.set(label,p);}
    }
    const attractionIds=[...new Set(visits.map(v=>v.attractionId).filter(Boolean))],names=new Map();
    for(let i=0;i<attractionIds.length;i+=100){const docs=await db.getAll(...attractionIds.slice(i,i+100).map(id=>db.doc('attractions/'+id)));for(const doc of docs)names.set(doc.id,doc.data()?.name??doc.id);}
    for(const visit of visits){const name=visit.attractionName??names.get(visit.attractionId)??'Attraction';rideCounts.set(name,(rideCounts.get(name)??0)+1);}
    const redeemed=vouchers.filter(v=>v.status==='used').length;
    return{start:start.toISOString(),end:end.toISOString(),currency:'MYR',summary:{revenueMinor:[...daily.values()].reduce((n,d)=>n+d.revenueMinor,0),ticketOrders:orders.filter(o=>o.status==='completed').length,photoOrders:photos.filter(o=>o.status==='confirmed').length,parkAdmissions:admissions.length,rideAdmissions:visits.length,reservations:reservations.length,cancellations:reservations.filter(r=>r.status==='cancelled').length,vouchersIssued:vouchers.length,vouchersRedeemed:redeemed,voucherUseEvents:voucherUses.length,voucherRedemptionRate:vouchers.length?Math.round(redeemed/vouchers.length*1000)/10:0},daily:[...daily.values()].sort((a,b)=>a.day.localeCompare(b.day)),topProducts:[...products.values()].sort((a,b)=>b.revenueMinor-a.revenueMinor).slice(0,10),topAttractions:[...rideCounts].map(([name,visits])=>({name,visits})).sort((a,b)=>b.visits-a.visits).slice(0,10)};
  }
  return{saveCampaign,saveLoyalty,savePhotoSettings,saveReward,saveWeather,refreshWeather,claimWeather,report,runWeather};
}
module.exports={createParkManagementHandlers,parkDay};
