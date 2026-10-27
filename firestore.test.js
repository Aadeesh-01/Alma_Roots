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

  it("Messaging (other participant can reply, participants in reversed order)", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().collection('institutes').doc('test_inst').collection('chats').doc('alumni_uid_student_uid').set({
        participants: ['student_uid', 'alumni_uid']
      });
    });
    // Mirrors ChatService.sendDirectMessage: message + merge on the chat doc, sender first.
    const db = testEnv.authenticatedContext('alumni_uid').firestore();
    const chatRef = db.collection('institutes').doc('test_inst').collection('chats').doc('alumni_uid_student_uid');
    const batch = db.batch();
    batch.set(chatRef.collection('messages').doc(), { senderId: 'alumni_uid', text: 'reply' });
    batch.set(chatRef, { participants: ['alumni_uid', 'student_uid'], readStatus: { alumni_uid: true, student_uid: false } }, { merge: true });
    await assertSucceeds(batch.commit());
  });

  it("Messaging (original sender can keep sending)", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().collection('institutes').doc('test_inst').collection('chats').doc('alumni_uid_student_uid').set({
        participants: ['student_uid', 'alumni_uid']
      });
    });
    const db = testEnv.authenticatedContext('student_uid').firestore();
    const chatRef = db.collection('institutes').doc('test_inst').collection('chats').doc('alumni_uid_student_uid');
    const batch = db.batch();
    batch.set(chatRef.collection('messages').doc(), { senderId: 'student_uid', text: 'hello again' });
    batch.set(chatRef, { participants: ['student_uid', 'alumni_uid'] }, { merge: true });
    await assertSucceeds(batch.commit());
  });

  it("Messaging (cannot replace a participant on update)", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().collection('institutes').doc('test_inst').collection('chats').doc('alumni_uid_student_uid').set({
        participants: ['student_uid', 'alumni_uid']
      });
    });
    const db = testEnv.authenticatedContext('student_uid').firestore();
    const chatRef = db.collection('institutes').doc('test_inst').collection('chats').doc('alumni_uid_student_uid');
    await assertFails(chatRef.set({ participants: ['student_uid', 'admin_uid'] }, { merge: true }));
    await assertFails(chatRef.set({ participants: ['student_uid', 'alumni_uid', 'admin_uid'] }, { merge: true }));
  });

  describe("Message permissions", () => {
    const chatId = 'alumni_uid_student_uid';
    const msgPath = (db) => db.collection('institutes').doc('test_inst').collection('chats').doc(chatId).collection('messages');

    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const chat = ctx.firestore().collection('institutes').doc('test_inst').collection('chats').doc(chatId);
        await chat.set({ participants: ['student_uid', 'alumni_uid'] });
        await chat.collection('messages').doc('m1').set({ senderId: 'student_uid', text: 'hello', isEdited: false, reactions: {}, deletedBy: {} });
      });
    });

    it("participant can send a message as themselves", async () => {
      const db = testEnv.authenticatedContext('alumni_uid').firestore();
      await assertSucceeds(msgPath(db).doc('m2').set({ senderId: 'alumni_uid', text: 'hi' }));
    });

    it("cannot send a message pretending to be the other person", async () => {
      const db = testEnv.authenticatedContext('alumni_uid').firestore();
      await assertFails(msgPath(db).doc('m3').set({ senderId: 'student_uid', text: 'fake' }));
    });

    it("sender can edit their own message", async () => {
      const db = testEnv.authenticatedContext('student_uid').firestore();
      await assertSucceeds(msgPath(db).doc('m1').update({ text: 'hello (edited)', isEdited: true }));
    });

    it("other participant cannot edit someone else's message", async () => {
      const db = testEnv.authenticatedContext('alumni_uid').firestore();
      await assertFails(msgPath(db).doc('m1').update({ text: 'rewritten', isEdited: true }));
    });

    it("other participant can react", async () => {
      const db = testEnv.authenticatedContext('alumni_uid').firestore();
      await assertSucceeds(msgPath(db).doc('m1').set({ reactions: { '👍': ['alumni_uid'] } }, { merge: true }));
    });

    it("participant can 'delete for me' with their own flag", async () => {
      const db = testEnv.authenticatedContext('alumni_uid').firestore();
      await assertSucceeds(msgPath(db).doc('m1').set({ deletedBy: { alumni_uid: true } }, { merge: true }));
    });

    it("cannot hide a message for the other person", async () => {
      const db = testEnv.authenticatedContext('alumni_uid').firestore();
      await assertFails(msgPath(db).doc('m1').set({ deletedBy: { student_uid: true } }, { merge: true }));
    });

    it("nobody can hard-delete a message", async () => {
      const db = testEnv.authenticatedContext('student_uid').firestore();
      await assertFails(msgPath(db).doc('m1').delete());
    });

    it("non-participant cannot read messages", async () => {
      const db = testEnv.authenticatedContext('admin_uid').firestore();
      await assertFails(msgPath(db).doc('m1').get());
    });

    it("first message + new chat in one batch still works", async () => {
      const db = testEnv.authenticatedContext('admin_uid').firestore();
      const chat = db.collection('institutes').doc('test_inst').collection('chats').doc('admin_uid_student_uid');
      const batch = db.batch();
      batch.set(chat.collection('messages').doc(), { senderId: 'admin_uid', text: 'welcome' });
      batch.set(chat, { participants: ['admin_uid', 'student_uid'] }, { merge: true });
      await assertSucceeds(batch.commit());
    });
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

  // Students and alumni may post events (hackathons, workshops); only news is admin-only.
  it("Alumni Can create event", async () => {
    const db = testEnv.authenticatedContext('alumni_uid').firestore();
    await assertSucceeds(db.collection('institutes').doc('test_inst').collection('posts').doc('post3').set({
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
