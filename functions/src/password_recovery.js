'use strict';
const {randomBytes, randomInt, createHash, scrypt, timingSafeEqual} = require('node:crypto');
const {promisify} = require('node:util');
const {HttpsError} = require('firebase-functions/v2/https');
const derive = promisify(scrypt);
const hash = value => createHash('sha256').update(value).digest('hex');
const date = value => value?.toDate ? value.toDate() : new Date(value);
const fail = (code, message) => { throw new HttpsError(code, message); };
const invalid = () => fail('invalid-argument', 'The OTP is incorrect, expired or already used. Request a new code if needed.');

// All records are private server records. No code, email, UID or reset grant is
// returned by the send endpoint. Firebase handles the final password change.
function createPasswordRecovery({db, auth, mailReady, deliver, clock = () => new Date()}) {
  const pending = new Set();
  async function limit(email, ip, sending) {
    const now = clock(), windowMs = sending ? 3600000 : 600000;
    const refs = [db.doc('recoveryLimits/' + hash('ip:' + ip + ':' + sending))];
    if (sending) refs.push(db.doc('recoveryLimits/' + hash('email:' + email)));
    await db.runTransaction(async tx => {
      const snapshots = await Promise.all(refs.map(ref => tx.get(ref)));
      const changes = snapshots.map((snapshot, i) => {
        const old = snapshot.data(), sameWindow = old && now - date(old.windowStart) < windowMs;
        const count = sameWindow ? old.count + 1 : 1;
        const maximum = sending ? (i === 0 ? 20 : 5) : 60;
        if (count > maximum || (sending && i === 1 && old && now - date(old.lastAt) < 60000)) {
          fail('resource-exhausted', 'Please wait before requesting or checking another OTP.');
        }
        return {count, windowStart: sameWindow ? old.windowStart : now, lastAt: now,
          expiresAt: new Date(now.getTime() + windowMs)};
      });
      refs.forEach((ref, i) => tx.set(ref, changes[i]));
    });
  }
  async function permitted(user) {
    if (!user || user.disabled || !user.providerData?.some(p => p.providerId === 'password')) return false;
    const [security, access] = await db.getAll(db.doc('accountSecurity/' + user.uid), db.doc('visitorAccess/' + user.uid));
    return !security.data()?.closing && (!access.exists || access.data().status === 'active');
  }
  async function send(data, ip) {
    const email = typeof data.email === 'string' ? data.email.trim().toLowerCase() : '';
    if (email.length > 254 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) fail('invalid-argument', 'Enter a valid email address.');
    if (!mailReady()) fail('unavailable', 'Email delivery is temporarily unavailable. Please try again later.');
    await limit(email, ip, true);
    let user;
    try { user = await auth.getUserByEmail(email); }
    catch (error) { if (error.code !== 'auth/user-not-found') throw error; }
    const uid = await permitted(user) ? user.uid : null;
    const challengeId = randomBytes(24).toString('hex'), salt = randomBytes(24).toString('hex');
    const otp = String(randomInt(1000000)).padStart(6, '0');
    const digest = (await derive(otp, salt, 32)).toString('hex');
    const subject = hash(email), now = clock(), expiresAt = new Date(now.getTime() + 300000);
    const ref = db.doc('recoveryChallenges/' + challengeId);
    await db.runTransaction(async tx => {
      tx.set(db.doc('recoverySubjects/' + subject), {challengeId, expiresAt});
      tx.set(ref, {uid, subject, salt, digest, attempts: 0, status: 'pending', expiresAt});
    });
    // Delivery is separate from the response so its timing and SMTP failures do
    // not disclose whether an address is registered. Failed mail is never retried
    // with the same code; requesting again replaces the active challenge.
    const job = (async () => {
      let delivered = false;
      try { if (uid) delivered = (await deliver({to: email, otp, challengeId})).sent === true; }
      catch (_) { /* SMTP credentials and codes never enter logs or responses. */ }
      await db.runTransaction(async tx => {
        const snapshot = await tx.get(ref);
        if (snapshot.data()?.status === 'pending') tx.update(ref, {status: delivered || !uid ? 'ready' : 'delivery-failed'});
      });
    })();
    pending.add(job); job.catch(() => {}).finally(() => pending.delete(job));
    return {challengeId, expiresAt: expiresAt.toISOString(), resendAfterSeconds: 60};
  }
  async function verify(data, ip) {
    if (!/^[a-f0-9]{48}$/.test(data.challengeId || '') || !/^\d{6}$/.test(data.otp || '')) invalid();
    await limit('', ip, false);
    const ref = db.doc('recoveryChallenges/' + data.challengeId), snapshot = await ref.get(), challenge = snapshot.data();
    if (!challenge || !/^[a-f0-9]{48}$/.test(challenge.salt || '')) invalid();
    const digest = (await derive(data.otp, challenge.salt, 32)).toString('hex');
    const won = await db.runTransaction(async tx => {
      const current = (await tx.get(ref)).data();
      const subject = current ? (await tx.get(db.doc('recoverySubjects/' + current.subject))).data() : null;
      if (!current || current.status !== 'ready' || date(current.expiresAt) <= clock() ||
          current.attempts >= 5 || subject?.challengeId !== data.challengeId) return false;
      const good = current.uid && typeof current.digest === 'string' && current.digest.length === digest.length &&
        timingSafeEqual(Buffer.from(current.digest, 'hex'), Buffer.from(digest, 'hex'));
      // Record wrong guesses without throwing inside the transaction (which
      // would roll back the attempt count). A successful OTP can be consumed once.
      tx.update(ref, {attempts: current.attempts + 1, ...(good ? {status: 'consumed', consumedAt: clock()} : {})});
      return Boolean(good);
    });
    if (!won) invalid();
    const user = await auth.getUser(challenge.uid);
    if (!await permitted(user)) invalid();
    const link = await auth.generatePasswordResetLink(user.email);
    const code = new URL(link).searchParams.get('oobCode');
    if (!code) fail('unavailable', 'Please request a new OTP and try again.');
    return {code, email: user.email};
  }
  return {send, verify, async drain() { await Promise.allSettled([...pending]); }};
}
module.exports = {createPasswordRecovery};
