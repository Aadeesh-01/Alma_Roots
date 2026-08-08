const admin = require('firebase-admin');

// Initialize with default credentials
admin.initializeApp({
  projectId: 'project-cs261'
});

const db = admin.firestore();

async function auditLive() {
  console.log("=== USER AUDIT ===");
  const emails = ['lokesh@email.com', 'demo.student1@demo.edu'];

  for (const email of emails) {
    console.log(`\n============================`);
    console.log(`Auditing: ${email}`);
    console.log(`============================`);
    
    // Auth
    let uid = null;
    try {
      const user = await admin.auth().getUserByEmail(email);
      uid = user.uid;
      console.log(`[AUTH] FOUND. UID: ${uid}`);
    } catch (e) {
      console.log(`[AUTH] NOT FOUND. Error: ${e.code}`);
    }

    // Participants
    const participantsSnap = await db.collectionGroup('participants').where('email', '==', email).get();
    if (participantsSnap.empty) {
      console.log(`[FIRESTORE: participants] NOT FOUND.`);
    } else {
      participantsSnap.forEach(doc => {
        console.log(`[FIRESTORE: participants] Path: ${doc.ref.path}`);
        console.log(`Data:`, JSON.stringify(doc.data(), null, 2));
      });
    }

    // Profiles
    const profilesSnap = await db.collectionGroup('profiles').where('email', '==', email).get();
    if (profilesSnap.empty) {
      console.log(`[FIRESTORE: profiles] NOT FOUND.`);
    } else {
      profilesSnap.forEach(doc => {
        console.log(`[FIRESTORE: profiles] Path: ${doc.ref.path}`);
        console.log(`Data:`, JSON.stringify(doc.data(), null, 2));
      });
    }
  }
}

auditLive();
