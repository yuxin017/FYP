'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),{randomUUID}=require('node:crypto');
if(process.env.GCLOUD_PROJECT!=='demo-themepark-fyp'||process.env.FIRESTORE_EMULATOR_HOST!=='127.0.0.1:8080'||process.env.FIREBASE_AUTH_EMULATOR_HOST!=='127.0.0.1:9099')throw Error('Group rules checks require isolated Auth and Firestore.');
const admin=require('firebase-admin');if(!admin.apps.length)admin.initializeApp({projectId:process.env.GCLOUD_PROJECT});
const db=admin.firestore(),root='http://127.0.0.1:8080/v1/projects/demo-themepark-fyp/databases/(default)/documents';
async function account(){const uid='group-rules-'+randomUUID(),email=uid+'@example.test';await admin.auth().createUser({uid,email,emailVerified:true,password:'IsolatedFixture123!'});const r=await fetch('http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=isolated',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({email,password:'IsolatedFixture123!',returnSecureToken:true})});assert.equal(r.status,200);return{uid,token:(await r.json()).idToken};}
async function request(path,token,body){const r=await fetch(root+path,{method:body?'POST':'GET',headers:{'Content-Type':'application/json',...(token?{Authorization:'Bearer '+token}:{})},body:body?JSON.stringify(body):undefined});return{status:r.status,data:await r.json()};}
const query=(collection,filters)=>({structuredQuery:{from:[{collectionId:collection}],where:{compositeFilter:{op:'AND',filters:filters.map(([key,value])=>({fieldFilter:{field:{fieldPath:key},op:'EQUAL',value:{stringValue:value}}}))}}}});
test('group query boundaries permit members and reject outsiders, private invitations and client writes',async()=>{
  const [owner,member,other]=await Promise.all([account(),account(),account()]),id=randomUUID();
  await db.doc('groups/'+id).set({ownerUid:owner.uid,memberUids:[owner.uid,member.uid]});
  await db.doc('groupMembers/'+id+'_member').set({groupId:id,ownerUid:member.uid,memberId:member.uid});
  await db.doc('groupBookings/'+id).set({groupId:id,ownerUid:owner.uid,memberUids:[owner.uid,member.uid]});
  await db.doc('reservations/'+id).set({groupId:id,groupBookingId:id,ownerUid:member.uid});
  await db.doc('groupInvites/'+id).set({groupId:id,code:'private'});
  for(const user of [owner,member]){
    assert.equal((await request('/groups/'+id,user.token)).status,200);
    assert.equal((await request(':runQuery',user.token,query('groupMembers',[['groupId',id]]))).status,200);
    assert.equal((await request(':runQuery',user.token,query('groupBookings',[['groupId',id]]))).status,200);
    assert.equal((await request(':runQuery',user.token,query('reservations',[['groupId',id],['groupBookingId',id]]))).status,200);
    assert.equal((await request('/groupInvites/'+id,user.token)).status,403);
    const response=await fetch(root+'/groups/'+id,{method:'PATCH',headers:{Authorization:'Bearer '+user.token,'Content-Type':'application/json'},body:JSON.stringify({fields:{ownerUid:{stringValue:user.uid},memberUids:{arrayValue:{values:[{stringValue:user.uid}]}}}})});assert.equal(response.status,403);
  }
  assert.equal((await request('/groups/'+id,other.token)).status,403);
  assert.equal((await request(':runQuery',other.token,query('reservations',[['groupId',id],['groupBookingId',id]]))).status,403);
  assert.equal((await request('/groups/'+id)).status,403);
  await db.doc('attractionRatings/'+id).set({ownerUid:owner.uid,stars:4});
  assert.equal((await request('/attractionRatings/'+id,owner.token)).status,200);assert.equal((await request('/attractionRatings/'+id,other.token)).status,403);
});
