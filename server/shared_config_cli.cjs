'use strict';
const fs=require('node:fs'),path=require('node:path');
const {createProjectConfiguration,writeMobileCache,serviceValues}=require('./project_configuration.cjs');
async function input(){const chunks=[];let size=0;for await(const chunk of process.stdin){size+=chunk.length;if(size>65536)throw Error('input-too-large');chunks.push(chunk);}return JSON.parse(Buffer.concat(chunks).toString('utf8').replace(/^\uFEFF/,''));}
async function main(){
 if(process.env.FIRESTORE_EMULATOR_HOST||process.env.FIREBASE_AUTH_EMULATOR_HOST)throw Error('shared-firebase-required');
 const {sharedFirestore,FieldValue}=require('./firebase_account_adapter.cjs');
 const root=path.resolve(__dirname,'..'),configuration=createProjectConfiguration({db:sharedFirestore(),FieldValue});
 async function sync(){writeMobileCache(root,await configuration.readMobile());}
 async function check(value){
  const {setServiceConfig}=require('./service_config.cjs'),{PythonWorker}=require('./python_worker.cjs');
  setServiceConfig(serviceValues(value));const worker=new PythonWorker();
  try{const result=await worker.call('check_email');if(result.authenticated!==true)throw Error('smtp-unavailable');}finally{worker.close();}
 }
 const command=process.argv[2];
 if(command==='sync-mobile'){await sync();console.log('Shared application settings loaded from Firebase.');}
 else if(command==='save-mobile'){await configuration.saveMobile(await input());await sync();console.log('Application settings saved to Firebase and loaded on this PC.');}
 else if(command==='save-services'){
  const value=serviceValues(await input());if(value.smtp.enabled)await check(value);
  await configuration.saveServices(value);console.log('Email settings saved to server-only Firebase configuration. No email was sent.');
 }
 else if(command==='check-email'){await check(await configuration.readServices());console.log('Shared SMTP connection and sign-in passed. No email was sent.');}
 else if(command==='publish-existing'){
  // One-time migration; these legacy files are never a runtime source again.
  const mobileFile=path.join(root,'env.json'),servicesFile=path.join(root,'.local/services.json');
  const mobile=JSON.parse(fs.readFileSync(fs.existsSync(mobileFile)?mobileFile:path.join(root,'config/mobile.example.json'),'utf8').replace(/^\uFEFF/,''));
  const services=JSON.parse(fs.readFileSync(servicesFile,'utf8').replace(/^\uFEFF/,''));
  if(services.smtp?.enabled)await check(services);
  const result=await configuration.publishInitial({mobile,services});
  const restored=await configuration.readServices();
  if(JSON.stringify(serviceValues(restored))!==JSON.stringify(serviceValues(services)))throw Error('shared-verification-failed');
  await sync();console.log(JSON.stringify({sharedConfigurationVerified:true,...result}));
 }
 else if(command==='status'){
  const [mobile,services]=await Promise.all([configuration.readMobile(),configuration.readServices()]);
  console.log(JSON.stringify({sharedConfiguration:true,emailConfigured:services.smtp?.enabled===true,mapboxConfigured:mobile.MAPBOX_PUBLIC_TOKEN.startsWith('pk.')}));
 }
 else throw Error('unsupported-command');
}
main().catch(error=>{const known=error.name==='ConfigurationError';console.error(known?error.message:'Shared configuration could not be loaded or saved. Check Firebase project access and the entered settings.');process.exitCode=1;});
