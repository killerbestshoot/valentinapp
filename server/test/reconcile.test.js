"use strict";

/**
 * Rekonsilyasyon: pasaj otomatik la, ak desizyon manyèl owner a sou transfè
 * Bazik ki pa ka rekonsilye otomatikman (repons pèdi, pa gen ID Bazik).
 */

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const express = require("express");

const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), "reconcile-test-"));
process.env.APP_DB_PATH = path.join(tempDir, "app.db");
process.env.BAZIK_MODE = "fake";

const db = require("../src/db/db");
const users = require("../src/auth/users");
const { createSession } = require("../src/auth/sessions");
const { attachUser } = require("../src/auth/middleware");
const bazikRoutes = require("../src/routes/bazik.routes");
const { getBazikService } = require("../src/bazik_service");
const { createReconcileJob } = require("../src/jobs/reconcile_job");
const { BazikError } = require("../../bazik/index.js");

const ENT = "ENT_RECON";
let server;
let baseUrl;
const tokens = {};
let agent;

test.before(async () => {
  db.getDb()
    .prepare(
      `INSERT INTO enterprises (enterprise_id, name, owner_uid, currency, is_active, created_at, updated_at)
       VALUES (?, 'R', '', 'USD', 1, ?, ?)`
    )
    .run(ENT, Date.now(), Date.now());
  for (const role of ["owner", "admin", "agent"]) {
    const user = await users.createUser({
      email: `${role}@recon.test`, password: "modpas-solid-2026", role, enterpriseId: ENT, enterpriseName: "R",
    });
    tokens[role] = createSession(user.uid).token;
    if (role === "agent") agent = user;
  }
  const app = express();
  app.use(express.json());
  app.use(attachUser);
  app.use("/api/bazik", bazikRoutes);
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

async function call(method, route, { role, body } = {}) {
  const r = await fetch(`${baseUrl}${route}`, {
    method,
    headers: { "content-type": "application/json", ...(role ? { authorization: `Bearer ${tokens[role]}` } : {}) },
    ...(body ? { body: JSON.stringify(body) } : {}),
  });
  return { status: r.status, json: await r.json() };
}

const balance = async () =>
  (await getBazikService().store.getWallet({ uid: agent.uid, enterpriseId: ENT }))?.balanceMinor ?? 0;

let seq = 0;
/** Yon transfè ki "pèdi": wallet debite, pa gen ID Bazik, make verifikasyon manyèl. */
async function lostTransfer({ txStatus = "pending" } = {}) {
  const service = getBazikService();
  seq += 1;
  if (seq === 1) {
    await service.store.creditWallet({
      uid: agent.uid, enterpriseId: ENT, enterpriseName: "R", role: "agent", amountMinor: 1_000_000,
      currency: "USD", type: "seed", note: "seed", idempotencyKey: "seed:recon",
    });
  }
  const txId = `TX_RECON_${seq}`;
  db.getDb()
    .prepare(
      `INSERT INTO transactions (tx_id, enterprise_id, staff_uid, staff_role, client_name, phone, service,
         amount_minor, currency, status, gateway_ref, commission_applied, created_at, updated_at)
       VALUES (?, ?, ?, 'agent', 'Junette', '+50948465325', 'MonCash', 10000, 'USD', ?, '', 0, ?, ?)`
    )
    .run(txId, ENT, agent.uid, txStatus, Date.now(), Date.now());

  const real = service.client.createTransfer;
  service.client.createTransfer = async () => {
    throw new BazikError("network_error", "timeout", { retryable: true });
  };
  try {
    await service.transfers.send({
      kind: "delivery", network: "moncash", amountMinor: 10000, currency: "USD", uid: agent.uid,
      enterpriseId: ENT, phone: "+50948465325", receiverName: "Junette", txId, idempotencySeed: `tx:${txId}`,
    });
  } catch {
    // transfer_pending_verification: sa nou vle a
  } finally {
    service.client.createTransfer = real;
  }
  const row = service.store._db.prepare("SELECT transfer_id FROM bazik_transfers WHERE tx_id = ?").get(txId);
  // Fè l "vye" (plis pase 15 minit) epi kite pasaj otomatik la make l.
  service.store._db.prepare("UPDATE bazik_transfers SET created_at = created_at - 3600000 WHERE transfer_id = ?").run(row.transfer_id);
  await service.transfers.refresh(row.transfer_id);
  return { transferId: row.transfer_id, txId };
}

test("pasaj otomatik: pa janm de an menm tan, erè yon etap pa bloke lòt yo", async () => {
  let calls = 0;
  let release;
  const job = createReconcileJob({
    intervalMs: 0,
    bazik: () => ({ transfers: { pollPending: async () => { calls += 1; await new Promise((r) => { release = r; }); return []; } } }),
    airtime: () => { throw new Error("reloadly down"); },
    commissions: async () => [{ status: "applied" }],
    log: { log() {}, error() {} },
  });
  const first = job.runOnce();
  await new Promise((r) => setImmediate(r));
  assert.deepEqual(await job.runOnce(), { skipped: true });
  release();
  const result = await first;
  assert.equal(calls, 1);
  assert.equal(result.commissions, 1);
  assert.match(result.errors.join(), /reloadly down/);
  assert.equal(job.start(), false, "intervalMs 0 = dezaktive");
});

test("lis pou verifye: transfè pèdi a parèt ak verifikasyon manyèl", async () => {
  const lost = await lostTransfer();
  const { status, json } = await call("GET", "/api/bazik/transfers/review", { role: "admin" });

  assert.equal(status, 200, JSON.stringify(json));
  const row = json.transfers.find((t) => t.transferId === lost.transferId);
  assert.ok(row);
  assert.equal(row.manualReview, true);
  assert.equal(row.phone, "+50948465325");
  assert.equal(row.receiverName, "Junette");
});

test("make echwe: ajan an ranbouse, tras la anrejistre, yon sèl fwa", async () => {
  const lost = await lostTransfer();
  const before = await balance();

  const noNote = await call("POST", `/api/bazik/transfers/${lost.transferId}/resolve`, { role: "owner", body: { action: "failed" } });
  assert.equal(noNote.json.code, "note_required");
  const asAdmin = await call("POST", `/api/bazik/transfers/${lost.transferId}/resolve`, { role: "admin", body: { action: "failed", note: "pa sou dashboard" } });
  assert.equal(asAdmin.status, 403, "owner sèlman");

  const ok = await call("POST", `/api/bazik/transfers/${lost.transferId}/resolve`, {
    role: "owner", body: { action: "failed", note: "Pa parèt sou dashboard Bazik la" },
  });
  assert.equal(ok.status, 200, JSON.stringify(ok.json));
  assert.equal(ok.json.transfer.status, "failed");
  assert.ok(ok.json.refunded);
  assert.ok(await balance() > before, "wallet la ranbouse");
  assert.equal(db.getDb().prepare("SELECT status FROM transactions WHERE tx_id = ?").get(lost.txId).status, "failed");
  const trace = db.getDb().prepare("SELECT * FROM transfer_resolutions WHERE transfer_id = ?").get(lost.transferId);
  assert.equal(trace.action, "failed");
  assert.match(trace.note, /dashboard/);

  const again = await call("POST", `/api/bazik/transfers/${lost.transferId}/resolve`, {
    role: "owner", body: { action: "failed", note: "dezyèm fwa" },
  });
  assert.equal(again.status, 409);
});

test("konfime livre: ID Bazik obligatwa, Bazik dwe di completed", async () => {
  const lost = await lostTransfer();
  const service = getBazikService();
  const realStatus = service.client.transferStatus;
  service.client.transferStatus = async (id) => {
    if (id === "BZK_OK") return { gatewayId: id, status: "completed" };
    if (id === "BZK_PENDING") return { gatewayId: id, status: "processing" };
    throw new BazikError("not_found", "Transfer not found", { status: 404 });
  };
  try {
    const noId = await call("POST", `/api/bazik/transfers/${lost.transferId}/resolve`, { role: "owner", body: { action: "completed", note: "wè l sou dashboard" } });
    assert.equal(noId.json.code, "gateway_id_required");
    const unknown = await call("POST", `/api/bazik/transfers/${lost.transferId}/resolve`, { role: "owner", body: { action: "completed", gatewayId: "BZK_X", note: "wè l sou dashboard" } });
    assert.equal(unknown.json.code, "gateway_id_unknown");
    const notDone = await call("POST", `/api/bazik/transfers/${lost.transferId}/resolve`, { role: "owner", body: { action: "completed", gatewayId: "BZK_PENDING", note: "wè l sou dashboard" } });
    assert.equal(notDone.json.code, "bazik_not_completed");
    const failedButPaid = await call("POST", `/api/bazik/transfers/${lost.transferId}/resolve`, { role: "owner", body: { action: "failed", gatewayId: "BZK_OK", note: "erè ajan an" } });
    assert.equal(failedButPaid.json.code, "bazik_completed", "pa ka ranbouse yon lajan ki pati");

    const before = await balance();
    const ok = await call("POST", `/api/bazik/transfers/${lost.transferId}/resolve`, { role: "owner", body: { action: "completed", gatewayId: "BZK_OK", note: "Wè l sou dashboard Bazik la" } });
    assert.equal(ok.status, 200, JSON.stringify(ok.json));
    assert.equal(ok.json.transfer.status, "completed");
    assert.equal(ok.json.refunded, null);
    const refunds = db.getDb()
      .prepare("SELECT COUNT(*) AS n FROM wallet_ledger WHERE source_id = ? AND type LIKE '%refund%'")
      .get(lost.transferId).n;
    assert.equal(refunds, 0, "pa ranbouse: lajan an pati");
    assert.equal(await balance() - before, 1000, "sèlman komisyon ajan an (10% legacy) lè l livre");
    assert.equal(db.getDb().prepare("SELECT status FROM transactions WHERE tx_id = ?").get(lost.txId).status, "delivered");
  } finally {
    service.client.transferStatus = realStatus;
  }
});

test("tranzaksyon make livre pa erè: refize san konfimasyon, epi komisyon yo anile", async () => {
  const lost = await lostTransfer({ txStatus: "delivered" });
  const r = await call("POST", `/api/bazik/transfers/${lost.transferId}/resolve`, {
    role: "owner", body: { action: "failed", note: "pa sou dashboard" },
  });
  assert.equal(r.status, 409);
  assert.equal(r.json.code, "transaction_delivered");

  // Komisyon yo te peye lè yo te make l livre alamen.
  const { applyCommissionToTx } = require("../src/commission/engine");
  await applyCommissionToTx(lost.txId);
  const log = db.getDb().prepare("SELECT agent_credit_minor FROM commission_logs WHERE tx_id = ?").get(lost.txId);
  assert.ok(log.agent_credit_minor > 0);
  const before = await balance();

  const ok = await call("POST", `/api/bazik/transfers/${lost.transferId}/resolve`, {
    role: "owner", body: { action: "failed", note: "pa sou dashboard Bazik", reverseCommissions: true },
  });
  assert.equal(ok.status, 200, JSON.stringify(ok.json));
  assert.equal(ok.json.commissionsReversed[0].who, "agent");
  const debit = db.getDb().prepare("SELECT debit_minor FROM bazik_transfers WHERE transfer_id = ?").get(lost.transferId).debit_minor;
  assert.equal(await balance() - before, debit - log.agent_credit_minor, "ranbouse debi a, mwens komisyon an");
  assert.equal(db.getDb().prepare("SELECT status FROM transactions WHERE tx_id = ?").get(lost.txId).status, "failed");
  assert.ok(db.getDb().prepare("SELECT reversed_at FROM commission_logs WHERE tx_id = ?").get(lost.txId).reversed_at);
});
