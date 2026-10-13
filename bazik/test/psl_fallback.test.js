"use strict";

/**
 * Relè PSL Wallet: lè Bazik refize, PSL voye MonCash (7 %) oswa NatCash (6 %).
 * `provider` OBLIGATWA nan chak demann PSL (sinon 422 provider_required).
 */

const test = require("node:test");
const assert = require("node:assert/strict");

const { createBazikService } = require("../index");
const { createSqliteStore } = require("../src/store/sqlite_store");
const { createFakeBazikClient } = require("../src/fake_client");
const { createPslClient, PslError } = require("../src/psl_client");
const { seedAgent, balanceOf, TEST_CONFIG } = require("./helpers");

const USD = (amount) => Math.round(amount * 100);
// 37000000: nimewo similatè Bazik la toujou refize.
const BAZIK_FAILS = "37000000";

function makeFakePsl({ status = "pending", balanceHtg = 1000000 } = {}) {
  const calls = [];
  return {
    calls,
    nextStatus: status,
    async balance() {
      return { availableMinor: Math.round(balanceHtg * 100), currency: "HTG", accountStatus: "active" };
    },
    async createPayout(args) {
      calls.push(args);
      return { gatewayId: `po_${calls.length}`, status: "processing", rawStatus: "pending", failureReason: "" };
    },
    async payoutStatus(id) {
      const raw = this.nextStatus;
      return {
        gatewayId: id,
        status: raw === "completed" ? "completed" : raw === "failed" ? "failed" : "processing",
        rawStatus: raw,
        failureReason: raw === "failed" ? "invalid_receiver" : "",
      };
    },
  };
}

function makeService(psl, { bazikHtg } = {}) {
  const service = createBazikService({
    store: createSqliteStore({ file: ":memory:" }),
    client: createFakeBazikClient(bazikHtg === undefined ? {} : { availableMinor: Math.round(bazikHtg * 100) }),
    pslClient: psl,
    config: { ...TEST_CONFIG },
    isPslFallbackEnabled: () => true,
  });
  return service;
}

test("NatCash: Bazik refize → PSL voye l ak provider natcash ak frè 6 %", async (t) => {
  const psl = makeFakePsl();
  const service = makeService(psl);
  t.after(() => service.close());
  const agent = await seedAgent(service.store, { balanceMinor: USD(500) });

  const result = await service.transfers.send({
    kind: "delivery",
    network: "natcash",
    amountMinor: USD(40), // 40 USD = 5 280 HTG (minimòm NatCash: 3 998)
    uid: agent.uid,
    enterpriseId: agent.enterpriseId,
    phone: BAZIK_FAILS,
    receiverName: "Wesner Louis",
    idempotencySeed: "nat-1",
  });

  assert.equal(psl.calls.length, 1);
  assert.equal(psl.calls[0].provider, "natcash");
  assert.equal(psl.calls[0].amountHtgMinor, 528000);
  assert.equal(result.provider, "psl");
  assert.equal(result.transfer.status, "processing", "NatCash PSL: voye alamen, rete an kou");
  assert.equal(result.transfer.feeHtgMinor, 31680, "6 % de 5 280 HTG");
  // 40 USD + 5 % (Bazik) + 1 % ajisteman PSL = 42,40 USD.
  assert.equal(await balanceOf(service.store, agent), USD(500) - USD(42.4));
});

test("MonCash: provider moncash ak frè 7 % (korije 422 provider_required)", async (t) => {
  const psl = makeFakePsl();
  const service = makeService(psl);
  t.after(() => service.close());
  const agent = await seedAgent(service.store, { balanceMinor: USD(500) });

  const result = await service.transfers.send({
    network: "moncash",
    amountMinor: USD(10),
    uid: agent.uid,
    enterpriseId: agent.enterpriseId,
    phone: BAZIK_FAILS,
    idempotencySeed: "mon-1",
  });

  assert.equal(psl.calls[0].provider, "moncash");
  assert.equal(result.transfer.feeHtgMinor, 9240, "7 % de 1 320 HTG");
  assert.equal(await balanceOf(service.store, agent), USD(500) - USD(10.7));
});

test("NatCash PSL: refresh fèmen l lè ekip PSL la voye l, oswa ranbouse si l echwe", async (t) => {
  const psl = makeFakePsl();
  const service = makeService(psl);
  t.after(() => service.close());
  const agent = await seedAgent(service.store, { balanceMinor: USD(500) });

  const send = (seed) => service.transfers.send({
    network: "natcash", amountMinor: USD(40), uid: agent.uid, enterpriseId: agent.enterpriseId,
    phone: BAZIK_FAILS, receiverName: "Wesner Louis", idempotencySeed: seed,
  });

  const ok = await send("nat-ok");
  psl.nextStatus = "completed";
  assert.equal((await service.transfers.refresh(ok.transfer.transferId)).transfer.status, "completed");

  const before = await balanceOf(service.store, agent);
  const ko = await send("nat-ko");
  psl.nextStatus = "failed";
  const refreshed = await service.transfers.refresh(ko.transfer.transferId);
  assert.equal(refreshed.transfer.status, "failed");
  assert.match(refreshed.transfer.failureReason, /invalid_receiver/);
  assert.equal(await balanceOf(service.store, agent), before, "montan + tout frè yo ranbouse");
});

test("kliyan PSL: provider voye nan kò a, rezo enkoni refize anvan rezo a", async () => {
  const sent = [];
  const client = createPslClient(
    { baseUrl: "https://psl.test", apiKey: "psk_test" },
    {
      fetchImpl: async (url, init) => {
        sent.push({ url, body: JSON.parse(init.body) });
        return { ok: true, status: 201, json: async () => ({ id: "po_1", status: "pending" }) };
      },
    }
  );

  await client.createPayout({ provider: "natcash", amountHtgMinor: 150000, phone: "+509 3712 3456", reference: "TRF_1" });
  assert.deepEqual(sent[0].body, { provider: "natcash", amount: "1500.00", phone: "50937123456", reference: "TRF_1" });

  await assert.rejects(client.createPayout({ amountHtgMinor: 100, phone: "37123456", reference: "x" }), (err) =>
    err instanceof PslError && err.code === "invalid_provider");
  assert.equal(sent.length, 1, "pa gen apèl si provider a manke");
});

test("float: Bazik 20 000 + PSL 30 000 → 25 000 pase pa PSL dirèkteman, 40 000 refize san debi", async (t) => {
  const psl = makeFakePsl({ balanceHtg: 30000 });
  const service = makeService(psl, { bazikHtg: 20000 });
  t.after(() => service.close());
  // Ajan an an HTG pou chif yo klè.
  await service.store.ensureWallet({ uid: "a", enterpriseId: "E", role: "agent", currency: "HTG" });
  await service.store.creditWallet({ uid: "a", enterpriseId: "E", amountMinor: 10000000, currency: "HTG", type: "seed", idempotencyKey: "s" });
  const agent = { uid: "a", enterpriseId: "E" };
  const send = (htg, seed) => service.transfers.send({
    network: "moncash", amountMinor: htg * 100, currency: "HTG", uid: "a", enterpriseId: "E", phone: "37123456", idempotencySeed: seed,
  });

  // 25 000 + 5 % = 26 250 > 20 000 Bazik; 25 000 + 7 % = 26 750 ≤ 30 000 PSL.
  const quote = await service.transfers.quote({ network: "moncash", amountMinor: 2500000, currency: "HTG" });
  assert.equal(quote.provider, "psl");
  const viaPsl = await send(25000, "f-1");
  assert.equal(viaPsl.provider, "psl");
  assert.equal(psl.calls.length, 1, "Bazik pa eseye: PSL dirèkteman");
  assert.equal(psl.calls[0].provider, "moncash");

  // 10 000: Bazik kouvri l (10 500 ≤ 20 000).
  const viaBazik = await send(10000, "f-2");
  assert.notEqual(viaBazik.provider, "psl");

  // 40 000: ni Bazik (20 000) ni PSL (30 000) pa ka voye l an yon fwa.
  const before = await balanceOf(service.store, agent);
  await assert.rejects(send(40000, "f-3"), (err) =>
    err.code === "gateway_underfunded" && /Bazik 20000 HTG.*PSL 30000 HTG/.test(err.message));
  assert.equal(await balanceOf(service.store, agent), before, "pa gen debi");
});

test("float: relè PSL dezaktive → mesaj Bazik sèlman", async (t) => {
  const service = createBazikService({
    store: createSqliteStore({ file: ":memory:" }),
    client: createFakeBazikClient({ availableMinor: 2000000 }),
    pslClient: makeFakePsl({ balanceHtg: 30000 }),
    config: { ...TEST_CONFIG },
    isPslFallbackEnabled: () => false,
  });
  t.after(() => service.close());
  await assert.rejects(
    service.transfers.quote({ network: "moncash", amountMinor: 2500000, currency: "HTG" }),
    (err) => err.code === "gateway_underfunded" && /Kont Bazik la pa gen ase/.test(err.message));
});
