// Run against firebase.attractions.json to exercise the complete merged rules.
const assert = require('node:assert/strict');
const {randomUUID} = require('node:crypto');
const {before, test} = require('node:test');
const project = process.env.GCLOUD_PROJECT;
const firestoreHost = process.env.FIRESTORE_EMULATOR_HOST;
const authHost = process.env.FIREBASE_AUTH_EMULATOR_HOST;
const local = /^(127\.0\.0\.1|localhost):\d+$/;
if (!project?.startsWith('demo-') || !local.test(firestoreHost || '') || !local.test(authHost || '')) {
  throw new Error('Shared-rule regression checks require isolated local demo-* emulators.');
}
const root = `http://${firestoreHost}/v1/projects/${project}/databases/(default)/documents`;
let visitor, other;
const prefix = 'shared-' + randomUUID();
async function request(path, token, method='GET', body) {
  const response = await fetch(root + '/' + path, {
    method, headers:{'Content-Type':'application/json', ...(token ? {Authorization:'Bearer ' + token} : {})},
    body:body === undefined ? undefined : JSON.stringify(body),
  });
  return {status:response.status, data:await response.json()};
}
async function account() {
  const response = await fetch(`http://${authHost}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=emulator-only-key`, {
    method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({returnSecureToken:true}),
  });
  assert.equal(response.status, 200);
  return response.json();
}
before(async () => {
  visitor = await account(); other = await account();
  const profile = {fields:{uid:{stringValue:visitor.localId}, fullName:{stringValue:'Visitor Test'},
    email:{stringValue:'visitor@example.test'},phoneNumber:{stringValue:''},role:{stringValue:'visitor'},
    loyaltyPoints:{integerValue:'0'},createdAt:{timestampValue:'2026-01-01T00:00:00Z'}}};
  assert.equal((await request('visitors/' + visitor.localId, 'owner','PATCH',profile)).status,200);
  for(const collection of ['orders','tickets']) {
    assert.equal((await request(collection + '/' + prefix,'owner','PATCH',{
      fields:{ownerUid:{stringValue:visitor.localId},status:{stringValue:'valid'}}})).status,200);
  }
});
test('existing profile reads and edits remain owner-scoped', async () => {
  assert.equal((await request('visitors/' + visitor.localId, visitor.idToken)).status,200);
  assert.equal((await request('visitors/' + visitor.localId, other.idToken)).status,403);
  assert.equal((await request('visitors/' + visitor.localId)).status,403);
  assert.equal((await request('visitors', visitor.idToken)).status,403);
  assert.equal((await request('visitors/' + visitor.localId + '?updateMask.fieldPaths=heightCm', visitor.idToken,'PATCH',
    {fields:{heightCm:{integerValue:'175'}}})).status,200);
  assert.equal((await request('visitors/' + visitor.localId + '?updateMask.fieldPaths=role', visitor.idToken,'PATCH',
    {fields:{role:{stringValue:'admin'}}})).status,403);
});
test('existing ticket and order privacy and write restrictions remain intact', async () => {
  for(const collection of ['orders','tickets']) {
    const path = collection + '/' + prefix;
    assert.equal((await request(path,visitor.idToken)).status,200);
    assert.equal((await request(path,other.idToken)).status,403);
    assert.equal((await request(path)).status,403);
    assert.equal((await request(path+'?updateMask.fieldPaths=status',visitor.idToken,'PATCH',
      {fields:{status:{stringValue:'used'}}})).status,403);
    assert.equal((await request(path,visitor.idToken,'DELETE')).status,403);
  }
});
test('private reservation guards and unknown collections remain denied', async () => {
  for(const collection of ['reservationGuards','reservationRequests','attractionQueueGuards','unrecognizedCollection']) {
    assert.equal((await request(collection + '/' + prefix,visitor.idToken)).status,403);
    assert.equal((await request(collection + '/' + prefix,visitor.idToken,'PATCH',
      {fields:{ownerUid:{stringValue:visitor.localId}}})).status,403);
  }
});
