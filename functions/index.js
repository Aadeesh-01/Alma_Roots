const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onDocumentCreated, onDocumentUpdated, onDocumentWritten } = require("firebase-functions/v2/firestore");
const { logger } = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

// Throws unless the caller is an active admin of the given institute. This mirrors
// isAdmin() in firestore.rules, so functions and rules agree on who is an admin.
async function assertInstituteAdmin(auth, instituteId) {
  if (!auth) throw new HttpsError("unauthenticated", "You must be logged in.");
  if (!instituteId || typeof instituteId !== "string") {
    throw new HttpsError("invalid-argument", "instituteId is required.");
  }
  const snap = await admin.firestore()
    .collection("institutes").doc(instituteId)
    .collection("participants").doc(auth.uid)
    .get();
  const p = snap.exists ? snap.data() : null;
  if (!p || p.role !== "admin" || p.isDeleted === true || (p.status && p.status !== "active")) {
    throw new HttpsError("permission-denied", "Only admins of this institute can do this.");
  }
}

// Mirrors SearchService.generateSearchKeywords in the app: every prefix of the whole
// lower-cased text plus every prefix of each word ("John Doe" -> j, jo, ..., d, do, doe).
function searchKeywordsFor(text) {
  const lower = String(text || "").toLowerCase().trim();
  if (!lower) return [];
  const out = new Set();
  for (let i = 1; i <= lower.length; i++) out.add(lower.slice(0, i));
  for (const word of lower.split(/\s+/)) {
    for (let i = 1; i <= word.length; i++) out.add(word.slice(0, i));
  }
  return [...out];
}

// Hands out sequential customIds (s1, s2 ... / a1 ... / ad1 ...) from a per-institute
// counter in a transaction, so concurrent creations never collide. The first time a
// prefix is used, the counter starts after the highest existing ID with that prefix.
async function nextCustomId(instituteId, role) {
  const prefix = role === "alumni" ? "a" : role === "admin" ? "ad" : "s";
  const db = admin.firestore();
  const instituteRef = db.collection("institutes").doc(instituteId);
  const counterRef = instituteRef.collection("meta").doc("counters");

  return db.runTransaction(async (tx) => {
    const snap = await tx.get(counterRef);
    let last = snap.exists ? snap.get(prefix) : undefined;
    if (typeof last !== "number") {
      const existing = await tx.get(instituteRef.collection("participants").select("customId"));
      const pattern = new RegExp(`^${prefix}(\\d+)$`);
      last = 0;
      existing.forEach((d) => {
        const m = pattern.exec(d.get("customId") || "");
        if (m) last = Math.max(last, parseInt(m[1], 10));
      });
    }
    const next = last + 1;
    tx.set(counterRef, { [prefix]: next }, { merge: true });
    return `${prefix}${next}`;
  });
}

// ========================== CREATE PARTICIPANT ACCOUNT ==========================
exports.createParticipantAccount = onCall(
  { region: "asia-south1" },
  async (request) => {
    try {
      const { data, auth } = request;

      let { email, password, name, role, instituteId, year } = data || {};
      await assertInstituteAdmin(auth, instituteId);
      if (!email || !password || !role) {
        throw new HttpsError("invalid-argument", "Email, password, role, and instituteId are required.");
      }
      if (!["student", "alumni", "admin"].includes(role)) {
        throw new HttpsError("invalid-argument", "Role must be student, alumni or admin.");
      }

      // 1. Normalize and Validate Email
      email = email.trim().toLowerCase();
      const emailRegex = /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/;
      if (!emailRegex.test(email)) {
        throw new HttpsError("invalid-argument", "Please enter a valid email address.");
      }

      // 2. Duplicate Email Protection
      try {
        await admin.auth().getUserByEmail(email);
        throw new HttpsError("already-exists", "This email is already registered."); // Stop here if user exists
      } catch (err) {
        if (err.code !== "auth/user-not-found" && err.code !== "functions/already-exists") throw err; // Re-throw real errors
        if (err.code === "functions/already-exists") throw err;
      }

      const participantSnap = await admin.firestore().collectionGroup("participants").where("email", "==", email).limit(1).get();
      if (!participantSnap.empty) {
        throw new HttpsError("already-exists", "This email is already registered.");
      }

      let uid = null;
      try {
        // 3. Create Firebase Auth User
        const userRecord = await admin.auth().createUser({
          email,
          password,
          displayName: name || email,
        });
        uid = userRecord.uid;

        const db = admin.firestore();
        const instituteRef = db.collection("institutes").doc(instituteId);
        const participantsRef = instituteRef.collection("participants");

        const nextId = await nextCustomId(instituteId, role);

        // Same prefix keywords the app builds, so new users are searchable immediately.
        const searchKeywords = Array.from(new Set(
          [name || "", email, role, year || ""].flatMap(searchKeywordsFor)
        ));

        // Set the admin claim before writing documents: if anything below fails,
        // the catch block deletes the Auth user and no partial account remains.
        if (role === "admin") {
          await admin.auth().setCustomUserClaims(uid, { role: "admin" });
        }

        const participantData = {
          uid,
          email,
          instituteId,
          name: name || "",
          role,
          year: year || "",
          customId: nextId,
          searchKeywords, // ✅ Added search keywords
          isProfileComplete: false,
          status: "active", // ✅ Future-proofing safe access
          isDeleted: false, // ✅ Future-proofing safe access
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        };

        // Participant, legacy profile and audit entry are written atomically.
        const batch = db.batch();
        batch.set(participantsRef.doc(uid), participantData);
        batch.set(instituteRef.collection("profiles").doc(uid), {
          uid,
          email,
          instituteId,
          name: name || "",
          role,
          isProfileComplete: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        batch.set(instituteRef.collection("admin_actions").doc(), {
          action: "USER_CREATED",
          targetUid: uid,
          targetEmail: email,
          adminUid: auth.uid,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
        });
        await batch.commit();

        return {
          success: true,
          uid,
          message: `✅ ${role} created successfully in ${instituteId}`,
        };
      } catch (error) {
        // 4. Rollback Strategy
        if (uid && error.code !== "functions/already-exists" && error.code !== "functions/invalid-argument") {
          try {
            await admin.auth().deleteUser(uid);
            logger.info(`Rollback executed: Deleted orphaned auth user ${uid}`);
          } catch (deleteErr) {
            logger.error(`Rollback failed for ${uid}:`, deleteErr);
          }
        }
        
        logger.error(`Firebase Auth Error Code: ${error.code}, Message: ${error.message}`);
        
        // Map generic errors to user-friendly messages
        if (error.code === "auth/email-already-exists") throw new HttpsError("already-exists", "This email is already registered.");
        if (error.code === "auth/weak-password") throw new HttpsError("invalid-argument", "Password must meet minimum requirements.");
        if (error.code === "auth/invalid-email") throw new HttpsError("invalid-argument", "Please enter a valid email address.");
        
        // Re-throw if it's already an HttpsError
        if (error instanceof HttpsError || (error.code && error.code.startsWith('functions/'))) throw error;

        throw new HttpsError("internal", error.message || "Unable to create account. Please try again.");
      }
    } catch (error) {
      logger.error(`Outer catch - Error Code: ${error.code}, Message: ${error.message}`);
      // Ensure we only throw user-friendly messages from this function
      if (error instanceof HttpsError || (error.code && error.code.startsWith('functions/'))) throw error;
      throw new HttpsError("internal", error.message || "Unable to create account. Please try again.");
    }
  }
);

// ========================== ADD ADMIN ROLE TO EXISTING USER ==========================
// Only an existing admin of the institute may promote someone in that same institute.
exports.addAdminRole = onCall(
  { region: "asia-south1" },
  async (request) => {
    const { email, instituteId } = request.data || {};
    await assertInstituteAdmin(request.auth, instituteId);
    if (!email) throw new HttpsError("invalid-argument", "Email is required.");

    let user;
    try {
      user = await admin.auth().getUserByEmail(String(email).trim().toLowerCase());
    } catch (err) {
      throw new HttpsError("not-found", "No account exists with that email.");
    }

    try {
      await admin.auth().setCustomUserClaims(user.uid, { role: "admin" });

      const participantsRef = admin
        .firestore()
        .collection("institutes")
        .doc(instituteId)
        .collection("participants");

      await participantsRef.doc(user.uid).set(
        {
          email: user.email,
          role: "admin",
          instituteId, // ✅ **FIX: Added instituteId here too**
          name: user.displayName || "Admin",
          isProfileComplete: true,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

      await admin.firestore().collection("institutes").doc(instituteId).collection("admin_actions").doc().set({
        action: "USER_PROMOTED_TO_ADMIN",
        targetUid: user.uid,
        targetEmail: user.email,
        adminUid: request.auth.uid,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });

      return { message: `${user.email} promoted to Admin in ${instituteId}` };
    } catch (error) {
      logger.error("addAdminRole failed:", error);
      throw new HttpsError("internal", "Could not grant admin role.");
    }
  }
);

// mode: "manual-target" (Process Now on one user), "manual-queue" (Process Queue),
// or "auto" (scheduled job).
async function processDeletion(doc, db, now, mode = "manual-queue") {
  const data = doc.data();
  const { email, requestedBy } = data;
  // Older entries may lack these fields; fall back to the document's own path.
  const uid = data.uid || doc.ref.id;
  const instituteId = data.instituteId || doc.ref.parent.parent.id;

  const batch = db.batch();

  try {
    const instituteRef = db.collection("institutes").doc(instituteId);
    const participantRef = instituteRef.collection("participants").doc(uid);

    let pData = null;
    const participantSnap = await participantRef.get();

    // Restoring or reactivating a user does not cancel their queue entry, so the
    // scheduled job must never delete someone who is active again.
    if (mode === "auto" && participantSnap.exists) {
      const p = participantSnap.data();
      if (p.isDeleted !== true && p.status !== "deleted") {
        await doc.ref.update({
          status: "cancelled",
          cancelledAt: now,
          cancelledBy: "system",
          notes: "Skipped by scheduled job: user is active again",
        });
        logger.info(`Skipped permanent deletion for active user ${uid}`);
        return "skipped";
      }
    }

    // 1. Delete Firebase Auth Account
    try {
      await admin.auth().deleteUser(uid);
      logger.info(`Deleted Auth user: ${uid}`);
    } catch (err) {
      if (err.code !== "auth/user-not-found") {
        throw err;
      }
    }

    if (participantSnap.exists) {
      pData = participantSnap.data();
      // 2. Archive User Metadata
      batch.set(instituteRef.collection("archived_users").doc(uid), pData);
    }

    // 3. Tombstone Participant Document
    batch.set(participantRef, {
      uid,
      status: "permanently_deleted",
      isDeleted: true, // so client-side "deleted user" filters hide tombstones
      name: "Deleted User",
      deletedAt: pData?.deletedAt || now,
      permanentDeletionAt: now,
    });

    // 4. Delete profile (if exists in legacy collection)
    batch.delete(instituteRef.collection("profiles").doc(uid));

    // 5. Reject pending reactivation requests
    const reqRef = instituteRef.collection("reactivation_requests").doc(uid);
    const reqSnap = await reqRef.get();
    if (reqSnap.exists && reqSnap.data().status === "pending") {
       batch.update(reqRef, { 
         status: "rejected", 
         reviewedAt: now, 
         notes: "Auto-rejected due to permanent deletion" 
       });
    }

    // 6. Update Deletion Queue
    batch.update(doc.ref, {
      status: "completed",
      completedAt: now
    });

    // 7. Audit Log
    const actions = {
      "manual-target": "MANUAL_USER_DELETION",
      "manual-queue": "MANUAL_QUEUE_PROCESSING",
      "auto": "AUTO_QUEUE_PROCESSING",
    };
    batch.set(instituteRef.collection("admin_actions").doc(), {
      action: actions[mode] || "MANUAL_QUEUE_PROCESSING",
      targetUid: uid,
      targetEmail: email || null,
      adminUid: mode === "auto" ? "system" : (requestedBy || "system"),
      scheduledBy: data.requestedBy || null,
      timestamp: now,
    });

    await batch.commit();
    return true;
  } catch (error) {
    logger.error(`Error processing permanent deletion for ${uid}:`, error);
    return false;
  }
}

// ========================== CALLABLE: PROCESS DELETION QUEUE NOW ==========================
exports.processDeletionQueueNow = onCall(
  { region: "asia-south1" },
  async (request) => {
    try {
      const { data, auth } = request;
      const { instituteId, targetUid } = data || {};
      await assertInstituteAdmin(auth, instituteId);

      const db = admin.firestore();

      const now = admin.firestore.Timestamp.now();
      let query = db.collection("institutes").doc(instituteId).collection("deletion_queue")
        .where("status", "==", "pending");

      if (targetUid) {
        // Case 1: Process specific user immediately
        query = query.where("uid", "==", targetUid);
      } else {
        // Case 2: Process entire eligible queue
        query = query.where("scheduledFor", "<=", now);
      }

      const snapshot = await query.get();

      if (snapshot.empty) {
        return { processed: 0, failed: 0, deletedUsers: [] };
      }

      let processed = 0;
      let failed = 0;
      const deletedUsers = [];

      for (const doc of snapshot.docs) {
        // Update requestedBy so the audit log shows the admin who actually triggered it
        const currentData = doc.data();
        currentData.requestedBy = auth.uid;

        // Mock doc object to pass to the helper
        const docWrapper = {
          data: () => currentData,
          ref: doc.ref
        };

        const success = await processDeletion(docWrapper, db, now, targetUid ? "manual-target" : "manual-queue");
        if (success === true) {
          processed++;
          deletedUsers.push(currentData.email || currentData.uid);
        } else {
          failed++;
        }
      }

      return { processed, failed, deletedUsers };
    } catch (error) {
      logger.error("Error in processDeletionQueueNow:", error);
      if (error instanceof HttpsError) throw error;
      throw new HttpsError("internal", error.message);
    }
  }
);

// ========================== SCHEDULED: AUTO-PROCESS DUE DELETIONS ==========================
// Runs every 5 minutes and permanently deletes users whose 24h grace period has passed.
exports.processPermanentDeletionQueue = onSchedule(
  { schedule: "every 5 minutes", region: "asia-south1", timeZone: "Asia/Kolkata" },
  async () => {
    const db = admin.firestore();
    const now = admin.firestore.Timestamp.now();

    const snapshot = await db.collectionGroup("deletion_queue")
      .where("status", "==", "pending")
      .where("scheduledFor", "<=", now)
      .get();

    if (snapshot.empty) {
      logger.info("No pending deletions to process.");
      return;
    }

    let processed = 0;
    let skipped = 0;
    let failed = 0;
    for (const doc of snapshot.docs) {
      const result = await processDeletion(doc, db, now, "auto");
      if (result === true) processed++;
      else if (result === "skipped") skipped++;
      else failed++;
    }

    logger.info(`Scheduled deletion run: ${processed} deleted, ${skipped} skipped (user active), ${failed} failed.`);
  }
);
// ========================== PUSH NOTIFICATIONS ==========================
// Devices register FCM tokens in participants/{uid}.fcmTokens. Each participant can
// opt out per category via notificationPrefs.{messages|posts|account} = false.

const TRIGGER_REGION = "asia-south1"; // must match the Firestore database location

function participantsRef(instituteId) {
  return admin.firestore().collection("institutes").doc(instituteId).collection("participants");
}

function isActiveParticipant(p) {
  return p && p.isDeleted !== true && (!p.status || p.status === "active");
}

function wantsCategory(p, category) {
  return !p.notificationPrefs || p.notificationPrefs[category] !== false;
}

// Sends one notification to every token of the given participant docs, then removes
// tokens FCM reports as dead so they don't pile up.
async function sendToParticipants(instituteId, participantDocs, notification, data) {
  const tokenOwner = new Map();
  for (const doc of participantDocs) {
    for (const t of (doc.data().fcmTokens || [])) tokenOwner.set(t, doc.id);
  }
  const tokens = [...tokenOwner.keys()];
  if (tokens.length === 0) return 0;

  const stringData = Object.fromEntries(
    Object.entries({ ...data, instituteId }).map(([k, v]) => [k, String(v ?? "")])
  );

  const dead = new Map(); // uid -> [tokens]
  let sent = 0;
  for (let i = 0; i < tokens.length; i += 500) {
    const batch = tokens.slice(i, i + 500);
    const res = await admin.messaging().sendEachForMulticast({
      tokens: batch,
      notification,
      data: stringData,
      android: { priority: "high", notification: { channelId: "alma_roots_default" } },
    });
    res.responses.forEach((r, idx) => {
      if (r.success) { sent++; return; }
      const code = r.error && r.error.code;
      if (code === "messaging/registration-token-not-registered" || code === "messaging/invalid-registration-token") {
        const owner = tokenOwner.get(batch[idx]);
        dead.set(owner, [...(dead.get(owner) || []), batch[idx]]);
      }
    });
  }

  await Promise.all([...dead.entries()].map(([uid, list]) =>
    participantsRef(instituteId).doc(uid).update({
      fcmTokens: admin.firestore.FieldValue.arrayRemove(...list),
    }).catch(() => {})
  ));
  return sent;
}

const truncate = (s, n) => (s && s.length > n ? `${s.slice(0, n - 1)}…` : (s || ""));

function displayName(p, fallback = "Someone") {
  const name = ((p && p.name) || "").trim();
  if (name) return name;
  const email = (p && p.email) || "";
  return email ? email.split("@")[0] : fallback;
}

// New chat message -> notify the other participant (unless they muted the chat).
exports.notifyNewMessage = onDocumentCreated(
  { document: "institutes/{instId}/chats/{chatId}/messages/{msgId}", region: TRIGGER_REGION },
  async (event) => {
    const { instId, chatId } = event.params;
    const msg = event.data && event.data.data();
    if (!msg || !msg.senderId) return;

    const chatSnap = await admin.firestore()
      .collection("institutes").doc(instId).collection("chats").doc(chatId).get();
    const chat = chatSnap.data() || {};
    const recipients = (chat.participants || []).filter((u) => u !== msg.senderId);
    if (recipients.length === 0) return;

    const [senderSnap, ...recipientSnaps] = await Promise.all([
      participantsRef(instId).doc(msg.senderId).get(),
      ...recipients.map((u) => participantsRef(instId).doc(u).get()),
    ]);
    const senderName = displayName(senderSnap.data());

    const targets = recipientSnaps.filter((s) =>
      s.exists && isActiveParticipant(s.data()) && wantsCategory(s.data(), "messages") &&
      !(chat.mutedBy && chat.mutedBy[s.id] === true)
    );

    const sent = await sendToParticipants(instId, targets,
      { title: senderName, body: truncate(msg.text, 140) },
      { type: "chat", otherUserId: msg.senderId, otherUserName: senderName });
    logger.info(`notifyNewMessage: ${sent} notification(s) for chat ${chatId}`);
  }
);

// New news or event post -> notify members who can see it.
exports.notifyNewPost = onDocumentCreated(
  { document: "institutes/{instId}/posts/{postId}", region: TRIGGER_REGION },
  async (event) => {
    const { instId, postId } = event.params;
    const post = event.data && event.data.data();
    if (!post || !["news", "event"].includes(post.type)) return;

    const visibleTo = {
      public: () => true,
      alumni_only: (r) => r === "alumni" || r === "admin",
      students_only: (r) => r === "student" || r === "admin",
      admins_only: (r) => r === "admin",
    }[post.visibility || "public"] || (() => true);

    const members = await participantsRef(instId).get();
    const targets = members.docs.filter((d) => {
      const p = d.data();
      return d.id !== post.authorUid && isActiveParticipant(p) &&
        wantsCategory(p, "posts") && visibleTo(p.role || "student");
    });

    const title = post.type === "event" ? `New event: ${post.title}` : (post.title || "New announcement");
    const sent = await sendToParticipants(instId, targets,
      { title: truncate(title, 80), body: truncate(post.description, 140) },
      { type: "post", postId });
    logger.info(`notifyNewPost: ${sent} notification(s) for post ${postId}`);
  }
);

// Someone cancels their RSVP -> give the freed spot to the earliest waitlisted person.
exports.promoteWaitlist = onDocumentUpdated(
  { document: "institutes/{instId}/posts/{postId}/attendees/{uid}", region: TRIGGER_REGION },
  async (event) => {
    const before = event.data.before.data() || {};
    const after = event.data.after.data() || {};
    if (!(before.status === "attending" && after.status === "declined")) return;

    const { instId, postId } = event.params;
    const db = admin.firestore();
    const postRef = db.collection("institutes").doc(instId).collection("posts").doc(postId);

    const promotedUid = await db.runTransaction(async (tx) => {
      const postSnap = await tx.get(postRef);
      if (!postSnap.exists) return null;
      const post = postSnap.data();
      const count = post.attendeeCount || 0;
      if (post.maxAttendees != null && count >= post.maxAttendees) return null;

      const waiting = await tx.get(postRef.collection("attendees")
        .where("status", "==", "waitlisted").orderBy("rsvpAt", "asc").limit(1));
      if (waiting.empty) return null;

      const next = waiting.docs[0];
      tx.update(next.ref, {
        status: "attending",
        promotedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      tx.update(postRef, { attendeeCount: admin.firestore.FieldValue.increment(1) });
      return next.id;
    });

    if (!promotedUid) return;
    logger.info(`promoteWaitlist: promoted ${promotedUid} for post ${postId}`);

    const [pSnap, postSnap] = await Promise.all([
      participantsRef(instId).doc(promotedUid).get(),
      postRef.get(),
    ]);
    if (pSnap.exists && isActiveParticipant(pSnap.data()) && wantsCategory(pSnap.data(), "posts")) {
      const eventTitle = truncate((postSnap.data() || {}).title, 80);
      await sendToParticipants(instId, [pSnap],
        { title: "You got a spot! 🎉", body: `A place opened up for ${eventTitle}.` },
        { type: "post", postId });
    }
  }
);

// Admin approves or rejects a reactivation request -> tell the requester.
exports.notifyReactivationDecision = onDocumentUpdated(
  { document: "institutes/{instId}/reactivation_requests/{reqId}", region: TRIGGER_REGION },
  async (event) => {
    const before = event.data.before.data() || {};
    const after = event.data.after.data() || {};
    if (before.status !== "pending" || !["approved", "rejected"].includes(after.status)) return;
    // Auto-rejections from permanent deletion have no one left to notify.
    if (after.notes && String(after.notes).startsWith("Auto-rejected")) return;

    const { instId, reqId } = event.params;
    const uid = after.userUid || reqId;
    const snap = await participantsRef(instId).doc(uid).get();
    if (!snap.exists || !wantsCategory(snap.data(), "account")) return;

    const approved = after.status === "approved";
    await sendToParticipants(instId, [snap],
      approved
        ? { title: "Welcome back to Alma Roots", body: "Your account has been reactivated. You can sign in again." }
        : { title: "Reactivation request update", body: "Your request was reviewed and not approved. Contact your institute admin for details." },
      { type: "account" });
  }
);

// ========================== DELETION SCHEDULE USES SERVER TIME ==========================
// The app computes scheduledFor from the device clock, which can be wrong. Whenever an
// entry becomes pending (new, or re-scheduled after a cancel), reset the deadline to
// server time + 24h on both the queue entry and the participant.
const GRACE_PERIOD_MS = 24 * 60 * 60 * 1000;

exports.normalizeDeletionSchedule = onDocumentWritten(
  { document: "institutes/{instId}/deletion_queue/{entryId}", region: TRIGGER_REGION },
  async (event) => {
    const before = event.data.before.exists ? event.data.before.data() : null;
    const after = event.data.after.exists ? event.data.after.data() : null;
    if (!after || after.status !== "pending") return;
    if (before && before.status === "pending") return; // already normalized; avoids loops

    const writtenAt = event.data.after.updateTime || admin.firestore.Timestamp.now();
    const scheduledFor = admin.firestore.Timestamp.fromMillis(writtenAt.toMillis() + GRACE_PERIOD_MS);

    const { instId, entryId } = event.params;
    const uid = after.uid || entryId;
    const batch = admin.firestore().batch();
    batch.update(event.data.after.ref, { scheduledFor, requestedAt: writtenAt });
    const participantRef = participantsRef(instId).doc(uid);
    const participantSnap = await participantRef.get();
    if (participantSnap.exists) {
      batch.update(participantRef, {
        permanentDeletionScheduledFor: scheduledFor,
        permanentDeletionRequestedAt: writtenAt,
      });
    }
    await batch.commit();
    logger.info(`normalizeDeletionSchedule: ${uid} scheduled for ${scheduledFor.toDate().toISOString()}`);
  }
);
