'use strict';
const {test}=require('node:test');
const assert=require('node:assert/strict');
const {createAccountService}=require('../../server/account_service.cjs');
test('reservation HTTP bridge verifies Firebase identity, retains domain errors and never trusts a body owner',async()=>{
  const calls=[], token={uid:'verified-visitor',email:'visitor@example.com',email_verified:true,auth_time:123};
  const auth={async verifyIdToken(value,revoked){assert.equal(revoked,true);if(value!=='valid')throw Error('Invalid token');return token;}};
  const reservations={async reserveSlot(request){calls.push(request);return{reservationId:'saved',status:'confirmed'};},async cancelReservation(){throw Object.assign(Error('This session has filled up.'),{code:'resource-exhausted',details:{reason:'slot-full'}});}};
  const api=createAccountService({auth,db:{async get(){return null;}},projectId:'isolated-fixture',reservations});
  const server=api.server();await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
  const url='http://127.0.0.1:'+server.address().port;
  const post=(path,bearer='valid')=>fetch(url+path,{method:'POST',headers:{Authorization:'Bearer '+bearer,'Content-Type':'application/json'},body:JSON.stringify({uid:'forged',slotId:'slot',ticketId:'ticket',requestId:'request'})});
  try{
    assert.equal((await post('/v1/reservations/reserve','invalid')).status,401);assert.equal(calls.length,0);
    const result=await post('/v1/reservations/reserve');assert.equal(result.status,200);assert.equal((await result.json()).reservationId,'saved');
    assert.equal(calls[0].auth.uid,'verified-visitor');assert.equal(calls[0].auth.token,token);
    const full=await post('/v1/reservations/cancel');assert.equal(full.status,429);assert.deepEqual(await full.json(),{error:'resource-exhausted',message:'This session has filled up.',details:{reason:'slot-full'}});
  }finally{await new Promise(resolve=>server.close(resolve));}
});
