"use strict";

/**
 * Sesyon yo.
 *
 * Jeton an se 32 bytes o aza. Nou voye l bay kliyan an yon sèl fwa, epi nou
 * stoke SHA-256 li sèlman. Menm si yon moun li tab `sessions` la, li pa ka
 * rekonstwi jeton an — donk li pa ka pran plas yon itilizatè.
 *
 * (Se menm rezònman ak modpas yo: nou pa janm kenbe sekrè a an klè.)
 */

const { randomBytes, createHash, timingSafeEqual } = require("node:crypto");
const { getDb, now } = require("../db/db");

/** Konbyen tan yon sesyon dire san aktivite. */
const SESSION_TTL_MS = Number(process.env.SESSION_TTL_HOURS || 24 * 7) * 3600 * 1000;

function hashToken(token) {
  return createHash("sha256").update(String(token)).digest("hex");
}

function safeEqual(a, b) {
  const bufferA = Buffer.from(String(a));
  const bufferB = Buffer.from(String(b));
  if (bufferA.length !== bufferB.length) return false;
  return timingSafeEqual(bufferA, bufferB);
}

/** Kreye yon sesyon. Retounen jeton an AN KLÈ (sèl fwa nou wè l). */
function createSession(uid, { userAgent = "" } = {}) {
  const token = randomBytes(32).toString("hex");
  const createdAt = now();

  getDb()
    .prepare(
      `INSERT INTO sessions (token_hash, uid, created_at, expires_at, last_seen_at, user_agent)
       VALUES (?, ?, ?, ?, ?, ?)`
    )
    .run(hashToken(token), uid, createdAt, createdAt + SESSION_TTL_MS, createdAt, userAgent);

  return { token, expiresAt: createdAt + SESSION_TTL_MS };
}

/**
 * Valide yon jeton epi retounen itilizatè a.
 * Retounen `null` si jeton an pa bon, ekspire, oswa kont lan dezaktive.
 */
function resolveSession(token) {
  if (!token) return null;

  const db = getDb();
  const tokenHash = hashToken(token);

  const session = db
    .prepare("SELECT * FROM sessions WHERE token_hash = ?")
    .get(tokenHash);

  if (!session) return null;

  if (!safeEqual(session.token_hash, tokenHash)) return null;

  if (session.expires_at < now()) {
    db.prepare("DELETE FROM sessions WHERE token_hash = ?").run(tokenHash);
    return null;
  }

  const user = db
    .prepare("SELECT * FROM users WHERE uid = ? AND is_active = 1")
    .get(session.uid);

  if (!user) return null;

  // Sesyon an glise: chak apèl pwolonje l.
  const current = now();
  db.prepare(
    "UPDATE sessions SET last_seen_at = ?, expires_at = ? WHERE token_hash = ?"
  ).run(current, current + SESSION_TTL_MS, tokenHash);

  return {
    uid: user.uid,
    email: user.email,
    displayName: user.display_name,
    role: user.role,
    mustChangePassword: user.must_change_password === 1,
  };
}

function destroySession(token) {
  if (!token) return;
  getDb().prepare("DELETE FROM sessions WHERE token_hash = ?").run(hashToken(token));
}

/** Dekonekte tout aparèy yon itilizatè (chanjman modpas, dezaktivasyon...). */
function destroyAllSessions(uid) {
  getDb().prepare("DELETE FROM sessions WHERE uid = ?").run(uid);
}

/** Netwaye sesyon ki ekspire yo. */
function purgeExpiredSessions() {
  const result = getDb()
    .prepare("DELETE FROM sessions WHERE expires_at < ?")
    .run(now());
  return result.changes;
}

module.exports = {
  createSession,
  resolveSession,
  destroySession,
  destroyAllSessions,
  purgeExpiredSessions,
  SESSION_TTL_MS,
};
