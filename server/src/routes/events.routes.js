"use strict";

/**
 * Kanal tan reyèl (Server-Sent Events).
 *
 *   POST /api/events/ticket   (konekte) → yon tikè yon sèl fwa, valab 60 s
 *   GET  /api/events?ticket=  → kouran evènman `change` yo
 *
 * Poukisa yon tikè: `EventSource` navigatè a pa ka voye header
 * `Authorization`, e mete jeton sesyon an nan URL la ta kite l nan log yo.
 * Tikè a sèvi yon sèl fwa epi li mouri apre 60 s.
 *
 * Kouran an fèmen poukont li lè sesyon an mouri (dekonekte, 5 minit san
 * aktivite): nou verifye sesyon an chak batman kè SAN pwolonje l.
 */

const express = require("express");
const { randomBytes, createHash } = require("node:crypto");

const { getDb } = require("../db/db");
const { requireAuth, requireEnterprise } = require("../auth/middleware");
const { subscribe } = require("../realtime/bus");

const router = express.Router();
const TICKET_TTL_MS = 60_000;
const HEARTBEAT_MS = Number(process.env.EVENTS_HEARTBEAT_MS || 20_000);
const tickets = new Map();

function readToken(req) {
  const header = String(req.get("authorization") || "");
  return header.toLowerCase().startsWith("bearer ") ? header.slice(7).trim() : "";
}

const hash = (token) => createHash("sha256").update(String(token)).digest("hex");

function sessionAlive(tokenHash) {
  return Boolean(
    getDb().prepare("SELECT 1 FROM sessions WHERE token_hash = ? AND expires_at > ?").get(tokenHash, Date.now())
  );
}

router.post("/ticket", requireAuth, requireEnterprise, (req, res) => {
  const now = Date.now();
  for (const [key, t] of tickets) if (t.exp < now) tickets.delete(key);
  const ticket = randomBytes(24).toString("hex");
  tickets.set(ticket, {
    uid: req.user.uid,
    enterpriseId: req.user.enterpriseId,
    tokenHash: hash(readToken(req)),
    exp: now + TICKET_TTL_MS,
  });
  return res.json({ ok: true, ticket, expiresIn: TICKET_TTL_MS / 1000 });
});

router.get("/", (req, res) => {
  const ticket = String(req.query.ticket || "");
  const grant = tickets.get(ticket);
  tickets.delete(ticket);
  if (!grant || grant.exp < Date.now() || !sessionAlive(grant.tokenHash)) {
    return res.status(401).json({ ok: false, code: "invalid_ticket" });
  }

  res.status(200);
  res.set({
    "Content-Type": "text/event-stream; charset=utf-8",
    "Cache-Control": "no-cache, no-transform",
    Connection: "keep-alive",
    // nginx (kontenè web la ak sèvè a) pa dwe kenbe evènman yo nan tanpon.
    "X-Accel-Buffering": "no",
  });
  res.flushHeaders?.();
  res.write("retry: 3000\n");
  res.write(`event: hello\ndata: ${JSON.stringify({ at: Date.now() })}\n\n`);

  const unsubscribe = subscribe((event) => {
    if (event.enterpriseId !== "*" && event.enterpriseId !== grant.enterpriseId) return;
    res.write(`id: ${event.id}\nevent: change\ndata: ${JSON.stringify({ topics: event.topics, at: event.at })}\n\n`);
  });

  const heartbeat = setInterval(() => {
    if (!sessionAlive(grant.tokenHash)) {
      res.write(`event: bye\ndata: {"reason":"session"}\n\n`);
      return res.end();
    }
    res.write(`: ping ${Date.now()}\n\n`);
  }, HEARTBEAT_MS);
  heartbeat.unref?.();

  req.on("close", () => {
    clearInterval(heartbeat);
    unsubscribe();
  });
});

module.exports = router;
module.exports._tickets = tickets;
