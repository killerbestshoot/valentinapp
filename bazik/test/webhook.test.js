"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const { createHmac } = require("node:crypto");

const { makeService, seedAgent, balanceOf } = require("./helpers");

const USD = (amount) => Math.round(amount * 100);
const SECRET = "whsec_test_secret";

function sign(body) {
  return createHmac("sha256", SECRET).update(body).digest("hex");
}

async function makeProcessingTransfer(service) {
  const agent = await seedAgent(service.store, { balanceMinor: USD(500) });
  const { transfer } = await service.transfers.send({
    network: "moncash",
    amountMinor: USD(10),
    uid: agent.uid,
    enterpriseId: agent.enterpriseId,
    phone: "37123456",
    idempotencySeed: `wh-${Math.random()}`,
  });
  return { agent, transfer };
}

test("webhook san siyati valid refize", async (t) => {
  const { service } = makeService();
  t.after(() => service.close());

  const body = JSON.stringify({ eventId: "evt1", data: { referenceId: "X", status: "completed" } });

  await assert.rejects(
    service.webhooks.handle({ rawBody: body, headers: { "x-bazik-signature": "pa-bon" } }),
    { code: "webhook_signature_invalid" }
  );

  await assert.rejects(service.webhooks.handle({ rawBody: body, headers: {} }), {
    code: "webhook_signature_missing",
  });
});

test("webhook 'completed' fèmen transfè a", async (t) => {
  const { service } = makeService();
  t.after(() => service.close());

  const { transfer } = await makeProcessingTransfer(service);

  const body = JSON.stringify({
    eventId: "evt_ok_1",
    event: "transfer.updated",
    data: { referenceId: transfer.reference, transactionId: "trf_x", status: "completed" },
  });

  const result = await service.webhooks.handle({
    rawBody: body,
    headers: { "x-bazik-signature": sign(body) },
  });

  assert.equal(result.status, "settled");
  const updated = await service.store.getTransfer(transfer.transferId);
  assert.equal(updated.status, "completed");
});

test("menm evènman voye 2 fwa = yon sèl tretman", async (t) => {
  const { service } = makeService();
  t.after(() => service.close());

  const { agent, transfer } = await makeProcessingTransfer(service);
  const afterDebit = await balanceOf(service.store, agent);

  const body = JSON.stringify({
    eventId: "evt_dup_1",
    data: { referenceId: transfer.reference, transactionId: "trf_y", status: "failed" },
  });
  const headers = { "x-bazik-signature": sign(body) };

  const first = await service.webhooks.handle({ rawBody: body, headers });
  const second = await service.webhooks.handle({ rawBody: body, headers });

  assert.equal(first.status, "settled");
  assert.equal(first.refunded, true);
  assert.equal(second.status, "duplicate", "dezyèm nan pa dwe retrete anyen");

  // Kritik: yon sèl ranbousman, menm ak 2 webhook.
  assert.equal(await balanceOf(service.store, agent), afterDebit + transfer.debitMinor);
});

test("de webhook diferan sou menm transfè a: dezyèm nan pa ka ranbouse 2 fwa", async (t) => {
  const { service } = makeService();
  t.after(() => service.close());

  const { agent, transfer } = await makeProcessingTransfer(service);
  const afterDebit = await balanceOf(service.store, agent);

  for (const eventId of ["evt_a", "evt_b"]) {
    const body = JSON.stringify({
      eventId,
      data: { referenceId: transfer.reference, transactionId: "trf_z", status: "failed" },
    });
    await service.webhooks.handle({ rawBody: body, headers: { "x-bazik-signature": sign(body) } });
  }

  assert.equal(
    await balanceOf(service.store, agent),
    afterDebit + transfer.debitMinor,
    "idempotans lan chita sou transfè a tou, pa sèlman sou eventId"
  );
});

test("webhook sou yon referans nou pa konnen: nou akize resepsyon san nou pa kraze", async (t) => {
  const { service } = makeService();
  t.after(() => service.close());

  const body = JSON.stringify({
    eventId: "evt_unknown",
    data: { referenceId: "TRF_pa-nan-baz-la", status: "completed" },
  });

  const result = await service.webhooks.handle({
    rawBody: body,
    headers: { "x-bazik-signature": sign(body) },
  });

  assert.equal(result.status, "ignored");
  assert.equal(result.reason, "unknown_reference");
});

test("webhook entèmedyè (processing) pa fèmen anyen", async (t) => {
  const { service } = makeService();
  t.after(() => service.close());

  const { transfer } = await makeProcessingTransfer(service);

  const body = JSON.stringify({
    eventId: "evt_mid",
    data: { referenceId: transfer.reference, status: "processing" },
  });

  const result = await service.webhooks.handle({
    rawBody: body,
    headers: { "x-bazik-signature": sign(body) },
  });

  assert.equal(result.status, "acknowledged");
  const updated = await service.store.getTransfer(transfer.transferId);
  assert.equal(updated.status, "processing");
});

test("siyati ak fòma 't=...,v1=...' aksepte tou", async (t) => {
  const { service } = makeService();
  t.after(() => service.close());

  const { transfer } = await makeProcessingTransfer(service);
  const body = JSON.stringify({
    eventId: "evt_fmt",
    data: { referenceId: transfer.reference, status: "completed" },
  });

  const result = await service.webhooks.handle({
    rawBody: body,
    headers: { "x-bazik-signature": `t=123,v1=${sign(body)}` },
  });

  assert.equal(result.status, "settled");
});
