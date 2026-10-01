"use strict";

/**
 * Wout otantifikasyon.
 *
 *   POST /api/auth/bootstrap   premye owner la (sèlman si baz la vid)
 *   POST /api/auth/login
 *   POST /api/auth/logout
 *   GET  /api/auth/me
 *   POST /api/auth/change-password
 */

const express = require("express");

const users = require("../auth/users");
const { createSession, destroySession } = require("../auth/sessions");
const { requireAuth, readToken } = require("../auth/middleware");
const { getDb, now } = require("../db/db");
const AppIds = require("../../../bazik/src/ids");

const router = express.Router();

function send(res, err) {
  const status = err.status || 500;
  if (status >= 500) console.error("[auth]", err);

  return res.status(status).json({
    ok: false,
    code: err.code || "internal_error",
    message: err.message,
  });
}

/** Ti frein kont fòs brit, pa adrès imel. */
const attempts = new Map();
const MAX_ATTEMPTS = 8;
const WINDOW_MS = 10 * 60 * 1000;

function throttle(email) {
  const key = users.normalizeEmail(email);
  const record = attempts.get(key);
  const current = Date.now();

  if (!record || current - record.first > WINDOW_MS) {
    attempts.set(key, { count: 1, first: current });
    return { allowed: true };
  }

  record.count += 1;

  if (record.count > MAX_ATTEMPTS) {
    const waitMs = WINDOW_MS - (current - record.first);
    return { allowed: false, retryAfterSeconds: Math.ceil(waitMs / 1000) };
  }

  return { allowed: true };
}

function clearThrottle(email) {
  attempts.delete(users.normalizeEmail(email));
}

/**
 * Premye demaraj: kreye owner la ak antrepriz li.
 *
 * Li mache SÈLMAN si pa gen okenn itilizatè. San sa, nenpòt moun ta ka rele l
 * pou l ba tèt li yon kont owner.
 */
router.post("/bootstrap", async (req, res) => {
  try {
    if (users.countUsers() > 0) {
      return res.status(409).json({
        ok: false,
        code: "already_bootstrapped",
        message: "Sistèm nan deja gen itilizatè. Sèvi ak /login.",
      });
    }

    const body = req.body || {};
    const enterpriseName = String(body.enterpriseName || "VOUPVAPCASH").trim();
    const enterpriseId = AppIds.enterprise(`${enterpriseName}:${Date.now()}`);

    getDb()
      .prepare(
        `INSERT INTO enterprises
          (enterprise_id, name, owner_uid, currency, is_active, created_at, updated_at)
         VALUES (?, ?, '', ?, 1, ?, ?)`
      )
      .run(enterpriseId, enterpriseName, body.currency || "USD", now(), now());

    const owner = await users.createUser({
      email: body.email,
      password: body.password,
      displayName: String(body.displayName || "Owner").trim(),
      role: "owner",
      enterpriseId,
      enterpriseName,
      createdBy: "bootstrap",
    });

    getDb()
      .prepare("UPDATE enterprises SET owner_uid = ?, updated_at = ? WHERE enterprise_id = ?")
      .run(owner.uid, now(), enterpriseId);

    const session = createSession(owner.uid, { userAgent: req.header("user-agent") || "" });

    return res.json({
      ok: true,
      user: users.profileOf(owner.uid),
      token: session.token,
      expiresAt: session.expiresAt,
      idleTimeoutMs: session.idleTimeoutMs,
    });
  } catch (err) {
    return send(res, err);
  }
});

/**
 * Enskripsyon libè pou yon ajan: li kreye kont la san sesyon, epi li rete
 * `is_active = 0` jiskaske yon owner (oswa admin) apwouve l nan ekran Agents.
 *
 * Nou tache ajan an sou PREMYE antrepriz ki egziste a. Si pa gen okenn
 * (sistèm pa bootstrap toujou), nou refize ak yon mesaj klè.
 */
router.post("/register-agent", async (req, res) => {
  try {
    const body = req.body || {};
    const email = String(body.email || "");

    const gate = throttle(email);
    if (!gate.allowed) {
      return res.status(429).json({
        ok: false,
        code: "too_many_attempts",
        message: `Twòp tantativ. Tann ${gate.retryAfterSeconds} segond.`,
        retryAfterSeconds: gate.retryAfterSeconds,
      });
    }

    const enterprise = getDb()
      .prepare(
        `SELECT enterprise_id, name FROM enterprises
          WHERE is_active = 1 ORDER BY created_at ASC LIMIT 1`
      )
      .get();

    if (!enterprise) {
      return res.status(409).json({
        ok: false,
        code: "no_enterprise",
        message:
          "Sistèm nan poko konfigire. Owner an dwe kreye antrepriz la anvan.",
      });
    }

    await users.createUser({
      email,
      password: String(body.password || ""),
      displayName: String(body.displayName || "").trim(),
      role: "agent",
      enterpriseId: enterprise.enterprise_id,
      enterpriseName: enterprise.name,
      createdBy: "self_register",
      mustChangePassword: false,
      currency: String(body.currency || "USD").toUpperCase(),
      // Kont lan rete bloke jiskaske yon owner apwouve l nan ekran Agents.
      isActive: false,
    });

    return res.json({
      ok: true,
      pending: true,
      message:
        "Kont ou kreye. Yon owner dwe apwouve l anvan ou ka konekte.",
    });
  } catch (err) {
    return send(res, err);
  }
});

router.post("/login", async (req, res) => {
  const email = String(req.body?.email || "");
  const password = String(req.body?.password || "");

  const gate = throttle(email);
  if (!gate.allowed) {
    return res.status(429).json({
      ok: false,
      code: "too_many_attempts",
      message: `Twòp tantativ. Tann ${gate.retryAfterSeconds} segond.`,
      retryAfterSeconds: gate.retryAfterSeconds,
    });
  }

  try {
    const user = await users.authenticate(email, password);
    clearThrottle(email);

    const session = createSession(user.uid, {
      userAgent: req.header("user-agent") || "",
    });

    return res.json({
      ok: true,
      user: users.profileOf(user.uid),
      token: session.token,
      expiresAt: session.expiresAt,
      idleTimeoutMs: session.idleTimeoutMs,
    });
  } catch (err) {
    return send(res, err);
  }
});

router.post("/logout", (req, res) => {
  destroySession(readToken(req));
  return res.json({ ok: true });
});

router.get("/me", requireAuth, (req, res) => {
  return res.json({
    ok: true,
    user: req.user,
    expiresAt: req.session?.expiresAt,
    idleTimeoutMs: req.session?.idleTimeoutMs,
  });
});

router.post("/change-password", requireAuth, async (req, res) => {
  try {
    const user = await users.changePassword(req.user.uid, {
      currentPassword: String(req.body?.currentPassword || ""),
      newPassword: String(req.body?.newPassword || ""),
    });

    // Tout sesyon yo tonbe: moun nan dwe konekte ankò.
    return res.json({ ok: true, user, message: 'Modpas chanje. Konekte ankò.' });
  } catch (err) {
    return send(res, err);
  }
});

module.exports = router;
