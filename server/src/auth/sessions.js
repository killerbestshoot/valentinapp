"use strict";

/**
 * Sesyon yo.
 *
 * Jeton an se 32 bytes o aza. Nou voye l bay kliyan an yon sèl fwa, epi nou
 * stoke SHA-256 li sèlman. Menm si yon moun li tab `sessions` la, li pa ka
 * rekonstwi jeton an — donk li pa ka pran plas yon itilizatè.
 *
 * (Se menm rezònman ak modpas yo: nou pa janm kenbe sekrè a an klè.)
 *
 * De limit kanpe sou chak sesyon:
 *
 *   1. INAKTIVITE (5 minit) — si pa gen okenn apèl pandan tan sa a, sesyon an
 *      mouri. Se limit ki konte pou sekirite a: yon telefòn ki rete louvri sou
 *      yon tab, oswa yon jeton yon moun vòlè epi li pa sèvi ak li touswit,
 *      pa vo anyen apre 5 minit.
 *   2. PLAFON (7 jou) — menm yon moun ki ap travay tout tan dwe rekonekte yon
 *      fwa pa semèn. Plafon sa a PA glise.
 *
 * `expires_at` nan baz la kenbe deja min(2 limit yo), donk yon sèl konparezon
 * ase pou valide yon sesyon.
 */

const { randomBytes, createHash, timingSafeEqual } = require("node:crypto");
const { getDb, now } = require("../db/db");

/** Konbyen tan yon sesyon dire SAN okenn aktivite. */
const SESSION_IDLE_MS =
  Number(process.env.SESSION_IDLE_MINUTES || 5) * 60 * 1000;

/** Konbyen tan yon sesyon ka dire an tou, menm si moun nan aktif. */
const SESSION_MAX_MS =
  Number(process.env.SESSION_TTL_HOURS || 24 * 7) * 3600 * 1000;

function hashToken(token) {
  return createHash("sha256").update(String(token)).digest("hex");
}

function safeEqual(a, b) {
  const bufferA = Buffer.from(String(a));
  const bufferB = Buffer.from(String(b));
  if (bufferA.length !== bufferB.length) return false;
  return timingSafeEqual(bufferA, bufferB);
}

/**
 * Kilè sesyon an mouri si nou pa tande anyen ankò.
 *
 * Se pi piti a nan de limit yo: inaktivite konte depi dènye apèl la, plafon an
 * konte depi koneksyon an e li pa bouje.
 */
function deadlineOf(createdAt, lastSeenAt) {
  return Math.min(lastSeenAt + SESSION_IDLE_MS, createdAt + SESSION_MAX_MS);
}

/** Kreye yon sesyon. Retounen jeton an AN KLÈ (sèl fwa nou wè l). */
function createSession(uid, { userAgent = "" } = {}) {
  const token = randomBytes(32).toString("hex");
  const createdAt = now();
  const expiresAt = deadlineOf(createdAt, createdAt);

  getDb()
    .prepare(
      `INSERT INTO sessions (token_hash, uid, created_at, expires_at, last_seen_at, user_agent)
       VALUES (?, ?, ?, ?, ?, ?)`
    )
    .run(hashToken(token), uid, createdAt, expiresAt, createdAt, userAgent);

  return { token, expiresAt, idleTimeoutMs: SESSION_IDLE_MS };
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

  // Yon sèl konparezon kouvri toude limit yo (gade tèt fichye a).
  if (session.expires_at < now()) {
    db.prepare("DELETE FROM sessions WHERE token_hash = ?").run(tokenHash);
    return null;
  }

  const user = db
    .prepare("SELECT * FROM users WHERE uid = ? AND is_active = 1")
    .get(session.uid);

  if (!user) return null;

  // Sesyon an glise sou inaktivite: chak apèl repouse limit 5 minit lan, men
  // plafon 7 jou a rete kote l te ye depi koneksyon an.
  const current = now();
  const expiresAt = deadlineOf(session.created_at, current);

  if (expiresAt <= current) {
    db.prepare("DELETE FROM sessions WHERE token_hash = ?").run(tokenHash);
    return null;
  }

  db.prepare(
    "UPDATE sessions SET last_seen_at = ?, expires_at = ? WHERE token_hash = ?"
  ).run(current, expiresAt, tokenHash);

  return {
    uid: user.uid,
    email: user.email,
    displayName: user.display_name,
    role: user.role,
    mustChangePassword: user.must_change_password === 1,
    expiresAt,
    idleTimeoutMs: SESSION_IDLE_MS,
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
  SESSION_IDLE_MS,
  SESSION_MAX_MS,
};
