'use strict';
const fs=require('node:fs'),path=require('node:path');
function serviceConfig(){try{return JSON.parse(fs.readFileSync(path.resolve(__dirname,'../.local/services.json'),'utf8'));}catch(_){return{};}}
function mailReady(){const c=serviceConfig().smtp;return !!(c?.enabled&&typeof c.host==='string'&&c.host&&c.username&&c.password&&/^\S+@\S+\.\S+$/.test(c.from)&&[465,587,2525].includes(c.port)&&['ssl','starttls'].includes(c.security));}
module.exports={serviceConfig,mailReady};
