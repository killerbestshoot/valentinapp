"use strict";

/**
 * Kont itilizatè yo (sa Firebase Auth + koleksyon `users` t ap fè ansanm).
 */

const { getDb, transaction, now } = require("../db/db");
const { hashPassword, verifyPassword, validatePassword } = require("./password");
const { destroyAllSessions } = require("./sessions");

const AppIds = require("../../../bazik/src/ids");

class AuthError extends Error {
  constructor(code, message, status = 400) {
    super(message);
    this.name = "AuthError";
    this.code = code;
    this.status = status;
  }
}

const ROLES = ["owner", "administrator", "admin", "agent", "client"];

function normalizeEmail(email) {
  return String(email ?? "").trim().toLowerCase();
}

function isValidEmail(email) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
}

/** Sa nou voye bay kliyan an. JANM `password_hash` ni `password_salt`. */
function publicUser(row) {
  if (!row) return null;
  return {
    uid: row.uid,
    email: row.email,
    displayName: row.display_name,
    role: row.role,
    isActive: row.is_active === 1,
    mustChangePassword: row.must_change_password === 1,
    createdAt: row.created_at,
    lastLoginAt: row.last_login_at,
  };
}

function findByEmail(email) {
  return getDb()
    .prepare("SELECT * FROM users WHERE email = ? COLLATE NOCASE")
    .get(normalizeEmail(email));
}

function findByUid(uid) {
  return getDb().prepare("SELECT * FROM users WHERE uid = ?").get(uid);
}

function countUsers() {
  return getDb().prepare("SELECT COUNT(*) AS n FROM users").get().n;
}

/**
 * Kreye yon itilizatè.
 *
 * Kontrèman ak `createUserWithEmailAndPassword` Firebase la, sa a PA konekte
 * nouvo itilizatè a nan plas moun k ap kreye l. Se te yon vye pwoblèm nan
 * ekran "Nouvo ajan" an: admin nan te dekonekte chak fwa.
 */
async function createUser({
  email,
  password,
  displayName = "",
  role = "agent",
  enterpriseId = "",
  enterpriseName = "",
  createdBy = "",
  mustChangePassword = false,
  currency = "USD",
}) {
  const normalizedEmail = normalizeEmail(email);

  if (!isValidEmail(normalizedEmail)) {
    throw new AuthError("invalid_email", "Adrès imel la pa valid.");
  }

  if (!ROLES.includes(role)) {
    throw new AuthError("invalid_role", `Wòl la pa valid: ${role}`);
  }

  const check = validatePassword(password);
  if (!check.ok) {
    throw new AuthError("weak_password", check.reason);
  }

  if (findByEmail(normalizedEmail)) {
    throw new AuthError("email_taken", "Adrès imel sa a deja gen yon kont.", 409);
  }

  // Deviz wallet la dwe gen yon to echanj, sinon nou p ap ka ni konvèti yon
  // rechaj, ni kalkile montan HTG pou Bazik. Pi bon nou bloke isit la pase
  // kite yon wallet ki pa ka sèvi.
  const walletCurrency = String(currency || "USD").toUpperCase().trim();

  if (enterpriseId) {
    const rate = getDb()
      .prepare("SELECT rate_to_htg FROM exchange_rates WHERE currency = ?")
      .get(walletCurrency);

    if (!rate || Number(rate.rate_to_htg) <= 0) {
      throw new AuthError(
        "unknown_currency",
        `Pa gen to echanj pou ${walletCurrency}. Chwazi yon deviz ki konfigire.`
      );
    }
  }

  const { hash, salt } = await hashPassword(password);
  const uid = AppIds.userForRole(role, `${normalizedEmail}:${Date.now()}`);
  const timestamp = now();

  transaction((db) => {
    db.prepare(
      `INSERT INTO users
        (uid, email, password_hash, password_salt, display_name, role, is_active,
         must_change_password, created_at, updated_at, created_by)
       VALUES (?, ?, ?, ?, ?, ?, 1, ?, ?, ?, ?)`
    ).run(
      uid, normalizedEmail, hash, salt, displayName, role,
      mustChangePassword ? 1 : 0, timestamp, timestamp, createdBy
    );

    if (enterpriseId) {
      db.prepare(
        `INSERT INTO enterprise_users
          (id, uid, enterprise_id, enterprise_name, display_name, email, role,
           is_active, created_at, created_by)
         VALUES (?, ?, ?, ?, ?, ?, ?, 1, ?, ?)`
      ).run(
        AppIds.enterpriseUser(`${enterpriseId}:${uid}`), uid, enterpriseId,
        enterpriseName, displayName, normalizedEmail, role, timestamp, createdBy
      );

      // Wallet la kreye vid, ak menm ID ak `BalanceService` nan Dart la.
      db.prepare(
        `INSERT INTO wallets
          (id, uid, enterprise_id, enterprise_name, role, currency, balance_minor,
           created_at, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, 0, ?, ?)
         ON CONFLICT(id) DO NOTHING`
      ).run(
        `${enterpriseId}_${uid}`, uid, enterpriseId, enterpriseName, role,
        walletCurrency, timestamp, timestamp
      );
    }
  });

  return publicUser(findByUid(uid));
}

/**
 * Verifye idantifyan yo.
 *
 * Nou bay MENM mesaj pou "imel pa egziste" ak "modpas pa bon". Si nou te di
 * "imel sa a pa egziste", yon moun ta ka teste adrès yo youn apre lòt pou l
 * konnen ki moun ki gen yon kont.
 */
async function authenticate(email, password) {
  const user = findByEmail(email);

  if (!user) {
    // Nou kalkile yon hash kanmenm: san sa, yon imel ki pa egziste t ap reponn
    // pi vit, e sa ta bay repons lan.
    await verifyPassword(password, { hash: "00".repeat(64), salt: "00" });
    throw new AuthError("invalid_credentials", "Imel oswa modpas pa bon.", 401);
  }

  if (user.is_active !== 1) {
    throw new AuthError("account_disabled", "Kont sa a dezaktive.", 403);
  }

  const ok = await verifyPassword(password, {
    hash: user.password_hash,
    salt: user.password_salt,
  });

  if (!ok) {
    throw new AuthError("invalid_credentials", "Imel oswa modpas pa bon.", 401);
  }

  getDb()
    .prepare("UPDATE users SET last_login_at = ?, updated_at = ? WHERE uid = ?")
    .run(now(), now(), user.uid);

  return publicUser(findByUid(user.uid));
}

/** Chanje modpas. Tout lòt sesyon yo tonbe. */
async function changePassword(uid, { currentPassword, newPassword }) {
  const user = findByUid(uid);
  if (!user) throw new AuthError("user_not_found", "Itilizatè a pa egziste.", 404);

  const ok = await verifyPassword(currentPassword, {
    hash: user.password_hash,
    salt: user.password_salt,
  });

  if (!ok) {
    throw new AuthError("invalid_credentials", "Ansyen modpas la pa bon.", 401);
  }

  const check = validatePassword(newPassword);
  if (!check.ok) throw new AuthError("weak_password", check.reason);

  const { hash, salt } = await hashPassword(newPassword);

  getDb()
    .prepare(
      `UPDATE users SET password_hash = ?, password_salt = ?,
         must_change_password = 0, updated_at = ? WHERE uid = ?`
    )
    .run(hash, salt, now(), uid);

  // Si yon moun te gen yon sesyon vòlè, li tonbe isit la.
  destroyAllSessions(uid);

  return publicUser(findByUid(uid));
}

/** Yon admin reinisyalize modpas yon staff (li pa bezwen ansyen an). */
async function resetPasswordAsAdmin(uid, newPassword) {
  const user = findByUid(uid);
  if (!user) throw new AuthError("user_not_found", "Itilizatè a pa egziste.", 404);

  const check = validatePassword(newPassword);
  if (!check.ok) throw new AuthError("weak_password", check.reason);

  const { hash, salt } = await hashPassword(newPassword);

  getDb()
    .prepare(
      `UPDATE users SET password_hash = ?, password_salt = ?,
         must_change_password = 1, updated_at = ? WHERE uid = ?`
    )
    .run(hash, salt, now(), uid);

  destroyAllSessions(uid);
  return publicUser(findByUid(uid));
}

function setActive(uid, isActive) {
  getDb()
    .prepare("UPDATE users SET is_active = ?, updated_at = ? WHERE uid = ?")
    .run(isActive ? 1 : 0, now(), uid);

  if (!isActive) destroyAllSessions(uid);

  return publicUser(findByUid(uid));
}

/** Pwofil konplè: itilizatè + antrepriz li. */
function profileOf(uid) {
  const user = findByUid(uid);
  if (!user) return null;

  const membership = getDb()
    .prepare(
      `SELECT * FROM enterprise_users
        WHERE uid = ? AND is_active = 1 LIMIT 1`
    )
    .get(uid);

  return {
    ...publicUser(user),
    enterpriseId: membership?.enterprise_id ?? "",
    enterpriseName: membership?.enterprise_name ?? "",
  };
}

module.exports = {
  AuthError,
  ROLES,
  createUser,
  authenticate,
  changePassword,
  resetPasswordAsAdmin,
  setActive,
  findByEmail,
  findByUid,
  countUsers,
  profileOf,
  publicUser,
  normalizeEmail,
};
