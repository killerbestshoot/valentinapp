"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");

// Chak fichye tès gen pwòp baz li. `db.js` li `APP_DB_PATH` lè li louvri.
const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), "auth-test-"));
process.env.APP_DB_PATH = path.join(tempDir, "app.db");

const db = require("../src/db/db");
const users = require("../src/auth/users");
const sessions = require("../src/auth/sessions");
const password = require("../src/auth/password");

test.after(() => {
  db.resetDb();
  fs.rmSync(tempDir, { recursive: true, force: true });
});

// --- Achaj modpas ---

test("menm modpas bay hash diferan (salt pa itilizatè)", async () => {
  const a = await password.hashPassword("menm-modpas-la");
  const b = await password.hashPassword("menm-modpas-la");

  assert.notEqual(a.hash, b.hash, "san sa, yon atakè ta ka reyitilize travay li");
  assert.notEqual(a.salt, b.salt);

  assert.ok(await password.verifyPassword("menm-modpas-la", a));
  assert.ok(await password.verifyPassword("menm-modpas-la", b));
});

test("move modpas refize", async () => {
  const stored = await password.hashPassword("bon-modpas-la");
  assert.equal(await password.verifyPassword("move-modpas", stored), false);
});

test("modpas fèb refize", () => {
  assert.equal(password.validatePassword("kout").ok, false);
  assert.equal(password.validatePassword("password").ok, false);
  assert.equal(password.validatePassword("12345678").ok, false);
  assert.equal(password.validatePassword("yon-modpas-solid").ok, true);
});

// --- Kont ---

test("kreye yon itilizatè epi konekte l", async () => {
  const created = await users.createUser({
    email: "Agent@Example.com",
    password: "modpas-ajan-2026",
    displayName: "Ajan Test",
    role: "agent",
  });

  assert.equal(created.email, "agent@example.com", "imel la nòmalize");
  assert.equal(created.role, "agent");
  assert.ok(created.uid.startsWith("AG_"), "ID a swiv menm konvansyon ak Dart la");

  const authenticated = await users.authenticate("agent@example.com", "modpas-ajan-2026");
  assert.equal(authenticated.uid, created.uid);
});

test("imel ki deja pran refize", async () => {
  await users.createUser({
    email: "doub@example.com",
    password: "modpas-solid-123",
    role: "agent",
  });

  await assert.rejects(
    users.createUser({
      email: "DOUB@example.com",
      password: "yon-lot-modpas",
      role: "agent",
    }),
    { code: "email_taken" }
  );
});

test("imel envalid ak wòl envalid refize", async () => {
  await assert.rejects(
    users.createUser({ email: "pa-yon-imel", password: "modpas-solid-123" }),
    { code: "invalid_email" }
  );

  await assert.rejects(
    users.createUser({
      email: "ok@example.com",
      password: "modpas-solid-123",
      role: "prezidan",
    }),
    { code: "invalid_role" }
  );
});

test("menm mesaj pou imel enkoni ak move modpas", async () => {
  const unknown = await users
    .authenticate("pyes-moun@example.com", "nenpot")
    .catch((e) => e);

  await users.createUser({
    email: "konnen@example.com",
    password: "modpas-solid-123",
    role: "agent",
  });

  const wrongPassword = await users
    .authenticate("konnen@example.com", "move-modpas")
    .catch((e) => e);

  // Si mesaj yo te diferan, yon moun ta ka teste adrès yo youn apre lòt pou l
  // konnen ki moun ki gen yon kont.
  assert.equal(unknown.message, wrongPassword.message);
  assert.equal(unknown.code, wrongPassword.code);
});

test("kont dezaktive pa ka konekte", async () => {
  const user = await users.createUser({
    email: "dezaktive@example.com",
    password: "modpas-solid-123",
    role: "agent",
  });

  users.setActive(user.uid, false);

  await assert.rejects(
    users.authenticate("dezaktive@example.com", "modpas-solid-123"),
    { code: "account_disabled" }
  );
});

test("kreye yon itilizatè PA konekte moun ki kreye l la", async () => {
  // Se te pwoblèm Firebase la: `createUserWithEmailAndPassword` te pran plas
  // admin nan. Isit la kreyasyon an pa touche okenn sesyon.
  const admin = await users.createUser({
    email: "admin-kreyate@example.com",
    password: "modpas-solid-123",
    role: "admin",
  });

  const session = sessions.createSession(admin.uid);

  await users.createUser({
    email: "nouvo-ajan@example.com",
    password: "modpas-solid-123",
    role: "agent",
  });

  const resolved = sessions.resolveSession(session.token);
  assert.equal(resolved.uid, admin.uid, "admin nan rete konekte");
});

// --- Sesyon ---

test("jeton an pa stoke an klè", async () => {
  const user = await users.createUser({
    email: "sesyon@example.com",
    password: "modpas-solid-123",
    role: "agent",
  });

  const session = sessions.createSession(user.uid);
  const rows = db.getDb().prepare("SELECT token_hash FROM sessions").all();

  assert.ok(
    rows.every((row) => row.token_hash !== session.token),
    "se SHA-256 la ki nan baz la, pa jeton an"
  );
  assert.equal(sessions.resolveSession(session.token).uid, user.uid);
});

test("jeton envalid oswa vid pa bay anyen", () => {
  assert.equal(sessions.resolveSession("pa-yon-jeton"), null);
  assert.equal(sessions.resolveSession(""), null);
  assert.equal(sessions.resolveSession(null), null);
});

test("dekonekte detwi sesyon an", async () => {
  const user = await users.createUser({
    email: "dekonekte@example.com",
    password: "modpas-solid-123",
    role: "agent",
  });

  const session = sessions.createSession(user.uid);
  sessions.destroySession(session.token);

  assert.equal(sessions.resolveSession(session.token), null);
});

test("chanje modpas fè tout sesyon yo tonbe", async () => {
  const user = await users.createUser({
    email: "chanje@example.com",
    password: "ansyen-modpas-123",
    role: "agent",
  });

  const phone = sessions.createSession(user.uid);
  const laptop = sessions.createSession(user.uid);

  await users.changePassword(user.uid, {
    currentPassword: "ansyen-modpas-123",
    newPassword: "nouvo-modpas-456",
  });

  // Si yon moun te gen yon sesyon vòlè, li tonbe la.
  assert.equal(sessions.resolveSession(phone.token), null);
  assert.equal(sessions.resolveSession(laptop.token), null);

  await assert.rejects(
    users.authenticate("chanje@example.com", "ansyen-modpas-123"),
    { code: "invalid_credentials" }
  );

  const ok = await users.authenticate("chanje@example.com", "nouvo-modpas-456");
  assert.equal(ok.uid, user.uid);
});

test("chanje modpas ak move ansyen modpas refize", async () => {
  const user = await users.createUser({
    email: "refize@example.com",
    password: "ansyen-modpas-123",
    role: "agent",
  });

  await assert.rejects(
    users.changePassword(user.uid, {
      currentPassword: "pa-bon",
      newPassword: "nouvo-modpas-456",
    }),
    { code: "invalid_credentials" }
  );
});

test("admin reinisyalize yon modpas: staff la dwe chanje l", async () => {
  const user = await users.createUser({
    email: "reset@example.com",
    password: "ansyen-modpas-123",
    role: "agent",
  });

  const updated = await users.resetPasswordAsAdmin(user.uid, "modpas-tanporè-1");

  assert.equal(updated.mustChangePassword, true);
  const ok = await users.authenticate("reset@example.com", "modpas-tanporè-1");
  assert.equal(ok.mustChangePassword, true);
});

test("dezaktive yon kont dekonekte l tou swit", async () => {
  const user = await users.createUser({
    email: "kick@example.com",
    password: "modpas-solid-123",
    role: "agent",
  });

  const session = sessions.createSession(user.uid);
  users.setActive(user.uid, false);

  assert.equal(sessions.resolveSession(session.token), null);
});
