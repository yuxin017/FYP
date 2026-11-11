'use strict';
// Applies the user's venue choice without enabling financial benefits or billing.
const {sharedFirestore,FieldValue}=require('./firebase_account_adapter.cjs');
const venue=require('../config/venue.json');
(async()=>{
 const db=sharedFirestore();
 await db.runTransaction(async tx=>{
  const ref=db.doc('parkSettings/weather'),old=(await tx.get(ref)).data();
  tx.set(ref,{enabled:false,rainThresholdMm:2,voucherBenefit:'Rainy-day park benefit',validityDays:30,...old,
   parkName:venue.name,latitude:venue.latitude,longitude:venue.longitude,updatedAt:FieldValue.serverTimestamp()});
  tx.set(db.doc('parkSettings/venue'),{name:venue.name,address:venue.address,latitude:venue.latitude,longitude:venue.longitude,
   north:venue.north,south:venue.south,east:venue.east,west:venue.west,updatedAt:FieldValue.serverTimestamp()});
 });
 console.log('TAR UMT Penang venue and weather location saved.');
})().catch(()=>{console.error('Venue settings could not be saved. Check Firebase CLI access.');process.exitCode=1;});
