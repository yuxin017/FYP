"use strict";

const crypto = require("node:crypto");
const {HttpsError, onCall} = require("firebase-functions/v2/https");
const {FieldValue, Timestamp} = require("firebase-admin/firestore");

const defaultReservationCapacity = 10;
const windowMinutes = 15;
// Match the map's category aliases, including records made before Add Facility.
const nonRideCategory = /dining|restaurant|café|cafe|shop|retail|facilit|service|restroom|first aid/i;

const dayKey = (instant) => new Date(instant.getTime() + 8 * 3600000).toISOString().slice(0, 10);
const instant = (value) => value && typeof value.toDate === "function" ? value.toDate() : null;
const hash = (value) => crypto.createHash("sha256").update(value).digest("hex");
const validDay = (value) => typeof value === "string" && /^\d{4}-\d{2}-\d{2}$/.test(value) && !Number.isNaN(Date.parse(value)) && new Date(value).toISOString().slice(0, 10) === value;
const fail = (code, reason, message) => { throw new HttpsError(code, message, {reason}); };
const id = (value, name) => {
  if (typeof value !== "string" || !/^[A-Za-z0-9_-]{1,160}$/.test(value)) fail("invalid-argument", "invalid-input", `Invalid ${name}.`);
  return value;
};
function input(request, keys) {
  if (!request.auth?.uid) fail("unauthenticated", "sign-in-required", "Please sign in before reserving.");
  if(request.auth.token?.email_verified!==true)fail('permission-denied','email-not-verified','Verify your email before reserving.');
  const data = request.data;
  if (!data || typeof data !== "object" || Array.isArray(data) || Object.keys(data).some((key) => !keys.includes(key))) fail("invalid-argument", "invalid-input", "Invalid reservation request.");
  for (const key of keys) id(data[key], key);
  if (data.requestId.length < 16) fail("invalid-argument", "invalid-request-id", "A unique request ID is required.");
  return data;
}
function validWindow(slot) {
  const start = instant(slot.startsAt), end = instant(slot.endsAt);
  if (!start || !end || end <= start) return false;
  const date = dayKey(start), opening = new Date(`${date}T09:30:00+08:00`), closing = new Date(`${date}T19:30:00+08:00`);
  return start >= opening && end <= closing;
}
function automaticWindow(slotId) {
  const match = /^auto_([A-Za-z0-9_-]+)_(\d{4}-\d{2}-\d{2})_(\d{13})$/.exec(slotId);
  if (!match) return null;
  const [, attractionId, date, milliseconds] = match;
  const start = new Date(Number(milliseconds));
  if (!validDay(date) || dayKey(start) !== date) return null;
  const end = new Date(start.getTime() + windowMinutes * 60000);
  const window = {attractionId, startsAt: Timestamp.fromDate(start), endsAt: Timestamp.fromDate(end)};
  if (!validWindow(window) ||
      (start - new Date(date + "T09:30:00+08:00")) % (windowMinutes * 60000) !== 0) return null;
  return window;
}

function queueSize(slots, date, now) {
  return slots.reduce((sum, doc) => {
    const slot = doc.data(), start = instant(slot.startsAt), end = instant(slot.endsAt);
    if (slot.retired || !start || !end || dayKey(start) !== date || end <= now) return sum;
    const count = slot.confirmedCount ?? slot.bookedCount;
    if (!Number.isInteger(count) || count < 0 || count > slot.bookedCount) fail("failed-precondition", "invalid-queue", "The queue needs an administrator review.");
    return sum + count;
  }, 0);
}
function offered(slot, count) {
  const interval = count < 50 ? 15 : count <= 100 ? 30 : 45;
  const start = instant(slot.startsAt);
  return validWindow(slot) && (start - new Date(`${dayKey(start)}T09:30:00+08:00`)) % (interval * 60000) === 0;
}
function counters(slot) {
  const {capacity, bookedCount} = slot, confirmedCount = slot.confirmedCount ?? bookedCount;
  if (![capacity, bookedCount, confirmedCount].every(Number.isInteger) || capacity < 1 || capacity > 1000 || bookedCount < 0 || confirmedCount < 0 || confirmedCount > bookedCount || bookedCount > capacity) {
    fail("failed-precondition", "invalid-queue", "The session counts need an administrator review.");
  }
  return {capacity, bookedCount, confirmedCount};
}

/** Domain handlers can be tested against Firestore with an injected clock.
 * Only the production onCall wrapper supplies authenticated request context.
 */
function createReservationHandlers({db, FieldValue, clock = () => new Date()}) {
  function checkAccess(request,access,security){
    if(access && access.status!=='active')fail('permission-denied','account-restricted','Your account cannot make reservations. Please contact support.');
    if(security?.closing || (security?.revokedBefore && (request.auth.token.auth_time??0)<=security.revokedBefore))fail('unauthenticated','session-ended','Your session has ended. Please sign in again.');
  }
  async function access(request,tx){
    const refs=[db.collection('visitorAccess').doc(request.auth.uid),db.collection('accountSecurity').doc(request.auth.uid)];
    const records=tx?await tx.getAll(...refs):await Promise.all(refs.map(r=>r.get()));
    checkAccess(request,records[0].data(),records[1].data());
  }
  const guard = (tx, ref, snapshot) => tx.set(ref, {revision: (snapshot.data()?.revision ?? 0) + 1, updatedAt: FieldValue.serverTimestamp()});
  const requestRef = (uid, op, requestId) => db.collection("reservationRequests").doc(hash(`${uid}\0${op}\0${requestId}`));
  async function replay(tx, ref, fingerprint) {
    const saved = await tx.get(ref);
    if (!saved.exists) return null;
    if (saved.data().fingerprint !== fingerprint) fail("already-exists", "request-mismatch", "This request ID was already used for different details.");
    return saved.data().result;
  }
  async function reserveSlot(request) {
    const {slotId, ticketId, requestId} = input(request, ["slotId", "ticketId", "requestId"]);
    const uid = request.auth.uid;
    await access(request);
    const dedupe = requestRef(uid, "reserve", requestId), fingerprint = JSON.stringify({slotId, ticketId});
    const completed = await replay({get: (ref) => ref.get()}, dedupe, fingerprint);
    if (completed) return completed;
    const slotRef = db.collection("attractionSlots").doc(slotId);
    const automatic = automaticWindow(slotId);
    const initial = automatic ? null : await slotRef.get();
    if (!automatic && !initial.exists) fail("not-found", "slot-not-found", "This return time no longer exists.");
    const attractionId = id(automatic?.attractionId ?? initial.data().attractionId, "attractionId");
    const userGuard = db.collection("reservationGuards").doc(uid);
    const queueGuard = db.collection("attractionQueueGuards").doc(attractionId);
    const result = {reservationId: hash(`${uid}\0reserve\0${requestId}`), status: "confirmed"};
    return db.runTransaction(async (tx) => {
      await access(request,tx);
      const prior = await replay(tx, dedupe, fingerprint); if (prior) return prior;
      const userLock = await tx.get(userGuard), queueLock = await tx.get(queueGuard);
      const [session, ticketDoc, profileDoc, attractionDoc] = await tx.getAll(slotRef, db.collection("tickets").doc(ticketId), db.collection("visitors").doc(uid), db.collection("attractions").doc(attractionId));
      const ride = attractionDoc.data(), ticket = ticketDoc.data(), profile = profileDoc.data();
      const stored = session.data();
      const materialize = automatic && (!stored || (stored.retired && stored.bookedCount === 0));
      const slot = materialize ? {
        ...automatic,
        capacity: ride?.reservationCapacity ?? defaultReservationCapacity,
        bookedCount: 0,
        confirmedCount: 0,
      } : stored;
      if (!slot) fail("not-found", "slot-not-found", "This return time no longer exists.");
      const now = clock(), start = instant(slot.startsAt), end = instant(slot.endsAt);
      if (!ride || ride.deletedAt || ride.status !== "open" || nonRideCategory.test(ride.category) || slot.retired) fail("failed-precondition", "ride-unavailable", "This attraction or return time is unavailable.");
      if (slot.attractionId !== attractionId ||
          (stored && automatic && (stored.attractionId !== attractionId ||
            instant(stored.startsAt)?.getTime() !== instant(automatic.startsAt).getTime() ||
            instant(stored.endsAt)?.getTime() !== instant(automatic.endsAt).getTime()))) {
        fail("failed-precondition", "slot-unavailable", "This return time has changed. Refresh and choose an available time.");
      }
      if (!start || !end || start <= now || !validWindow(slot)) fail("failed-precondition", "slot-unavailable", "Choose a future session during park hours.");
      const date = dayKey(start);
      const guestEmail=typeof ticket?.guestEmail==='string'?ticket.guestEmail.toLowerCase():'';
      const callerEmail=String(request.auth.token?.email??'').toLowerCase();
      if (!ticket || (ticket.ownerUid !== uid && (!guestEmail||guestEmail!==callerEmail))) fail("permission-denied", "ticket-owner", "Choose your own admission ticket.");
      const validUntil = ticket.validUntil ?? ticket.visitDate;
      if (!["valid", "used"].includes(ticket.status) || !validDay(ticket.visitDate) || !validDay(validUntil) || ticket.visitDate > date || validUntil < date) fail("failed-precondition", "ticket-ineligible", "A valid admission ticket for this visit date is required.");
      if (ticket.guestEmail && (typeof ticket.guestEmail !== "string" || ticket.guestEmail.toLowerCase() !== String(request.auth.token?.email ?? "").toLowerCase())) fail("permission-denied", "ticket-guest", "This admission ticket is assigned to another visitor.");
      if (!profile) fail("failed-precondition", "profile-required", "Complete your visitor profile before reserving.");
      if (!Number.isInteger(ride.minHeightCm) || ride.minHeightCm < 0) fail("failed-precondition", "ride-unavailable", "The attraction safety details need an administrator review.");
      if (ride.minHeightCm > 0 && (!Number.isInteger(profile.heightCm) || profile.heightCm < ride.minHeightCm)) fail("failed-precondition", "height-ineligible", `A minimum height of ${ride.minHeightCm} cm is required. Check your profile height.`);
      const owned = await tx.get(db.collection("reservations").where("ownerUid", "==", uid));
      const activeBookings = owned.docs.filter((doc) => ["confirmed", "checked_in"].includes(doc.data().status));
      const legacy = activeBookings.filter((doc) => !instant(doc.data().startsAt) || !instant(doc.data().endsAt));
      const legacySlots = legacy.length ? await tx.getAll(...[...new Set(legacy.map((doc) => id(doc.data().slotId, "slotId")))].map((key) => db.collection("attractionSlots").doc(key))) : [];
      const byId = new Map(legacySlots.map((doc) => [doc.id, doc.data()]));
      for (const doc of activeBookings) {
        const reservation = doc.data(), old = instant(reservation.startsAt) ? reservation : byId.get(reservation.slotId);
        const oldStart = instant(old?.startsAt), oldEnd = instant(old?.endsAt);
        if (!oldStart || !oldEnd) fail("failed-precondition", "invalid-history", "Your reservation history needs an administrator review.");
        if (dayKey(oldStart) !== date) continue;
        const active = ["confirmed", "checked_in"].includes(reservation.status);
        if (reservation.attractionId === attractionId && active) fail("already-exists", "attraction-already-booked", "You already have a reservation for this attraction on this visit date.");
        if (active && start < oldEnd && oldStart < end) fail("already-exists", "time-overlap", "This time overlaps another attraction reservation.");
      }
      const sessions = await tx.get(db.collection("attractionSlots").where("attractionId", "==", attractionId));
      if (materialize && sessions.docs.some(doc => {
        const existing = doc.data();
        const existingStart = instant(existing.startsAt), existingEnd = instant(existing.endsAt);
        return doc.id !== slotId && (!existing.retired || existing.bookedCount > 0) &&
          existingStart && existingEnd && existingStart < end && start < existingEnd;
      })) {
        fail("failed-precondition", "slot-unavailable", "This return time has changed. Refresh and choose an available time.");
      }
      if (!offered(slot, queueSize(sessions.docs, date, now))) fail("failed-precondition", "queue-changed", "The queue changed. Refresh and choose an available time.");
      const counts = counters(slot);
      if (counts.bookedCount >= counts.capacity) fail("resource-exhausted", "slot-full", "This session has just filled up. Choose another time.");
      tx.create(db.collection("reservations").doc(result.reservationId), {ownerUid: uid, ticketId, attractionId, slotId, status: "confirmed", visitDate: date, startsAt: slot.startsAt, endsAt: slot.endsAt, attractionName: ride.name, createdAt: FieldValue.serverTimestamp(), requestId});
      const updatedCounts = {bookedCount: counts.bookedCount + 1, confirmedCount: counts.confirmedCount + 1};
      if (materialize) {
        tx.set(slotRef, {...slot, ...updatedCounts});
      } else {
        tx.update(slotRef, updatedCounts);
      }
      tx.create(dedupe, {ownerUid: uid, fingerprint, result, createdAt: FieldValue.serverTimestamp()});
      guard(tx, userGuard, userLock); guard(tx, queueGuard, queueLock);
      return result;
    });
  }
  async function cancelReservation(request) {
    const {reservationId, requestId} = input(request, ["reservationId", "requestId"]), uid = request.auth.uid;
    await access(request);
    const dedupe = requestRef(uid, "cancel", requestId), fingerprint = JSON.stringify({reservationId});
    const completed = await replay({get: (ref) => ref.get()}, dedupe, fingerprint);
    if (completed) return completed;
    const ref = db.collection("reservations").doc(reservationId), initial = await ref.get();
    if (!initial.exists) fail("not-found", "reservation-not-found", "This reservation no longer exists.");
    if (initial.data().ownerUid !== uid) fail("permission-denied", "reservation-owner", "This reservation belongs to another visitor.");
    const attractionId = id(initial.data().attractionId, "attractionId");
    const userGuard = db.collection("reservationGuards").doc(uid), queueGuard = db.collection("attractionQueueGuards").doc(attractionId);
    return db.runTransaction(async (tx) => {
      await access(request,tx);
      const prior = await replay(tx, dedupe, fingerprint); if (prior) return prior;
      const userLock = await tx.get(userGuard), queueLock = await tx.get(queueGuard), saved = await tx.get(ref);
      if (!saved.exists || saved.data().ownerUid !== uid) fail("permission-denied", "reservation-owner", "This reservation is not available to your account.");
      const reservation = saved.data(), result = {reservationId, status: "cancelled"};
      if (reservation.status !== "cancelled") {
        if (reservation.status !== "confirmed") fail("failed-precondition", "already-checked-in", "A checked-in reservation cannot be cancelled.");
        if(instant(reservation.endsAt)&&instant(reservation.endsAt)<=clock())fail('failed-precondition','return-window-ended','This return window has ended. Open your visit history to view its details.');
        const slotRef = db.collection("attractionSlots").doc(id(reservation.slotId, "slotId")), session = await tx.get(slotRef);
        if (!session.exists) fail("failed-precondition", "invalid-queue", "The session needs an administrator review.");
        const counts = counters(session.data());
        if (counts.bookedCount < 1 || counts.confirmedCount < 1) fail("failed-precondition", "invalid-queue", "The session counts need an administrator review.");
        tx.update(ref, {status: "cancelled", cancelledAt: FieldValue.serverTimestamp()});
        tx.update(slotRef, {bookedCount: counts.bookedCount - 1, confirmedCount: counts.confirmedCount - 1});
      }
      tx.create(dedupe, {ownerUid: uid, fingerprint, result, createdAt: FieldValue.serverTimestamp()});
      guard(tx, userGuard, userLock); guard(tx, queueGuard, queueLock);
      return result;
    });
  }
  return {reserveSlot, cancelReservation};
}

function reservationExports(admin) {
  const handlers = createReservationHandlers({db: admin.firestore(), FieldValue});
  const options = {region: "us-central1", memory: "256MiB", maxInstances: 5, timeoutSeconds: 60, enforceAppCheck: false};
  return {reserveSlot: onCall(options, handlers.reserveSlot), cancelReservation: onCall(options, handlers.cancelReservation)};
}
module.exports = {createReservationHandlers, reservationExports, dayKey, offered,
  bookingPolicy:{automaticWindow,validWindow,counters,queueSize,nonRideCategory,validDay}};
