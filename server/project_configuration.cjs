'use strict';
const fs=require('node:fs'),path=require('node:path');
const defaults=JSON.parse(fs.readFileSync(path.join(__dirname,'../config/mobile.example.json'),'utf8'));
const MOBILE_PATH='applicationConfiguration/mobile',SERVICES_PATH='serverConfiguration/services';
class ConfigurationError extends Error{constructor(message){super(message);this.name='ConfigurationError';}}
const fail=message=>{throw new ConfigurationError(message);};
const object=value=>value&&typeof value==='object'&&!Array.isArray(value);
function mobileValues(value,{partial=false}={}){
 if(!object(value)||Object.keys(value).some(key=>!Object.hasOwn(defaults,key)))fail('Application settings contain an unsupported field.');
 const result=partial?{}:{...defaults};
 for(const [key,raw]of Object.entries(value)){
  if(key==='USE_FIREBASE_FUNCTIONS'){
   if(![true,false,'true','false'].includes(raw))fail('Choose a valid cloud reservation setting.');
   result[key]=raw===true||raw==='true';continue;
  }
  if(!['string','number'].includes(typeof raw))fail('Review the application setting values.');
  const entry=String(raw);if(entry.length>(key==='SITUM_POI_MAP'?30000:3000)||/[\r\n\0]/.test(entry))fail('An application setting is too long or invalid.');
  if(key==='MAPBOX_PUBLIC_TOKEN'&&entry&&!/^pk\.[A-Za-z0-9_.-]+$/.test(entry))fail('Mapbox requires a public pk. token.');
  if(key==='MAPBOX_STYLE'&&!/^[\w-]+\/[\w-]+$/.test(entry))fail('Choose a valid Mapbox style.');
  if(key==='ACCOUNT_SERVICE_URL'){
   let url;try{url=new URL(entry);}catch(_){fail('Choose a valid application API address.');}
   if(!['http:','https:'].includes(url.protocol)||url.username||url.password||url.search||url.hash)fail('Choose a valid application API address.');
  }
  if(key.startsWith('PARK_')&&entry&&(!Number.isFinite(Number(entry))||Math.abs(Number(entry))>(['PARK_NORTH','PARK_SOUTH'].includes(key)?90:180)))fail('Choose valid venue coordinates.');
  if(key==='SITUM_POI_MAP'){
   let mapping;try{mapping=JSON.parse(entry);}catch(_){fail('Choose a valid Situm point mapping.');}
   if(!object(mapping)||Object.keys(mapping).length>1000||Object.entries(mapping).some(([k,v])=>!k||k.length>160||typeof v!=='string'||!v||v.length>160))fail('Choose a valid Situm point mapping.');
  }
  result[key]=entry;
 }
 if(!partial&&[result.PARK_NORTH,result.PARK_SOUTH,result.PARK_EAST,result.PARK_WEST].every(v=>v!=='')){
  if(Number(result.PARK_NORTH)<=Number(result.PARK_SOUTH)||Number(result.PARK_EAST)<=Number(result.PARK_WEST))fail('The venue boundary coordinates are reversed.');
 }
 return result;
}
function serviceValues(value){
 if(!object(value)||Object.keys(value).some(k=>k!=='smtp')||!object(value.smtp))fail('Review the server email settings.');
 const c=value.smtp,keys=['enabled','host','port','security','username','password','from'];
 if(Object.keys(c).some(k=>!keys.includes(k))||typeof c.enabled!=='boolean')fail('Review the server email settings.');
 const smtp={enabled:c.enabled};
 for(const key of ['host','security','username','password','from']){
  if(typeof c[key]!=='string'||c[key].length>4096||/[\r\n\0]/.test(c[key]))fail('Review the server email settings.');
  smtp[key]=c[key];
 }
 smtp.port=c.port;
 if(![465,587,2525].includes(c.port)||!['ssl','starttls'].includes(c.security))fail('Choose an encrypted SMTP connection.');
 if(c.enabled&&(!/^[a-zA-Z0-9.-]{1,253}$/.test(c.host)||!c.username||!c.password||!/^\S+@\S+\.\S+$/.test(c.from)))fail('Complete the sending email settings.');
 return{smtp};
}
function createProjectConfiguration({db,FieldValue}){
 async function readMobile(){
  const snapshot=await db.doc(MOBILE_PATH).get();
  if(!snapshot.exists)fail('Shared application settings are missing from Firebase. Publish the project configuration before using another PC.');
  if(snapshot.data().schemaVersion!==1)fail('Update the application to read the shared settings.');
  return mobileValues(snapshot.data().values);
 }
 async function readServices(){
  const snapshot=await db.doc(SERVICES_PATH).get();
  if(!snapshot.exists)return{};
  if(snapshot.data().schemaVersion!==1)fail('Update the server to read the shared email settings.');
  return serviceValues(snapshot.data().values);
 }
 async function saveMobile(patch){
  const validated=mobileValues(patch,{partial:true});
  return db.runTransaction(async tx=>{
   const ref=db.doc(MOBILE_PATH),old=await tx.get(ref),values=mobileValues({...defaults,...(old.data()?.values??{}),...validated});
   tx.set(ref,{schemaVersion:1,values,updatedAt:FieldValue.serverTimestamp()});return values;
  });
 }
 async function saveServices(value){
  const values=serviceValues(value);
  await db.doc(SERVICES_PATH).set({schemaVersion:1,values,updatedAt:FieldValue.serverTimestamp()});
 }
 async function publishInitial({mobile,services}){
  const mobileSettings=mobileValues(mobile),serverSettings=serviceValues(services);
  return db.runTransaction(async tx=>{
   const mobileRef=db.doc(MOBILE_PATH),serverRef=db.doc(SERVICES_PATH),[oldMobile,oldServer]=await tx.getAll(mobileRef,serverRef);
   if(oldServer.exists&&JSON.stringify(serviceValues(oldServer.data().values))!==JSON.stringify(serverSettings))fail('Shared email settings already exist. Use the email configuration command to change them.');
   if(!oldMobile.exists)tx.create(mobileRef,{schemaVersion:1,values:mobileSettings,updatedAt:FieldValue.serverTimestamp()});
   if(!oldServer.exists)tx.create(serverRef,{schemaVersion:1,values:serverSettings,updatedAt:FieldValue.serverTimestamp()});
   return{mobileCreated:!oldMobile.exists,servicesCreated:!oldServer.exists};
  });
 }
 return{readMobile,readServices,saveMobile,saveServices,publishInitial};
}
function writeMobileCache(root,values){
 const safe=mobileValues(values),target=path.join(root,'.local/mobile.defines.json');
 fs.mkdirSync(path.dirname(target),{recursive:true});
 fs.writeFileSync(target+'.tmp',JSON.stringify(safe,null,2)+'\n',{mode:0o600});fs.renameSync(target+'.tmp',target);
 return target;
}
module.exports={createProjectConfiguration,mobileValues,serviceValues,writeMobileCache,MOBILE_PATH,SERVICES_PATH,ConfigurationError};
