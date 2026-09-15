"use strict";

/**
 * Pwoteksyon wout yo.
 *
 * Diferans ak ansyen serveur dev la: `x-dev-uid` pa egziste ankò. Idantite a
 * soti nan yon jeton sesyon, e kliyan an pa ka envante l.
 */

const { resolveSession } = require("./sessions");
const { profileOf } = require("./users");

function readToken(req) {
  const header = String(req.header("authorization") || "");
  if (header.toLowerCase().startsWith("bearer ")) {
    return header.slice(7).trim();
  }
  return "";
}

/** Mete `req.user` si jeton an bon. Li pa bloke anyen. */
function attachUser(req, res, next) {
  const session = resolveSession(readToken(req));
  req.user = session ? profileOf(session.uid) : null;
  next();
}

/** Bloke si moun nan pa konekte. */
function requireAuth(req, res, next) {
  if (!req.user) {
    return res.status(401).json({
      ok: false,
      code: "unauthenticated",
      message: "Ou dwe konekte.",
    });
  }
  next();
}

/**
 * Bloke si wòl la pa nan lis la.
 *
 *   router.post("/x", requireAuth, requireRole("owner", "admin"), handler)
 */
function requireRole(...roles) {
  const allowed = new Set(roles.flat());

  return (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({
        ok: false,
        code: "unauthenticated",
        message: "Ou dwe konekte.",
      });
    }

    // `admin` ak `administrator` se menm bagay nan done ki egziste yo.
    const role = req.user.role === "administrator" ? "admin" : req.user.role;
    const normalized = new Set(
      [...allowed].map((r) => (r === "administrator" ? "admin" : r))
    );

    if (!normalized.has(role)) {
      return res.status(403).json({
        ok: false,
        code: "forbidden",
        message: `Aksyon sa a mande wòl: ${[...allowed].join(", ")}.`,
      });
    }

    next();
  };
}

/** Bloke si moun nan pa nan yon antrepriz (tout mouvman lajan mande sa). */
function requireEnterprise(req, res, next) {
  if (!req.user?.enterpriseId) {
    return res.status(403).json({
      ok: false,
      code: "no_enterprise",
      message: "Itilizatè sa a pa nan okenn antrepriz aktif.",
    });
  }
  next();
}

module.exports = { attachUser, requireAuth, requireRole, requireEnterprise, readToken };
