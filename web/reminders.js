'use strict';
(() => {
  const database = () => new Promise((resolve, reject) => {
    const request = indexedDB.open('themepark-reminders', 1);
    request.onupgradeneeded = () => { request.result.createObjectStore('settings'); request.result.createObjectStore('shown'); };
    request.onerror = () => reject(request.error); request.onsuccess = () => resolve(request.result);
  });
  async function binding(value) {
    const db = await database();
    try { return await new Promise((resolve, reject) => {
      const tx = db.transaction('settings', value === undefined ? 'readonly' : 'readwrite'), store = tx.objectStore('settings');
      const request = value === undefined ? store.get('device') : value === null ? store.delete('device') : store.put(value, 'device');
      request.onsuccess = () => resolve(request.result); tx.onabort = () => reject(tx.error);
    }); } finally { db.close(); }
  }
  const supported = () => window.isSecureContext && 'Notification' in window && 'serviceWorker' in navigator && 'PushManager' in window;
  async function worker() {
    const registration = await navigator.serviceWorker.register(new URL('reminders/service-worker.js', document.baseURI), {scope: new URL('reminders/', document.baseURI).pathname});
    if (registration.active) return registration;
    await new Promise((resolve, reject) => {
      const pending = registration.installing || registration.waiting;
      if (!pending) return reject(Error('Notification service could not start.'));
      const timeout = setTimeout(() => reject(Error('Notification service took too long to start.')), 15000);
      pending.addEventListener('statechange', () => {
        if (pending.state === 'activated') { clearTimeout(timeout); resolve(); }
        if (pending.state === 'redundant') { clearTimeout(timeout); reject(Error('Notification service could not start.')); }
      });
    });
    return registration;
  }
  let onOpen;
  if ('serviceWorker' in navigator) navigator.serviceWorker.addEventListener('message', event => {
    if (event.data?.type === 'park-reminder-open' && /^[\w-]{1,160}$/.test(event.data.reservationId)) onOpen?.(event.data.reservationId);
  });
  window.parkReminders = {
    origin: () => location.origin,
    onOpen: callback => { onOpen = callback; },
    async status(device) {
      if (!supported()) return JSON.stringify({supported:false,enabled:false,message:'Use a supported browser over HTTPS or localhost for notifications.'});
      let subscribed = false;
      if (Notification.permission === 'granted') {
        const registration = await navigator.serviceWorker.getRegistration(new URL('reminders/', document.baseURI));
        subscribed = !!(await registration?.pushManager.getSubscription());
      }
      return JSON.stringify({supported:true,enabled:subscribed && await binding() === device,
        message:Notification.permission === 'denied' ? 'Allow notifications in your browser’s site settings, then enable reminders here.' : null});
    },
    async subscribe(key) {
      try {
        if (!supported()) return JSON.stringify({permission:'unsupported',message:'This browser does not support notifications here.'});
        const permission = Notification.permission === 'default' ? await Notification.requestPermission() : Notification.permission;
        if (permission !== 'granted' || !key) return JSON.stringify({permission});
        const registration = await worker(), bytes = Uint8Array.from(atob(key.replace(/-/g,'+').replace(/_/g,'/')), c => c.charCodeAt(0));
        let saved = await registration.pushManager.getSubscription();
        if (saved && Array.from(new Uint8Array(saved.options.applicationServerKey)).join(',') !== Array.from(bytes).join(',')) { await saved.unsubscribe(); saved = null; }
        saved ||= await registration.pushManager.subscribe({userVisibleOnly:true,applicationServerKey:bytes});
        return JSON.stringify({permission,subscription:saved.toJSON()});
      } catch (_) { return JSON.stringify({permission:'error',message:'Browser notifications could not start. Check your connection and site permissions, then try again.'}); }
    },
    bind: device => binding(device),
    async remove(device) {
      if (!supported() || await binding() !== device) return;
      await binding(null);
      const registration = await navigator.serviceWorker.getRegistration(new URL('reminders/', document.baseURI));
      for (const notice of await registration?.getNotifications() || []) notice.close();
      await (await registration?.pushManager.getSubscription())?.unsubscribe();
    },
  };
})();
