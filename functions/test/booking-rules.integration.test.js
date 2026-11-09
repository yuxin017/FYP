const {test, before} = require('node:test');
const assert = require('node:assert/strict');
const {readFile} = require('node:fs/promises');
const path = require('node:path');
const {randomBytes} = require('node:crypto');
const {localEnvironment, seedFixtures, projectId} = require('./fixtures.cjs');
const {getAuth} = require('firebase-admin/auth');
const {getFirestore} = require('firebase-admin/firestore');

localEnvironment();
const root = `projects/${projectId}/databases/(default)/documents`;
const endpoint = `http://127.0.0.1:8080/v1/${root}`;
let alice, bob, unverified;
const visitDate = new Date(Date.now() + 8 * 3600000).toISOString().slice(0, 10);

async function signIn(email) {
  const response = await fetch('http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=12345', {
    method:'POST', headers:{'Content-Type':'application/json'},
    body:JSON.stringify({email,password:'DemoVisitor123!',returnSecureToken:true}),
  });
  const body = await response.json();
  assert.equal(response.status, 200, body.error?.message);
  return {uid:body.localId, token:body.idToken};
}
function value(item) {
  if (Array.isArray(item)) return {arrayValue:{values:item.map(value)}};
  if (item !== null && typeof item === 'object') return {mapValue:{fields:Object.fromEntries(Object.entries(item).map(([k,v])=>[k,value(v)]))}};
  if (typeof item === 'number') return {integerValue:String(item)};
  if (typeof item === 'boolean') return {booleanValue:item};
  return {stringValue:item};
}
function write(collection, id, data) {
  return {
    update:{name:`${root}/${collection}/${id}`,
      fields:Object.fromEntries(Object.entries(data).map(([key,item]) => [key,value(item)]))},
    updateTransforms:[{fieldPath:'createdAt',setToServerValue:'REQUEST_TIME'}],
    currentDocument:{exists:false},
  };
}
function booking(quantity = 1, changes = {}) {
  const id = randomBytes(24).toString('hex');
  const ticketIds = Array.from({length:quantity},(_,i) => `${id}_${i+1}`);
  const order = {requestId:id,ownerUid:alice.uid,packageId:'general-admission',
    packageName:'General Admission',quantity,visitDate,unitPriceMinor:12000,
    totalMinor:12000*quantity,currency:'MYR',status:'completed',ticketIds,...changes};
  const tickets = ticketIds.map(ticketId => ({id:ticketId,data:{ownerUid:order.ownerUid,
    orderId:id,packageId:order.packageId,packageName:order.packageName,
    visitDate:order.visitDate,status:'valid',unitPriceMinor:order.unitPriceMinor,currency:'MYR'}}));
  return {id,order,tickets};
}
async function commit(pack, user = alice, ticketCount = pack.tickets.length) {
  const writes = [write('orders',pack.id,pack.order),
    ...pack.tickets.slice(0,ticketCount).map(ticket => write('tickets',ticket.id,ticket.data))];
  const response = await fetch(`${endpoint}:commit`, {
    method:'POST',headers:{'Content-Type':'application/json',Authorization:`Bearer ${user.token}`},
    body:JSON.stringify({writes}),
  });
  return {status:response.status,body:await response.json()};
}
async function readOrder(id, user) {
  const response = await fetch(`${endpoint}/orders/${id}`, {
    headers:{Authorization:`Bearer ${user.token}`},
  });
  return {status:response.status,body:await response.json()};
}

before(async () => {
  await seedFixtures();
  const rules = await readFile(path.resolve(__dirname,'../../firestore.rules'),'utf8');
  const response = await fetch(`http://127.0.0.1:8080/emulator/v1/projects/${projectId}:securityRules`, {
    method:'PUT',headers:{'Content-Type':'application/json'},
    body:JSON.stringify({rules:{files:[{name:'firestore.rules',content:rules}]}}),
  });
  const body = await response.json();
  assert.equal(response.status,200,JSON.stringify(body));
  await getFirestore().collection('ticketPackages').doc('general-admission').set({
    name:'General Admission',description:'One-day admission to the park.',priceMinor:12000,currency:'MYR',active:true,
  });
  const uid = 'rules-unverified-visitor';
  try { await getAuth().getUser(uid); }
  catch(error) {
    if(error.code !== 'auth/user-not-found') throw error;
    await getAuth().createUser({uid,email:'rules-unverified@demo.test',password:'DemoVisitor123!',emailVerified:false});
  }
  [alice,bob,unverified] = await Promise.all([
    signIn('alice@demo.test'),signIn('bob@demo.test'),signIn('rules-unverified@demo.test'),
  ]);
});

function journeyBooking(quantity=1, changes={}) {
  const id=randomBytes(24).toString('hex');
  const ticketIds=Array.from({length:quantity},(_,i)=>`${id}_${i+1}`);
  const items=ticketIds.map((_,i)=>({packageId:'general-admission',packageName:'General Admission',visitDate,validUntil:visitDate,durationDays:1,ticketType:i%2?'child':'adult',guestName:`Guest ${i+1}`,guestEmail:i%2?'bob@demo.test':'alice@demo.test',unitPriceMinor:i%2?9000:12000}));
  const subtotalMinor=items.reduce((total,item)=>total+item.unitPriceMinor,0);
  const reference=`TP-${visitDate.replaceAll('-','').slice(2)}-${id.slice(0,8).toUpperCase()}`;
  const order={version:2,ownerUid:alice.uid,requestId:id,fingerprint:'a'.repeat(64),packageId:'general-admission',packageName:'General Admission',visitDate,quantity,ticketIds,items,lineItems:[{id:'line'}],subtotalMinor,pointsUsed:0,totalMinor:subtotalMinor,paymentMethod:'fpx',cardLast4:'',currency:'MYR',status:'completed',displayCode:reference,...changes};
  const tickets=items.map((item,i)=>({id:ticketIds[i],data:{...item,item,version:2,index:i,ownerUid:alice.uid,purchaserUid:alice.uid,orderId:id,displayCode:`${reference}-${String(i+1).padStart(2,'0')}`,currency:'MYR',status:'valid'}}));
  return {id,order,tickets};
}
async function commitJourney(pack,{redeem=false,references=true}={}) {
  const writes=[write('orders',pack.id,pack.order),...pack.tickets.map(t=>write('tickets',t.id,t.data))];
  if(references) for(const ticket of pack.tickets) writes.push({update:{name:`${root}/ticketReferences/${ticket.data.displayCode}`,fields:{ticketId:value(ticket.id),ownerUid:value(alice.uid),guestEmail:value(ticket.data.guestEmail)}},currentDocument:{exists:false}});
  if(redeem) writes.push({update:{name:`${root}/visitors/${alice.uid}`,fields:{loyaltyPoints:value(2450-pack.order.pointsUsed),lastRedemptionOrderId:value(pack.id)}},updateMask:{fieldPaths:['loyaltyPoints','lastRedemptionOrderId']},currentDocument:{exists:true}});
  const response=await fetch(`${endpoint}:commit`,{method:'POST',headers:{'Content-Type':'application/json',Authorization:`Bearer ${alice.token}`},body:JSON.stringify({writes})});
  return {status:response.status,body:await response.json()};
}
test('journey issues mixed adult and child tickets and references at the ten-ticket limit',async()=>{
  await getFirestore().collection('ticketPackages').doc('general-admission').update({childPriceMinor:9000,durationDays:1});
  for(const quantity of [1,3,10]) {
    const pack=journeyBooking(quantity);const result=await commitJourney(pack);
    assert.equal(result.status,200,JSON.stringify(result.body));
    const saved=(await getFirestore().collection('orders').doc(pack.id).get()).data();
    assert.equal(saved.totalMinor,pack.order.subtotalMinor);
  }
});
test('journey rejects forged fares, missing tickets, wrong totals, and unbacked points discounts',async()=>{
  const bad=[];
  let pack=journeyBooking(2);pack.tickets.pop();bad.push(pack);
  pack=journeyBooking();pack.order.subtotalMinor=1;pack.order.totalMinor=1;bad.push(pack);
  pack=journeyBooking();pack.order.items[0].unitPriceMinor=1;pack.tickets[0].data.unitPriceMinor=1;pack.order.subtotalMinor=1;pack.order.totalMinor=1;bad.push(pack);
  bad.push(journeyBooking(1,{pointsUsed:100,totalMinor:11900}));
  pack=journeyBooking();pack.tickets[0].data.validUntil='2099-12-31';pack.order.items[0].validUntil='2099-12-31';bad.push(pack);
  for(const p of bad){const result=await commitJourney(p);assert.equal(result.status,403,JSON.stringify(result.body));assert.equal((await getFirestore().collection('orders').doc(p.id).get()).exists,false);}
});
test('points deduction is atomic, bounded by real balance and cannot increase points',async()=>{
  await getFirestore().collection('visitors').doc(alice.uid).set({uid:alice.uid,email:'alice@demo.test',loyaltyPoints:2450});
  const pack=journeyBooking(10,{pointsUsed:2000,totalMinor:105000-2000});
  const result=await commitJourney(pack,{redeem:true});assert.equal(result.status,200,JSON.stringify(result.body));
  assert.equal((await getFirestore().collection('visitors').doc(alice.uid).get()).data().loyaltyPoints,450);
  const forged=journeyBooking(1,{pointsUsed:1000,totalMinor:11000});
  assert.equal((await commitJourney(forged,{redeem:true})).status,403);
});
test('assigned guests can read only their ticket; other orders and QR references stay private',async()=>{
  const pack=journeyBooking(2);assert.equal((await commitJourney(pack)).status,200);
  async function get(collection,id,user){return fetch(`${endpoint}/${collection}/${id}`,{headers:{Authorization:`Bearer ${user.token}`}});}
  assert.equal((await get('tickets',pack.tickets[1].id,bob)).status,200);
  assert.equal((await get('tickets',pack.tickets[0].id,bob)).status,403);
  assert.equal((await get('ticketReferences',pack.tickets[1].data.displayCode,bob)).status,200);
  assert.equal((await readOrder(pack.id,bob)).status,403);
});
test('five different passes with ten guests and points fit Firestore atomic access limits',async()=>{
  await getFirestore().collection('visitors').doc(alice.uid).set({uid:alice.uid,email:'alice@demo.test',loyaltyPoints:2450});
  for(let i=0;i<5;i++)await getFirestore().collection('ticketPackages').doc('limit-pass-'+i).set({name:'Pass '+i,priceMinor:12000,childPriceMinor:9000,durationDays:1,currency:'MYR',active:true});
  const pack=journeyBooking(10,{pointsUsed:2000,totalMinor:103000});
  pack.tickets.forEach((ticket,i)=>{const index=Math.floor(i/2);const item={...pack.order.items[i],packageId:'limit-pass-'+index,packageName:'Pass '+index};pack.order.items[i]=item;Object.assign(ticket.data,item,{item});});
  pack.order.lineItems=Array.from({length:5},(_,i)=>({id:'line'+i}));
  const result=await commitJourney(pack,{redeem:true});assert.equal(result.status,200,JSON.stringify(result.body));
});

test('one-ticket and ten-ticket bookings are issued atomically within rule limits', async () => {
  const lastDate = new Date(Date.now() + 8 * 3600000 + 365 * 86400000).toISOString().slice(0,10);
  for(const [quantity,date] of [[1,visitDate],[10,visitDate],[1,lastDate]]) {
    const pack = booking(quantity,{visitDate:date});
    const result = await commit(pack);
    assert.equal(result.status,200,JSON.stringify(result.body));
    const order = await readOrder(pack.id,alice);
    assert.equal(order.status,200);
    assert.equal(order.body.fields.ticketIds.arrayValue.values.length,quantity);
    assert.equal(Number(order.body.fields.totalMinor.integerValue),12000*quantity);
  }
});
test('an incomplete order cannot issue partial tickets', async () => {
  const pack = booking(2);
  const result = await commit(pack,alice,1);
  assert.equal(result.status,403,JSON.stringify(result.body));
  assert.equal((await getFirestore().collection('orders').doc(pack.id).get()).exists,false);
  assert.equal((await getFirestore().collection('tickets').doc(pack.tickets[0].id).get()).exists,false);
});
test('prices, quantities, dates and owner identities cannot be forged', async () => {
  for(const changes of [
    {unitPriceMinor:1,totalMinor:1}, {totalMinor:1}, {quantity:11}, {quantity:0},
    {visitDate:`${new Date().getUTCFullYear()+1}-02-31`},
    {visitDate:'2000-01-01'}, {visitDate:'2099-12-31'},
    {ownerUid:bob.uid}, {currency:'USD'}, {status:'paid'}, {packageName:'Another package'},
  ]) {
    const result = await commit(booking(1,changes));
    assert.equal(result.status,403,JSON.stringify({changes,...result}));
  }
});
test('unverified visitors and inactive packages cannot create bookings', async () => {
  const unverifiedPack = booking(1,{ownerUid:unverified.uid});
  assert.equal((await commit(unverifiedPack,unverified)).status,403);
  await getFirestore().collection('ticketPackages').doc('rules-inactive').set({
    name:'General Admission',priceMinor:12000,currency:'MYR',active:false,
  });
  assert.equal((await commit(booking(1,{packageId:'rules-inactive'}))).status,403);
});
test('booking history is private and retries cannot overwrite or duplicate an order', async () => {
  const pack = booking(2);
  assert.equal((await commit(pack)).status,200);
  assert.equal((await readOrder(pack.id,bob)).status,403);
  assert.equal((await readOrder(pack.id,alice)).status,200);
  assert.notEqual((await commit(pack)).status,200);
  const saved = (await getFirestore().collection('orders').doc(pack.id).get()).data();
  assert.equal(saved.ticketIds.length,2);
  assert.equal(saved.totalMinor,24000);
});
