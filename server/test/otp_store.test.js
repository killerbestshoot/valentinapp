"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");

/** Chak tès gen pwòp fichye baz li. */
function useTempDb(t) {
  const file = path.join(
    fs.mkdtempSync(path.join(os.tmpdir(), "otp-test-")),
    "otp_db.json"
  );

  process.env.OTP_DB_PATH = file;
  process.env.OTP_SECRET = "test-secret";

  t.after(() => {
    fs.rmSync(path.dirname(file), { recursive: true, force: true });
    delete process.env.OTP_DB_PATH;
  });

  return file;
}

const store = require("../src/otp_store");

test("kòd la PA stoke an klè sou disk", (t) => {
  const file = useTempDb(t);

  store.saveOtp("moun@example.com", "123456", 300);

  const raw = fs.readFileSync(file, "utf8");
  assert.ok(!raw.includes("123456"), "kòd la pa dwe parèt nan fichye a");
  assert.match(raw, /"hash":\s*"[0-9a-f]{64}"/, "se yon HMAC-SHA256 ki stoke");
});

test("bon kòd la pase, epi li sèvi yon sèl fwa", (t) => {
  useTempDb(t);

  store.saveOtp("moun@example.com", "123456", 300);

  assert.equal(store.verifyOtp("moun@example.com", "123456").ok, true);

  const second = store.verifyOtp("moun@example.com", "123456");
  assert.equal(second.ok, false);
  assert.equal(second.reason, "not_found", "yon kòd pa ka sèvi de fwa");
});

test("adrès imel la pa sansib a majiskil", (t) => {
  useTempDb(t);

  store.saveOtp("Moun@Example.COM", "123456", 300);
  assert.equal(store.verifyOtp("moun@example.com", "123456").ok, true);
});

test("apre 5 move tantativ kòd la mouri", (t) => {
  useTempDb(t);

  store.saveOtp("moun@example.com", "123456", 300);

  for (let attempt = 1; attempt <= 4; attempt++) {
    const result = store.verifyOtp("moun@example.com", "000000");
    assert.equal(result.reason, "invalid");
    assert.equal(result.attemptsLeft, 5 - attempt);
  }

  const fifth = store.verifyOtp("moun@example.com", "000000");
  assert.equal(fifth.reason, "too_many_attempts");

  // Menm bon kòd la pa mache ankò: nou dwe mande yon nouvo.
  assert.equal(store.verifyOtp("moun@example.com", "123456").ok, false);
});

test("kòd ki ekspire refize", (t) => {
  useTempDb(t);

  store.saveOtp("moun@example.com", "123456", -1);

  const result = store.verifyOtp("moun@example.com", "123456");
  assert.equal(result.ok, false);
  assert.equal(result.reason, "expired");
});

test("delè anpeche yon moun inonde yon adrès", (t) => {
  useTempDb(t);
  process.env.OTP_RESEND_COOLDOWN_SECONDS = "60";

  assert.equal(store.canSend("moun@example.com").allowed, true);

  store.saveOtp("moun@example.com", "123456", 300);

  const gate = store.canSend("moun@example.com");
  assert.equal(gate.allowed, false);
  assert.ok(gate.retryAfterSeconds > 0 && gate.retryAfterSeconds <= 60);

  delete process.env.OTP_RESEND_COOLDOWN_SECONDS;
});

test("adrès san kòd bay 'not_found'", (t) => {
  useTempDb(t);
  assert.equal(store.verifyOtp("pyès-moun@example.com", "123456").reason, "not_found");
});

test("purgeExpired netwaye sa ki mouri", (t) => {
  useTempDb(t);

  store.saveOtp("vye@example.com", "111111", -1);
  store.saveOtp("nouvo@example.com", "222222", 300);

  assert.equal(store.purgeExpired(), 1);
  assert.equal(store.verifyOtp("nouvo@example.com", "222222").ok, true);
});

test("de adrès diferan ak menm kòd bay hash diferan", (t) => {
  useTempDb(t);

  assert.notEqual(
    store.hashOtp("a@example.com", "123456"),
    store.hashOtp("b@example.com", "123456"),
    "hash la mare ak adrès la: yon hash vòlè pa ka sèvi sou yon lòt kont"
  );
});
