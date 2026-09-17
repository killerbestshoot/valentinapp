"use strict";

/**
 * Chemen AMBIGI yo — kote lajan te disparèt.
 *
 * Tès ki te egziste yo te kouvri chemen kontan yo ak echèk PWÒP. Odit la te
 * jwenn tout pèt reyèl yo nan chemen ambigi (timeout, konkirans, deviz), ke
 * okenn tès pa t egzèse. Chak tès isit la repwodui yon eksplwatasyon oswa yon
 * pèt ki te pwouve.
 */

const test = require("node:test");
const assert = require("node:assert/strict");

const { makeService, seedAgent, balanceOf } = require("./helpers");
const { BazikError } = require("../src/errors");
const mapper = require("../src/mapper");

const USD = (amount) => Math.round(amount * 100);

async function htgAgent(store, balanceMinor) {
  const uid = "agent-htg";
  const enterpriseId = "ENT1";

  await store.ensureWallet({ uid, enterpriseId, role: "agent", currency: "HTG" });
  await store.creditWallet({
    uid,
    enterpriseId,
    amountMinor: balanceMinor,
    currency: "HTG",
    type: "seed",
    note: "seed",
    idempotencyKey: `seed:${uid}`,
  });

  return { uid, enterpriseId };
}

// --- Vòl pa konfizyon deviz ---

test("wallet HTG ki voye an 'USD': debi a konvèti an HTG, pa janm 105 HTG pou 13 200", async (t) => {
  // Eksplwatasyon ki te pwouve: 100 'USD' = 13 200 HTG voye bay benefisyè a,
  // men 105 sèlman debite nan wallet HTG la. Ajan an achte ×125.
  // Premye koreksyon an te REFIZE lòt deviz yo. Kounye a nou KONVÈTI — e se
  // tès sa a ki garanti debi a toujou kalkile nan inite wallet la.
  const { service } = makeService({ autoComplete: true });
  t.after(() => service.close());

  const agent = await htgAgent(service.store, 2000000); // 20 000 HTG

  const { transfer } = await service.transfers.send({
    network: "moncash",
    amountMinor: 10000, // 100 USD
    currency: "USD",
    uid: agent.uid,
    enterpriseId: agent.enterpriseId,
    phone: "37123456",
    idempotencySeed: "vol-deviz",
  });

  assert.equal(transfer.amountHtgMinor, 1320000, "100 USD × 132 = 13 200 HTG pou benefisyè a");
  assert.equal(transfer.walletCurrency, "HTG");
  assert.equal(transfer.debitMinor, 1386000, "13 200 + 5% = 13 860 HTG debite, PA 105");
  assert.equal(await balanceOf(service.store, agent), 2000000 - 1386000);
});

test("deviz wallet la aplike menm si demann lan pa di anyen", async (t) => {
  const { service } = makeService({ autoComplete: true });
  t.after(() => service.close());

  const agent = await htgAgent(service.store, 1000000);

  const { transfer } = await service.transfers.send({
    network: "moncash",
    amountMinor: 50000, // 500 HTG
    uid: agent.uid,
    enterpriseId: agent.enterpriseId,
    phone: "37123456",
    idempotencySeed: "deviz-default",
  });

  assert.equal(transfer.currency, "HTG");
  assert.equal(transfer.amountHtgMinor, 50000, "500 HTG, pa 500 × 132");
});

// --- Idempotans ---

test("san kle idempotans ni txId, transfè a refize", async (t) => {
  // Anvan: seed la te gen `Date.now()` — de klik a 1 ms, de transfè.
  const { service } = makeService();
  t.after(() => service.close());

  const agent = await seedAgent(service.store, { balanceMinor: USD(500) });

  await assert.rejects(
    service.transfers.send({
      network: "moncash",
      amountMinor: USD(10),
      uid: agent.uid,
      enterpriseId: agent.enterpriseId,
      phone: "37123456",
    }),
    { code: "missing_idempotency_key" }
  );
});

test("de apèl konkiran ak menm kle = yon sèl transfè, yon sèl debi", async (t) => {
  const { service } = makeService({ autoComplete: true });
  t.after(() => service.close());

  const agent = await seedAgent(service.store, { balanceMinor: USD(500) });

  const params = {
    network: "moncash",
    amountMinor: USD(10),
    uid: agent.uid,
    enterpriseId: agent.enterpriseId,
    phone: "37123456",
    idempotencySeed: "doub-klik",
  };

  const [a, b] = await Promise.all([
    service.transfers.send(params),
    service.transfers.send(params),
  ]);

  assert.equal(a.transfer.transferId, b.transfer.transferId);
  assert.equal(await balanceOf(service.store, agent), USD(500) - USD(10.5), "yon sèl debi");
});

test("txId la bay yon kle stab pou kont li", async (t) => {
  const { service } = makeService({ autoComplete: true });
  t.after(() => service.close());

  const agent = await seedAgent(service.store, { balanceMinor: USD(500) });

  const params = {
    kind: "delivery",
    network: "moncash",
    amountMinor: USD(10),
    uid: agent.uid,
    enterpriseId: agent.enterpriseId,
    phone: "37123456",
    txId: "TX_STAB",
  };

  await service.transfers.send(params);
  const second = await service.transfers.send(params);

  assert.equal(second.duplicate, true);
  assert.equal(await balanceOf(service.store, agent), USD(500) - USD(10.5));
});

// --- Echèk ambigi: pa ranbouse ---

test("timeout apre Bazik aksepte: wallet la PA ranbouse", async (t) => {
  // Pèt ki te pwouve: Bazik voye lajan an, sokèt la mouri, nou ranbouse ajan
  // an — benefisyè a resevwa l E ajan an refè kòb li. Antrepriz la pèdi 100%.
  const { service, client } = makeService();
  t.after(() => service.close());

  client.createTransfer = async () => {
    throw new BazikError("network_error", "socket hang up", { retryable: true });
  };

  const agent = await seedAgent(service.store, { balanceMinor: USD(500) });

  await assert.rejects(
    service.transfers.send({
      network: "moncash",
      amountMinor: USD(10),
      uid: agent.uid,
      enterpriseId: agent.enterpriseId,
      phone: "37123456",
      idempotencySeed: "timeout",
    }),
    { code: "transfer_pending_verification" }
  );

  // Kòb la rete bloke, pa ranbouse: `pollPending` ap rekonsilye l.
  assert.equal(await balanceOf(service.store, agent), USD(500) - USD(10.5));

  const pending = await service.store.listPendingTransfers();
  assert.equal(pending.length, 1);
  assert.equal(pending[0].gatewayStatus, "unknown");
  assert.equal(pending[0].refunded, false);
});

test("5xx Bazik se ambigi tou: pa ranbouse", async (t) => {
  const { service, client } = makeService();
  t.after(() => service.close());

  client.createTransfer = async () => {
    throw new BazikError("http_502", "bad gateway", { status: 502, retryable: true });
  };

  const agent = await seedAgent(service.store, { balanceMinor: USD(500) });

  await assert.rejects(
    service.transfers.send({
      network: "moncash",
      amountMinor: USD(10),
      uid: agent.uid,
      enterpriseId: agent.enterpriseId,
      phone: "37123456",
      idempotencySeed: "502",
    }),
    { code: "transfer_pending_verification" }
  );

  assert.equal(await balanceOf(service.store, agent), USD(500) - USD(10.5));
});

test("refi klè (4xx metye): ranbousman san risk", async (t) => {
  const { service, client } = makeService();
  t.after(() => service.close());

  client.createTransfer = async () => {
    throw new BazikError("amount_too_low", "too low", { status: 400 });
  };

  const agent = await seedAgent(service.store, { balanceMinor: USD(500) });

  await assert.rejects(
    service.transfers.send({
      network: "moncash",
      amountMinor: USD(10),
      uid: agent.uid,
      enterpriseId: agent.enterpriseId,
      phone: "37123456",
      idempotencySeed: "4xx",
    }),
    { code: "amount_too_low" }
  );

  assert.equal(await balanceOf(service.store, agent), USD(500), "ranbouse konplètman");
});

test("transfè ambigi rekonsilye pa pollPending lè Bazik konfime", async (t) => {
  const { service, client } = makeService();
  t.after(() => service.close());

  const realCreate = client.createTransfer.bind(client);
  let transferRef = null;

  // Bazik aksepte (dosye egziste), men nou pa resevwa repons lan.
  client.createTransfer = async (network, params) => {
    await realCreate(network, params);
    transferRef = params.reference;
    throw new BazikError("network_error", "timeout", { retryable: true });
  };

  const agent = await seedAgent(service.store, { balanceMinor: USD(500) });

  await assert.rejects(
    service.transfers.send({
      network: "moncash",
      amountMinor: USD(10),
      uid: agent.uid,
      enterpriseId: agent.enterpriseId,
      phone: "37123456",
      idempotencySeed: "rekonsilyasyon",
    }),
    { code: "transfer_pending_verification" }
  );

  client._markCompleted(transferRef);
  await service.transfers.pollPending();

  const transfer = await service.store.getTransfer(transferRef);
  assert.equal(transfer.status, "completed");
  assert.equal(transfer.refunded, false);
});

// --- Atomisite ---

test("si debi a echwe, pa gen liy transfè òfelen", async (t) => {
  const { service } = makeService({ autoComplete: true });
  t.after(() => service.close());

  const agent = await seedAgent(service.store, { balanceMinor: USD(5) });

  await assert.rejects(
    service.transfers.send({
      network: "moncash",
      amountMinor: USD(10),
      uid: agent.uid,
      enterpriseId: agent.enterpriseId,
      phone: "37123456",
      idempotencySeed: "orfelen",
    }),
    { code: "insufficient_funds" }
  );

  assert.equal((await service.store.listPendingTransfers()).length, 0);
});

test("transfè a louvri deja make walletDebited = true", async (t) => {
  // Anvan: debi a ak flag la te de ekriti separe. Yon kras ant yo te kite
  // `walletDebited = false` — e `settleTransfer` refize ranbouse sou flag sa a.
  const { service } = makeService();
  t.after(() => service.close());

  const agent = await seedAgent(service.store, { balanceMinor: USD(500) });

  const { transfer } = await service.transfers.send({
    network: "moncash",
    amountMinor: USD(10),
    uid: agent.uid,
    enterpriseId: agent.enterpriseId,
    phone: "37123456",
    idempotencySeed: "flag-atomik",
  });

  assert.equal(transfer.walletDebited, true);

  const settled = await service.store.settleTransfer({
    transferId: transfer.transferId,
    status: "failed",
  });
  assert.ok(settled.refund, "ranbousman an posib paske flag la te la depi kòmansman");
});

// --- Webhook ---

test("id jenerik la pa vale evènman konplesyon an", async () => {
  // Anpil pasrèl mete ID tranzaksyon an nan `id` — menm pou tout evènman.
  const processing = mapper.readWebhookEvent({
    id: "trf_123",
    data: { referenceId: "TRF_X", status: "processing" },
  });
  const completed = mapper.readWebhookEvent({
    id: "trf_123",
    data: { referenceId: "TRF_X", status: "completed" },
  });

  assert.notEqual(processing.eventId, completed.eventId, "de evènman, de kle");
});

test("yon eventId eksplisit toujou respekte", () => {
  const event = mapper.readWebhookEvent({
    eventId: "evt_42",
    id: "trf_123",
    data: { referenceId: "TRF_X", status: "completed" },
  });
  assert.equal(event.eventId, "evt_42");
});

// --- Non NatCash ---

test("yon sèl mo pa bay yon siyati envante", () => {
  assert.deepEqual(mapper.splitName("Jean"), { firstName: "Jean", lastName: "" });

  assert.throws(
    () =>
      mapper.buildNatcashTransferRequest({
        reference: "R",
        amountHtgMinor: 500000,
        phone: "37123456",
        receiverName: "Jean",
      }),
    { code: "missing_receiver_name" }
  );
});

// --- Frè ---

test("devi enkoyeran: frè 5% la aplike, pa zewo", async (t) => {
  // Si Bazik chanje non chan `fee`, `feeMinor` tounen 0 men `total_cost` rete
  // pozitif. Anvan, frè yo te tonbe a zewo — antrepriz la t ap peye 5%.
  const { service, client } = makeService();
  t.after(() => service.close());

  client.quote = async ({ amountHtgMinor }) => ({
    deliveryMinor: amountHtgMinor,
    feeMinor: 0,
    totalCostMinor: amountHtgMinor + Math.round(amountHtgMinor * 0.05),
    feePercent: 5,
    currency: "HTG",
  });

  const quote = await service.transfers.quote({ amountMinor: USD(10), network: "moncash" });

  assert.equal(quote.feeHtg, 66, "5% de 1320 HTG");
});
