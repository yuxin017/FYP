'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),{randomUUID}=require('node:crypto');
if(process.env.GCLOUD_PROJECT!=='demo-themepark-fyp'||process.env.FIRESTORE_EMULATOR_HOST!=='127.0.0.1:8080')throw Error('Recovery checks require isolated fixtures.');
const admin=require('../../functions/node_modules/firebase-admin');if(!admin.apps.length)admin.initializeApp({projectId:process.env.GCLOUD_PROJECT});const db=admin.firestore();
const {createPasswordRecovery}=require('../../functions/src/password_recovery');
function fixture(){
 const uid='otp-'+randomUUID(),email=uid+'@example.test',ip=randomUUID(),sent=[],grants=[];let now=new Date('2100-01-01T00:00:00Z'),disabled=false,sendFailed=false;
 const auth={async getUserByEmail(value){if(value!==email){const e=Error();e.code='auth/user-not-found';throw e;}return this.getUser(uid);},async getUser(){return{uid,email,disabled,providerData:[{providerId:'password'}]};},async generatePasswordResetLink(value){grants.push(value);return'https://example.test/action?oobCode=private-grant';}};
 const service=createPasswordRecovery({db,auth,clock:()=>now,mailReady:()=>true,async deliver(data){sent.push(data);if(sendFailed)throw Error('never disclose SMTP details');return{sent:true};}});
 return{uid,email,ip,sent,grants,service,advance(ms){now=new Date(now.getTime()+ms);},disable(){disabled=true;},failMail(){sendFailed=true;},async send(address=email){const result=await service.send({email:address},ip);await service.drain();return result;},async verify(challenge,otp){return service.verify({challengeId:challenge.challengeId,otp:otp??sent.at(-1).otp},ip);}};
}
test('OTP delivery contains a six-digit code while API and private record contain no plaintext code; concurrent redemption mints one grant',async()=>{
 const f=fixture(),challenge=await f.send();assert.match(f.sent[0].otp,/^\d{6}$/);assert.deepEqual(Object.keys(challenge).sort(),['challengeId','expiresAt','resendAfterSeconds']);
 const stored=(await db.doc('recoveryChallenges/'+challenge.challengeId).get()).data();assert.equal(stored.otp,undefined);assert.equal(stored.digest.length,64);
 const answers=await Promise.allSettled([f.verify(challenge),f.verify(challenge)]);assert.equal(answers.filter(a=>a.status==='fulfilled').length,1);assert.equal(f.grants.length,1);assert.deepEqual(answers.find(a=>a.status==='fulfilled').value,{code:'private-grant',email:f.email});
});
test('five incorrect guesses persist and block a later correct OTP',async()=>{
 const f=fixture(),challenge=await f.send(),wrong=f.sent[0].otp==='000000'?'111111':'000000';for(let i=0;i<5;i++)await assert.rejects(f.verify(challenge,wrong),e=>e.code==='invalid-argument');
 assert.equal((await db.doc('recoveryChallenges/'+challenge.challengeId).get()).data().attempts,5);await assert.rejects(f.verify(challenge),e=>e.code==='invalid-argument');assert.equal(f.grants.length,0);
});
test('resend cooldown survives handler recreation, newer code replaces the old challenge, and expiry is checked server-side',async()=>{
 const f=fixture(),first=await f.send();await assert.rejects(f.send(),e=>e.code==='resource-exhausted');f.advance(61000);const second=await f.send();await assert.rejects(f.verify(first,f.sent[0].otp),e=>e.code==='invalid-argument');f.advance(300000);await assert.rejects(f.verify(second),e=>e.code==='invalid-argument');assert.equal(f.grants.length,0);
});
test('unknown, disabled and restricted accounts cannot obtain a reset grant; delivery failures do not disclose SMTP errors',async()=>{
 const unknown=fixture(),a=await unknown.send('unknown-'+randomUUID()+'@example.test');assert.equal(unknown.sent.length,0);await assert.rejects(unknown.verify(a,'123456'),e=>e.code==='invalid-argument');
 const disabled=fixture(),b=await disabled.send();disabled.disable();await assert.rejects(disabled.verify(b),e=>e.code==='invalid-argument');assert.equal(disabled.grants.length,0);
 const restricted=fixture(),c=await restricted.send();await db.doc('visitorAccess/'+restricted.uid).set({status:'suspended'});await assert.rejects(restricted.verify(c),e=>e.code==='invalid-argument');
 const failed=fixture();failed.failMail();const d=await failed.send();assert.equal(Object.keys(d).includes('error'),false);await assert.rejects(failed.verify(d),e=>e.code==='invalid-argument');
});
