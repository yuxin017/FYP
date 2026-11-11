'use strict';
function createPrivateRecordCleanup({db,clock=()=>new Date()}){
 return async function cleanup(){
  for(const name of ['parkLocations','parkLocationSamples','recoveryChallenges','recoverySubjects','recoveryLimits','ticketCurrencyQuotes','reminderDevices','reservationReminderRequests']){
   const now=clock(),rows=await db.collection(name).where('expiresAt','<=',now).limit(100).get();
   for(const row of rows.docs)await db.runTransaction(async tx=>{const current=await tx.get(row.ref),expires=current.data()?.expiresAt?.toDate?.();if(expires&&expires<=now)tx.delete(row.ref);});
  }
 };
}
module.exports={createPrivateRecordCleanup};
