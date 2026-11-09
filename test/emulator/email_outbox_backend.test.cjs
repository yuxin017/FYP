'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),{randomUUID}=require('node:crypto');
if(process.env.GCLOUD_PROJECT!=='demo-themepark-fyp'||process.env.FIRESTORE_EMULATOR_HOST!=='127.0.0.1:8080')throw Error('Email checks require isolated fixtures.');
const admin=require('../../functions/node_modules/firebase-admin');if(!admin.apps.length)admin.initializeApp({projectId:process.env.GCLOUD_PROJECT});const db=admin.firestore(),{FieldValue}=admin.firestore,{createEmailOutbox}=require('../../server/email_outbox.cjs');
test('mail workers lease one delivery and keep unconfigured or uncertain messages unsent',async()=>{
 const id='email-'+randomUUID(),uid='email-owner-'+randomUUID(),calls=[];let fail=false;const ai={async call(operation){if(operation==='send_photo_email'){calls.push(operation);if(fail)throw Error('uncertain delivery');return{messageId:'fixture-message-id'};}throw Error('unexpected call');}};
 const order=()=>db.doc('photoOrders/'+id).set({ownerUid:uid,items:[],totalMinor:3500});await order();await db.doc('emailOutbox/'+id).set({ownerUid:uid,orderId:id,to:'fixture@example.test',status:'queued'});
 const disabled=createEmailOutbox({db,FieldValue,ai,mailReady:()=>false});await disabled.run();assert.equal(calls.length,0);
 const one=createEmailOutbox({db,FieldValue,ai,mailReady:()=>true}),two=createEmailOutbox({db,FieldValue,ai,mailReady:()=>true});await Promise.all([one.run(),two.run()]);assert.equal(calls.length,1);assert.equal((await db.doc('photoOrders/'+id).get()).data().emailStatus,'sent');
 fail=true;await db.doc('emailOutbox/'+id).update({status:'queued'});await one.run();await two.run();assert.equal(calls.length,2);assert.equal((await db.doc('emailOutbox/'+id).get()).data().status,'attention');assert.equal((await db.doc('photoOrders/'+id).get()).data().emailStatus,'attention');
});
