'use strict';
const {test}=require('node:test');
const assert=require('node:assert/strict');
const {createAccountService}=require('../../server/account_service.cjs');

test('API health identifies its workspace without granting access to application operations',async()=>{
  const api=createAccountService({auth:{async verifyIdToken(){throw Error('Invalid');}},db:{},projectId:'isolated-fixture',workspaceId:'fixture-workspace'});
  const server=api.server();await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
  const base='http://127.0.0.1:'+server.address().port;
  try{
    assert.deepEqual(await(await fetch(base+'/health')).json(),{ok:true,projectId:'isolated-fixture',workspaceId:'fixture-workspace'});
    assert.equal((await fetch(base+'/v1/sessions/list',{method:'POST'})).status,401);
  }finally{await new Promise(resolve=>server.close(resolve));}
});

test('existing API fixtures keep the same health contract when no workspace is supplied',async()=>{
  const server=createAccountService({auth:{},db:{},projectId:'isolated-fixture'}).server();
  await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
  try{assert.deepEqual(await(await fetch('http://127.0.0.1:'+server.address().port+'/health')).json(),{ok:true,projectId:'isolated-fixture'});}
  finally{await new Promise(resolve=>server.close(resolve));}
});
