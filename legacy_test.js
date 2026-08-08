const { initializeTestEnvironment, assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const fs = require('fs');

async function runTests() {
  const testEnv = await initializeTestEnvironment({
    projectId: "demo-legacy-test",
    firestore: { host: "127.0.0.1", port: 8080 },
  });

  await testEnv.clearFirestore();

  // Create an admin context to set up the DB
  const adminDb = testEnv.unauthenticatedContext().firestore();
  
  // Set up an institute
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await db.collection('institutes').doc('inst1').set({ name: 'Test Inst' });
    
    // User 1: Missing role
    await db.collection('institutes').doc('inst1').collection('participants').doc('missing_role').set({
      name: "Legacy User 1",
      status: "active",
      instituteId: "inst1",
      isDeleted: false
    });
    
    // User 2: Missing status
    await db.collection('institutes').doc('inst1').collection('participants').doc('missing_status').set({
      name: "Legacy User 2",
      role: "student",
      instituteId: "inst1",
      isDeleted: false
    });
    
    // User 3: Missing isDeleted
    await db.collection('institutes').doc('inst1').collection('participants').doc('missing_isDeleted').set({
      name: "Legacy User 3",
      role: "student",
      status: "active",
      instituteId: "inst1"
    });
    
    // User 4: Missing instituteId
    await db.collection('institutes').doc('inst1').collection('participants').doc('missing_instituteId').set({
      name: "Legacy User 4",
      role: "student",
      status: "active",
      isDeleted: false
    });
  });

  const tests = [
    { id: 'missing_role', name: 'User with role missing' },
    { id: 'missing_status', name: 'User with status missing' },
    { id: 'missing_isDeleted', name: 'User with isDeleted missing' },
    { id: 'missing_instituteId', name: 'User with instituteId missing' },
  ];

  for (const test of tests) {
    const userDb = testEnv.authenticatedContext(test.id).firestore();
    try {
      await assertSucceeds(
        userDb.collection('institutes').doc('inst1').collection('participants').doc(test.id).set({
          name: "Updated Name"
        }, { merge: true })
      );
      console.log(`✅ ${test.name}: PASSED`);
    } catch (e) {
      console.log(`❌ ${test.name}: FAILED (Permission Denied)`);
    }
  }

  await testEnv.cleanup();
}

runTests();
