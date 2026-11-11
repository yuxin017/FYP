'use strict';
// This entry point deploys the theme-park application only. Legacy exports in
// index.js belong to the original source and are not loaded by this codebase.
const {initializeApp,getApps}=require('firebase-admin/app');
const {getFirestore,FieldValue}=require('firebase-admin/firestore');
const {onCall}=require('firebase-functions/v2/https');
const {onSchedule}=require('firebase-functions/v2/scheduler');
if(!getApps().length)initializeApp();
const db=getFirestore(),dependencies={db,FieldValue};
const {createReservationHandlers}=require('./src/reservations');
const {createGroupHandlers}=require('./src/groups');
const {createVisitHandlers}=require('./src/visits');
const {createParkManagementHandlers}=require('./src/park_management');
const {createQueueJobs}=require('./src/queue_jobs');
const options={region:'us-central1',memory:'256MiB',maxInstances:2,timeoutSeconds:60};
const reservations=createReservationHandlers(dependencies),groups=createGroupHandlers(dependencies),visits=createVisitHandlers(dependencies),park=createParkManagementHandlers(dependencies),queue=createQueueJobs(dependencies);
exports.reserveSlot=onCall(options,reservations.reserveSlot);
exports.cancelReservation=onCall(options,reservations.cancelReservation);
// The Node API and callable functions use the same transaction implementations.
for(const [name,handler]of Object.entries(groups))exports['group'+name[0].toUpperCase()+name.slice(1)]=onCall(options,handler);
exports.checkInAttraction=onCall(options,visits.checkIn);
exports.rateAttraction=onCall(options,visits.rate);
exports.claimWeatherBenefit=onCall(options,park.claimWeather);
const scheduled={region:'us-central1',memory:'256MiB',maxInstances:1,timeoutSeconds:300,timeZone:'Asia/Kuala_Lumpur',retryCount:0};
exports.processMissedReservations=onSchedule({...scheduled,schedule:'every 5 minutes'},async()=>{await queue.processNoShows();});
exports.updateParkWeather=onSchedule({...scheduled,schedule:'every 15 minutes'},async()=>{await park.runWeather();});
