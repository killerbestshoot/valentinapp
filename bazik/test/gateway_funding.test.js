"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");

const { makeService, seedAgent, balanceOf } = require("./helpers");

const USD = (amount) => Math.round(amount * 100);

/**
 * Sentòm nan: "mwen pa wè anyen sou dashboard Bazik la".
 *
 * De kòz posib, e tès sa yo kouvri toude:
 *  1. float Bazik la vid -> Bazik refize anvan li kreye anyen;
 *  2. nou an mòd similasyon -> apèl la pa janm kite machin nan.
 */

test("float Bazik vid: nou echwe VIT, san nou pa touche wallet ajan an", async (t) => {
  const { service } = makeService({ availableMinor: 0 });
  t.after(() => service.close());

  const agent = await seedAgent(service.store, { balanceMinor: USD(500) });

  await assert.rejects(
    service.transfers.send({
      network: "moncash",
      amountMinor: USD(10),
      uid: agent.uid,
      enterpriseId: agent.enterpriseId,
      phone: "37123456",
      idempotencySeed: "gf1",
    }),
    { code: "gateway_underfunded" }
  );

  assert.equal(
    await balanceOf(service.store, agent),
    USD(500),
    "sòld la pa dwe desann epi remonte: sa twonpe ajan an"
  );

  // Okenn transfè pa kreye non plis: pa gen fatra nan baz la.
  assert.equal((await service.store.listPendingTransfers()).length, 0);
});

test("float ki pa ase pou frè yo tou konte", async (t) => {
  // 1320 HTG + 5% = 1386 HTG nesesè. Nou bay 1350 sèlman.
  const { service } = makeService({ availableMinor: 135000 });
  t.after(() => service.close());

  const agent = await seedAgent(service.store, { balanceMinor: USD(500) });

  await assert.rejects(
    service.transfers.send({
      network: "moncash",
      amountMinor: USD(10),
      uid: agent.uid,
      enterpriseId: agent.enterpriseId,
      phone: "37123456",
      idempotencySeed: "gf2",
    }),
    (err) => {
      assert.equal(err.code, "gateway_underfunded");
      assert.match(err.message, /frè ladan/, "mesaj la dwe di frè yo konte");
      return true;
    }
  );
});

test("float ki ase: transfè a pase nòmalman", async (t) => {
  const { service } = makeService({ availableMinor: 1000000, autoComplete: true });
  t.after(() => service.close());

  const agent = await seedAgent(service.store, { balanceMinor: USD(500) });

  const result = await service.transfers.send({
    network: "moncash",
    amountMinor: USD(10),
    uid: agent.uid,
    enterpriseId: agent.enterpriseId,
    phone: "37123456",
    idempotencySeed: "gf3",
  });

  assert.equal(result.transfer.status, "completed");
  assert.ok(result.transfer.gatewayId, "gatewayId a se sa nou chèche sou dashboard la");
});

test("chak rezilta di nan ki mòd nou ye", async (t) => {
  const { service } = makeService();
  t.after(() => service.close());

  const agent = await seedAgent(service.store, { balanceMinor: USD(500) });

  const quote = await service.transfers.quote({ amountMinor: USD(10), network: "moncash" });
  assert.equal(quote.mode, "fake", "UI a bezwen sa pou l avèti ajan an");

  const result = await service.transfers.send({
    network: "moncash",
    amountMinor: USD(10),
    uid: agent.uid,
    enterpriseId: agent.enterpriseId,
    phone: "37123456",
    idempotencySeed: "gf4",
  });

  assert.equal(result.mode, "fake");
});

test("si tchèk float la echwe, nou kontinye (Bazik rete otorite a)", async (t) => {
  const { service, client } = makeService({ autoComplete: true });
  t.after(() => service.close());

  // Kèk kont pa gen dwa li sòld la (403 sou /balance). Sa pa dwe bloke
  // transfè yo — se Bazik ki deside alafen.
  client.wallet = async () => {
    const { BazikError } = require("../src/errors");
    throw new BazikError("endpoint_not_authorized", "not allowed", { status: 403 });
  };

  const agent = await seedAgent(service.store, { balanceMinor: USD(500) });

  const result = await service.transfers.send({
    network: "moncash",
    amountMinor: USD(10),
    uid: agent.uid,
    enterpriseId: agent.enterpriseId,
    phone: "37123456",
    idempotencySeed: "gf5",
  });

  assert.equal(result.transfer.status, "completed");
});
