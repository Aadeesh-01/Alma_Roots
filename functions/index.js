const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { logger } = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

// ========================== CREATE PARTICIPANT ACCOUNT ==========================
exports.createParticipantAccount = onCall(
  { region: "asia-south1" },
  async (request) => {
    try {
      const { data, auth } = request;
      if (!auth) throw new HttpsError("unauthenticated", "You must be logged in to create participants.");
      if (auth.token.role !== "admin") throw new HttpsError("permission-denied", "Only admins can create participants.");

      let { email, password, name, role, instituteId, year } = data;
      if (!email || !password || !role || !instituteId) {
        throw new HttpsError("invalid-argument", "Email, password, role, and instituteId are required.");
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

        const participantsRef = admin
          .firestore()
          .collection("institutes")
          .doc(instituteId)
          .collection("participants");

        // Generate custom ID based on role
        const prefix = role === "alumni" ? "a" : role === "admin" ? "ad" : "s";
        const snapshot = await participantsRef.orderBy("customId", "desc").limit(1).get();

        let nextId = `${prefix}1`;
        if (!snapshot.empty) {
          const lastId = snapshot.docs[0].data().customId;
          const lastNum = parseInt(lastId?.replace(/\D/g, "")) || 0;
          nextId = `${prefix}${lastNum + 1}`;
        }

        // Generate search keywords
        const searchKeywords = Array.from(new Set([
          ...email.split('@')[0].split(/[._+-]/),
          role,
          instituteId,
          email
        ].filter(k => k.length > 0).map(k => k.toLowerCase())));

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

        await participantsRef.doc(uid).set(participantData);

        // Create profile inside same institute
        await admin
          .firestore()
          .collection("institutes")
          .doc(instituteId)
          .collection("profiles")
          .doc(uid)
          .set({
            uid,
            email,
            instituteId,
            name: name || "",
            role,
            isProfileComplete: false,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          });

        // Audit Logging
        await admin.firestore().collection("institutes").doc(instituteId).collection("admin_actions").doc().set({
          action: "USER_CREATED",
          targetUid: uid,
          targetEmail: email,
          adminUid: auth.uid,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
        });

        // If admin role, assign admin claim
        if (role === "admin") {
          await admin.auth().setCustomUserClaims(uid, { role: "admin" });
        }

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
exports.addAdminRole = onCall(
  { region: "asia-south1" },
  async (request) => {
    const { email, instituteId } = request.data;
    if (!email || !instituteId) throw new Error("Email and instituteId are required.");

    try {
      const user = await admin.auth().getUserByEmail(email);
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

      return { message: `✅ ${email} promoted to Admin in ${instituteId}` };
    } catch (error) {
      throw new Error(`Error setting admin role: ${error.message}`);
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
      if (!auth) throw new HttpsError("unauthenticated", "You must be logged in.");

      const { instituteId, targetUid } = data;
      if (!instituteId) throw new HttpsError("invalid-argument", "instituteId is required.");

      const db = admin.firestore();

      // Ensure caller is an admin by checking Firestore
      const callerRef = db.collection("institutes").doc(instituteId).collection("participants").doc(auth.uid);
      const callerSnap = await callerRef.get();
      if (!callerSnap.exists || callerSnap.data().role !== "admin") {
        throw new HttpsError("permission-denied", "Only admins can process the deletion queue.");
      }

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