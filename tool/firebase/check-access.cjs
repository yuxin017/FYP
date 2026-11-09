'use strict';
const path=require('node:path');
const cliRoot=path.resolve(__dirname,'node_modules/firebase-tools');
const auth=require(path.join(cliRoot,'lib/auth'));
(async()=>{
  const account=auth.getGlobalDefaultAccount();
  if(!account?.tokens?.refresh_token){console.log('Firebase sign-in is required on this computer.');process.exitCode=2;return;}
  let token;try{token=await auth.getAccessToken(account.tokens.refresh_token,[]);}catch(_){console.log('Firebase sign-in has expired. Sign in again.');process.exitCode=2;return;}
  const response=await fetch('https://firebase.googleapis.com/v1beta1/projects/themeparksmartmanagement',{headers:{Authorization:'Bearer '+token.access_token},signal:AbortSignal.timeout(20000)});
  if(response.status===401){console.log('Firebase sign-in needs to be renewed.');process.exitCode=2;return;}
  if(!response.ok){console.log('This Firebase account cannot access themeparksmartmanagement. Ask the project owner for access, or run tool\\firebase-login.cmd with the correct account.');process.exitCode=1;return;}
  console.log('Firebase access verified: themeparksmartmanagement.');
})().catch(()=>{console.log('Firebase access could not be checked. Check the internet connection and retry.');process.exitCode=1;});
