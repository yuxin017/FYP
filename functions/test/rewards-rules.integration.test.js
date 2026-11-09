const {test,before}=require('node:test');
const assert=require('node:assert/strict');
const crypto=require('node:crypto');
const fs=require('node:fs/promises');
const path=require('node:path');
const {getFirestore}=require('firebase-admin/firestore');
const {seedFixtures,projectId}=require('./fixtures.cjs');
const root=`projects/${projectId}/databases/(default)/documents`;
const endpoint='http://127.0.0.1:8080/v1/'+root;
let alice,bob;
const newId=()=>crypto.randomBytes(24).toString('hex');
const field=v=>v===null?{nullValue:null}:v instanceof Date?{timestampValue:v.toISOString()}:Array.isArray(v)?{arrayValue:{values:v.map(field)}}:typeof v==='object'?{mapValue:{fields:Object.fromEntries(Object.entries(v).map(([k,x])=>[k,field(x)]))}}:typeof v==='number'?{integerValue:String(v)}:typeof v==='boolean'?{booleanValue:v}:{stringValue:v};
function write(collection,id,data,partial=false){const values=Object.entries(data).filter(([,v])=>v!=='SERVER'),transforms=Object.entries(data).filter(([,v])=>v==='SERVER');return {update:{name:`${root}/${collection}/${id}`,fields:Object.fromEntries(values.map(([k,v])=>[k,field(v)]))},...(partial?{updateMask:{fieldPaths:values.map(([k])=>k)}}:{}),...(transforms.length?{updateTransforms:transforms.map(([fieldPath])=>({fieldPath,setToServerValue:'REQUEST_TIME'}))}:{})};}
async function commit(writes,user=alice){const r=await fetch(endpoint+':commit',{method:'POST',headers:{'Content-Type':'application/json',Authorization:'Bearer '+user.token},body:JSON.stringify({writes})});return {status:r.status,body:await r.json()};}
async function signIn(email){const r=await fetch('http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=12345',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({email,password:'DemoVisitor123!',returnSecureToken:true})});const d=await r.json();assert.equal(r.status,200);return{uid:d.localId,token:d.idToken};}
const offer={name:'20% Off Dining',subtitle:'Selected park restaurants',category:'dining',benefit:'20% off eligible dining items.',pointsCost:150,validityDays:30,instructions:['Show staff before payment.','Confirm use when accepted.'],terms:['One use only.'],active:true,sortOrder:1};
const snapshot=Object.fromEntries(['name','subtitle','category','benefit','terms','instructions','validityDays'].map(k=>[k,offer[k]]));
before(async()=>{
 await seedFixtures();[alice,bob]=await Promise.all([signIn('alice@demo.test'),signIn('bob@demo.test')]);
 const content=await fs.readFile(path.resolve(__dirname,'../../firestore.rules'),'utf8');
 const r=await fetch(`http://127.0.0.1:8080/emulator/v1/projects/${projectId}:securityRules`,{method:'PUT',headers:{'Content-Type':'application/json'},body:JSON.stringify({rules:{files:[{name:'firestore.rules',content}]}})});assert.equal(r.status,200,await r.text());
 await getFirestore().collection('visitorAccess').doc(alice.uid).delete();
 await getFirestore().collection('rewardCatalogue').doc('dining').set(offer);
});
async function profile(points=1000){await getFirestore().collection('visitors').doc(alice.uid).set({uid:alice.uid,fullName:'Alice Visitor',email:'alice@demo.test',phoneNumber:'+60123456789',role:'visitor',loyaltyPoints:points,createdAt:new Date()});}
async function order(totalMinor=14000,extra={}){const id=newId();await getFirestore().collection('orders').doc(id).set({version:2,ownerUid:alice.uid,totalMinor,status:'completed',currency:'MYR',...extra});return id;}
test('ticket earning uses the immutable rate recorded on that purchase',async()=>{
 await profile(1000);const id=await order(10000,{loyaltyEarnRate:3});
 assert.equal((await commit(earn(id,100,1000))).status,403);
 assert.equal((await commit(earn(id,300,1000))).status,200);
});
function earn(id,delta,balance){const event='earn_'+id;return [write('loyaltyEvents',event,{ownerUid:alice.uid,kind:'earned',sourceId:id,delta,createdAt:'SERVER'}),write('visitors',alice.uid,{loyaltyPoints:balance+delta,lastLoyaltyEventId:event},true)];}
function redeem(id,balance=1000,cost=150){const today=new Date(Date.now()+8*3600000);const expires=new Date(Date.UTC(today.getUTCFullYear(),today.getUTCMonth(),today.getUTCDate()+30)-8*3600000);return [write('rewardVouchers',id,{ownerUid:alice.uid,rewardId:'dining',reward:snapshot,pointsCost:cost,status:'available',issuedAt:'SERVER',expiresAt:expires,usedAt:null,usedBy:''}),write('loyaltyEvents','redeem_'+id,{ownerUid:alice.uid,kind:'redeemed',sourceId:id,delta:-cost,createdAt:'SERVER'}),write('visitors',alice.uid,{loyaltyPoints:balance-cost,lastLoyaltyEventId:'redeem_'+id},true)];}
test('points are earned once from completed purchases and only for the net MYR total',async()=>{
 await profile(0);const id=await order(13999);const result=await commit(earn(id,139,0));assert.equal(result.status,200,JSON.stringify(result.body));
 assert.equal((await commit(earn(id,139,139))).status,403);
 assert.equal((await getFirestore().collection('visitors').doc(alice.uid).get()).data().loyaltyPoints,139);
 const discounted=await order(12000);assert.equal((await commit(earn(discounted,120,139))).status,200);
});
test('forged, foreign, incomplete and atomicity-breaking credits are rejected',async()=>{
 await profile(0);const id=await order();
 for(const writes of [earn(id,9999,0),[earn(id,140,0)[0]],[earn(id,140,0)[1]],[write('visitors',alice.uid,{loyaltyPoints:9999},true)]])assert.equal((await commit(writes)).status,403);
 for(const extra of [{ownerUid:bob.uid},{status:'pending'},{version:1},{currency:'USD'}]){const invalid=await order(14000,extra);assert.equal((await commit(earn(invalid,140,0))).status,403);}
 assert.equal((await commit(earn(id,140,0),bob)).status,403);
});
test('voucher creation, catalogue price, ledger debit and balance are coupled atomically',async()=>{
 await profile();const id=newId(),valid=redeem(id);const result=await commit(valid);assert.equal(result.status,200,JSON.stringify(result.body));
 assert.equal((await getFirestore().collection('visitors').doc(alice.uid).get()).data().loyaltyPoints,850);
 assert.equal((await commit(redeem(id,850))).status,403);
 for(const writes of [[redeem(newId(),850)[0]],redeem(newId(),850,1),redeem(newId(),1000)])assert.equal((await commit(writes)).status,403);
 const changed=redeem(newId(),850);changed[0].update.fields.reward.mapValue.fields.name=field('Forged reward');assert.equal((await commit(changed)).status,403);
 const extended=redeem(newId(),850);extended[0].update.fields.expiresAt=field(new Date(Date.now()+365*86400000));assert.equal((await commit(extended)).status,403);
});
test('simultaneous redemptions cannot overspend the same points',async()=>{
 await profile(150);const results=await Promise.all([commit(redeem(newId(),150)),commit(redeem(newId(),150))]);
 assert.equal(results.filter(r=>r.status===200).length,1,JSON.stringify(results));
 assert.equal((await getFirestore().collection('visitors').doc(alice.uid).get()).data().loyaltyPoints,0);
 assert.equal((await commit(redeem(newId(),0))).status,403);
});
test('vouchers can be used once, cannot be extended or transferred, and reject expired use',async()=>{
 await profile();const id=newId();assert.equal((await commit(redeem(id))).status,200);
 const use=()=>[write('rewardVouchers',id,{status:'used',usedAt:'SERVER',usedBy:alice.uid},true)];
 assert.equal((await commit(use(),bob)).status,403);
 for(const patch of [{expiresAt:new Date(Date.now()+999*86400000)},{ownerUid:bob.uid},{pointsCost:1}])assert.equal((await commit([write('rewardVouchers',id,patch,true)])).status,403);
 const results=await Promise.all([commit(use()),commit(use())]);assert.equal(results.filter(r=>r.status===200).length,1);
 assert.equal((await commit(use())).status,403);
 const expired=newId();await getFirestore().collection('rewardVouchers').doc(expired).set({ownerUid:alice.uid,status:'available',expiresAt:new Date(Date.now()-1000)});
 assert.equal((await commit([write('rewardVouchers',expired,{status:'used',usedAt:'SERVER',usedBy:alice.uid},true)])).status,403);
});
test('reward data is account-scoped and suspension blocks direct reward writes',async()=>{
 await profile();const id=newId();assert.equal((await commit(redeem(id))).status,200);
 for(const collection of ['rewardVouchers','loyaltyEvents']){const doc=collection==='rewardVouchers'?id:'redeem_'+id;const r=await fetch(`${endpoint}/${collection}/${doc}`,{headers:{Authorization:'Bearer '+bob.token}});assert.equal(r.status,403);}
 for(const collection of ['rewardVouchers','loyaltyEvents']){
  const missing=await fetch(`${endpoint}/${collection}/${newId()}`,{headers:{Authorization:'Bearer '+alice.token}});assert.equal(missing.status,404);
  const query={structuredQuery:{from:[{collectionId:collection}],where:{fieldFilter:{field:{fieldPath:'ownerUid'},op:'EQUAL',value:field(alice.uid)}}}};
  const own=await fetch(endpoint+':runQuery',{method:'POST',headers:{Authorization:'Bearer '+alice.token,'Content-Type':'application/json'},body:JSON.stringify(query)});assert.equal(own.status,200,await own.text());
  const broad=await fetch(endpoint+':runQuery',{method:'POST',headers:{Authorization:'Bearer '+alice.token,'Content-Type':'application/json'},body:JSON.stringify({structuredQuery:{from:[{collectionId:collection}]}})});assert.equal(broad.status,403);
 }
 assert.equal((await commit([write('rewardCatalogue','forged',offer)])).status,403);
 await getFirestore().collection('visitorAccess').doc(alice.uid).set({status:'suspended'});
 assert.equal((await commit(redeem(newId(),850))).status,403);
 const purchase=await order();assert.equal((await commit(earn(purchase,140,850))).status,403);
 await getFirestore().collection('visitorAccess').doc(alice.uid).delete();
});
