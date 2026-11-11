'use strict';
const {test,after}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),{randomUUID}=require('node:crypto');
if(process.env.GCLOUD_PROJECT!=='demo-themepark-fyp'||process.env.FIRESTORE_EMULATOR_HOST!=='127.0.0.1:8080')throw Error('Configuration checks require isolated fixtures.');
const admin=require('../../functions/node_modules/firebase-admin');if(!admin.apps.length)admin.initializeApp({projectId:process.env.GCLOUD_PROJECT});const db=admin.firestore(),{FieldValue}=admin.firestore;
const {createProjectConfiguration,mobileValues,serviceValues,writeMobileCache,MOBILE_PATH,SERVICES_PATH}=require('../../server/project_configuration.cjs');
const configuration=createProjectConfiguration({db,FieldValue});
const services={smtp:{enabled:true,host:'smtp.fixture.invalid',port:465,security:'ssl',username:'fixture@example.test',password:'isolated-server-secret',from:'fixture@example.test'}};
const mobile=mobileValues({});
after(async()=>{await db.doc(MOBILE_PATH).delete();await db.doc(SERVICES_PATH).delete();});

test('shared settings keep server credentials separate and a second source folder receives only client defines',async()=>{
 await db.doc(MOBILE_PATH).delete();await db.doc(SERVICES_PATH).delete();
 assert.deepEqual(await configuration.publishInitial({mobile,services}),{mobileCreated:true,servicesCreated:true});
 const otherPc=createProjectConfiguration({db,FieldValue}),downloaded=await otherPc.readMobile();
 assert.deepEqual(await otherPc.readServices(),services);
 const root=path.join(process.cwd(),'.local','configuration-checks','Other PC '+randomUUID());
 const target=writeMobileCache(root,downloaded),output=fs.readFileSync(target,'utf8');
 assert.deepEqual(JSON.parse(output),mobile);assert.equal(output.includes('isolated-server-secret'),false);assert.equal(output.includes('smtp'),false);assert.equal(fs.existsSync(path.join(root,'env.json')),false);assert.equal(fs.existsSync(path.join(root,'.local/services.json')),false);
 assert.throws(()=>writeMobileCache(root,{...downloaded,smtp:services.smtp}));assert.equal(fs.readFileSync(target,'utf8'),output);
});
test('provider changes are shared across instances and preserve unrelated settings',async()=>{
 await configuration.saveMobile({MAPBOX_PUBLIC_TOKEN:'pk.isolated-public-token',SITUM_BUILDING_ID:'1234',SITUM_API_KEY:'isolated-mobile-key'});
 await configuration.saveMobile({USE_FIREBASE_FUNCTIONS:true});
 const second=createProjectConfiguration({db,FieldValue}),values=await second.readMobile();
 assert.equal(values.MAPBOX_PUBLIC_TOKEN,'pk.isolated-public-token');assert.equal(values.SITUM_BUILDING_ID,'1234');assert.equal(values.USE_FIREBASE_FUNCTIONS,true);assert.deepEqual(await second.readServices(),services);
 await assert.rejects(configuration.saveMobile({PARK_NORTH:'1'}));assert.equal((await second.readMobile()).PARK_NORTH,mobile.PARK_NORTH);
});
test('a stale copied local secret cannot overwrite the shared email configuration during migration',async()=>{
 assert.deepEqual(await configuration.publishInitial({mobile,services}),{mobileCreated:false,servicesCreated:false});
 await assert.rejects(configuration.publishInitial({mobile,services:{smtp:{...services.smtp,password:'stale-isolated-password'}}}));
 assert.equal((await configuration.readServices()).smtp.password,services.smtp.password);
});
test('validation rejects secret fields in client settings, credential-bearing URLs and insecure SMTP',()=>{
 for(const value of [{password:'never-bundle-this'},{MAPBOX_PUBLIC_TOKEN:'sk.secret-token'},{ACCOUNT_SERVICE_URL:'https://user:secret@example.test'},{SITUM_POI_MAP:'[]'}])assert.throws(()=>mobileValues(value));
 assert.throws(()=>serviceValues({smtp:{...services.smtp,port:25}}));assert.throws(()=>serviceValues({smtp:{...services.smtp,from:'a@example.test\r\nBcc: other@example.test'}}));
});
test('server credentials load from Firebase into memory with no local-file fallback',async()=>{
 const {loadServiceConfig,serviceConfig,mailReady}=require('../../server/service_config.cjs');
 await loadServiceConfig(configuration);assert.equal(mailReady(),true);assert.deepEqual(serviceConfig(),services);
 await db.doc(SERVICES_PATH).delete();await loadServiceConfig(configuration);assert.deepEqual(serviceConfig(),{});assert.equal(mailReady(),false);
 await db.doc(MOBILE_PATH).delete();await assert.rejects(configuration.readMobile());
});
