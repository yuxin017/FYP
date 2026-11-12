const assert = require('node:assert/strict');
const {randomUUID} = require('node:crypto');
const {test} = require('node:test');

const project = process.env.GCLOUD_PROJECT;
const dbHost = process.env.FIRESTORE_EMULATOR_HOST;
const authHost = process.env.FIREBASE_AUTH_EMULATOR_HOST;
const local = /^(127\.0\.0\.1|localhost):\d+$/;
if (project !== 'demo-themepark-fyp' || !local.test(dbHost) || !local.test(authHost)) {
  throw Error('Camera rules checks require local Auth and Firestore emulators.');
}
const admin = require('../../functions/node_modules/firebase-admin');
admin.initializeApp({projectId: project});
const db = admin.firestore();
const documents = `projects/${project}/databases/(default)/documents`;
const base = `http://${dbHost}/v1/${documents}`;

async function user(staff) {
  const email = `${randomUUID()}@example.test`;
  const password = randomUUID();
  const account = await admin.auth().createUser({email, password, emailVerified: true});
  if (staff) await admin.auth().setCustomUserClaims(account.uid, {admin: true});
  const response = await fetch(`http://${authHost}/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=emulator-only`, {
    method: 'POST', headers: {'Content-Type': 'application/json'},
    body: JSON.stringify({email, password, returnSecureToken: true}),
  });
  const body = await response.json();
  assert.equal(response.status, 200, body.error?.message);
  return {uid: account.uid, token: body.idToken};
}

async function write(path, fields, actor, timestamp, mask) {
  const update = {
    name: `${documents}/${path}`,
    fields: Object.fromEntries(Object.entries(fields).map(([key, value]) => [
      key, typeof value === 'boolean' ? {booleanValue: value} : {stringValue: value},
    ])),
  };
  const write = {update};
  if (timestamp) write.updateTransforms = [{fieldPath: timestamp, setToServerValue: 'REQUEST_TIME'}];
  if (mask) write.updateMask = {fieldPaths: mask};
  const response = await fetch(`${base}:commit`, {
    method: 'POST', headers: {'Content-Type': 'application/json', Authorization: `Bearer ${actor.token}`},
    body: JSON.stringify({writes: [write]}),
  });
  return {status: response.status, body: await response.json()};
}

test('only assigned staff cameras can publish and only staff can view or answer', async () => {
  const [sender, viewer, visitor] = await Promise.all([user(true), user(true), user(false)]);
  const id = `camera-rules-${randomUUID()}`;
  const place = `attractions/${id}`;
  const assignment = `attractionCameras/${id}`;
  const broadcast = `cameraBroadcasts/${id}`;
  const request = `cameraViewRequests/${id}`;
  await db.doc(place).set({name: 'Camera test attraction', category: 'Family rides'});
  const session = 'A'.repeat(20);
  const presence = {session, ownerUid: sender.uid};
  assert.equal((await write(broadcast, presence, sender, 'updatedAt')).status, 403);
  assert.equal((await write(assignment, {enabled: true}, visitor)).status, 403);
  const assigned = await write(assignment, {enabled: true}, viewer);
  assert.equal(assigned.status, 200, assigned.body.error?.message);
  const started = await write(broadcast, presence, sender, 'updatedAt');
  assert.equal(started.status, 200, started.body.error?.message);
  assert.equal((await write(broadcast, {session: 'B'.repeat(20), ownerUid: viewer.uid}, viewer, 'updatedAt')).status, 403);

  const offer = {session, viewId: 'C'.repeat(20), viewerUid: viewer.uid, offer: 'example-rtc-offer'};
  assert.equal((await write(request, {...offer, viewerUid: visitor.uid}, visitor, 'requestedAt')).status, 403);
  assert.equal((await write(request, {...offer, session: 'D'.repeat(20)}, viewer, 'requestedAt')).status, 403);
  const opened = await write(request, offer, viewer, 'requestedAt');
  assert.equal(opened.status, 200, opened.body.error?.message);
  assert.equal((await fetch(`${base}/${request}`, {headers: {Authorization: `Bearer ${visitor.token}`}})).status, 403);
  assert.equal((await write(request, {answer: 'forged'}, viewer, undefined, ['answer'])).status, 403);
  const answered = await write(request, {answer: 'example-rtc-answer'}, sender, undefined, ['answer']);
  assert.equal(answered.status, 200, answered.body.error?.message);
  await db.doc(assignment).delete();
  assert.equal((await write(broadcast, presence, sender, 'updatedAt')).status, 403);
});
