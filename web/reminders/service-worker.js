'use strict';
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', event => event.waitUntil(self.clients.claim()));
function database() {
  return new Promise((resolve,reject) => {
    const request = indexedDB.open('themepark-reminders',1);
    request.onupgradeneeded = () => {request.result.createObjectStore('settings');request.result.createObjectStore('shown');};
    request.onsuccess = () => resolve(request.result); request.onerror = () => reject(request.error);
  });
}
async function claim(data) {
  const db = await database();
  try { return await new Promise((resolve,reject) => {
    const tx = db.transaction(['settings','shown'],'readwrite'), binding = tx.objectStore('settings').get('device'), seen = tx.objectStore('shown').get(data.id);
    let allowed = false;
    seen.onsuccess = () => {
      if (binding.result === data.deviceId && !seen.result && data.expiresAt > Date.now()) {
        tx.objectStore('shown').put(data.expiresAt,data.id); allowed = true;
      }
      const cursor = tx.objectStore('shown').openCursor();
      cursor.onsuccess = () => {const item=cursor.result;if(item){if(item.value<Date.now())item.delete();item.continue();}};
    };
    tx.oncomplete = () => resolve(allowed); tx.onabort = () => reject(tx.error);
  }); } finally {db.close();}
}
self.addEventListener('push', event => event.waitUntil((async () => {
  let data; try {data=event.data.json();} catch (_) {return;}
  if (!/^[a-f0-9]{64}$/.test(data.id||'') || !/^[a-f0-9]{48}$/.test(data.deviceId||'') || !/^[\w-]{1,160}$/.test(data.reservationId||'') || typeof data.title!=='string' || typeof data.body!=='string' || !Number.isFinite(data.expiresAt)) return;
  let url; try {url=new URL(data.url);}catch(_){return;}
  if (url.origin !== self.location.origin || !await claim(data)) return;
  await self.registration.showNotification(data.title.slice(0,100),{body:data.body.slice(0,300),icon:'../icons/Icon-192.png',badge:'../icons/Icon-192.png',tag:'ride-'+data.id,renotify:false,data:{url:url.href,reservationId:data.reservationId}});
})()));
self.addEventListener('notificationclick', event => {
  event.notification.close();
  event.waitUntil((async () => {
    const {url,reservationId}=event.notification.data||{};
    if (typeof url!=='string'||new URL(url).origin!==self.location.origin) return;
    const clients=await self.clients.matchAll({type:'window',includeUncontrolled:true});
    const target=clients.find(client=>new URL(client.url).origin===self.location.origin);
    if (target) {await target.focus();target.postMessage({type:'park-reminder-open',reservationId});}
    else await self.clients.openWindow(url);
  })());
});
