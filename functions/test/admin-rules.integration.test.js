const {test,before}=require('node:test');
const assert=require('node:assert/strict');
const {randomBytes}=require('node:crypto');
const {readFile}=require('node:fs/promises');
const path=require('node:path');
const {localEnvironment,seedFixtures,projectId}=require('./fixtures.cjs');
const {getAuth}=require('firebase-admin/auth');
const {getFirestore}=require('firebase-admin/firestore');
localEnvironment();
const root=`projects/${projectId}/databases/(default)/documents`,endpoint=`http://127.0.0.1:8080/v1/${root}`;
let admin,otherAdmin,visitor;
const parkNow=new Date(Date.now()+8*3600000),dayKey=parkNow.toISOString().slice(0,10),day=new Date(dayKey+'T00:00:00.000Z');
const shifted=n=>new Date(day.getTime()+n*86400000).toISOString().slice(0,10);
const newId=()=>randomBytes(24).toString('hex');
const value=v=>v instanceof Date?{timestampValue:v.toISOString()}:Array.isArray(v)?{arrayValue:{values:v.map(value)}}:v!==null&&typeof v==='object'?{mapValue:{fields:Object.fromEntries(Object.entries(v).map(([k,x])=>[k,value(x)]))}}:typeof v==='number'?{integerValue:String(v)}:typeof v==='boolean'?{booleanValue:v}:{stringValue:v};
function write(collection,id,data,{partial=false,create=false}={}){
 const normal=Object.entries(data).filter(([,v])=>v!=='SERVER');const transforms=Object.entries(data).filter(([,v])=>v==='SERVER');
 return {update:{name:`${root}/${collection}/${id}`,fields:Object.fromEntries(normal.map(([k,v])=>[k,value(v)]))},...(partial?{updateMask:{fieldPaths:normal.map(([k])=>k)}}:{}),...(transforms.length?{updateTransforms:transforms.map(([fieldPath])=>({fieldPath,setToServerValue:'REQUEST_TIME'}))}:{}),...(create?{currentDocument:{exists:false}}:{})};
}
async function commit(writes,user=admin){const r=await fetch(endpoint+':commit',{method:'POST',headers:{'Content-Type':'application/json',Authorization:'Bearer '+user.token},body:JSON.stringify({writes})});return {status:r.status,body:await r.json()};}
async function read(collection,id,user=admin){return fetch(`${endpoint}/${collection}/${id}`,{headers:{Authorization:'Bearer '+user.token}});}
async function signIn(email){const r=await fetch('http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=12345',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({email,password:'DemoVisitor123!',returnSecureToken:true})});const d=await r.json();assert.equal(r.status,200,JSON.stringify(d));return{uid:d.localId,token:d.idToken};}
before(async()=>{
 await seedFixtures();
 for(const [uid,email] of [['rules-admin','rules-admin@demo.test'],['rules-admin-two','rules-admin-two@demo.test']]){try{await getAuth().createUser({uid,email,password:'DemoVisitor123!',emailVerified:true});}catch(e){if(e.code!=='auth/uid-already-exists')throw e;}await getAuth().setCustomUserClaims(uid,{admin:true});}
 [admin,otherAdmin,visitor]=await Promise.all([signIn('rules-admin@demo.test'),signIn('rules-admin-two@demo.test'),signIn('alice@demo.test')]);
 const content=await readFile(path.resolve(__dirname,'../../firestore.rules'),'utf8');
 const r=await fetch(`http://127.0.0.1:8080/emulator/v1/projects/${projectId}:securityRules`,{method:'PUT',headers:{'Content-Type':'application/json'},body:JSON.stringify({rules:{files:[{name:'firestore.rules',content}]}})});assert.equal(r.status,200,await r.text());
 await getFirestore().collection('visitors').doc(visitor.uid).set({uid:visitor.uid,fullName:'Alice Visitor',email:'alice@demo.test',phoneNumber:'+60123456789',role:'visitor',loyaltyPoints:0,createdAt:new Date()});
 await getFirestore().collection('ticketPackages').doc('admin-pass').delete();
 await getFirestore().collection('visitorSessions').doc(visitor.uid+'_'+dayKey).delete();
});
const access=(id,status,user=admin)=>write('visitorAccess',id,{status,reason:'Account review',updatedBy:user.uid,updatedAt:'SERVER'});
test('only trusted admin claims can manage profiles, private notes and visitor access',async()=>{
 const meta={membership:'gold',riskLevel:'review',watchlisted:true,notes:'Private admin note',updatedBy:admin.uid,updatedAt:'SERVER'};
 assert.equal((await commit([write('visitorAdmin',visitor.uid,meta)])).status,200);
 assert.equal((await read('visitorAdmin',visitor.uid,visitor)).status,403);
 assert.equal((await commit([write('visitorAdmin',visitor.uid,{...meta,updatedBy:visitor.uid})],visitor)).status,403);
 assert.equal((await commit([access(visitor.uid,'suspended')])).status,200);
 assert.equal((await read('visitorAccess',visitor.uid,visitor)).status,200);
 assert.equal((await commit([access(visitor.uid,'active',visitor)],visitor)).status,403);
 assert.equal((await commit([access(admin.uid,'suspended')])).status,403);
 assert.equal((await commit([write('visitors',visitor.uid,{fullName:'Alice Updated'},{partial:true})])).status,200);
 for(const patch of [{role:'admin'},{loyaltyPoints:99999},{email:'other@demo.test'}])assert.equal((await commit([write('visitors',visitor.uid,patch,{partial:true})])).status,403);
 assert.equal((await commit([access(visitor.uid,'active')])).status,200);
});
test('live pass packages are admin-only writes with trusted prices and soft deactivation',async()=>{
 const pack={name:'Admin Day Pass',description:'A park day pass.',priceMinor:12000,childPriceMinor:9000,currency:'MYR',active:true,category:'day',imageAsset:'assets/images/ticketing/castle.png',durationDays:1,sortOrder:1,createdAt:'SERVER',updatedAt:'SERVER',updatedBy:admin.uid};
 assert.equal((await commit([write('ticketPackages','admin-pass',pack)])).status,200);
 assert.equal((await read('ticketPackages','admin-pass',visitor)).status,200);
 assert.equal((await commit([write('ticketPackages','visitor-forged-pass',{...pack,updatedBy:visitor.uid})],visitor)).status,403);
 for(const patch of [{priceMinor:0},{currency:'USD'},{durationDays:366},{updatedBy:visitor.uid}]){assert.equal((await commit([write('ticketPackages','admin-pass',{...patch,updatedAt:'SERVER'},{partial:true})])).status,403);}
 assert.equal((await commit([write('ticketPackages','admin-pass',{active:false,updatedBy:admin.uid,updatedAt:'SERVER'},{partial:true})])).status,200);
 assert.equal((await read('ticketPackages','admin-pass',visitor)).status,403);
 assert.equal((await read('ticketPackages','admin-pass')).status,200);
 await getFirestore().collection('ticketPackages').doc('admin-pass').update({active:true});
});
test('suspended access blocks direct checkout and cannot be reset by a visitor',async()=>{
 await commit([access(visitor.uid,'suspended')]);
 const id=newId(),ticketId=id+'_1';
 const order={requestId:id,ownerUid:visitor.uid,packageId:'admin-pass',packageName:'Admin Day Pass',quantity:1,visitDate:dayKey,unitPriceMinor:12000,totalMinor:12000,currency:'MYR',status:'completed',ticketIds:[ticketId],createdAt:'SERVER'};
 const ticket={ownerUid:visitor.uid,orderId:id,packageId:'admin-pass',packageName:'Admin Day Pass',visitDate:dayKey,status:'valid',unitPriceMinor:12000,currency:'MYR',createdAt:'SERVER'};
 assert.equal((await commit([write('orders',id,order,{create:true}),write('tickets',ticketId,ticket,{create:true})],visitor)).status,403);
 await commit([access(visitor.uid,'active')]);
 assert.equal((await commit([write('orders',id,order,{create:true}),write('tickets',ticketId,ticket,{create:true})],visitor)).status,200);
});
test('visitor sessions are account-scoped, day-scoped, and preserve their creation timestamp',async()=>{
 const id=visitor.uid+'_'+dayKey,data={ownerUid:visitor.uid,day:dayKey,action:'session_opened',createdAt:'SERVER',lastSeenAt:'SERVER'};
 assert.equal((await commit([write('visitorSessions',id,data)],visitor)).status,200);
 assert.equal((await commit([write('visitorSessions',id,{lastSeenAt:'SERVER'},{partial:true})],visitor)).status,200);
 assert.equal((await commit([write('visitorSessions',id,{ownerUid:admin.uid},{partial:true})],visitor)).status,403);
 assert.equal((await commit([write('visitorSessions',visitor.uid+'_2099-01-01',{...data,day:'2099-01-01'})],visitor)).status,403);
});
async function seedTicket({start=dayKey,end=dayKey,status='valid',previous=[]}={}){
 const id=newId()+'_1';await getFirestore().collection('tickets').doc(id).set({ownerUid:visitor.uid,orderId:id.split('_')[0],packageName:'Admission Pass',visitDate:start,validUntil:end,status,admissionDays:previous});return id;
}
function admissionWrites(id,request,user,{status='used',previous=[]}={}){
 return [write('tickets',id,{status,usedAt:'SERVER',usedBy:user.uid,validationId:request,lastAdmissionDay:day,admissionDays:[...previous,day]},{partial:true}),write('admissions',request,{ticketId:id,orderId:id.split('_')[0],ownerUid:visitor.uid,actorUid:user.uid,visitDay:day,createdAt:'SERVER',outcome:'admitted'},{create:true})];
}
test('only an administrator can atomically admit a current-day ticket and write its audit receipt',async()=>{
 const id=await seedTicket(),request=newId();
 assert.equal((await commit(admissionWrites(id,request,visitor),visitor)).status,403);
 assert.equal((await commit([admissionWrites(id,request,admin)[0]])).status,403);
 const result=await commit(admissionWrites(id,request,admin));assert.equal(result.status,200,JSON.stringify(result.body));
 assert.equal((await commit(admissionWrites(id,newId(),admin))).status,403);
 assert.equal((await read('admissions',request,visitor)).status,403);
 assert.equal((await getFirestore().collection('tickets').doc(id).get()).data().status,'used');
});
test('simultaneous scans admit exactly once; invalid dates, cancelled tickets and altered fares are rejected',async()=>{
 const id=await seedTicket();const results=await Promise.all([commit(admissionWrites(id,newId(),admin),admin),commit(admissionWrites(id,newId(),otherAdmin),otherAdmin)]);
 assert.equal(results.filter(r=>r.status===200).length,1);
 assert.equal((await getFirestore().collection('tickets').doc(id).get()).data().admissionDays.length,1);
 for(const config of [{start:shifted(1),end:shifted(1)},{start:shifted(-1),end:shifted(-1)},{status:'cancelled'}]){const ticket=await seedTicket(config);assert.equal((await commit(admissionWrites(ticket,newId(),admin))).status,403);}
 const ticket=await seedTicket();const forged=admissionWrites(ticket,newId(),admin);forged[0].update.fields.unitPriceMinor=value(1);forged[0].updateMask.fieldPaths.push('unitPriceMinor');assert.equal((await commit(forged)).status,403);
});
test('multi-day and annual passes admit once per valid day without losing their remaining validity',async()=>{
 const yesterday=new Date(day.getTime()-86400000);const id=await seedTicket({start:shifted(-1),end:shifted(2),previous:[yesterday]});
 const result=await commit(admissionWrites(id,newId(),admin,{status:'valid',previous:[yesterday]}));assert.equal(result.status,200,JSON.stringify(result.body));
 assert.equal((await commit(admissionWrites(id,newId(),admin,{status:'valid',previous:[yesterday,day]}))).status,403);
 assert.equal((await getFirestore().collection('tickets').doc(id).get()).data().status,'valid');
});
test('administrator audit records cannot impersonate another actor or be rewritten',async()=>{
 const id=newId(),data={action:'visitor_updated',targetIds:[visitor.uid],actorUid:admin.uid,details:{fields:['fullName']},createdAt:'SERVER'};
 assert.equal((await commit([write('adminAudit',id,data,{create:true})])).status,200);
 assert.equal((await commit([write('adminAudit',newId(),{...data,actorUid:visitor.uid},{create:true})])).status,403);
 assert.equal((await commit([write('adminAudit',id,{action:'watchlist_added'},{partial:true})])).status,403);
});
