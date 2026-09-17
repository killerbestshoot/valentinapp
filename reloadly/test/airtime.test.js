"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");

const {
  USD,
  makeAirtime,
  seedAgent,
  balanceOf,
  seedTransaction,
  txStatus,
  ledgerRows,
} = require("./helpers");
const { ReloadlyError } = require("../src/errors");

function setup(t, clientOptions) {
  const ctx = makeAirtime(clientOptions);
  t.after(() => ctx.bazik.close());
  return ctx;
}

// --- Chemen nòmal ------------------------------------------------------------

test("rechaj Digicel ki reyisi: wallet la debite montan an EGZAKTEMAN, san frè", async (t) => {
  const { service, wallets, db } = setup(t);
  const agent = await seedAgent(wallets, { balanceMinor: USD(100) });
  const txId = seedTransaction(db);

  const result = await service.topups.send({
    ...agent,
    phone: "3712 3456",
    amountMinor: USD(5),
    txId,
  });

  assert.equal(result.duplicate, false);
  assert.equal(result.topup.status, "completed");
  assert.equal(result.topup.operatorName, "Digicel Haiti");
  assert.equal(result.topup.phone, "+50937123456");
  assert.equal(result.topup.useLocalAmount, false);
  assert.equal(result.topup.deliveredMinor, 60730, "5 USD × 121,46 = 607,30 HTG (to sandbox 17/09/2026)");
  assert.equal(result.topup.deliveredCurrency, "HTG");
  assert.equal(result.topup.discountMinor, 10, "remiz 2% Digicel la anrejistre: se maj antrepriz la");
  assert.ok(result.topup.gatewayId, "ID Reloadly a dwe konsève pou rekonsilyasyon");

  assert.equal(await balanceOf(wallets, agent), USD(95));
  assert.deepEqual(ledgerRows(db), [{ type: "airtime_minit", direction: "debit", amount_minor: USD(5) }]);
  assert.equal(txStatus(db, txId), "delivered");
});

test("wallet HTG + Natcom: montan lokal (`useLocalAmount`), pa gen konvèsyon an kachèt", async (t) => {
  const { service, wallets, client } = setup(t);
  await wallets.ensureWallet({ uid: "agent-h", enterpriseId: "ENT1", currency: "HTG" });
  await wallets.creditWallet({
    uid: "agent-h", enterpriseId: "ENT1", amountMinor: 500000, currency: "HTG",
    type: "seed", idempotencyKey: "seed:htg",
  });

  let sent;
  const original = client.topup;
  client.topup = async (params) => ((sent = params), original(params));

  const result = await service.topups.send({
    uid: "agent-h", enterpriseId: "ENT1", phone: "33123456", amountMinor: 50000, idempotencySeed: "h1",
  });

  assert.equal(result.topup.operatorName, "Natcom Haiti");
  assert.equal(sent.useLocalAmount, true);
  assert.equal(sent.amountMinor, 50000, "500 HTG voye tel kel");
  assert.equal(result.topup.deliveredMinor, 50000);
  assert.equal(await balanceOf(wallets, { uid: "agent-h", enterpriseId: "ENT1" }), 450000);
});

test("wallet HTG + Digicel (pa aksepte HTG): montan an KONVÈTI an USD, debi a an HTG", async (t) => {
  const { service, wallets, client, db } = setup(t);
  await wallets.ensureWallet({ uid: "agent-h", enterpriseId: "ENT1", currency: "HTG" });
  await wallets.creditWallet({
    uid: "agent-h", enterpriseId: "ENT1", amountMinor: 500000, currency: "HTG",
    type: "seed", idempotencyKey: "seed:htg",
  });

  let sent;
  const original = client.topup;
  client.topup = async (params) => ((sent = params), original(params));

  // 1 000 HTG / 132 (to seed tès) = 7,5757 USD -> 7,57 USD voye (awondi an BA)
  const result = await service.topups.send({
    uid: "agent-h", enterpriseId: "ENT1", phone: "37123456", amountMinor: 100000, idempotencySeed: "h2",
  });

  assert.equal(sent.useLocalAmount, false);
  assert.equal(sent.amountMinor, 757, "pa janm voye plis valè pase sa kliyan an peye");
  assert.equal(result.topup.sendCurrency, "USD");
  assert.equal(result.topup.debitMinor, 100000);
  assert.equal(result.topup.walletCurrency, "HTG");
  assert.equal(await balanceOf(wallets, { uid: "agent-h", enterpriseId: "ENT1" }), 400000);
  assert.equal(
    db.prepare("SELECT currency FROM wallet_ledger WHERE type = 'airtime_minit'").get().currency,
    "HTG"
  );
});

// --- Validasyon anvan debi ---------------------------------------------------

test("montan anba minimòm operatè a: refi an Kreyòl, san debi, san liy", async (t) => {
  const { service, wallets, db } = setup(t);
  const agent = await seedAgent(wallets, { balanceMinor: USD(100) });

  await assert.rejects(
    service.topups.send({ ...agent, phone: "37123456", amountMinor: USD(0.5), idempotencySeed: "low" }),
    (err) => err.code === "amount_too_low" && /Minimòm Digicel Haiti se 4.00 USD/.test(err.message)
  );
  await assert.rejects(
    service.topups.send({ ...agent, phone: "37123456", amountMinor: USD(101), idempotencySeed: "high" }),
    { code: "amount_too_high" }
  );

  assert.equal(await balanceOf(wallets, agent), USD(100));
  assert.equal(db.prepare("SELECT COUNT(*) AS n FROM airtime_topups").get().n, 0);
});

test("operatè FIXED: yon montan ki pa nan lis la bay lis montan ki valab yo", async (t) => {
  const fixedOperator = {
    id: 900, name: "Digicel Haiti Fixed", country: { isoName: "HT" },
    denominationType: "FIXED", senderCurrencyCode: "USD", destinationCurrencyCode: "HTG",
    fixedAmounts: [2, 5, 10], fx: { rate: 128 }, internationalDiscount: 5,
  };
  const { service, wallets } = setup(t, { operators: [fixedOperator] });
  const agent = await seedAgent(wallets, { balanceMinor: USD(100) });

  await assert.rejects(
    service.topups.send({ ...agent, phone: "37123456", amountMinor: USD(3), idempotencySeed: "f1" }),
    (err) => err.code === "amount_not_offered" && err.allowedAmounts.join(",") === "2,5,10"
  );

  const ok = await service.topups.send({ ...agent, phone: "37123456", amountMinor: USD(5), idempotencySeed: "f2" });
  assert.equal(ok.topup.status, "completed");
});

test("nimewo envalid oswa fiks: refi anvan nenpòt apèl ki deplase lajan", async (t) => {
  const { service, wallets } = setup(t);
  const agent = await seedAgent(wallets, { balanceMinor: USD(100) });

  await assert.rejects(
    service.topups.send({ ...agent, phone: "3712", amountMinor: USD(5), idempotencySeed: "p1" }),
    { code: "invalid_phone" }
  );
  await assert.rejects(
    service.topups.send({ ...agent, phone: "22123456", amountMinor: USD(5), idempotencySeed: "p2" }),
    { code: "operator_not_found" }
  );

  assert.equal(await balanceOf(wallets, agent), USD(100));
});

test("operatè ki vann done/PIN pa ka sèvi pou Minit Haiti", async (t) => {
  const dataOperator = {
    id: 901, name: "Digicel Haiti Data", country: { isoName: "HT" }, data: true,
    denominationType: "RANGE", senderCurrencyCode: "USD", destinationCurrencyCode: "HTG",
    minAmount: 1, maxAmount: 70, fx: { rate: 128 },
  };
  const { service, wallets } = setup(t, { operators: [dataOperator] });
  const agent = await seedAgent(wallets, { balanceMinor: USD(100) });

  await assert.rejects(
    service.topups.send({ ...agent, phone: "37123456", amountMinor: USD(5), idempotencySeed: "d1" }),
    { code: "operator_not_supported" }
  );
});

test("kont Reloadly pa ase: refi AVAN debi ajan an", async (t) => {
  const { service, wallets } = setup(t, { balance: 2 });
  const agent = await seedAgent(wallets, { balanceMinor: USD(100) });

  await assert.rejects(
    service.topups.send({ ...agent, phone: "37123456", amountMinor: USD(5), idempotencySeed: "u1" }),
    { code: "airtime_underfunded" }
  );
  assert.equal(await balanceOf(wallets, agent), USD(100));
});

test("sòld ajan pa ase: ROLLBACK retire liy rechaj la tou (pa gen òfelen)", async (t) => {
  const { service, wallets, db } = setup(t);
  const agent = await seedAgent(wallets, { balanceMinor: USD(2) });

  await assert.rejects(
    service.topups.send({ ...agent, phone: "37123456", amountMinor: USD(5), idempotencySeed: "i1" }),
    { code: "insufficient_funds" }
  );
  assert.equal(db.prepare("SELECT COUNT(*) AS n FROM airtime_topups").get().n, 0);
});

test("jeton Reloadly enposib pou jwenn: echèk AVAN debi, pa yon rechaj bloke an verifikasyon", async (t) => {
  const { service, wallets, client, db } = setup(t);
  const agent = await seedAgent(wallets, { balanceMinor: USD(100) });

  client.prepare = async () => {
    throw new ReloadlyError("network_error", "auth.reloadly.com pa reponn", { retryable: true });
  };

  await assert.rejects(
    service.topups.send({ ...agent, phone: "37123456", amountMinor: USD(5), idempotencySeed: "tok" }),
    { code: "network_error" }
  );
  assert.equal(await balanceOf(wallets, agent), USD(100));
  assert.equal(db.prepare("SELECT COUNT(*) AS n FROM airtime_topups").get().n, 0);
});

// --- Idempotans ----------------------------------------------------------------

test("menm tranzaksyon voye de fwa: yon sèl rechaj, yon sèl debi", async (t) => {
  const { service, wallets, db, client } = setup(t);
  const agent = await seedAgent(wallets, { balanceMinor: USD(100) });
  const txId = seedTransaction(db);

  const first = await service.topups.send({ ...agent, phone: "37123456", amountMinor: USD(5), txId });
  const second = await service.topups.send({ ...agent, phone: "37123456", amountMinor: USD(5), txId });

  assert.equal(second.duplicate, true);
  assert.equal(second.topup.topupId, first.topup.topupId);
  assert.equal(client.records.size, 1, "Reloadly rele yon sèl fwa");
  assert.equal(await balanceOf(wallets, agent), USD(95));
});

test("doub-klik KONKIRAN (de apèl an menm tan): yon sèl debi", async (t) => {
  const { service, wallets, client } = setup(t);
  const agent = await seedAgent(wallets, { balanceMinor: USD(100) });

  const params = { ...agent, phone: "37123456", amountMinor: USD(5), idempotencySeed: "race" };
  const results = await Promise.all([service.topups.send(params), service.topups.send(params)]);

  assert.equal(results.filter((r) => r.duplicate).length, 1);
  assert.equal(client.records.size, 1);
  assert.equal(await balanceOf(wallets, agent), USD(95));
});

test("ajan an EPI yon admin livre menm tranzaksyon an: yon sèl rechaj", async (t) => {
  const { service, wallets, client, db } = setup(t);
  const agent = await seedAgent(wallets, { uid: "agent-1", balanceMinor: USD(100) });
  const admin = await seedAgent(wallets, { uid: "admin-1", balanceMinor: USD(100) });
  const txId = seedTransaction(db);

  const [a, b] = await Promise.all([
    service.topups.send({ ...agent, phone: "37123456", amountMinor: USD(5), txId }),
    service.topups.send({ ...admin, phone: "37123456", amountMinor: USD(5), txId }),
  ]);

  assert.equal(a.topup.topupId, b.topup.topupId);
  assert.equal(client.records.size, 1, "Reloadly rele yon sèl fwa");
  assert.equal((await balanceOf(wallets, agent)) + (await balanceOf(wallets, admin)), USD(195), "yon sèl debi total");
});

test("san kle idempotans ni txId: refi", async (t) => {
  const { service, wallets } = setup(t);
  const agent = await seedAgent(wallets, { balanceMinor: USD(100) });

  await assert.rejects(
    service.topups.send({ ...agent, phone: "37123456", amountMinor: USD(5) }),
    { code: "missing_idempotency_key" }
  );
});

// --- Refi ak ambigwite ---------------------------------------------------------

test("Reloadly REFIZE (4xx) apre debi a: ranbousman egzak, tranzaksyon `failed`", async (t) => {
  const { service, wallets, db } = setup(t);
  const agent = await seedAgent(wallets, { balanceMinor: USD(100) });
  const txId = seedTransaction(db);

  await assert.rejects(
    // 37000000 toujou refize nan similatè a.
    service.topups.send({ ...agent, phone: "37000000", amountMinor: USD(5), txId }),
    (err) =>
      err.code === "transaction_cannot_be_processed_at_the_moment" &&
      err.topup.status === "failed" &&
      err.topup.refunded === true
  );

  assert.equal(await balanceOf(wallets, agent), USD(100));
  assert.deepEqual(ledgerRows(db).map((r) => `${r.direction}:${r.amount_minor}`), ["debit:500", "credit:500"]);
  assert.equal(txStatus(db, txId), "failed");
});

for (const [label, error] of [
  ["timeout rezo", new ReloadlyError("network_error", "socket hang up", { retryable: true })],
  ["5xx", new ReloadlyError("http_502", "Bad Gateway", { status: 502, retryable: true })],
  ["erè JavaScript enkoni", new Error("boom")],
]) {
  test(`repons AMBIGI (${label}): PA ranbouse, rechaj la rete an verifikasyon`, async (t) => {
    const { service, wallets, client, db } = setup(t);
    const agent = await seedAgent(wallets, { balanceMinor: USD(100) });
    const txId = seedTransaction(db);

    client.topup = async () => {
      throw error;
    };

    await assert.rejects(
      service.topups.send({ ...agent, phone: "37123456", amountMinor: USD(5), txId }),
      (err) => err.code === "airtime_pending_verification" && err.topup.status === "processing"
    );

    assert.equal(await balanceOf(wallets, agent), USD(95), "si minit yo te pase, yon ranbousman ta yon pèt");
    assert.equal(txStatus(db, txId), "pending");
  });
}

test("repons pèdi, men Reloadly TE trete l: rekonsilyasyon pa `customIdentifier` fèmen l", async (t) => {
  const { service, wallets, client, db } = setup(t);
  const agent = await seedAgent(wallets, { balanceMinor: USD(100) });
  const txId = seedTransaction(db);

  // Reloadly egzekite rechaj la, men koneksyon an mouri anvan repons lan.
  const original = client.topup;
  client.topup = async (params) => {
    await original(params);
    throw new ReloadlyError("network_error", "timeout", { retryable: true });
  };

  const pending = await service.topups
    .send({ ...agent, phone: "37123456", amountMinor: USD(5), txId })
    .catch((err) => err.topup);

  assert.equal(pending.gatewayId, "", "nou pa gen transactionId: se customIdentifier ki sove nou");

  const refreshed = await service.topups.refresh(pending.topupId);
  assert.equal(refreshed.changed, true);
  assert.equal(refreshed.topup.status, "completed");
  assert.ok(refreshed.topup.gatewayId);
  assert.equal(await balanceOf(wallets, agent), USD(95));
  assert.equal(txStatus(db, txId), "delivered");
});

test("repons pèdi, Reloadly pa konnen rechaj la: `notFound`, PA ranbouse otomatikman", async (t) => {
  const { service, wallets, client } = setup(t);
  const agent = await seedAgent(wallets, { balanceMinor: USD(100) });

  client.topup = async () => {
    throw new ReloadlyError("network_error", "timeout", { retryable: true });
  };

  const pending = await service.topups
    .send({ ...agent, phone: "37123456", amountMinor: USD(5), idempotencySeed: "nf" })
    .catch((err) => err.topup);

  const refreshed = await service.topups.refresh(pending.topupId);
  assert.equal(refreshed.notFound, true);
  assert.equal(refreshed.topup.status, "processing");
  assert.equal(await balanceOf(wallets, agent), USD(95));
});

test("PROCESSING: `refresh` fèmen l `completed` lè Reloadly konfime", async (t) => {
  const { service, wallets, db } = setup(t);
  const agent = await seedAgent(wallets, { balanceMinor: USD(100) });
  const txId = seedTransaction(db);

  const sent = await service.topups.send({ ...agent, phone: "37111111", amountMinor: USD(5), txId });
  assert.equal(sent.topup.status, "processing");
  assert.equal(txStatus(db, txId), "pending");

  const refreshed = await service.topups.refresh(sent.topup.topupId);
  assert.equal(refreshed.topup.status, "completed");
  assert.equal(txStatus(db, txId), "delivered");
});

test("PROCESSING ki tounen REFUNDED: yon sèl ranbousman, menm si nou verifye plizyè fwa", async (t) => {
  const { service, wallets, db } = setup(t);
  const agent = await seedAgent(wallets, { balanceMinor: USD(100) });

  const sent = await service.topups.send({ ...agent, phone: "37222222", amountMinor: USD(5), idempotencySeed: "rf" });

  const first = await service.topups.refresh(sent.topup.topupId);
  const second = await service.topups.refresh(sent.topup.topupId);
  const polled = await service.topups.pollPending();

  assert.equal(first.topup.status, "failed");
  assert.equal(first.topup.refunded, true);
  assert.equal(second.changed, false);
  assert.deepEqual(polled, []);
  assert.equal(await balanceOf(wallets, agent), USD(100));
  assert.equal(ledgerRows(db).filter((r) => r.direction === "credit").length, 1);
});

test("fèmti yon rechaj pa janm touche tranzaksyon yon LÒT antrepriz", async (t) => {
  const { service, wallets, db } = setup(t);
  const agent = await seedAgent(wallets, { balanceMinor: USD(100) });
  seedTransaction(db, { txId: "TX_OTHER", enterpriseId: "ENT2", uid: "someone" });

  await service.topups.send({ ...agent, phone: "37123456", amountMinor: USD(5), txId: "TX_OTHER" });

  assert.equal(txStatus(db, "TX_OTHER"), "pending");
});

test("devi: menm validasyon ak voye a, men ANYEN pa deplase", async (t) => {
  const { service, wallets, client, db } = setup(t);
  const agent = await seedAgent(wallets, { balanceMinor: USD(100) });

  const quote = await service.topups.quote({ ...agent, phone: "37123456", amountMinor: USD(5) });

  assert.equal(quote.operator.name, "Digicel Haiti");
  assert.equal(quote.operator.minAmount, 4);
  assert.equal(quote.estimatedDelivered, 607.3);
  assert.equal(quote.debit, 5);
  assert.equal(quote.currency, "USD");

  await assert.rejects(
    service.topups.quote({ ...agent, phone: "37123456", amountMinor: USD(0.5) }),
    { code: "amount_too_low" }
  );

  assert.equal(client.records.size, 0);
  assert.equal(await balanceOf(wallets, agent), USD(100));
  assert.equal(db.prepare("SELECT COUNT(*) AS n FROM airtime_topups").get().n, 0);
});

// --- Leson sandbox la (17/09/2026) --------------------------------------------

test("CUSTOM_IDENTIFIER_ALREADY_USED: Reloadly te deja livre — nou REKONSILYE, nou pa ranbouse", async (t) => {
  // Senaryo reyèl: baz la retabli depi yon sovgad. Rechaj la te pati, men baz
  // la pa konnen l. Ajan an reyeseye menm tranzaksyon an -> menm ID.
  const { service, wallets, client, db } = setup(t);
  const agent = await seedAgent(wallets, { balanceMinor: USD(100) });
  const txId = seedTransaction(db);

  const first = await service.topups.send({ ...agent, phone: "37123456", amountMinor: USD(5), txId });
  const topupId = first.topup.topupId;

  // "Retabli sovgad la": liy rechaj la ak debi a disparèt, tranzaksyon an pending.
  db.prepare("DELETE FROM airtime_topups").run();
  db.prepare("DELETE FROM wallet_ledger WHERE type != 'seed'").run();
  db.prepare("UPDATE wallets SET balance_minor = ?").run(USD(100));
  db.prepare("UPDATE transactions SET status = 'pending'").run();

  const retry = await service.topups.send({ ...agent, phone: "37123456", amountMinor: USD(5), txId });

  assert.equal(retry.topup.topupId, topupId);
  assert.equal(retry.topup.status, "completed", "minit yo te pase: se yon livrezon, pa yon echèk");
  assert.equal(retry.topup.refunded, false);
  assert.equal(client.records.size, 1, "pa gen dezyèm rechaj");
  assert.equal(await balanceOf(wallets, agent), USD(95), "yon sèl debi pou yon sèl livrezon");
  assert.equal(txStatus(db, txId), "delivered");
});

test("CUSTOM_IDENTIFIER_ALREADY_USED men rechaj la pa jwenn: an verifikasyon, PA ranbouse", async (t) => {
  const { service, wallets, client } = setup(t);
  const agent = await seedAgent(wallets, { balanceMinor: USD(100) });

  client.topup = async () => {
    throw new ReloadlyError("custom_identifier_already_used", "already used", { status: 400 });
  };
  client.findTopupByCustomIdentifier = async () => null;

  await assert.rejects(
    service.topups.send({ ...agent, phone: "37123456", amountMinor: USD(5), idempotencySeed: "cid" }),
    (err) => err.code === "airtime_pending_verification" && err.topup.status === "processing"
  );
  assert.equal(await balanceOf(wallets, agent), USD(95));
});

test("operatorId ki pa koresponn ak nimewo a: refi (pakè #1296 pa ka pase pou minit)", async (t) => {
  const { service, wallets, client } = setup(t);
  const agent = await seedAgent(wallets, { balanceMinor: USD(100) });

  await assert.rejects(
    service.topups.send({ ...agent, phone: "37123456", amountMinor: USD(5), operatorId: 1296, idempotencySeed: "om" }),
    (err) => err.code === "operator_mismatch" && /Digicel Haiti \(#173\)/.test(err.message)
  );
  assert.equal(client.records.size, 0);
  assert.equal(await balanceOf(wallets, agent), USD(100));

  // operatorId ki DAKÒ ak nimewo a: aksepte.
  const ok = await service.topups.send({ ...agent, phone: "37123456", amountMinor: USD(5), operatorId: 173, idempotencySeed: "ok" });
  assert.equal(ok.topup.status, "completed");
});

test("operatè ki pa ACTIVE sou Reloadly: refi AVAN debi", async (t) => {
  const inactive = {
    id: 173, name: "Digicel Haiti", country: { isoName: "HT" }, status: "INACTIVE",
    denominationType: "RANGE", senderCurrencyCode: "USD", destinationCurrencyCode: "HTG",
    minAmount: 4, maxAmount: 100, fx: { rate: 121.46 },
  };
  const { service, wallets } = setup(t, { operators: [inactive] });
  const agent = await seedAgent(wallets, { balanceMinor: USD(100) });

  await assert.rejects(
    service.topups.send({ ...agent, phone: "37123456", amountMinor: USD(5), idempotencySeed: "in" }),
    { code: "operator_unavailable" }
  );
  assert.equal(await balanceOf(wallets, agent), USD(100));
});

test("Natcom an montan LOKAL (HTG): remiz 0% — rechaj la pase, men li pa bay okenn maj", async (t) => {
  const { service, wallets } = setup(t);
  await wallets.ensureWallet({ uid: "agent-h", enterpriseId: "ENT1", currency: "HTG" });
  await wallets.creditWallet({
    uid: "agent-h", enterpriseId: "ENT1", amountMinor: 500000, currency: "HTG",
    type: "seed", idempotencyKey: "seed:htg2",
  });

  const result = await service.topups.send({
    uid: "agent-h", enterpriseId: "ENT1", phone: "33123456", amountMinor: 50000, idempotencySeed: "loc",
  });

  assert.equal(result.topup.useLocalAmount, true);
  assert.equal(result.topup.discountMinor, 0, "`localDiscount: 0` sou sandbox la");
});

// --- Konvèsyon deviz (to jounen an) -------------------------------------------

async function mxnAgent(wallets, balanceMinor = 1000000) {
  await wallets.ensureWallet({ uid: "agent-m", enterpriseId: "ENT1", currency: "MXN" });
  await wallets.creditWallet({
    uid: "agent-m", enterpriseId: "ENT1", amountMinor: balanceMinor, currency: "MXN",
    type: "seed", idempotencyKey: "seed:mxn",
  });
  return { uid: "agent-m", enterpriseId: "ENT1" };
}

test("wallet MXN: 100 MXN -> USD awondi an BA pou Reloadly, 100 MXN debite", async (t) => {
  const { service, wallets, client } = setup(t);
  const agent = await mxnAgent(wallets);

  let sent;
  const original = client.topup;
  client.topup = async (params) => ((sent = params), original(params));

  // 100 MXN × 7,25 / 132 = 5,4924 USD -> 5,49
  const quote = await service.topups.quote({ ...agent, phone: "37123456", amountMinor: 10000 });
  assert.equal(quote.currency, "MXN");
  assert.equal(quote.sendAmount, 5.49);
  assert.equal(quote.sendCurrency, "USD");
  assert.equal(quote.debit, 100);
  assert.equal(quote.debitCurrency, "MXN");
  assert.ok(Math.abs(quote.conversionRate - 7.25 / 132) < 1e-12);

  const result = await service.topups.send({ ...agent, phone: "37123456", amountMinor: 10000, idempotencySeed: "mx" });

  assert.equal(sent.amountMinor, 549);
  assert.equal(result.topup.amountMinor, 10000);
  assert.equal(result.topup.currency, "MXN");
  assert.equal(result.topup.sendAmountMinor, 549);
  assert.equal(await balanceOf(wallets, agent), 1000000 - 10000);
});

test("wallet USD, tranzaksyon an MXN: debi an USD (o pi pre), voye an USD (an ba)", async (t) => {
  const { service, wallets, client } = setup(t);
  const agent = await seedAgent(wallets, { balanceMinor: USD(100) });

  let sent;
  const original = client.topup;
  client.topup = async (params) => ((sent = params), original(params));

  const result = await service.topups.send({
    ...agent, phone: "37123456", amountMinor: 10000, currency: "MXN", idempotencySeed: "usd-mxn",
  });

  assert.equal(sent.amountMinor, 549, "5,4924 -> 5,49 voye");
  assert.equal(result.topup.debitMinor, 549, "5,4924 -> 5,49 debite");
  assert.equal(result.topup.walletCurrency, "USD");
  assert.equal(await balanceOf(wallets, agent), USD(100) - 549);
});

test("montan konvèti anba minimòm: mesaj la montre toude deviz yo", async (t) => {
  const { service, wallets } = setup(t);
  const agent = await mxnAgent(wallets);

  await assert.rejects(
    // 50 MXN = 2,74 USD < 4 USD
    service.topups.quote({ ...agent, phone: "37123456", amountMinor: 5000 }),
    (err) =>
      err.code === "amount_too_low" &&
      /Minimòm Digicel Haiti se 4\.00 USD \(≈ 72\.83 MXN\)/.test(err.message) &&
      /Ou mande 50\.00 MXN \(≈ 2\.74 USD\)/.test(err.message)
  );
});

test("rechaj konvèti ki echwe: ranbousman EGZAK nan deviz wallet la", async (t) => {
  const { service, wallets, db } = setup(t);
  const agent = await mxnAgent(wallets);

  await assert.rejects(
    service.topups.send({ ...agent, phone: "37000000", amountMinor: 10000, idempotencySeed: "mx-fail" }),
    (err) => err.topup?.refunded === true
  );

  assert.equal(await balanceOf(wallets, agent), 1000000);
  const refund = db.prepare("SELECT currency, amount_minor FROM wallet_ledger WHERE type = 'airtime_refund'").get();
  assert.deepEqual({ ...refund }, { currency: "MXN", amount_minor: 10000 });
});

test("pwodiksyon: konvèsyon ak to ki pa soti nan API a refize AVAN debi", async (t) => {
  const { createRateBook } = require("../../bazik/src/rates");
  const { createAirtimeService } = require("../index");
  const { createFakeReloadlyClient } = require("../src/fake_client");
  const { TEST_CONFIG } = require("./helpers");

  const { bazik, wallets, db } = setup(t);
  const strict = createAirtimeService({
    ledgerStore: bazik.store,
    client: createFakeReloadlyClient(),
    config: { ...TEST_CONFIG },
    rates: createRateBook({ store: bazik.store, requireFresh: true }),
  });
  const agent = await mxnAgent(wallets);

  await assert.rejects(
    strict.topups.send({ ...agent, phone: "37123456", amountMinor: 10000, idempotencySeed: "stale" }),
    { code: "rates_stale" }
  );
  assert.equal(await balanceOf(wallets, agent), 1000000);
  assert.equal(db.prepare("SELECT COUNT(*) AS n FROM airtime_topups").get().n, 0);

  // Menm deviz ak operatè a (USD -> USD): pa gen konvèsyon, pa gen blokaj.
  const usdAgent = await seedAgent(wallets, { uid: "agent-usd", balanceMinor: USD(100) });
  const ok = await strict.topups.send({ ...usdAgent, phone: "37123456", amountMinor: USD(5), idempotencySeed: "same" });
  assert.equal(ok.topup.status, "completed");
});
