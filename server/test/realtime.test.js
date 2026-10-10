"use strict";

/** Kanal tan reyèl: tikè, izolasyon antrepriz, evènman apre chanjman, fèmen lè sesyon an mouri. */

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const express = require("express");

const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), "realtime-test-"));
process.env.APP_DB_PATH = path.join(tempDir, "app.db");
process.env.EVENTS_HEARTBEAT_MS = "150";

const db = require("../src/db/db");
const users = require("../src/auth/users");
const { createSession, destroySession } = require("../src/auth/sessions");
const { attachUser } = require("../src/auth/middleware");
const { publishMutations, listenerCount } = require("../src/realtime/bus");
const eventsRoutes = require("../src/routes/events.routes");

let server;
let baseUrl;
const tokens = {};

test.before(async () => {
  for (const ent of ["ENT_A", "ENT_B"]) {
    db.getDb()
      .prepare(`INSERT INTO enterprises (enterprise_id, name, owner_uid, currency, is_active, created_at, updated_at) VALUES (?, ?, '', 'USD', 1, ?, ?)`)
      .run(ent, ent, Date.now(), Date.now());
  }
  for (const [key, ent] of [["a", "ENT_A"], ["a2", "ENT_A"], ["b", "ENT_B"]]) {
    const u = await users.createUser({ email: `${key}@rt.test`, password: "modpas-solid-2026", role: "agent", enterpriseId: ent, enterpriseName: ent });
    tokens[key] = createSession(u.uid).token;
  }
  const app = express();
  app.use(express.json());
  app.use(attachUser);
  app.use(publishMutations);
  app.use("/api/events", eventsRoutes);
  app.post("/api/transactions", (req, res) => res.json({ ok: true }));
  app.post("/api/transactions/fail", (req, res) => res.status(400).json({ ok: false }));
  app.post("/api/transactions/quote", (req, res) => res.json({ ok: true }));
  server = await new Promise((resolve) => {
    const s = app.listen(0, "127.0.0.1", () => resolve(s));
  });
  baseUrl = `http://127.0.0.1:${server.address().port}`;
});

test.after(() => {
  server?.close();
  db.resetDb();
  fs.rmSync(tempDir, { recursive: true, force: true });
});

const ticketFor = async (key) =>
  (await (await fetch(`${baseUrl}/api/events/ticket`, { method: "POST", headers: { authorization: `Bearer ${tokens[key]}` } })).json()).ticket;

/** Louvri kouran an; `next(name)` tann evènman sa a (oswa null apre `ms`). */
async function open(key) {
  const controller = new AbortController();
  const res = await fetch(`${baseUrl}/api/events?ticket=${await ticketFor(key)}`, { signal: controller.signal });
  assert.equal(res.status, 200);
  assert.match(res.headers.get("content-type"), /text\/event-stream/);
  assert.equal(res.headers.get("x-accel-buffering"), "no");
  const reader = res.body.getReader();
  const decoder = new TextDecoder();
  let buffer = "";
  let ended = false;
  const events = [];
  (async () => {
    try {
      for (;;) {
        const { value, done } = await reader.read();
        if (done) break;
        buffer += decoder.decode(value, { stream: true });
        let i;
        while ((i = buffer.indexOf("\n\n")) >= 0) {
          const block = buffer.slice(0, i);
          buffer = buffer.slice(i + 2);
          const name = /^event: (.+)$/m.exec(block)?.[1];
          const data = /^data: (.+)$/m.exec(block)?.[1];
          if (name) events.push({ name, data: data ? JSON.parse(data) : null });
        }
      }
    } catch {
      // abort
    } finally {
      ended = true;
    }
  })();
  const next = async (name, ms = 1500) => {
    const start = Date.now();
    while (Date.now() - start < ms) {
      const i = events.findIndex((e) => e.name === name);
      if (i >= 0) return events.splice(i, 1)[0];
      await new Promise((r) => setTimeout(r, 20));
    }
    return null;
  };
  return { next, close: () => controller.abort(), ended: () => ended };
}

test("tikè: obligatwa, yon sèl fwa", async () => {
  assert.equal((await fetch(`${baseUrl}/api/events/ticket`, { method: "POST" })).status, 401);
  assert.equal((await fetch(`${baseUrl}/api/events?ticket=nope`)).status, 401);
  const t = await ticketFor("a");
  const first = await fetch(`${baseUrl}/api/events?ticket=${t}`);
  assert.equal(first.status, 200);
  await first.body.cancel();
  assert.equal((await fetch(`${baseUrl}/api/events?ticket=${t}`)).status, 401, "tikè a deja sèvi");
});

test("yon chanjman rive sou ekran menm antrepriz la, pa sou lòt la", async () => {
  const a2 = await open("a2");
  const b = await open("b");
  assert.ok(await a2.next("hello"));
  assert.ok(await b.next("hello"));

  await fetch(`${baseUrl}/api/transactions`, { method: "POST", headers: { authorization: `Bearer ${tokens.a}` } });
  const ev = await a2.next("change");
  assert.ok(ev, "evènman an rive");
  assert.deepEqual(ev.data.topics, ["transactions"]);
  assert.equal(await b.next("change", 400), null, "lòt antrepriz la pa wè anyen");

  await fetch(`${baseUrl}/api/transactions/fail`, { method: "POST", headers: { authorization: `Bearer ${tokens.a}` } });
  assert.equal(await a2.next("change", 400), null, "yon erè pa pibliye anyen");

  await fetch(`${baseUrl}/api/transactions/quote`, { method: "POST", headers: { authorization: `Bearer ${tokens.a}` } });
  assert.equal(await a2.next("change", 400), null, "yon devi pa chanje anyen: pa gen siyal");

  a2.close();
  b.close();
  await new Promise((r) => setTimeout(r, 100));
  assert.equal(listenerCount(), 0, "koneksyon fèmen = abònman libere");
});

test("webhook san itilizatè: tout antrepriz rechaje", async () => {
  const b = await open("b");
  await b.next("hello");
  const { publish } = require("../src/realtime/bus");
  publish("*", ["transfers"]);
  assert.ok(await b.next("change"));
  b.close();
});

test("sesyon an mouri: kouran an fèmen", async () => {
  const u = await users.createUser({ email: "c@rt.test", password: "modpas-solid-2026", role: "agent", enterpriseId: "ENT_A", enterpriseName: "A" });
  tokens.c = createSession(u.uid).token;
  const c = await open("c");
  await c.next("hello");
  destroySession(tokens.c);
  assert.ok(await c.next("bye", 1500), "sèvè a di orevwa");
  await new Promise((r) => setTimeout(r, 100));
  assert.equal(c.ended(), true);
});
