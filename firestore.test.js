const { initializeTestEnvironment, assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const fs = require('fs');

let testEnv;

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: "project-cs261-test",
    firestore: { rules: fs.readFileSync("firestore.rules", "utf8") },
  });
});

after(async () => {
  await testEnv.cleanup();
});

beforeEach(async () => {
  await testEnv.clearFirestore();
  // Setup mock data via admin context
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    // Institute
    await db.collection('institutes').doc('test_inst').set({ name: 'Test Inst' });
    
    // Admin
    await db.collection('institutes').doc('test_inst').collection('participants').doc('admin_uid').set({
      role: 'admin',
      status: 'active',
      instituteId: 'test_inst'
    });
    
    // Student
    await db.collection('institutes').doc('test_inst').collection('participants').doc('student_uid').set({
      role: 'student',
      status: 'active',
      instituteId: 'test_inst'
    });
    
    // Alumni
    await db.collection('institutes').doc('test_inst').collection('participants').doc('alumni_uid').set({
      role: 'alumni',
      status: 'active',
      instituteId: 'test_inst'
    });
  });
});

describe("Firestore Security Rules", () => {
  it("Student Login (can read their own profile)", async () => {
    const db = testEnv.authenticatedContext('student_uid').firestore();
    await assertSucceeds(db.collection('institutes').doc('test_inst').collection('participants').doc('student_uid').get());
  });

  it("Student Search (can read other active profiles)", async () => {
    const db = testEnv.authenticatedContext('student_uid').firestore();
    await assertSucceeds(db.collection('institutes').doc('test_inst').collection('participants').doc('alumni_uid').get());
  });

  it("Student Messaging (can read own chat)", async () => {
    const db = testEnv.authenticatedContext('student_uid').firestore();
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().collection('institutes').doc('test_inst').collection('chats').doc('chat1').set({
        participants: ['student_uid', 'alumni_uid']
      });
    });
    await assertSucceeds(db.collection('institutes').doc('test_inst').collection('chats').doc('chat1').get());
  });

  it("Student Messaging (cannot read others' chat)", async () => {
    const db = testEnv.authenticatedContext('student_uid').firestore();
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().collection('institutes').doc('test_inst').collection('chats').doc('chat2').set({
        participants: ['admin_uid', 'alumni_uid']
      });
    });
    await assertFails(db.collection('institutes').doc('test_inst').collection('chats').doc('chat2').get());
  });

  it("Student Profile edit (cannot change role)", async () => {
    const db = testEnv.authenticatedContext('student_uid').firestore();
    await assertFails(db.collection('institutes').doc('test_inst').collection('participants').doc('student_uid').update({
      role: 'admin'
    }));
  });

  it("Student Cannot access admin screens (admin_actions)", async () => {
    const db = testEnv.authenticatedContext('student_uid').firestore();
    await assertFails(db.collection('institutes').doc('test_inst').collection('admin_actions').get());
  });

  it("Alumni Create experience", async () => {
    const db = testEnv.authenticatedContext('alumni_uid').firestore();
    await assertSucceeds(db.collection('institutes').doc('test_inst').collection('posts').doc('post1').set({
      authorUid: 'alumni_uid',
      type: 'experience'
    }));
  });

  it("Alumni Cannot create news", async () => {
    const db = testEnv.authenticatedContext('alumni_uid').firestore();
    await assertFails(db.collection('institutes').doc('test_inst').collection('posts').doc('post2').set({
      authorUid: 'alumni_uid',
      type: 'news'
    }));
  });

  it("Alumni Cannot create event", async () => {
    const db = testEnv.authenticatedContext('alumni_uid').firestore();
    await assertFails(db.collection('institutes').doc('test_inst').collection('posts').doc('post3').set({
      authorUid: 'alumni_uid',
      type: 'event'
    }));
  });

  it("Admin Soft delete", async () => {
    const db = testEnv.authenticatedContext('admin_uid').firestore();
    await assertSucceeds(db.collection('institutes').doc('test_inst').collection('participants').doc('student_uid').update({
      isDeleted: true,
      status: 'deleted'
    }));
  });

  it("Admin Reactivation", async () => {
    const db = testEnv.authenticatedContext('admin_uid').firestore();
    await assertSucceeds(db.collection('institutes').doc('test_inst').collection('reactivation_requests').doc('student_uid').delete());
  });

  it("Admin News creation", async () => {
    const db = testEnv.authenticatedContext('admin_uid').firestore();
    await assertSucceeds(db.collection('institutes').doc('test_inst').collection('posts').doc('post4').set({
      authorUid: 'admin_uid',
      type: 'news'
    }));
  });

  it("Admin Event creation", async () => {
    const db = testEnv.authenticatedContext('admin_uid').firestore();
    await assertSucceeds(db.collection('institutes').doc('test_inst').collection('posts').doc('post5').set({
      authorUid: 'admin_uid',
      type: 'event'
    }));
  });

  it("Admin Deletion queue", async () => {
    const db = testEnv.authenticatedContext('admin_uid').firestore();
    await assertSucceeds(db.collection('institutes').doc('test_inst').collection('deletion_queue').doc('student_uid').set({
      reason: 'test'
    }));
  });
});
