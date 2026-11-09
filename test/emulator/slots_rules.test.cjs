const assert=require('node:assert/strict');
const {randomUUID}=require('node:crypto');
const {before,test}=require('node:test');
const project=process.env.GCLOUD_PROJECT,db=process.env.FIRESTORE_EMULATOR_HOST,auth=process.env.FIREBASE_AUTH_EMULATOR_HOST;
const local=/^(127\.0\.0\.1|localhost):\d+$/;
if(!project?.startsWith('demo-') || !local.test(db||'') || !local.test(auth||''))throw Error('Only isolated local demo emulators are allowed');
const root=`http://${db}/v1/projects/${project}/databases/(default)/documents`,prefix='slots-'+randomUUID();
let admin,visitor;
async function request(url,method='GET',body,token){
 const response=await fetch(url,{method,headers:{'Content-Type':'application/json',...(token?{Authorization:'Bearer '+token}:{})},body:body===undefined?undefined:JSON.stringify(body)});
 return {status:response.status,data:await response.json()};
}
async function account(isAdmin){
 const sign=await request(`http://${auth}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=emulator-only-key`,'POST',{returnSecureToken:true});assert.equal(sign.status,200);
 if(!isAdmin)return sign.data;
 const claim=await request(`http://${auth}/identitytoolkit.googleapis.com/v1/projects/${project}/accounts:update`,'POST',
  {localId:sign.data.localId,customAttributes:JSON.stringify({admin:true})},'owner');assert.equal(claim.status,200);
 const response=await fetch(`http://${auth}/securetoken.googleapis.com/v1/token?key=emulator-only-key`,{method:'POST',headers:{'Content-Type':'application/x-www-form-urlencoded'},
  body:new URLSearchParams({grant_type:'refresh_token',refresh_token:sign.data.refreshToken})});const refreshed=await response.json();assert.equal(response.status,200);
 return {...sign.data,idToken:refreshed.id_token};
}
function fields(values){return Object.fromEntries(Object.entries(values).map(([key,value])=>[key,
 value instanceof Date?{timestampValue:value.toISOString()}:typeof value==='string'?{stringValue:value}:
 typeof value==='boolean'?{booleanValue:value}:
 Number.isInteger(value)?{integerValue:String(value)}:{doubleValue:value}]));}
const parkNow=new Date(Date.now()+8*3600000);
const future=new Date(Date.UTC(parkNow.getUTCFullYear(),parkNow.getUTCMonth(),parkNow.getUTCDate()+1,1,30)),end=new Date(future.getTime()+900000);
const slot=(changes={})=>({attractionId:prefix,startsAt:future,endsAt:end,capacity:10,bookedCount:0,...changes});
const create=(id,values,token)=>request(`${root}/attractionSlots?documentId=${id}`,'POST',{fields:fields(values)},token);
const update=(id,values,token)=>request(`${root}/attractionSlots/${id}?${Object.keys(values).map(key=>'updateMask.fieldPaths='+key).join('&')}`,'PATCH',{fields:fields(values)},token);
before(async()=>{
 admin=await account(true);visitor=await account(false);
 const attraction={name:'Session test ride',category:'Family rides',status:'open',minHeightCm:0,mapX:.3,mapY:.4};
 assert.equal((await request(`${root}/attractions/${prefix}`,'PATCH',{fields:fields(attraction)},'owner')).status,200);
});
test('server-created windows are readable by signed-in visitors', async () => {
  const id = prefix + '-shared';
  const url = root + '/attractionSlots/' + id;
  const seeded = await request(url, 'PATCH', {
    fields: fields(slot({bookedCount: 3, confirmedCount: 3})),
  }, 'owner');
  assert.equal(seeded.status, 200);

  const saved = await request(url, 'GET', undefined, visitor.idToken);
  assert.equal(saved.status, 200);
  assert.equal(saved.data.fields.bookedCount.integerValue, '3');
  assert.equal((await request(root + '/attractionSlots', 'GET', undefined, visitor.idToken)).status, 200);
  assert.equal((await request(url)).status, 403);
});

test('neither staff nor visitors can create, edit, retire or delete a return window directly', async () => {
  const id = prefix + '-shared';
  for (const user of [admin, visitor]) {
    assert.equal((await create(prefix + '-manual', slot(), user.idToken)).status, 403);
    for (const changes of [
      {capacity: 20},
      {bookedCount: 0, confirmedCount: 0},
      {startsAt: new Date(future.getTime() + 900000)},
      {retired: true},
    ]) {
      assert.equal((await update(id, changes, user.idToken)).status, 403);
    }
    assert.equal((await request(root + '/attractionSlots/' + id, 'DELETE', undefined, user.idToken)).status, 403);
  }
});

test('staff can set a valid per-attraction capacity while visitors cannot', async () => {
  const url = root + '/attractions/' + prefix + '?updateMask.fieldPaths=reservationCapacity';
  const change = (capacity, user) => request(url, 'PATCH', {
    fields: fields({reservationCapacity: capacity}),
  }, user.idToken);

  assert.equal((await change(25, admin)).status, 200);
  assert.equal((await change(10, admin)).status, 200);
  assert.equal((await change(25, visitor)).status, 403);
  for (const invalid of [0, 1.5, 1001]) {
    assert.equal((await change(invalid, admin)).status, 403);
  }
});
