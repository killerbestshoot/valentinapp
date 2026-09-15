"use strict";

/**
 * Itilizatè / staff — ranplase koleksyon `users` ak `enterprise_users`.
 *
 *   GET   /api/users              lis staff antrepriz la (ak sòld yo)
 *   GET   /api/users/:uid
 *   POST  /api/users              kreye yon staff (owner/admin)
 *   PATCH /api/users/:uid         aktive / dezaktive / chanje wòl
 *   POST  /api/users/:uid/password  admin reinisyalize yon modpas
 *
 * Kreye yon kont PA konekte moun k ap kreye l la — kontrèman ak Firebase Auth.
 */

const express = require("express");

const { getDb, now } = require("../db/db");
const users = require("../auth/users");
const { requireAuth, requireRole, requireEnterprise } = require("../auth/middleware");
const { money } = require("../../../bazik/index.js");

const router = express.Router();

/**
 * Nivo yerachi a. Yon moun pa ka bay, ni modifye, yon wòl ki egal oswa pi wo
 * pase pa li.
 *
 * Anvan, yon admin te ka fè `PATCH` sou PWÒP uid li ak `role: "owner"`, epi
 * dezaktive owner lejitim nan. Sèl auto-DEZAKTIVASYON te bloke, pa
 * auto-PROMOSYON.
 */
const RANK = { owner: 3, administrator: 2, admin: 2, agent: 1, client: 0 };

function rankOf(role) {
  return RANK[String(role || "").toLowerCase()] ?? -1;
}

function send(res, err) {
  const status = err.status || 400;
  if (status >= 500) console.error("[users]", err);

  return res.status(status).json({
    ok: false,
    code: err.code || "error",
    message: err.message,
  });
}

/** Staff + sòld wallet li, nan yon sèl rekèt. */
function listStaff(enterpriseId) {
  return getDb()
    .prepare(
      `SELECT u.uid, u.email, u.display_name, u.role, u.is_active,
              u.last_login_at, u.created_at,
              eu.enterprise_id, eu.enterprise_name,
              w.balance_minor, w.currency
         FROM enterprise_users eu
         JOIN users u ON u.uid = eu.uid
         LEFT JOIN wallets w ON w.id = eu.enterprise_id || '_' || eu.uid
        WHERE eu.enterprise_id = ? AND eu.is_active = 1
        ORDER BY u.created_at ASC`
    )
    .all(enterpriseId)
    .map((row) => ({
      uid: row.uid,
      email: row.email,
      displayName: row.display_name,
      role: row.role,
      isActive: row.is_active === 1,
      enterpriseId: row.enterprise_id,
      enterpriseName: row.enterprise_name,
      balance: money.fromMinor(row.balance_minor || 0),
      currency: row.currency || "USD",
      lastLoginAt: row.last_login_at,
      createdAt: row.created_at,
    }));
}

// Lis la gen sòld tout staff la: se yon enfòmasyon jesyon, pa yon ajan.
router.get("/", requireAuth, requireEnterprise, requireRole("owner", "admin"), (req, res) => {
  try {
    const all = listStaff(req.user.enterpriseId);
    const role = String(req.query.role || "").trim();

    return res.json({
      ok: true,
      users: role ? all.filter((u) => u.role === role) : all,
    });
  } catch (err) {
    return send(res, err);
  }
});

router.get("/:uid", requireAuth, requireEnterprise, requireRole("owner", "admin"), (req, res) => {
  try {
    const found = listStaff(req.user.enterpriseId).find((u) => u.uid === req.params.uid);
    if (!found) return res.status(404).json({ ok: false, code: "not_found" });

    return res.json({ ok: true, user: found });
  } catch (err) {
    return send(res, err);
  }
});

router.post(
  "/",
  requireAuth,
  requireEnterprise,
  requireRole("owner", "admin"),
  async (req, res) => {
    try {
      const body = req.body || {};
      const role = String(body.role || "agent");

      if (rankOf(role) >= rankOf(req.user.role)) {
        return send(res, {
          status: 403,
          code: "role_too_high",
          message: "Ou pa ka kreye yon kont ak yon wòl egal oswa pi wo pase pa ou.",
        });
      }

      const created = await users.createUser({
        email: body.email,
        password: body.password,
        displayName: String(body.displayName || "").trim(),
        role,
        // Antrepriz la soti nan sesyon an: yon admin pa ka mete yon staff nan
        // yon lòt antrepriz.
        enterpriseId: req.user.enterpriseId,
        enterpriseName: req.user.enterpriseName,
        createdBy: req.user.uid,
        mustChangePassword: body.mustChangePassword !== false,
        // Deviz wallet la. Pa default: deviz antrepriz la.
        currency: body.currency || req.user.walletCurrency || "USD",
      });

      return res.json({ ok: true, user: created });
    } catch (err) {
      return send(res, err);
    }
  }
);

router.patch(
  "/:uid",
  requireAuth,
  requireEnterprise,
  requireRole("owner", "admin"),
  (req, res) => {
    try {
      const target = listStaff(req.user.enterpriseId).find(
        (u) => u.uid === req.params.uid
      );
      if (!target) return res.status(404).json({ ok: false, code: "not_found" });

      if (target.uid === req.user.uid) {
        return send(res, {
          status: 403,
          code: "cannot_modify_self",
          message: "Ou pa ka chanje wòl ni aktivasyon pwòp kont ou.",
        });
      }

      // Yon admin pa ka touche yon owner, ni yon lòt admin.
      if (rankOf(target.role) >= rankOf(req.user.role)) {
        return send(res, {
          status: 403,
          code: "target_too_high",
          message: "Ou pa ka modifye yon kont ki gen yon wòl egal oswa pi wo pase pa ou.",
        });
      }

      if (req.body?.role && rankOf(req.body.role) >= rankOf(req.user.role)) {
        return send(res, {
          status: 403,
          code: "role_too_high",
          message: "Ou pa ka bay yon wòl egal oswa pi wo pase pa ou.",
        });
      }

      if (req.body?.isActive !== undefined) {
        users.setActive(target.uid, req.body.isActive === true);
      }

      if (req.body?.role && users.ROLES.includes(req.body.role)) {
        getDb()
          .prepare("UPDATE users SET role = ?, updated_at = ? WHERE uid = ?")
          .run(req.body.role, now(), target.uid);
        // Limite sou antrepriz la: yon moun ki manm de antrepriz pa dwe wè wòl
        // li chanje nan tou de pa yon admin ki kontwole yon sèl.
        getDb()
          .prepare("UPDATE enterprise_users SET role = ? WHERE uid = ? AND enterprise_id = ?")
          .run(req.body.role, target.uid, req.user.enterpriseId);
      }

      const updated = listStaff(req.user.enterpriseId).find(
        (u) => u.uid === req.params.uid
      );
      return res.json({ ok: true, user: updated });
    } catch (err) {
      return send(res, err);
    }
  }
);

router.post(
  "/:uid/password",
  requireAuth,
  requireEnterprise,
  requireRole("owner", "admin"),
  async (req, res) => {
    try {
      const target = listStaff(req.user.enterpriseId).find(
        (u) => u.uid === req.params.uid
      );
      if (!target) return res.status(404).json({ ok: false, code: "not_found" });

      if (target.uid !== req.user.uid && rankOf(target.role) >= rankOf(req.user.role)) {
        return send(res, {
          status: 403,
          code: "target_too_high",
          message: "Ou pa ka reinisyalize modpas yon kont ki pi wo pase pa ou.",
        });
      }

      const updated = await users.resetPasswordAsAdmin(
        target.uid,
        String(req.body?.password || "")
      );

      return res.json({ ok: true, user: updated });
    } catch (err) {
      return send(res, err);
    }
  }
);

module.exports = router;
