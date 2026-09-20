"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");

const { makeService, seedAgent, balanceOf } = require("./helpers");
const { money } = require("../index");

/** 100 USD = 13 200 HTG ak to 132 la. */
const USD = (amount) => Math.round(amount * 100);

test("transfè MonCash ki reyisi debite montan an + 5% frè", async (t) => {
  const { service, client } = makeService({ autoComplete: true });
  t.after(() => service.close());

  const agent = await seedAgent(service.store, { balanceMinor: USD(500) });

  const result = await service.transfers.send({
    kind: "payout",
    network: "moncash",
    amountMinor: USD(10), // 10 USD = 1320 HTG
    uid: agent.uid,
    enterpriseId: agent.enterpriseId,
    phone: "+509 3712 3456",
    idempotencySeed: "t1",
  });

  assert.equal(result.transfer.status, "completed");
  assert.equal(result.transfer.amountHtgMinor, 132000); // 1320 HTG
  assert.equal(result.transfer.feeHtgMinor, 6600); //   66 HTG = 5%
  assert.equal(result.transfer.totalHtgMinor, 138600);

  // Wallet la pèdi 10 USD + 5% = 10,50 USD
  assert.equal(await balanceOf(service.store, agent), USD(500) - USD(10.5));
  assert.equal(result.transfer.walletDebited, true);
});

test("transfè Bazik make 'failed' tou swit: sld la retounen jan l te ye", async (t) => {
  const { service } = makeService();
  t.after(() => service.close());

  const agent = await seedAgent(service.store, { balanceMinor: USD(500) });
  const before = await balanceOf(service.store, agent);

  // 37000000 se yon nimewo ki toujou echwe nan similatè a.
  const result = await service.transfers.send({
    network: "moncash",
    amountMinor: USD(10),
    uid: agent.uid,
    enterpriseId: agent.enterpriseId,
    phone: "37000000",
    idempotencySeed: "t2",
  });

  assert.equal(result.transfer.status, "failed");
  assert.equal(result.transfer.refunded, true);
  assert.equal(await balanceOf(service.store, agent), before, "sld la dwe retounen jan l te ye");
});

test("si Bazik REJTE demand lan (4xx) apre debi a, nou ranbouse", async (t) => {
  // Float la gen pwovizyon (donk tchèk anvan an pase), men Bazik refize kanmenm.
  // Sa rive vre: yon lòt transfè ka vide float la ant tchèk nou an ak apèl la.
  const { service, client } = makeService();
  t.after(() => service.close());

  const { BazikError } = require("../src/errors");
  client.createTransfer = async () => {
    throw new BazikError("insufficient_balance", "balance is insufficient", { status: 400 });
  };

  const agent = await seedAgent(service.store, { balanceMinor: USD(500) });
  const before = await balanceOf(service.store, agent);

  await assert.rejects(
    service.transfers.send({
      network: "moncash",
      amountMinor: USD(10),
      uid: agent.uid,
      enterpriseId: agent.enterpriseId,
      phone: "37123456",
      idempotencySeed: "t2b",
    }),
    (err) => {
      assert.equal(err.code, "insufficient_balance", "kòd Bazik la pase jouk nan domèn nan");
      assert.match(err.message, /ranbouse/);
      return true;
    }
  );

  assert.equal(await balanceOf(service.store, agent), before, "wallet ajan an pa dwe pèdi anyen");
});

test("transfè ki echwe apre yo aksepte l: webhook ranbouse yon sèl fwa", async (t) => {
  const { service, client } = makeService();
  t.after(() => service.close());

  const agent = await seedAgent(service.store, { balanceMinor: USD(500) });

  const { transfer } = await service.transfers.send({
    network: "moncash",
    amountMinor: USD(10),
    uid: agent.uid,
    enterpriseId: agent.enterpriseId,
    phone: "37123456",
    idempotencySeed: "t3",
  });

  assert.equal(transfer.status, "processing");
  const afterDebit = await balanceOf(service.store, agent);

  client._markFailed(transfer.reference);
  const settled = await service.transfers.refresh(transfer.transferId);

  assert.equal(settled.transfer.status, "failed");
  assert.equal(settled.transfer.refunded, true);
  assert.equal(await balanceOf(service.store, agent), afterDebit + transfer.debitMinor);

  // Yon dezyèm pasaj pa dwe ranbouse ankò.
  const again = await service.transfers.refresh(transfer.transferId);
  assert.equal(again.changed, false);
  assert.equal(await balanceOf(service.store, agent), afterDebit + transfer.debitMinor);
});

test("menm seed idempotans = yon sèl transfè", async (t) => {
  const { service } = makeService({ autoComplete: true });
  t.after(() => service.close());

  const agent = await seedAgent(service.store, { balanceMinor: USD(500) });

  const params = {
    network: "moncash",
    amountMinor: USD(10),
    uid: agent.uid,
    enterpriseId: agent.enterpriseId,
    phone: "37123456",
    idempotencySeed: "menm-seed",
  };

  const first = await service.transfers.send(params);
  const second = await service.transfers.send(params);

  assert.equal(second.duplicate, true);
  assert.equal(first.transfer.transferId, second.transfer.transferId);
  assert.equal(await balanceOf(service.store, agent), USD(500) - USD(10.5), "yon sèl debi");
});

test("NatCash refize san non benefisyè a", async (t) => {
  const { service } = makeService();
  t.after(() => service.close());

  const agent = await seedAgent(service.store, { balanceMinor: USD(500) });

  await assert.rejects(
    service.transfers.send({
      network: "natcash",
      amountMinor: USD(50),
      uid: agent.uid,
      enterpriseId: agent.enterpriseId,
      phone: "37123456",
      idempotencySeed: "t4",
    }),
    { code: "missing_receiver_name" }
  );
});

test("limit rezo yo bloke anvan nou rele Bazik", async (t) => {
  const { service } = makeService();
  t.after(() => service.close());

  const agent = await seedAgent(service.store, { balanceMinor: USD(5000) });

  // 0,50 USD = 66 HTG < 100 HTG minimòm MonCash
  await assert.rejects(
    service.transfers.send({
      network: "moncash",
      amountMinor: USD(0.5),
      uid: agent.uid,
      enterpriseId: agent.enterpriseId,
      phone: "37123456",
      idempotencySeed: "t5",
    }),
    { code: "amount_too_low" }
  );

  // 10 USD = 1320 HTG < 3998 HTG minimòm NatCash
  await assert.rejects(
    service.transfers.send({
      network: "natcash",
      amountMinor: USD(10),
      uid: agent.uid,
      enterpriseId: agent.enterpriseId,
      phone: "37123456",
      receiverName: "Jean Bastien",
      idempotencySeed: "t6",
    }),
    { code: "amount_too_low" }
  );

  // 600 USD = 79 200 HTG > 75 000 HTG maksimòm
  await assert.rejects(
    service.transfers.send({
      network: "moncash",
      amountMinor: USD(600),
      uid: agent.uid,
      enterpriseId: agent.enterpriseId,
      phone: "37123456",
      idempotencySeed: "t7",
    }),
    { code: "amount_too_high" }
  );

  assert.equal(await balanceOf(service.store, agent), USD(5000), "okenn debi pou yon demand ki envalid");
});

test("yon ajan ki pa gen ase kòb pa ka voye", async (t) => {
  const { service } = makeService();
  t.after(() => service.close());

  const agent = await seedAgent(service.store, { balanceMinor: USD(5) });

  await assert.rejects(
    service.transfers.send({
      network: "moncash",
      amountMinor: USD(10),
      uid: agent.uid,
      enterpriseId: agent.enterpriseId,
      phone: "37123456",
      idempotencySeed: "t8",
    }),
    { code: "insufficient_funds" }
  );

  assert.equal(await balanceOf(service.store, agent), USD(5));
});

test("livrezon konfime pase tranzaksyon an nan 'delivered'", async (t) => {
  const { service, client } = makeService();
  t.after(() => service.close());

  const agent = await seedAgent(service.store, { balanceMinor: USD(500) });

  await service.store.createTransaction({
    txId: "TX_TEST_1",
    enterpriseId: agent.enterpriseId,
    staffUid: agent.uid,
    service: "MonCash",
    amountMinor: USD(10),
    status: "pending",
  });

  const { transfer } = await service.transfers.send({
    kind: "delivery",
    network: "moncash",
    amountMinor: USD(10),
    uid: agent.uid,
    enterpriseId: agent.enterpriseId,
    phone: "37123456",
    txId: "TX_TEST_1",
    idempotencySeed: "t9",
  });

  client._markCompleted(transfer.reference);
  await service.transfers.refresh(transfer.transferId);

  const tx = await service.store.getTransaction("TX_TEST_1");
  assert.equal(tx.status, "delivered", "se konfimasyon Bazik la ki bay 'delivered', pa yon klik");
});

test("quote bay frè a san anyen pa deplase", async (t) => {
  const { service } = makeService();
  t.after(() => service.close());

  const quote = await service.transfers.quote({ amountMinor: USD(10), network: "moncash" });

  assert.equal(quote.amountHtg, 1320);
  assert.equal(quote.feeHtg, 66);
  assert.equal(quote.totalHtg, 1386);
  assert.equal(quote.feePercent, 5);
  assert.equal(money.fromMinor(quote.debitMinor), 10.5);
});

test("liy lan sonje KI MOUN ki peye frè a", async (t) => {
  const { service } = makeService({ autoComplete: true });
  t.after(() => service.close());

  const agent = await seedAgent(service.store, { balanceMinor: USD(500) });
  const base = {
    kind: "payout",
    network: "moncash",
    amountMinor: USD(10),
    uid: agent.uid,
    enterpriseId: agent.enterpriseId,
    phone: "+509 3712 3456",
  };

  // Pa defo: ajan an peye frè a anplis.
  const surAjan = await service.transfers.send({ ...base, idempotencySeed: "frè-sou-ajan" });
  assert.equal(surAjan.transfer.feeChargedToWallet, true);
  assert.equal(surAjan.transfer.debitMinor, USD(10.5), "montan an + 5%");

  const nanMontan = await service.transfers.send({
    ...base,
    idempotencySeed: "frè-nan-montan",
    chargeFeeToWallet: false,
  });
  assert.equal(nanMontan.transfer.feeChargedToWallet, false);
  assert.equal(nanMontan.transfer.debitMinor, USD(10), "san frè a");

  // Se sa resi a li: san li, yon kliyan pa ka konnen si frè a soti nan lajan l.
  const relue = await service.store.getTransfer(nanMontan.transfer.transferId);
  assert.equal(relue.feeChargedToWallet, false, "li siviv yon relekti nan baz la");
});

// --- Poukisa yon transfè echwe ---

/**
 * Vre repons Bazik la, kopye sou yon transfè ki echwe an pwodiksyon
 * (TRF_1789875312_5926344d, 2026-09-20). Se referans nou.
 *
 * Remake `description`: se TÈKS PA NOU an ke Bazik voye tounen. Anvan, se li
 * nou te anrejistre kòm rezon echèk — «Livrezon MonCash», ki pa di anyen.
 */
const REPONS_ECHEK = {
  type: "transfer.failed",
  transactionId: "TRF_1789875312_5926344d",
  status: "failed",
  amount: 15276.22,
  fees: 763.81,
  total: 16040.03,
  currency: "HTG",
  wallet: "48465325",
  description: "Livrezon MonCash",
  referenceId: "TRF_97dce9d2-cd98-5ed9-aefa-7580f6d94d28",
  failureReason: "Failed to obtain MonCash OAuth token",
  timestamp: "2026-09-20T03:35:11.840376+00:00",
  provider: "moncash",
  environment: "production",
};

test("nou li vrè rezon Bazik la, pa tèks pa nou an", () => {
  const { readTransferResponse, readWebhookEvent } = require("../src/mapper");

  const read = readTransferResponse(REPONS_ECHEK);
  assert.equal(read.status, "failed");
  assert.equal(read.failureReason, "Failed to obtain MonCash OAuth token");
  assert.notEqual(read.message, "Livrezon MonCash", "`description` se tèks pa nou");

  // Webhook la gen menm fòm nan.
  const event = readWebhookEvent(REPONS_ECHEK);
  assert.equal(event.failureReason, "Failed to obtain MonCash OAuth token");
  assert.equal(event.reference, "TRF_97dce9d2-cd98-5ed9-aefa-7580f6d94d28");
  assert.equal(event.status, "failed");
});

test("yon erè PA NOU ranbouse wallet la tou swit", async (t) => {
  const { service } = makeService({ autoComplete: true });
  t.after(() => service.close());

  const agent = await seedAgent(service.store, { balanceMinor: USD(500) });
  const avan = await balanceOf(service.store, agent);

  // NatCash mande non AK siyati. `buildNatcashTransferRequest` leve erè a
  // anvan okenn apèl rezo: Bazik pa janm wè anyen.
  await assert.rejects(
    service.transfers.send({
      kind: "payout",
      network: "natcash",
      amountMinor: USD(50),
      uid: agent.uid,
      enterpriseId: agent.enterpriseId,
      phone: "+509 3712 3456",
      receiverName: "Junette", // yon sèl mo
      idempotencySeed: "yon-sel-mo",
    }),
    { code: "missing_receiver_name" }
  );

  // Anvan koreksyon an, erè sa a te pase pou «ambigu»: transfè a te rete
  // `processing` e wallet la te rete debite pou yon transfè ki pa t janm pati.
  assert.equal(
    await balanceOf(service.store, agent),
    avan,
    "sòld la dwe retounen jan l te ye"
  );
});
