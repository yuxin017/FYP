const {test,before}=require('node:test');const assert=require('node:assert/strict');const crypto=require('node:crypto');
const fs=require('node:fs/promises');const path=require('node:path');
const {getFirestore}=require('firebase-admin/firestore');const {getAuth}=require('firebase-admin/auth');
const {seedFixtures,projectId}=require('./fixtures.cjs');
const root=`projects/${projectId}/databases/(default)/documents`,endpoint='http://127.0.0.1:8080/v1/'+root;
let alice,bob,admin;const newId=()=>crypto.randomBytes(24).toString('hex');
const field=v=>v===null?{nullValue:null}:v instanceof Date?{timestampValue:v.toISOString()}:Array.isArray(v)?{arrayValue:{values:v.map(field)}}:typeof v==='object'?{mapValue:{fields:Object.fromEntries(Object.entries(v).map(([k,x])=>[k,field(x)]))}}:typeof v==='number'?{integerValue:String(v)}:typeof v==='boolean'?{booleanValue:v}:{stringValue:v};
function write(collection,id,data,partial=false){const entries=Object.entries(data).filter(([,v])=>v!=='SERVER'),transforms=Object.entries(data).filter(([,v])=>v==='SERVER');return {update:{name:`${root}/${collection}/${id}`,fields:Object.fromEntries(entries.map(([k,v])=>[k,field(v)]))},...(partial?{updateMask:{fieldPaths:entries.map(([k])=>k)}}:{}),...(transforms.length?{updateTransforms:transforms.map(([fieldPath])=>({fieldPath,setToServerValue:'REQUEST_TIME'}))}:{})};}
async function commit(writes,user=alice){const r=await fetch(endpoint+':commit',{method:'POST',headers:{'Content-Type':'application/json',Authorization:'Bearer '+user.token},body:JSON.stringify({writes})});return {status:r.status,body:await r.json()};}
async function read(collection,id,user=alice){return fetch(`${endpoint}/${collection}/${id}`,{headers:{Authorization:'Bearer '+user.token}});}
async function signIn(email){const r=await fetch('http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=12345',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({email,password:'DemoVisitor123!',returnSecureToken:true})});const d=await r.json();assert.equal(r.status,200);return{uid:d.localId,token:d.idToken};}
before(async()=>{
 await seedFixtures();try{await getAuth().createUser({uid:'support-rules-admin',email:'support-admin@demo.test',password:'DemoVisitor123!',emailVerified:true});}catch(e){if(e.code!=='auth/uid-already-exists')throw e;}
 await getAuth().setCustomUserClaims('support-rules-admin',{admin:true});[alice,bob,admin]=await Promise.all([signIn('alice@demo.test'),signIn('bob@demo.test'),signIn('support-admin@demo.test')]);
 const content=await fs.readFile(path.resolve(__dirname,'../../firestore.rules'),'utf8');const r=await fetch(`http://127.0.0.1:8080/emulator/v1/projects/${projectId}:securityRules`,{method:'PUT',headers:{'Content-Type':'application/json'},body:JSON.stringify({rules:{files:[{name:'firestore.rules',content}]}})});assert.equal(r.status,200,await r.text());
 for(const user of [alice,bob,admin]){await getFirestore().collection('visitors').doc(user.uid).set({uid:user.uid,fullName:user.uid===alice.uid?'Alice Visitor':user.uid===bob.uid?'Bob Visitor':'Park Support',email:user.uid===alice.uid?'alice@demo.test':user.uid===bob.uid?'bob@demo.test':'support-admin@demo.test',phoneNumber:'+60123456789',role:'visitor',loyaltyPoints:0,createdAt:new Date()});await getFirestore().collection('visitorAccess').doc(user.uid).delete();}
});
function caseData(patch={}){return {ownerUid:alice.uid,ownerName:'Alice Visitor',type:'problem',category:'Tickets & Admission',subject:'Unable to locate my ticket',message:'Please help me find the booking for my visit.',orderId:'',contactConsent:false,contactEmail:'',fingerprint:'f'.repeat(64),attachment:null,status:'new',priority:'medium',assigneeUid:'',assigneeName:'',createdAt:'SERVER',updatedAt:'SERVER',firstResponseAt:null,resolvedAt:null,resolution:'',messageCount:0,lastMessageId:'',lastEventId:'',...patch};}
async function createCase(patch={}){const id=newId();const result=await commit([write('supportCases',id,caseData(patch))]);assert.equal(result.status,200,JSON.stringify(result.body));return id;}
async function replyWrites(id,nonce,user,body='We are reviewing your request.'){const record=(await getFirestore().collection('supportCases').doc(id).get()).data();const msg=id+'_'+nonce;const staff=user.uid===admin.uid;return [write('supportMessages',msg,{ownerUid:record.ownerUid,caseId:id,authorUid:user.uid,authorName:staff?'Park Support':'Alice Visitor',role:staff?'admin':'visitor',body,createdAt:'SERVER'}),write('supportCases',id,{messageCount:record.messageCount+1,lastMessageId:msg,updatedAt:'SERVER',...(staff?{status:'in_progress',...(record.firstResponseAt===null?{firstResponseAt:'SERVER'}:{})}:{})},true)];}
async function changeWrites(id,user,{status='in_progress',priority='medium',category='Tickets & Admission',assigneeUid='',resolution=''}={}){const old=(await getFirestore().collection('supportCases').doc(id).get()).data();const eventId=id+'_'+newId();const action=old.status!==status&&status==='resolved'?'resolved':old.status==='resolved'&&status!=='resolved'?'reopened':'updated';return [write('supportCases',id,{status,priority,category,assigneeUid,assigneeName:assigneeUid?'Park Support':'',resolution,resolvedAt:status==='resolved'?(old.status==='resolved'?old.resolvedAt.toDate():'SERVER'):null,updatedAt:'SERVER',lastEventId:eventId},true),write('supportEvents',eventId,{caseId:id,ownerUid:old.ownerUid,actorUid:user.uid,actorName:user.uid===admin.uid?'Park Support':'Alice Visitor',action,fromStatus:old.status,toStatus:status,createdAt:'SERVER'})];}
test('verified visitors create private cases with exact defaults and immutable originals',async()=>{
 const id=await createCase();assert.equal((await read('supportCases',id)).status,200);assert.equal((await read('supportCases',id,bob)).status,403);assert.equal((await read('supportCases',id,admin)).status,200);
 assert.equal((await commit([write('supportCases',id,caseData())])).status,403);
 for(const user of [alice,admin])assert.equal((await commit([write('supportCases',id,{subject:'Changed original report'},true)],user)).status,403);
 assert.equal((await read('supportCases',newId())).status,404);
});
test('spoofed identity, privileged defaults, malformed content and foreign bookings are rejected',async()=>{
 const foreign=newId(),owned=newId();await getFirestore().collection('orders').doc(foreign).set({ownerUid:bob.uid});await getFirestore().collection('orders').doc(owned).set({ownerUid:alice.uid});
 for(const patch of [{ownerUid:bob.uid},{ownerName:'Someone Else'},{priority:'high'},{status:'resolved'},{contactEmail:'other@example.com'},{message:'short'},{message:'x'.repeat(501)},{subject:'ab'},{orderId:foreign},{messageCount:3},{firstResponseAt:'SERVER'}])assert.equal((await commit([write('supportCases',newId(),caseData(patch))])).status,403,JSON.stringify(patch));
 await createCase({orderId:owned,contactConsent:true,contactEmail:'alice@demo.test'});
});
test('optional attachments are bounded, typed, private and atomically linked to a new case',async()=>{
 const bytes=Buffer.from('%PDF-1.4\nSupport attachment\n%%EOF');const meta={name:'visit-details.pdf',mime:'application/pdf',size:bytes.length,sha256:crypto.createHash('sha256').update(bytes).digest('hex')};
 const id=newId(),file={ownerUid:alice.uid,caseId:id,...meta,base64:bytes.toString('base64'),createdAt:'SERVER'};
 assert.equal((await commit([write('supportCases',id,caseData({attachment:meta}))])).status,403);
 assert.equal((await commit([write('supportAttachments',id,file)])).status,403);
 const result=await commit([write('supportCases',id,caseData({attachment:meta})),write('supportAttachments',id,file)]);assert.equal(result.status,200,JSON.stringify(result.body));
 assert.equal((await read('supportAttachments',id)).status,200);assert.equal((await read('supportAttachments',id,bob)).status,403);assert.equal((await read('supportAttachments',id,admin)).status,200);
 const tooLarge=newId(),badMeta={...meta,size:512001};assert.equal((await commit([write('supportCases',tooLarge,caseData({attachment:badMeta})),write('supportAttachments',tooLarge,{...file,...badMeta,caseId:tooLarge})])).status,403);
 const fake=newId();assert.equal((await commit([write('supportCases',fake,caseData({attachment:meta})),write('supportAttachments',fake,{...file,caseId:fake,base64:Buffer.alloc(bytes.length).toString('base64')})])).status,403);
 assert.equal((await commit([write('supportAttachments',id,{name:'changed.pdf'},true)])).status,403);
});
test('case and reply queries require ownership while administrators can see the case inbox',async()=>{
 await createCase();
 for(const collection of ['supportCases','supportMessages','supportEvents']){
  const query={structuredQuery:{from:[{collectionId:collection}],where:{fieldFilter:{field:{fieldPath:'ownerUid'},op:'EQUAL',value:field(alice.uid)}}}};
  const request=async(body,user)=>fetch(endpoint+':runQuery',{method:'POST',headers:{Authorization:'Bearer '+user.token,'Content-Type':'application/json'},body:JSON.stringify(body)});
  assert.equal((await request(query,alice)).status,200);
  const broad={structuredQuery:{from:[{collectionId:collection}]}};assert.equal((await request(broad,alice)).status,403);assert.equal((await request(broad,admin)).status,200);
 }
});
test('public replies require an owned case and atomic counters; role impersonation and replay fail',async()=>{
 const id=await createCase(),nonce=newId(),writes=await replyWrites(id,nonce,alice,'Here is some more information.');
 assert.equal((await commit([writes[0]])).status,403);assert.equal((await commit([writes[1]])).status,403);assert.equal((await commit(writes,bob)).status,403);
 const forged=await replyWrites(id,newId(),alice);forged[0].update.fields.role=field('admin');assert.equal((await commit(forged)).status,403);
 const result=await commit(writes);assert.equal(result.status,200,JSON.stringify(result.body));assert.equal((await commit(writes)).status,403);
 assert.equal((await getFirestore().collection('supportCases').doc(id).get()).data().messageCount,1);
});
test('simultaneous replies preserve counters and admin response timestamps reflect the first reply only',async()=>{
 const id=await createCase(),a=newId(),b=newId();const writes=await Promise.all([replyWrites(id,a,alice),replyWrites(id,b,alice)]);const results=await Promise.all(writes.map(w=>commit(w)));assert.equal(results.filter(r=>r.status===200).length,1,JSON.stringify(results));
 const retry=results[0].status===200?b:a;assert.equal((await commit(await replyWrites(id,retry,alice))).status,200);
 const first=await commit(await replyWrites(id,newId(),admin),admin);assert.equal(first.status,200,JSON.stringify(first.body));
 const stamp=(await getFirestore().collection('supportCases').doc(id).get()).data().firstResponseAt.toMillis();
 assert.equal((await commit(await replyWrites(id,newId(),admin),admin)).status,200);
 assert.equal((await getFirestore().collection('supportCases').doc(id).get()).data().firstResponseAt.toMillis(),stamp);
});
test('internal notes are immutable administrator-only records, including queries',async()=>{
 const id=await createCase(),noteId=id+'_'+newId(),note={ownerUid:alice.uid,caseId:id,authorUid:admin.uid,authorName:'Park Support',role:'admin',body:'Private case handling note.',createdAt:'SERVER'};
 assert.equal((await commit([write('supportNotes',noteId,note)],admin)).status,200);assert.equal((await read('supportNotes',noteId)).status,403);assert.equal((await read('supportNotes',noteId,admin)).status,200);
 assert.equal((await commit([write('supportNotes',id+'_'+newId(),{...note,authorUid:alice.uid})])).status,403);
 assert.equal((await commit([write('supportNotes',noteId,{body:'Changed note'},true)],admin)).status,403);
 const r=await fetch(endpoint+':runQuery',{method:'POST',headers:{Authorization:'Bearer '+alice.token,'Content-Type':'application/json'},body:JSON.stringify({structuredQuery:{from:[{collectionId:'supportNotes'}],where:{fieldFilter:{field:{fieldPath:'ownerUid'},op:'EQUAL',value:field(alice.uid)}}}})});assert.equal(r.status,403);
});
test('admin handling is audited; resolution needs a summary; owners can explicitly reopen their own case',async()=>{
 const id=await createCase();let writes=await changeWrites(id,admin,{status:'in_progress',priority:'high',assigneeUid:admin.uid});
 assert.equal((await commit([writes[0]],admin)).status,403);assert.equal((await commit(writes,alice)).status,403);
 let result=await commit(writes,admin);assert.equal(result.status,200,JSON.stringify(result.body));
 writes=await changeWrites(id,admin,{status:'resolved'});assert.equal((await commit(writes,admin)).status,403);
 result=await commit(await changeWrites(id,admin,{status:'resolved',resolution:'The visitor has located the saved ticket.'}),admin);assert.equal(result.status,200,JSON.stringify(result.body));
 assert.equal((await commit(await replyWrites(id,newId(),alice))).status,403);
 const reopened=await changeWrites(id,alice);const fieldsToRemove=['priority','category','assigneeUid','assigneeName'];for(const key of fieldsToRemove){delete reopened[0].update.fields[key];reopened[0].updateMask.fieldPaths=reopened[0].updateMask.fieldPaths.filter(p=>p!==key);}
 result=await commit(reopened);assert.equal(result.status,200,JSON.stringify(result.body));
 const ownerChange=await changeWrites(id,alice,{priority:'high'});assert.equal((await commit(ownerChange)).status,403);
});
test('suspended accounts cannot create, reply or alter status through direct writes',async()=>{
 const id=await createCase();await getFirestore().collection('visitorAccess').doc(alice.uid).set({status:'suspended'});
 assert.equal((await commit([write('supportCases',newId(),caseData())])).status,403);
 assert.equal((await commit(await replyWrites(id,newId(),alice))).status,403);
 assert.equal((await commit(await replyWrites(id,newId(),admin),admin)).status,200);
 await getFirestore().collection('visitorAccess').doc(alice.uid).delete();
});
