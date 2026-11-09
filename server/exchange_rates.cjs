'use strict';
const {createRequire}=require('node:module'),path=require('node:path');
const requireFunctions=createRequire(path.join(__dirname,'../functions/package.json'));
const {HttpsError}=requireFunctions('firebase-functions/v2/https');
function createExchangeRates({fetcher=globalThis.fetch,clock=()=>new Date()}={}){
  let cached;
  async function rates(request){
    if(!request.auth?.uid||request.auth.token?.email_verified!==true)throw new HttpsError('unauthenticated','Please sign in with a verified account.');
    if(cached&&clock()-cached.fetchedAt<3600000)return cached.value;
    try{
      const response=await fetcher('https://api.frankfurter.dev/v2/rates?base=MYR&quotes=USD%2CSGD%2CCNY%2CEUR',{signal:AbortSignal.timeout(12000)});if(!response.ok)throw Error();const rows=await response.json(),rates={MYR:1},dates=[];
      if(!Array.isArray(rows))throw Error();for(const row of rows){if(row.base!=='MYR'||!['USD','SGD','CNY','EUR'].includes(row.quote)||!Number.isFinite(row.rate)||row.rate<=0||row.rate>1000000||!/^\d{4}-\d{2}-\d{2}$/.test(row.date))throw Error();rates[row.quote]=row.rate;dates.push(row.date);}
      if(Object.keys(rates).length!==5)throw Error();const asOf=dates.sort()[0],age=clock()-new Date(asOf+'T00:00:00Z');if(age>14*86400000||age< -86400000)throw Error();
      const value={base:'MYR',rates,asOf,source:'Frankfurter',fetchedAt:clock().toISOString()};cached={value,fetchedAt:clock()};return value;
    }catch(_){throw new HttpsError('unavailable','Currency conversion is temporarily unavailable. Prices remain available in MYR.');}
  }
  return{rates};
}
module.exports={createExchangeRates};
