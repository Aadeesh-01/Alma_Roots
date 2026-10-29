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

  describe("Batch 6: post counters, visibility, editing and profile fields", () => {
    const inst = (db) => db.collection('institutes').doc('test_inst');
    const posts = (db) => inst(db).collection('posts');

    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const p = posts(ctx.firestore());
        await p.doc('pub').set({ authorUid: 'alumni_uid', type: 'experience', visibility: 'public', title: 'Hi',
          likeCount: 0, commentCount: 0, attendeeCount: 0, isPinned: false, status: 'published' });
        await p.doc('alum').set({ authorUid: 'admin_uid', type: 'news', visibility: 'alumni_only', title: 'Alumni only',
          likeCount: 0, commentCount: 0, attendeeCount: 0, isPinned: false });
        await p.doc('ev').set({ authorUid: 'admin_uid', type: 'event', visibility: 'public', title: 'Meetup',
          likeCount: 0, commentCount: 0, attendeeCount: 0, maxAttendees: 1, isPinned: false });
      });
    });

    // S5: counters
    it("like: +1 together with your own like record is allowed", async () => {
      const db = testEnv.authenticatedContext('student_uid').firestore();
      const batch = db.batch();
      batch.set(posts(db).doc('pub').collection('likes').doc('student_uid'), { uid: 'student_uid' });
      batch.update(posts(db).doc('pub'), { likeCount: 1 });
      await assertSucceeds(batch.commit());
    });
    it("like: +1 without a like record is blocked", async () => {
      const db = testEnv.authenticatedContext('student_uid').firestore();
      await assertFails(posts(db).doc('pub').update({ likeCount: 1 }));
    });
    it("like: jumping the count to 500 is blocked", async () => {
      const db = testEnv.authenticatedContext('student_uid').firestore();
      const batch = db.batch();
      batch.set(posts(db).doc('pub').collection('likes').doc('student_uid'), { uid: 'student_uid' });
      batch.update(posts(db).doc('pub'), { likeCount: 500 });
      await assertFails(batch.commit());
    });
    it("comments: count may only move by one", async () => {
      const db = testEnv.authenticatedContext('student_uid').firestore();
      await assertSucceeds(posts(db).doc('pub').update({ commentCount: 1 }));
      await assertFails(posts(db).doc('pub').update({ commentCount: 40 }));
    });
    it("author cannot set their own like count", async () => {
      const db = testEnv.authenticatedContext('alumni_uid').firestore();
      await assertFails(posts(db).doc('pub').update({ likeCount: 99 }));
    });
    it("RSVP: taking a seat must count it, and respects capacity", async () => {
      const student = testEnv.authenticatedContext('student_uid').firestore();
      const b1 = student.batch();
      b1.set(posts(student).doc('ev').collection('attendees').doc('student_uid'), { status: 'attending' });
      b1.update(posts(student).doc('ev'), { attendeeCount: 1 });
      await assertSucceeds(b1.commit());

      const alumni = testEnv.authenticatedContext('alumni_uid').firestore();
      const b2 = alumni.batch();
      b2.set(posts(alumni).doc('ev').collection('attendees').doc('alumni_uid'), { status: 'attending' });
      b2.update(posts(alumni).doc('ev'), { attendeeCount: 2 });
      await assertFails(b2.commit()); // capacity is 1
    });
    it("RSVP: marking yourself attending without counting it is blocked", async () => {
      const db = testEnv.authenticatedContext('student_uid').firestore();
      await assertFails(posts(db).doc('ev').collection('attendees').doc('student_uid').set({ status: 'attending' }));
    });
    it("RSVP: joining the waitlist needs no count change", async () => {
      const db = testEnv.authenticatedContext('student_uid').firestore();
      await assertSucceeds(posts(db).doc('ev').collection('attendees').doc('student_uid').set({ status: 'waitlisted' }));
    });

    // S6: visibility
    it("student cannot read an alumni-only post; alumni and admin can", async () => {
      await assertFails(posts(testEnv.authenticatedContext('student_uid').firestore()).doc('alum').get());
      await assertSucceeds(posts(testEnv.authenticatedContext('alumni_uid').firestore()).doc('alum').get());
      await assertSucceeds(posts(testEnv.authenticatedContext('admin_uid').firestore()).doc('alum').get());
    });
    it("feed query must ask only for visible posts", async () => {
      const db = testEnv.authenticatedContext('student_uid').firestore();
      await assertSucceeds(posts(db).where('visibility', 'in', ['public', 'students_only']).get());
      await assertFails(posts(db).get());
      await assertFails(posts(db).where('visibility', 'in', ['public', 'alumni_only']).get());
    });

    // S7: editing
    it("author can edit content and soft-delete", async () => {
      const db = testEnv.authenticatedContext('alumni_uid').firestore();
      await assertSucceeds(posts(db).doc('pub').update({ title: 'Updated', description: 'More' }));
      await assertSucceeds(posts(db).doc('pub').update({ status: 'deleted' }));
    });
    it("author cannot turn their post into news or pin it", async () => {
      const db = testEnv.authenticatedContext('alumni_uid').firestore();
      await assertFails(posts(db).doc('pub').update({ type: 'news' }));
      await assertFails(posts(db).doc('pub').update({ isPinned: true }));
    });
    it("new posts cannot start pinned or with fake counts", async () => {
      const db = testEnv.authenticatedContext('student_uid').firestore();
      await assertFails(posts(db).doc('x1').set({ authorUid: 'student_uid', type: 'experience', isPinned: true }));
      await assertFails(posts(db).doc('x2').set({ authorUid: 'student_uid', type: 'experience', likeCount: 50 }));
    });

    // S8: profile fields
    it("user can edit their profile fields, tokens and notification settings", async () => {
      const db = testEnv.authenticatedContext('student_uid').firestore();
      const me = inst(db).collection('participants').doc('student_uid');
      await assertSucceeds(me.update({ bio: 'Hello', department: 'CS', isProfileComplete: true }));
      await assertSucceeds(me.set({ fcmTokens: ['tok1'] }, { merge: true }));
      await assertSucceeds(me.update({ 'notificationPrefs.messages': false }));
    });
    it("user cannot edit admin-managed fields", async () => {
      const db = testEnv.authenticatedContext('student_uid').firestore();
      const me = inst(db).collection('participants').doc('student_uid');
      await assertFails(me.update({ customId: 's1' }));
      await assertFails(me.update({ pendingPermanentDeletion: false }));
      await assertFails(me.update({ email: 'someone@else.com' }));
      await assertFails(me.update({ status: 'active', role: 'admin' }));
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
