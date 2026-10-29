const { initializeTestEnvironment, assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const fs = require('fs');

let testEnv;
const PNG = new Uint8Array([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: "project-cs261-test",
    storage: { rules: fs.readFileSync("storage.rules", "utf8") },
  });
});

after(async () => {
  await testEnv.cleanup();
});

beforeEach(async () => {
  await testEnv.clearStorage();
});

const avatar = (ctx, uid) => ctx.storage().ref(`profile_pictures/${uid}/avatar.jpg`);

describe("Storage rules: profile pictures", () => {
  it("you can upload your own picture", async () => {
    const me = testEnv.authenticatedContext('alice');
    await assertSucceeds(avatar(me, 'alice').put(PNG, { contentType: 'image/jpeg' }));
  });

  it("you cannot overwrite someone else's picture", async () => {
    const me = testEnv.authenticatedContext('alice');
    await assertFails(avatar(me, 'bob').put(PNG, { contentType: 'image/jpeg' }));
  });

  it("only images are accepted", async () => {
    const me = testEnv.authenticatedContext('alice');
    await assertFails(avatar(me, 'alice').put(PNG, { contentType: 'application/pdf' }));
  });

  it("files over 5 MB are rejected", async () => {
    const me = testEnv.authenticatedContext('alice');
    const big = new Uint8Array(5 * 1024 * 1024 + 1);
    await assertFails(avatar(me, 'alice').put(big, { contentType: 'image/jpeg' }));
  });

  it("signed-in members can view pictures; signed-out visitors cannot", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await avatar(ctx, 'alice').put(PNG, { contentType: 'image/jpeg' });
    });
    await assertSucceeds(avatar(testEnv.authenticatedContext('bob'), 'alice').getDownloadURL());
    await assertFails(avatar(testEnv.unauthenticatedContext(), 'alice').getDownloadURL());
  });

  it("nothing outside profile_pictures is writable", async () => {
    const me = testEnv.authenticatedContext('alice');
    await assertFails(me.storage().ref('uploads/alice/file.jpg').put(PNG, { contentType: 'image/jpeg' }));
  });
});
