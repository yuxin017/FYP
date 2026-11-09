const {createAccountLifecycle}=require('../functions/src/account_lifecycle');
'use strict';
const path = require('node:path');
const {createRequire} = require('node:module');
const requireFunctions = createRequire(path.join(__dirname, '../functions/package.json'));
const {initializeApp, getApps} = requireFunctions('firebase-admin/app');
const {getAuth} = requireFunctions('firebase-admin/auth');
const projectId = 'themeparksmartmanagement';
const cliRoot = process.env.FIREBASE_CLI_ROOT || path.join(__dirname, '../tool/firebase/node_modules/firebase-tools');
const cliAuth = require(path.join(cliRoot, 'lib/auth'));
const cliApi = require(path.join(cliRoot, 'lib/api'));
const {Firestore, FieldValue, Timestamp} = requireFunctions('@google-cloud/firestore');
let transactionStore;
function sharedFirestore() {
  if (!transactionStore) {
    const account=cliAuth.getGlobalDefaultAccount();
    if(!account?.tokens?.refresh_token)throw Error('Firebase CLI sign-in is required.');
    transactionStore=new Firestore({projectId,preferRest:true,credentials:{type:'authorized_user',client_id:cliApi.clientId(),client_secret:cliApi.clientSecret(),refresh_token:account.tokens.refresh_token}});
  }
  return transactionStore;
}
async function accessToken() {
  const account = cliAuth.getGlobalDefaultAccount();
  if (!account?.tokens?.refresh_token) throw new Error('Sign in with Firebase CLI before starting the account service.');
  return (await cliAuth.getAccessToken(account.tokens.refresh_token, [])).access_token;
}
const credential = {async getAccessToken() {return {access_token: await accessToken(), expires_in: 3000};}};
const app = getApps().find(a => a.name === 'AccountService') || initializeApp({projectId, credential}, 'AccountService');
const auth = getAuth(app);
const base = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents`;
function encode(value) {
  if (value === null) return {nullValue: null};
  if (value instanceof Date) return {timestampValue: value.toISOString()};
  if (typeof value === 'boolean') return {booleanValue: value};
  if (typeof value === 'number') return Number.isInteger(value) ? {integerValue: String(value)} : {doubleValue: value};
  if (typeof value === 'string') return {stringValue: value};
  if (Array.isArray(value)) return {arrayValue: {values: value.map(encode)}};
  return {mapValue: {fields: Object.fromEntries(Object.entries(value).map(([k,v]) => [k,encode(v)]))}};
}
function decode(value) {
  if ('nullValue' in value) return null;
  if ('timestampValue' in value) return new Date(value.timestampValue);
  if ('integerValue' in value) return Number(value.integerValue);
  if ('doubleValue' in value) return value.doubleValue;
  if ('booleanValue' in value) return value.booleanValue;
  if ('stringValue' in value) return value.stringValue;
  if ('arrayValue' in value) return (value.arrayValue.values || []).map(decode);
  return Object.fromEntries(Object.entries(value.mapValue?.fields || {}).map(([k,v]) => [k,decode(v)]));
}
function document(data) {return Object.fromEntries(Object.entries(data).map(([k,v]) => [k,encode(v)]));}
function unpack(doc) {return {path: doc.name.split('/documents/')[1], data: Object.fromEntries(Object.entries(doc.fields || {}).map(([k,v]) => [k,decode(v)]))};}
async function request(url, options = {}) {
  const response = await fetch(url, {headers: {Authorization: 'Bearer ' + await accessToken(), 'Content-Type':'application/json'}, ...options, signal: AbortSignal.timeout(30000)});
  const body = await response.json();
  if (!response.ok) {const e = new Error('Firebase account operation failed. Please reconnect and retry.'); e.status = response.status; throw e;}
  return body;
}
const db = {
  async beginClosure(uid,now) { return createAccountLifecycle({db:sharedFirestore(),FieldValue}).beginClosure(uid,now); },
  async cleanupGroups(uid) { return createAccountLifecycle({db:sharedFirestore(),FieldValue}).cleanupGroups(uid); },
  async get(key) {try {return unpack(await request(base + '/' + key)).data;} catch (e) {if(e.status === 404)return null; throw e;}},
  async query(collection, field, value) {
    const rows = await request(base + ':runQuery', {method: 'POST', body:JSON.stringify({structuredQuery:{from:[{collectionId:collection}],where:{fieldFilter:{field:{fieldPath:field},op:'EQUAL',value:encode(value)}}}})});
    return rows.filter(row => row.document).map(row => unpack(row.document));
  },
  async set(key, data, merge = true) {
    const write = {update:{name:base.slice('https://firestore.googleapis.com/v1/'.length) + '/' + key,fields:document(data)}};
    if(merge)write.updateMask={fieldPaths:Object.keys(data)};
    await request(base + ':commit', {method:'POST',body:JSON.stringify({writes:[write]})});
  },
  async remove(keys) {
    for(let i=0;i<keys.length;i+=400) await request(base + ':commit',{method:'POST',body:JSON.stringify({writes:keys.slice(i,i+400).map(key=>({delete:base.slice('https://firestore.googleapis.com/v1/'.length)+'/'+key}))})});
  },
};
module.exports = {projectId, db, auth, accessToken, encode, decode, sharedFirestore, FieldValue, Timestamp};
