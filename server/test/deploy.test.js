"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { DatabaseSync } = require("node:sqlite");

const { checkProductionConfig } = require("../src/preflight");
const { backup } = require("../scripts/backup_db");

const SECRET = "a".repeat(64);

/** Yon konfigirasyon pwodiksyon valab; chak tès kase yon sèl bagay. */
function prodEnv(overrides = {}) {
  return {
    NODE_ENV: "production",
    OTP_SECRET: SECRET,
    BAZIK_MODE: "live",
    BAZIK_USER_ID: "bzk_live_x",
    BAZIK_SECRET_KEY: "sk_live_x",
    BAZIK_WEBHOOK_SECRET: "whsec_live_x",
    MAIL_PROVIDER: "hostinger_smtp",
    SMTP_USER: "no-reply@example.com",
    SMTP_PASS: "x",
    CORS_ORIGINS: "https://app.example.com",
    ...overrides,
  };
}

test("preflight: yon konfigirasyon pwodiksyon konplè pase san erè ni avètisman", () => {
  assert.deepEqual(checkProductionConfig(prodEnv()), { errors: [], warnings: [] });
});

test("preflight: an devlopman, anyen pa bloke", () => {
  assert.deepEqual(checkProductionConfig({}), { errors: [], warnings: [] });
});

test("preflight: OTP_SECRET manke oswa twò kout bloke demaraj la", () => {
  assert.equal(checkProductionConfig(prodEnv({ OTP_SECRET: "" })).errors.length, 1);
  assert.equal(checkProductionConfig(prodEnv({ OTP_SECRET: "court" })).errors.length, 1);
});

test("preflight: pasrèl fake (kle bliye) bloke demaraj la an pwodiksyon", () => {
  const env = prodEnv({ BAZIK_MODE: "", BAZIK_USER_ID: "", BAZIK_SECRET_KEY: "" });
  const { errors } = checkProductionConfig(env);
  assert.equal(errors.length, 1);
  assert.match(errors[0], /fake/);

  // ... sof si yon moun mande l klèman pou yon demo.
  assert.deepEqual(checkProductionConfig({ ...env, ALLOW_FAKE_GATEWAY: "true" }).errors, []);
});

test("preflight: san sekrè webhook, transfè yo pa ta janm konfime", () => {
  const { errors } = checkProductionConfig(prodEnv({ BAZIK_WEBHOOK_SECRET: "" }));
  assert.equal(errors.length, 1);
  assert.match(errors[0], /BAZIK_WEBHOOK_SECRET/);
});

test("preflight: OTP nan log (console) entèdi an pwodiksyon", () => {
  const env = prodEnv({ MAIL_PROVIDER: "console" });
  assert.equal(checkProductionConfig(env).errors.length, 1);
});

test("preflight: sandbox ak CORS louvri se avètisman, pa erè", () => {
  const { errors, warnings } = checkProductionConfig(
    prodEnv({ BAZIK_MODE: "sandbox", CORS_ORIGINS: "" })
  );
  assert.deepEqual(errors, []);
  assert.equal(warnings.length, 2);
});

function tempDir() {
  return fs.mkdtempSync(path.join(os.tmpdir(), "vpc-backup-"));
}

function seedDb(file) {
  const db = new DatabaseSync(file);
  db.exec("CREATE TABLE wallets (uid TEXT PRIMARY KEY, balance_minor INTEGER NOT NULL)");
  db.prepare("INSERT INTO wallets VALUES (?, ?)").run("agent-1", 123456);
  db.close();
}

test("backup: kopi a konplè, lizib, e li pa touche orijinal la", () => {
  const dir = tempDir();
  const source = path.join(dir, "app.db");
  seedDb(source);

  const result = backup({ source, dir: path.join(dir, "backups"), keep: 5 });

  const copy = new DatabaseSync(result.target, { readOnly: true });
  assert.deepEqual(
    { ...copy.prepare("SELECT uid, balance_minor FROM wallets").get() },
    { uid: "agent-1", balance_minor: 123456 }
  );
  copy.close();

  const original = new DatabaseSync(source);
  assert.equal(original.prepare("SELECT COUNT(*) AS n FROM wallets").get().n, 1);
  original.close();
});

test("backup: kenbe sèlman N dènye kopi yo, pa janm lòt fichye", () => {
  const dir = tempDir();
  const source = path.join(dir, "app.db");
  const backups = path.join(dir, "backups");
  seedDb(source);
  fs.mkdirSync(backups);

  for (const name of ["app-20260101-000000.db", "app-20260102-000000.db", "app-20260103-000000.db"]) {
    fs.writeFileSync(path.join(backups, name), "old");
  }
  fs.writeFileSync(path.join(backups, "notes.txt"), "a pa efase");

  const result = backup({ source, dir: backups, keep: 2 });

  assert.deepEqual(result.removed, ["app-20260101-000000.db", "app-20260102-000000.db"]);
  assert.ok(fs.existsSync(path.join(backups, "notes.txt")));
  assert.ok(fs.existsSync(result.target));
});

test("backup: yon baz ki pa egziste echwe klèman", () => {
  const dir = tempDir();
  assert.throws(
    () => backup({ source: path.join(dir, "absent.db"), dir, keep: 1 }),
    /pa egziste/
  );
});
