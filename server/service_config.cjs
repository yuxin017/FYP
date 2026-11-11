'use strict';
let current={};
function setServiceConfig(value){current=value;}
function serviceConfig(){return current;}
async function loadServiceConfig(configuration){setServiceConfig(await configuration.readServices());}
function mailReady(){const c=serviceConfig().smtp;return !!(c?.enabled&&typeof c.host==='string'&&c.host&&c.username&&c.password&&/^\S+@\S+\.\S+$/.test(c.from)&&[465,587,2525].includes(c.port)&&['ssl','starttls'].includes(c.security));}
module.exports={serviceConfig,mailReady,setServiceConfig,loadServiceConfig};
