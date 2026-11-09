'use strict';
const {createServer} = require('node:http');
const {randomBytes} = require('node:crypto');
class AccountError extends Error {constructor(status,code,message){super(message);this.status=status;this.code=code;}}
const fail=(status,code,message)=>{throw new AccountError(status,code,message);};
const ownedCollections=['orders','tickets','ticketReferences','admissions','visitorSessions','rewardVouchers','loyaltyEvents','supportAttachments','supportMessages','supportNotes','supportEvents','supportCases','accountSessions','rideAdmissions','attractionRatings','attractionRatingAttachments','groupMembers','groupLocations','groupBookings','faceTemplates','faceProfiles','photoMatchingJobs','photoMatches','photoOrders','photoEntitlements','photoOrderPreviews','photoMatchReviews','kioskRequests','emailOutbox'];
function createAccountService({auth,db,projectId,workspaceId,reservations,operations={},clock=()=>new Date()}) {
  const jobs=new Map(), rate=new Map();
  const recent=token=>{if(!Number.isInteger(token.auth_time) || Math.abs(clock().getTime()/1000-token.auth_time)>300)fail(401,'recent-login-required','Please confirm your password again.');};
  async function requireOpen(uid){if((await db.get('accountSecurity/'+uid))?.closing)fail(409,'closure-in-progress','Account deletion is in progress. Return to Delete Account to finish.');}
  async function syncProfile(token,phone=false){
    await requireOpen(token.uid);
    const user=await auth.getUser(token.uid), profile=await db.get('visitors/'+token.uid);
    if(!profile || !user.emailVerified || !user.email) return {email: user.email||'', synced:false};
    if(profile.email !== user.email)await db.set('visitors/'+token.uid,{email:user.email});
    if(phone&&user.phoneNumber&&profile.phoneNumber!==user.phoneNumber)await db.set('visitors/'+token.uid,{phoneNumber:user.phoneNumber});
    return {email:user.email,synced:true};
  }
  async function closeAccount(token){
    recent(token);const uid=token.uid;
    if(jobs.has(uid))return jobs.get(uid);
    const job=(async()=>{
      const user=await auth.getUser(uid),previous=await db.get('accountSecurity/'+uid)||{};
      if(db.beginClosure){
        try{await db.beginClosure(uid,clock());}catch(error){if(error.code==='active-reservation')fail(409,'active-reservation','Cancel your active individual and group reservations before deleting your account.');throw error;}
      }else{
        const current=await db.query('reservations','ownerUid',uid);
        if(current.some(r=>r.data.status==='confirmed'))fail(409,'active-reservation','Cancel your active attraction reservation before deleting your account.');
        await db.set('accountSecurity/'+uid,{...previous,closing:true,closingAt:clock()});
      }
      const reservations=await db.query('reservations','ownerUid',uid);
      // A durable, private marker permits a retry if cleanup is interrupted.
      await db.set('accountClosures/'+uid,{status:'deleting',updatedAt:clock()},true);
      if(db.cleanupGroups)await db.cleanupGroups(uid);
      for(const collection of ownedCollections){const records=await db.query(collection,'ownerUid',uid);await db.remove(records.map(r=>r.path));}
      // Remove the deleted visitor's guest identity without deleting another purchaser's order.
      if(user.email){
        const guests=await db.query('tickets','guestEmail',user.email.toLowerCase());
        for(const ticket of guests){
          await db.set(ticket.path,{guestName:'Guest',guestEmail:'',...(ticket.data.item?{item:{...ticket.data.item,guestName:'Guest',guestEmail:''}}:{})});
          if(ticket.data.orderId){const key='orders/'+ticket.data.orderId,order=await db.get(key);if(order?.items)await db.set(key,{items:order.items.map(item=>item.guestEmail?.toLowerCase()===user.email.toLowerCase()?{...item,guestName:'Guest',guestEmail:''}:item)});}
        }
        const references=await db.query('ticketReferences','guestEmail',user.email.toLowerCase());
        for(const reference of references)await db.set(reference.path,{guestEmail:''});
      }
      await db.remove(reservations.map(r=>r.path));
      await db.remove(['visitorAdmin/'+uid,'visitorAccess/'+uid,'visitors/'+uid]);
      await db.set('accountClosures/'+uid,{status:'data_deleted',updatedAt:clock()},true);
      // Authentication is deleted last so a failed cleanup remains retryable.
      await auth.deleteUser(uid);
      return {deleted:true};
    })();jobs.set(uid,job);try{return await job;}finally{jobs.delete(uid);}
  }
  async function dispatch(path,body,token){
    const uid=token.uid, now=clock();
    if(path==='/v1/account/close'){
      if(body.confirmation!=='DELETE')fail(400,'confirmation-required','Type DELETE to confirm.');
      return closeAccount(token);
    }
    if(path==='/v1/account/state')return {closing:(await db.get('accountSecurity/'+uid))?.closing===true};
    if(path==='/v1/profile/sync')return syncProfile(token);
    if(path==='/v1/profile/sync-phone')return syncProfile(token,true);
    await requireOpen(uid);
    if(Object.hasOwn(operations,path)){
      const access=await db.get('visitorAccess/'+uid);if(access&&access.status!=='active')fail(403,'permission-denied','This account is restricted. Please contact support.');
      return operations[path]({auth:{uid,token},data:body});
    }
    if(path==='/v1/reservations/reserve'||path==='/v1/reservations/cancel'){
      if(!reservations)fail(503,'unavailable','Reservation services are unavailable. Please try again.');
      const method=path.endsWith('/reserve')?'reserveSlot':'cancelReservation';
      return reservations[method]({auth:{uid,token},data:body});
    }
    if(path==='/v1/sessions/open'){
      let id=body.id;
      if(typeof id!=='string'||!/^[a-f0-9]{48}$/.test(id))id=randomBytes(24).toString('hex');
      const key='accountSessions/'+uid+'_'+id, old=await db.get(key);
      if(old && old.ownerUid!==uid)id=randomBytes(24).toString('hex');
      const actual='accountSessions/'+uid+'_'+id, existing=id===body.id?old:null;
      const name=typeof body.deviceName==='string'?body.deviceName.replace(/[\r\n\t]/g,' ').slice(0,100):'Browser';
      await db.set(actual,{ownerUid:uid,sessionId:id,deviceName:name,authTime:token.auth_time,startedAt:existing?.startedAt||now,lastSeenAt:now});
      return {id};
    }
    if(path==='/v1/sessions/list'){
      const sessions=await db.query('accountSessions','ownerUid',uid);
      return {sessions:sessions.map(s=>s.data).sort((a,b)=>b.lastSeenAt-a.lastSeenAt)};
    }
    if(path==='/v1/sessions/end'){
      if(typeof body.id!=='string'||!/^[a-f0-9]{48}$/.test(body.id))fail(400,'invalid-session','Choose a valid session.');
      await db.remove(['accountSessions/'+uid+'_'+body.id]);return {ended:true};
    }
    if(path==='/v1/sessions/revoke-all'){
      recent(token);
      await auth.revokeRefreshTokens(uid);
      const user=await auth.getUser(uid), revokedBefore=Math.floor(new Date(user.tokensValidAfterTime).getTime()/1000);
      await db.set('accountSecurity/'+uid,{revokedBefore,updatedAt:now},true);
      const sessions=await db.query('accountSessions','ownerUid',uid);await db.remove(sessions.map(s=>s.path));
      return {signedOut:true};
    }
    fail(404,'not-found','This account action is unavailable.');
  }
  async function handler(req,res){
    const origin=req.headers.origin;
    const allowed=new Set(['http://localhost:5173','http://127.0.0.1:5173']);
    res.setHeader('Cache-Control','no-store');res.setHeader('Content-Type','application/json');
    if(origin&&!allowed.has(origin)){res.writeHead(403);res.end(JSON.stringify({error:'origin-not-allowed',message:'This application address is not allowed.'}));return;}
    if(origin)res.setHeader('Access-Control-Allow-Origin',origin);
    res.setHeader('Vary','Origin');res.setHeader('Access-Control-Allow-Headers','Authorization, Content-Type');res.setHeader('Access-Control-Allow-Methods','POST, GET, OPTIONS');
    if(req.method==='OPTIONS'){res.writeHead(204);res.end();return;}
    if(req.url==='/health'&&req.method==='GET'){res.end(JSON.stringify({ok:true,projectId,...(workspaceId?{workspaceId}:{})}));return;}
    try{
      if(req.method!=='POST')fail(405,'method-not-allowed','Use a supported account action.');
      const bearer=/^Bearer (\S+)$/.exec(req.headers.authorization||'');if(!bearer)fail(401,'unauthenticated','Please sign in again.');
      let token;try{token=await auth.verifyIdToken(bearer[1],true);}catch(_){fail(401,'session-expired','Your session has ended. Please sign in again.');}
      if(!token.email_verified)fail(403,'email-not-verified','Verify your email before managing your account.');
      const key=token.uid+'_'+Math.floor(clock().getTime()/60000),count=(rate.get(key)||0)+1;rate.set(key,count);if(rate.size>1000)rate.clear();if(count>60)fail(429,'too-many-requests','Please wait a moment and try again.');
      const limit=req.url==='/v1/photos/upload'?12000000:['/v1/photos/enroll','/v1/ai/saveLandmark','/v1/ai/recognizeLandmark'].includes(req.url)?3000000:req.url==='/v1/visits/rate'?300000:req.url?.startsWith('/v1/tickets/')?30000:8192;
      const chunks=[];let size=0;for await(const chunk of req){size+=chunk.length;if(size>limit)fail(413,'request-too-large','The request is too large.');chunks.push(chunk);}
      const raw=Buffer.concat(chunks).toString('utf8');
      let body;try{body=raw?JSON.parse(raw):{};}catch(_){fail(400,'invalid-request','Review the request and try again.');}
      if(!body||typeof body!=='object'||Array.isArray(body))fail(400,'invalid-request','Review the request and try again.');
      const result=await dispatch(req.url,body,token);res.end(JSON.stringify(result));
    }catch(e){const statuses={'unauthenticated':401,'permission-denied':403,'invalid-argument':400,'not-found':404,'already-exists':409,'failed-precondition':409,'resource-exhausted':429,'unavailable':503,'deadline-exceeded':504};const domain=Object.hasOwn(statuses,e.code);res.statusCode=e.status||statuses[e.code]||503;res.end(JSON.stringify({error:e.code||'unavailable',message:e instanceof AccountError||domain?e.message:'Application services are unavailable. Please reconnect and retry.',...(domain&&e.details?{details:e.details}:{})}));}
  }
  return {handler,dispatch,server:()=>createServer(handler)};
}
module.exports={createAccountService,AccountError,ownedCollections};
