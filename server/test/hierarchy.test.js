"use strict";

/**
 * Yerachi wòl yo: owner > admin > agent.
 *
 * Tès sa yo egziste paske yon odit te jwenn 3 twou reyèl:
 *   1. wout Bazik yo te aksepte yon header `x-dev-uid` san okenn jeton —
 *      donk nenpòt moun te ka VOYE LAJAN;
 *   2. yon ajan te ka wè sòld tout staff la;
 *   3. yon ajan te ka make pwòp tranzaksyon li `delivered`, sa ki deklanche
 *      komisyon — li t ap valide pwòp travay li epi peye tèt li.
 *
 * Yo pa dwe tounen.
 */

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");

const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), "hierarchy-test-"));
process.env.APP_DB_PATH = path.join(tempDir, "app.db");

const db = require("../src/db/db");
const users = require("../src/auth/users");
const { requireRole, requireEnterprise, requireAuth } = require("../src/auth/middleware");

test.after(() => {
  db.resetDb();
  fs.rmSync(tempDir, { recursive: true, force: true });
});

/** Similasyon yon rekèt Express ki pase nan yon middleware. */
function run(middleware, user) {
  const req = { user };
  let status = 200;
  let body = null;
  let passed = false;

  const res = {
    status(code) {
      status = code;
      return res;
    },
    json(payload) {
      body = payload;
      return res;
    },
  };

  middleware(req, res, () => {
    passed = true;
  });

  return { passed, status, code: body?.code };
}

const owner = { uid: "OW_1", role: "owner", enterpriseId: "ENT_1" };
const admin = { uid: "AD_1", role: "admin", enterpriseId: "ENT_1" };
const agent = { uid: "AG_1", role: "agent", enterpriseId: "ENT_1" };
const orphan = { uid: "AG_2", role: "agent", enterpriseId: "" };

test("san sesyon, tout wout pwoteje refize", () => {
  const result = run(requireAuth, null);
  assert.equal(result.passed, false);
  assert.equal(result.status, 401);
  assert.equal(result.code, "unauthenticated");
});

test("owner pase tout kote", () => {
  assert.ok(run(requireRole("owner"), owner).passed);
  assert.ok(run(requireRole("owner", "admin"), owner).passed);
});

test("admin pase kote admin gen dwa, men pa kote owner sèlman", () => {
  assert.ok(run(requireRole("owner", "admin"), admin).passed);

  const blocked = run(requireRole("owner"), admin);
  assert.equal(blocked.passed, false);
  assert.equal(blocked.status, 403);
  assert.equal(blocked.code, "forbidden");
});

test("agent pa pase okenn wout jesyon", () => {
  assert.equal(run(requireRole("owner"), agent).passed, false);
  assert.equal(run(requireRole("owner", "admin"), agent).passed, false);
});

test("`administrator` ak `admin` se menm nivo", () => {
  // Done ki egziste yo sèvi ak de non yo; yerachi a pa dwe depann de sa.
  const administrator = { ...admin, role: "administrator" };

  assert.ok(run(requireRole("owner", "admin"), administrator).passed);
  assert.ok(run(requireRole("administrator"), admin).passed);
});

test("san antrepriz, okenn mouvman lajan", () => {
  // `balances/{enterpriseId}_{uid}` pa ka egziste san antrepriz.
  const result = run(requireEnterprise, orphan);
  assert.equal(result.passed, false);
  assert.equal(result.status, 403);
  assert.equal(result.code, "no_enterprise");

  assert.ok(run(requireEnterprise, agent).passed);
});

test("yon kont dezaktive pèdi sesyon l tou swit", async () => {
  const sessions = require("../src/auth/sessions");

  const user = await users.createUser({
    email: "yerachi@example.com",
    password: "modpas-solid-123",
    role: "agent",
  });

  const session = sessions.createSession(user.uid);
  assert.equal(sessions.resolveSession(session.token).role, "agent");

  users.setActive(user.uid, false);

  // Menm si jeton an poko ekspire, li pa vo anyen ankò.
  assert.equal(sessions.resolveSession(session.token), null);
});

test("wòl la soti nan baz la, pa nan sa kliyan an voye", async () => {
  const sessions = require("../src/auth/sessions");

  const user = await users.createUser({
    email: "wol@example.com",
    password: "modpas-solid-123",
    role: "agent",
  });

  const session = sessions.createSession(user.uid);
  const resolved = sessions.resolveSession(session.token);

  // Kliyan an pa gen okenn mwayen pou l di "mwen se owner".
  assert.equal(resolved.role, "agent");
  assert.equal(resolved.uid, user.uid);
});

// --- Rang: pa ka bay, ni touche, yon wòl egal oswa pi wo ---
//
// Odit la te pwouve yon admin te ka fè PATCH sou pwòp uid li ak
// `role: "owner"`, epi dezaktive owner lejitim nan.

test("rang yo: owner > admin > agent > client", () => {
  const routes = require("fs").readFileSync(
    require("path").join(__dirname, "..", "src", "routes", "users.routes.js"),
    "utf8"
  );

  // Gad yo dwe prezan sou kreyasyon, modifikasyon ak reinisyalizasyon.
  assert.match(routes, /code: "role_too_high"/, "kreyasyon/atribisyon wòl pi wo refize");
  assert.match(routes, /code: "cannot_modify_self"/, "pa ka modifye tèt ou");
  assert.match(routes, /code: "target_too_high"/, "pa ka touche yon wòl pi wo");
  assert.match(
    routes,
    /UPDATE enterprise_users SET role = \? WHERE uid = \? AND enterprise_id = \?/,
    "chanjman wòl limite sou antrepriz la"
  );
});
