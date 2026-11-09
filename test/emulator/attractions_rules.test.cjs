// Emulator-only authorization/persistence checks; no third-party test packages.
const assert = require('node:assert/strict');
const { randomUUID } = require('node:crypto');
const { before, after, test } = require('node:test');

const project = process.env.GCLOUD_PROJECT;
const firestoreHost = process.env.FIRESTORE_EMULATOR_HOST;
const authHost = process.env.FIREBASE_AUTH_EMULATOR_HOST;
const localHost = /^(127\.0\.0\.1|localhost):\d+$/;
if (!project?.startsWith('demo-') || !localHost.test(firestoreHost || '') || !localHost.test(authHost || '')) {
  throw new Error('Refusing to run outside local Auth/Firestore emulators and an isolated demo-* test project.');
}
const documents = `http://${firestoreHost}/v1/projects/${project}/databases/(default)/documents`;
const auth = `http://${authHost}/identitytoolkit.googleapis.com/v1`;
const prefix = `m1-${randomUUID()}`;
after(async () => {
  let pageToken;
  do {
    const result = await request(`${documents}/attractions?pageSize=1000${pageToken ? '&pageToken='+encodeURIComponent(pageToken) : ''}`, undefined, 'owner', 'GET');
    for (const doc of result.data.documents || []) {
      if (doc.name.split('/').at(-1).startsWith(prefix)) await request('http://'+firestoreHost+'/v1/'+doc.name, undefined, 'owner', 'DELETE');
    }
    pageToken = result.data.nextPageToken;
  } while (pageToken);
});
let admin, visitor, visitor2, stringAdmin;

async function request(url, body, token, method = 'POST') {
  const response = await fetch(url, {
    method, headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const data = await response.json();
  return { status: response.status, data };
}

async function account(claims) {
  const result = await request(`${auth}/accounts:signUp?key=emulator-only-key`, { returnSecureToken: true });
  assert.equal(result.status, 200, result.data.error?.message);
  if (!claims) return result.data;
  const update = await request(`${auth}/projects/${project}/accounts:update`, {
    localId: result.data.localId, customAttributes: JSON.stringify(claims), returnSecureToken: true,
  }, 'owner');
  assert.equal(update.status, 200, update.data.error?.message);
  // Refresh through the emulator so the returned ID token contains the claims.
  const refresh = await fetch(`http://${authHost}/securetoken.googleapis.com/v1/token?key=emulator-only-key`, {
    method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({ grant_type: 'refresh_token', refresh_token: result.data.refreshToken }),
  });
  const data = await refresh.json();
  assert.equal(refresh.status, 200, data.error?.message);
  return { ...result.data, idToken: data.id_token };
}

function fields(values) {
  return Object.fromEntries(Object.entries(values).map(([key, value]) => [key,
    value === null ? { nullValue: 'NULL_VALUE' } : typeof value === 'string' ? { stringValue: value } :
    typeof value === 'boolean' ? { booleanValue: value } :
    Number.isInteger(value) ? { integerValue: String(value) } : { doubleValue: Number.isFinite(value) ? value : String(value) },
  ]));
}
const attraction = (changes = {}) => ({ name: 'Mountain Falls', category: 'Water rides', status: 'open', minHeightCm: 110, mapX: .3, mapY: .7, ...changes });
const create = (id, values, token) => request(`${documents}/attractions?documentId=${encodeURIComponent(id)}`, { fields: fields(values) }, token);
const read = (id, token) => request(`${documents}/attractions/${id}`, undefined, token, 'GET');
const update = (id, values, token) => request(`${documents}/attractions/${id}?${Object.keys(values).map(key => `updateMask.fieldPaths=${encodeURIComponent(key)}`).join('&')}`, { fields: fields(values) }, token, 'PATCH');

before(async () => {
  admin = await account({ admin: true });
  visitor = await account();
  visitor2 = await account();
  stringAdmin = await account({ admin: 'true' });
});

test('admin creates an attraction; separate visitor clients read its persisted changes', async () => {
  const id = `${prefix}-shared`;
  assert.equal((await create(id, attraction(), admin.idToken)).status, 200);
  assert.equal((await read(id, visitor.idToken)).data.fields.name.stringValue, 'Mountain Falls');
  for (const status of ['closed', 'maintenance', 'open']) {
    assert.equal((await update(id, { status }, admin.idToken)).status, 200);
    assert.equal((await read(id, visitor2.idToken)).data.fields.status.stringValue, status);
  }
  assert.equal((await update(id, { name: 'Mountain Falls Rapids' }, admin.idToken)).status, 200);
  const renamed = await read(id, visitor.idToken);
  assert.equal(renamed.data.name.split('/').at(-1), id);
  assert.equal(renamed.data.fields.name.stringValue, 'Mountain Falls Rapids');
});

test('unauthenticated reads and writes are rejected', async () => {
  assert.equal((await read(`${prefix}-shared`)).status, 403);
  assert.equal((await create(`${prefix}-anonymous`, attraction())).status, 403);
});

test('an admin can save each new place type for the customer map', async () => {
  for (const category of ['Dining', 'Facilities', 'Shops']) {
    const id = `${prefix}-${category.toLowerCase()}`;
    const place = attraction({ name: `Park ${category}`, category, minHeightCm: 0,
      description: 'Visitor information', coverImageBase64: null, crowdLevel: null, standbyMinutes: null });
    assert.equal((await create(id, place, visitor.idToken)).status, 403);
    const created = await create(id, place, admin.idToken);
    assert.equal(created.status, 200, created.data.error?.message);
    const saved = await read(id, visitor.idToken);
    assert.equal(saved.status, 200);
    assert.equal(saved.data.fields.category.stringValue, category);
    assert.equal((await update(id, {status: 'closed'}, admin.idToken)).status, 200);
    assert.equal((await read(id, visitor.idToken)).data.fields.status.stringValue, 'closed');
  }
});

test('signed-in admins and visitors can list attractions but signed-out requests cannot', async () => {
  for (const token of [admin.idToken, visitor.idToken]) {
    let pageToken, found = false;
    do {
      const result = await request(`${documents}/attractions?pageSize=1000${pageToken ? '&pageToken='+encodeURIComponent(pageToken) : ''}`, undefined, token, 'GET');
      assert.equal(result.status, 200);
      found ||= (result.data.documents || []).some(document => document.name.endsWith(`/${prefix}-shared`));
      pageToken = result.data.nextPageToken;
    } while (pageToken);
    assert.ok(found);
  }
  assert.equal((await request(`${documents}/attractions`, undefined, undefined, 'GET')).status, 403);
});

test('the reported Water Ride form values are valid for an authorized admin', async () => {
  const values = attraction({ name: 'Water Ride', minHeightCm: 150, mapX: 101.6934, mapY: 3.1492 });
  const id = `${prefix}-reported-input`;
  assert.equal((await create(id, values, admin.idToken)).status, 200);
  const saved = await read(id, visitor.idToken);
  assert.equal(saved.status, 200);
  assert.equal(saved.data.fields.name.stringValue, 'Water Ride');
});

test('ordinary visitor cannot create, edit or delete attractions', async () => {
  assert.equal((await create(`${prefix}-visitor`, attraction(), visitor.idToken)).status, 403);
  assert.equal((await update(`${prefix}-shared`, { status: 'closed' }, visitor.idToken)).status, 403);
  assert.equal((await request(`${documents}/attractions/${prefix}-shared`, undefined, visitor.idToken, 'DELETE')).status, 403);
});

test('a profile role or a string-valued claim cannot grant attraction admin access', async () => {
  const profile = await request(`${documents}/visitors/${visitor.localId}`, { fields: fields({ role: 'admin' }) }, 'owner', 'PATCH');
  assert.equal(profile.status, 200);
  assert.equal((await create(`${prefix}-profile-escalation`, attraction(), visitor.idToken)).status, 403);
  assert.equal((await create(`${prefix}-string-claim`, attraction(), stringAdmin.idToken)).status, 403);
  const claimAttempt = await request(`${auth}/accounts:update?key=emulator-only-key`, {
    idToken: visitor.idToken, customAttributes: JSON.stringify({ admin: true }), returnSecureToken: true,
  });
  assert.notEqual(claimAttempt.status, 200);
});

test('admin cannot hard-delete attractions or add unagreed fields', async () => {
  assert.equal((await request(`${documents}/attractions/${prefix}-shared`, undefined, admin.idToken, 'DELETE')).status, 403);
  assert.equal((await create(`${prefix}-extra`, attraction({ admin: true }), admin.idToken)).status, 403);
  assert.equal((await update(`${prefix}-shared`, { bookedCount: 0 }, admin.idToken)).status, 403);
});

test('schema rejects unknown statuses, blank names, invalid heights and coordinates', async () => {
  const invalid = [
    { status: 'available' }, { name: '   ' }, { category: '' }, { name: 'x'.repeat(81) },
    { minHeightCm: -1 }, { minHeightCm: 100.5 }, { minHeightCm: 251 },
    { mapX: '0.5' }, { mapX: Number.NaN }, { mapY: Infinity },
  ];
  for (let i = 0; i < invalid.length; i++) {
    assert.equal((await create(`${prefix}-invalid-${i}`, attraction(invalid[i]), admin.idToken)).status, 403, JSON.stringify(invalid[i]));
  }
  const missing = attraction();
  delete missing.mapY;
  assert.equal((await create(`${prefix}-missing`, missing, admin.idToken)).status, 403);
});

test('updates preserve pre-existing extension fields without allowing edits to them', async () => {
  const id = `${prefix}-extension`;
  assert.equal((await request(`${documents}/attractions/${id}`, { fields: fields(attraction({ futureField: 'keep' })) }, 'owner', 'PATCH')).status, 200);
  assert.equal((await update(id, { status: 'closed' }, admin.idToken)).status, 200);
  assert.equal((await read(id, visitor.idToken)).data.fields.futureField.stringValue, 'keep');
  assert.equal((await update(id, { futureField: 'overwrite' }, admin.idToken)).status, 403);
});

test('approved customer-card fields persist and reject malformed operational data', async () => {
  const values = attraction({description:'Ride information',coverImageBase64:'iVBORw0KGgo=',crowdLevel:'moderate',standbyMinutes:35});
  const id = `${prefix}-rich`;
  assert.equal((await create(id,values,admin.idToken)).status,200);
  const saved = await read(id,visitor.idToken);
  assert.equal(saved.data.fields.standbyMinutes.integerValue,'35');
  assert.equal(saved.data.fields.crowdLevel.stringValue,'moderate');
  for (const invalid of [{standbyMinutes:-1},{standbyMinutes:2.5},{standbyMinutes:601},
    {crowdLevel:'packed'},{description:'x'.repeat(1201)},{coverImageBase64:'invalid !'},
    {coverImageBase64:'A'.repeat(240004)},{ratingAverage:4.8},{ratingCount:12}]) {
    assert.equal((await create(`${prefix}-bad-rich-${randomUUID()}`,attraction(invalid),admin.idToken)).status,403);
  }
  assert.equal((await update(id,{crowdLevel:null,standbyMinutes:null},admin.idToken)).status,200);
});

const removeFromCatalogue = (id, token, extra = {}) => request(`${documents}:commit`, { writes: [{
  update: { name: `projects/${project}/databases/(default)/documents/attractions/${id}`, fields: fields({status:'closed',...extra}) },
  updateMask: { fieldPaths: ['status',...Object.keys(extra)] },
  updateTransforms: ['deletedAt','updatedAt'].map(fieldPath=>({fieldPath,setToServerValue:'REQUEST_TIME'})),
}] }, token);

test('only a boolean-claim admin can delete from the catalogue, retaining an immutable closed record', async () => {
  const id=`${prefix}-delete`;
  assert.equal((await create(id,attraction({description:'Keep this history'}),admin.idToken)).status,200);
  for(const token of [undefined,visitor.idToken,stringAdmin.idToken]) {
    assert.equal((await removeFromCatalogue(id,token)).status,403);
  }
  assert.equal((await removeFromCatalogue(id,admin.idToken,{name:'Hidden overwrite'})).status,403);
  assert.equal((await update(id,{deletedAt:'fake-date',status:'closed'},admin.idToken)).status,403);
  assert.equal((await removeFromCatalogue(id,admin.idToken)).status,200);
  const saved=(await read(id,admin.idToken)).data.fields;
  assert.equal(saved.status.stringValue,'closed');
  assert.equal(saved.description.stringValue,'Keep this history');
  assert.ok(saved.deletedAt.timestampValue);
  assert.equal(saved.deletedAt.timestampValue,saved.updatedAt.timestampValue);
  for(const changes of [{status:'open'},{deletedAt:null},{description:'overwrite history'}]) {
    assert.equal((await update(id,changes,admin.idToken)).status,403);
  }
  assert.equal((await request(`${documents}/attractions/${id}`,undefined,admin.idToken,'DELETE')).status,403);
});

test('deleting an attraction retains linked sessions/reservations and rejects new sessions for it', async () => {
  const id=`${prefix}-linked-delete`,slotId=`${prefix}-linked-slot`,bookingId=`${prefix}-linked-booking`;
  assert.equal((await create(id,attraction(),admin.idToken)).status,200);
  const slotFields={attractionId:{stringValue:id},startsAt:{timestampValue:new Date(Date.now()+3600000).toISOString()},
    endsAt:{timestampValue:new Date(Date.now()+7200000).toISOString()},capacity:{integerValue:'10'},bookedCount:{integerValue:'3'}};
  assert.equal((await request(`${documents}/attractionSlots/${slotId}`,{fields:slotFields},'owner','PATCH')).status,200);
  const bookingFields=fields({attractionId:id,slotId,status:'confirmed'});
  assert.equal((await request(`${documents}/reservations/${bookingId}`,{fields:bookingFields},'owner','PATCH')).status,200);
  assert.equal((await removeFromCatalogue(id,admin.idToken)).status,200);
  assert.deepEqual((await request(`${documents}/attractionSlots/${slotId}`,undefined,'owner','GET')).data.fields,slotFields);
  assert.deepEqual((await request(`${documents}/reservations/${bookingId}`,undefined,'owner','GET')).data.fields,bookingFields);
  assert.equal((await request(`${documents}/attractionSlots?documentId=${prefix}-new-after-delete`,{
    fields:{...slotFields,bookedCount:{integerValue:'0'}},
  },admin.idToken)).status,403);
});
