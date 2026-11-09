const assert=require('node:assert/strict');
const {before,test}=require('node:test');
const {randomUUID}=require('node:crypto');
const project=process.env.GCLOUD_PROJECT,db=process.env.FIRESTORE_EMULATOR_HOST,auth=process.env.FIREBASE_AUTH_EMULATOR_HOST;
if(!['demo-fyp-module1','demo-themepark-fyp'].includes(project)||!['127.0.0.1:8832','127.0.0.1:8080'].includes(db)||!['127.0.0.1:9192','127.0.0.1:9099'].includes(auth))throw Error('Only isolated local test services are allowed');
const root=`http://${db}/v1/projects/${project}/databases/(default)/documents`,id='reservation-rules-'+randomUUID();let owner,other,admin;
async function call(url,token,method='GET',data){const response=await fetch(url,{method,headers:{'Content-Type':'application/json',...(token?{Authorization:'Bearer '+token}:{})},body:data===undefined?undefined:JSON.stringify(data)});return {status:response.status,data:response.status===204?null:await response.json()};}
async function account(isAdmin=false){
 const result=await call(`http://${auth}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=test` ,undefined,'POST',{returnSecureToken:true});assert.equal(result.status,200);
 if(!isAdmin)return result.data;
 assert.equal((await call(`http://${auth}/identitytoolkit.googleapis.com/v1/projects/${project}/accounts:update`,'owner','POST',{localId:result.data.localId,customAttributes:JSON.stringify({admin:true})})).status,200);
 const response=await fetch(`http://${auth}/securetoken.googleapis.com/v1/token?key=test`,{method:'POST',headers:{'Content-Type':'application/x-www-form-urlencoded'},body:new URLSearchParams({grant_type:'refresh_token',refresh_token:result.data.refreshToken})});const refreshed=await response.json();assert.equal(response.status,200);
 return {...result.data,idToken:refreshed.id_token};
}
before(async()=>{owner=await account();other=await account();admin=await account(true);assert.equal((await call(`${root}/reservations/${id}`,'owner','PATCH',{fields:{ownerUid:{stringValue:owner.localId},status:{stringValue:'confirmed'}}})).status,200);});
test('only the owner and admin can read an existing reservation',async()=>{
 assert.equal((await call(`${root}/reservations/${id}`,owner.idToken)).status,200);assert.equal((await call(`${root}/reservations/${id}`,admin.idToken)).status,200);
 assert.equal((await call(`${root}/reservations/${id}`,other.idToken)).status,403);assert.equal((await call(`${root}/reservations/${id}`)).status,403);
});
test('visitor lists require an owner query and cannot list someone else',async()=>{
 const query=(uid)=>({structuredQuery:{from:[{collectionId:'reservations'}],...(uid?{where:{fieldFilter:{field:{fieldPath:'ownerUid'},op:'EQUAL',value:{stringValue:uid}}}}:{})}});
 assert.equal((await call(`${root}:runQuery`,owner.idToken,'POST',query(owner.localId))).status,200);
 assert.equal((await call(`${root}:runQuery`,owner.idToken,'POST',query(other.localId))).status,403);
 assert.equal((await call(`${root}:runQuery`,owner.idToken,'POST',query())).status,403);
 assert.equal((await call(`${root}:runQuery`,admin.idToken,'POST',query())).status,200);
});
test('the admin portal can read one Kuala Lumpur visit day and look up its visitors', async () => {
 const start = '2089-11-06T16:00:00Z';
 const end = '2089-11-07T16:00:00Z';
 for (const [label, time] of [['before', '2089-11-06T15:59:59Z'], ['in-day', start], ['after', end]]) {
  const saved = await call(`${root}/reservations/${id}-${label}`, 'owner', 'PATCH', {
   fields: {ownerUid: {stringValue: owner.localId}, startsAt: {timestampValue: time}},
  });
  assert.equal(saved.status, 200);
 }
 const field = {fieldPath: 'startsAt'};
 const query = {structuredQuery: {
  from: [{collectionId: 'reservations'}],
  where: {compositeFilter: {op: 'AND', filters: [
   {fieldFilter: {field, op: 'GREATER_THAN_OR_EQUAL', value: {timestampValue: start}}},
   {fieldFilter: {field, op: 'LESS_THAN', value: {timestampValue: end}}},
  ]}},
  orderBy: [{field, direction: 'ASCENDING'}],
 }};
 const day = await call(`${root}:runQuery`, admin.idToken, 'POST', query);
 assert.equal(day.status, 200);
 assert.deepEqual(day.data.flatMap(row => row.document ? [row.document.name.split('/').at(-1)] : []).filter(name => name.startsWith(id)), [`${id}-in-day`]);
 assert.equal((await call(`${root}:runQuery`, owner.idToken, 'POST', query)).status, 403);

 const profile = `projects/${project}/databases/(default)/documents/visitors/${owner.localId}`;
 assert.equal((await call(`${root}/visitors/${owner.localId}`, 'owner', 'PATCH', {fields: {fullName: {stringValue: 'Test Visitor'}}})).status, 200);
 const names = await call(`${root}:runQuery`, admin.idToken, 'POST', {structuredQuery: {
  from: [{collectionId: 'visitors'}],
  where: {fieldFilter: {field: {fieldPath: '__name__'}, op: 'IN', value: {arrayValue: {values: [{referenceValue: profile}]}}}},
 }});
 assert.equal(names.status, 200);
 assert.equal(names.data[0].document.fields.fullName.stringValue, 'Test Visitor');
});
test('visitors and portal admins cannot bypass callables to create, alter or erase reservations',async()=>{
 for(const token of [owner.idToken,other.idToken,admin.idToken]){
  assert.equal((await call(`${root}/reservations/new-${randomUUID()}`,token,'PATCH',{fields:{ownerUid:{stringValue:owner.localId},status:{stringValue:'confirmed'}}})).status,403);
  assert.equal((await call(`${root}/reservations/${id}?updateMask.fieldPaths=status`,token,'PATCH',{fields:{status:{stringValue:'cancelled'}}})).status,403);
  assert.equal((await call(`${root}/reservations/${id}`,token,'DELETE')).status,403);
 }
});
