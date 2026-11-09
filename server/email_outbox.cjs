'use strict';
const crypto=require('node:crypto');
function createEmailOutbox({db,FieldValue,ai,mailReady,clock=()=>new Date()}){
  const workerId=crypto.randomUUID();
  async function run(){
    if(!mailReady())return{configured:false};
    const abandoned=await db.collection('emailOutbox').where('status','==','sending').limit(20).get();
    for(const candidate of abandoned.docs)if(candidate.data().startedAt?.toDate?.()<new Date(clock().getTime()-180000))await db.runTransaction(async tx=>{const current=await tx.get(candidate.ref),data=current.data();if(data?.status!=='sending'||!data.startedAt?.toDate||data.startedAt.toDate()>new Date(clock().getTime()-180000))return;const order=await tx.get(db.doc('photoOrders/'+data.orderId));tx.update(candidate.ref,{status:'attention',updatedAt:FieldValue.serverTimestamp()});if(order.exists)tx.update(order.ref,{emailStatus:'attention'});});
    const rows=await db.collection('emailOutbox').where('status','==','queued').limit(3).get();let sent=0;
    for(const candidate of rows.docs){
      const job=await db.runTransaction(async tx=>{const [current,security]=await tx.getAll(candidate.ref,db.doc('accountSecurity/'+candidate.data().ownerUid));if(current.data()?.status!=='queued'||security.data()?.closing)return null;tx.update(candidate.ref,{status:'sending',workerId,startedAt:clock()});return current.data();});if(!job)continue;
      try{
        const order=await db.doc('photoOrders/'+job.orderId).get();if(!order.exists||order.data().ownerUid!==job.ownerUid)throw Error('order unavailable');
        const images=[];
        for(const item of order.data().items.filter(i=>i.format!=='print')){
          const original=await db.doc('photoOriginals/'+item.photoId).get();if(!original.exists)throw Error('photo unavailable');
          const rendered=await ai.call('render_photo',{imageBase64:original.data().imageBase64,edits:item.edits});images.push({name:'ThemePark-'+item.photoId.slice(0,12)+'.jpg',imageBase64:rendered.imageBase64});
        }
        const result=await ai.call('send_photo_email',{to:job.to,orderId:job.orderId,totalMinor:order.data().totalMinor,attachments:images});
        await db.runTransaction(async tx=>{const current=await tx.get(candidate.ref);if(current.data()?.workerId!==workerId)return;tx.update(candidate.ref,{status:'sent',messageId:result.messageId,sentAt:clock()});tx.update(order.ref,{emailStatus:'sent',emailSentAt:clock()});});sent++;
      }catch(_){await db.runTransaction(async tx=>{const [current,order]=await tx.getAll(candidate.ref,db.doc('photoOrders/'+job.orderId));if(current.data()?.workerId!==workerId)return;tx.update(candidate.ref,{status:'attention',updatedAt:FieldValue.serverTimestamp()});if(order.exists)tx.update(order.ref,{emailStatus:'attention'});});}
    }
    return{configured:true,sent};
  }
  return{run};
}
module.exports={createEmailOutbox};
