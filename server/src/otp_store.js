"use strict";

/**
 * Stokaj OTP.
 *
 * Twa pwoteksyon ki pa opsyonèl sou yon kòd 6 chif:
 *
 *  1. NOU PA STOKE KÒD LA. Nou stoke yon HMAC-SHA256. Si yon moun li fichye a
 *     (oswa yon backup), li pa ka jwenn kòd yo.
 *  2. LIMIT TANTATIV. 6 chif = 1 000 000 posiblite, men yon script ka eseye yo
 *     tout an kèk minit. Apre 5 move tantativ, kòd la mouri.
 *  3. DELÈ ANT DE VOYE. San sa, yon moun ka sèvi ak fòm nan pou inonde yon
 *     adrès imel (e boule kota Hostinger ou an).
 *
 * Konparezon an fèt an tan konstan (`timingSafeEqual`).
 */

const fs = require("node:fs");
const path = require("node:path");
const { createHmac, timingSafeEqual } = require("node:crypto");

const DEFAULT_MAX_ATTEMPTS = 5;
const DEFAULT_RESEND_COOLDOWN_SECONDS = 60;

/** Sekrè HMAC la. An pwodiksyon li OBLIGATWA. */
function hmacSecret() {
  const secret = String(process.env.OTP_SECRET || "").trim();

  if (secret) return secret;

  if (process.env.NODE_ENV === "production") {
    throw new Error("OTP_SECRET obligatwa an pwodiksyon.");
  }

  return "dev-only-otp-secret";
}

function dbPath() {
  return (
    process.env.OTP_DB_PATH || path.join(__dirname, "..", "data", "otp_db.json")
  );
}

function hashOtp(email, otp) {
  return createHmac("sha256", hmacSecret())
    .update(`${String(email).trim().toLowerCase()}:${String(otp).trim()}`)
    .digest("hex");
}

function safeEqual(a, b) {
  const bufferA = Buffer.from(String(a));
  const bufferB = Buffer.from(String(b));
  if (bufferA.length !== bufferB.length) return false;
  return timingSafeEqual(bufferA, bufferB);
}

function readDb() {
  try {
    return JSON.parse(fs.readFileSync(dbPath(), "utf8"));
  } catch (err) {
    if (err.code === "ENOENT") return {};
    throw err;
  }
}

function writeDb(db) {
  const file = dbPath();
  fs.mkdirSync(path.dirname(file), { recursive: true });
  // Ekri nan yon fichye tanporè epi ranplase: konsa yon kras pa kite yon
  // fichye JSON kase dèyè.
  const temp = `${file}.tmp`;
  fs.writeFileSync(temp, JSON.stringify(db, null, 2), { mode: 0o600 });
  fs.renameSync(temp, file);
}

function normalizeEmail(email) {
  return String(email).trim().toLowerCase();
}

function maxAttempts() {
  return Number(process.env.OTP_MAX_ATTEMPTS || DEFAULT_MAX_ATTEMPTS);
}

function resendCooldownSeconds() {
  return Number(process.env.OTP_RESEND_COOLDOWN_SECONDS || DEFAULT_RESEND_COOLDOWN_SECONDS);
}

/**
 * Èske nou gen dwa voye yon nouvo kòd bay adrès sa a kounye a?
 * @returns {{allowed: boolean, retryAfterSeconds: number}}
 */
function canSend(email) {
  const key = normalizeEmail(email);
  const record = readDb()[key];

  if (!record?.lastSentAt) return { allowed: true, retryAfterSeconds: 0 };

  const elapsed = (Date.now() - record.lastSentAt) / 1000;
  const cooldown = resendCooldownSeconds();

  if (elapsed >= cooldown) return { allowed: true, retryAfterSeconds: 0 };

  return { allowed: false, retryAfterSeconds: Math.ceil(cooldown - elapsed) };
}

/** Anrejistre yon kòd (se HMAC la ki ale nan disk, pa kòd la). */
function saveOtp(email, otp, ttlSeconds) {
  const key = normalizeEmail(email);
  const db = readDb();

  db[key] = {
    hash: hashOtp(key, otp),
    expiresAt: Date.now() + Number(ttlSeconds) * 1000,
    attempts: 0,
    lastSentAt: Date.now(),
  };

  writeDb(db);
  return { ok: true };
}

/**
 * Verifye yon kòd.
 * @returns {{ok: boolean, reason?: string, attemptsLeft?: number}}
 */
function verifyOtp(email, otp) {
  const key = normalizeEmail(email);
  const db = readDb();
  const record = db[key];

  if (!record) return { ok: false, reason: "not_found" };

  if (Date.now() > record.expiresAt) {
    delete db[key];
    writeDb(db);
    return { ok: false, reason: "expired" };
  }

  if (record.attempts >= maxAttempts()) {
    delete db[key];
    writeDb(db);
    return { ok: false, reason: "too_many_attempts" };
  }

  if (!safeEqual(record.hash, hashOtp(key, otp))) {
    record.attempts += 1;
    const attemptsLeft = Math.max(0, maxAttempts() - record.attempts);

    if (attemptsLeft === 0) {
      delete db[key];
      writeDb(db);
      return { ok: false, reason: "too_many_attempts", attemptsLeft: 0 };
    }

    db[key] = record;
    writeDb(db);
    return { ok: false, reason: "invalid", attemptsLeft };
  }

  // Yon kòd sèvi yon sèl fwa.
  delete db[key];
  writeDb(db);
  return { ok: true };
}

/** Netwaye kòd ki ekspire yo (rele nan yon tach pwograme si ou vle). */
function purgeExpired() {
  const db = readDb();
  const now = Date.now();
  let removed = 0;

  for (const [key, record] of Object.entries(db)) {
    if (record.expiresAt < now) {
      delete db[key];
      removed += 1;
    }
  }

  if (removed > 0) writeDb(db);
  return removed;
}

module.exports = {
  saveOtp,
  verifyOtp,
  canSend,
  purgeExpired,
  hashOtp,
  DEFAULT_MAX_ATTEMPTS,
  DEFAULT_RESEND_COOLDOWN_SECONDS,
};
