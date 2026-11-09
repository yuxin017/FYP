const {initializeApp, getApps} = require('firebase-admin/app');
const {getAuth} = require('firebase-admin/auth');
const projectId = 'demo-themepark-fyp';
function localEnvironment() {
  process.env.GCLOUD_PROJECT = projectId;
  process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8080';
  process.env.FIREBASE_AUTH_EMULATOR_HOST = '127.0.0.1:9099';
  if (!getApps().length) initializeApp({projectId});
}
async function seedFixtures() {
  localEnvironment();
  for (const name of ['alice','bob']) {
    const uid = `ticket-demo-${name}`;
    const user = {email:`${name}@demo.test`,password:'DemoVisitor123!',
      emailVerified:true,displayName:name[0].toUpperCase()+name.slice(1)};
    try { await getAuth().createUser({uid,...user}); }
    catch(error) {
      if(error.code !== 'auth/uid-already-exists') throw error;
      await getAuth().updateUser(uid,user);
    }
  }
}
module.exports = {localEnvironment,seedFixtures,projectId};
