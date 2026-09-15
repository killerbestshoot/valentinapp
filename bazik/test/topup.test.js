"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");

const { makeService, seedAgent, balanceOf } = require("./helpers");

const USD = (amount) => Math.round(amount * 100);

test("kont tip `transfer` la pa ka ankese: mesaj la klè", async (t) => {
  // `allowCashIn: false` = konpòtman vre kont sandbox la (403).
  const { service } = makeService({ allowCashIn: false });
  t.after(() => service.close());

  const agent = await seedAgent(service.store, { balanceMinor: 0 });

  await assert.rejects(
    service.topups.create({
      targetUid: agent.uid,
      enterpriseId: agent.enterpriseId,
      amountMinor: USD(10),
      phone: "37123456",
      idempotencySeed: "tu1",
    }),
    { code: "cash_in_unavailable" }
  );

  assert.equal(await balanceOf(service.store, agent), 0, "okenn kòb pa parèt nan wallet la");
});

test("ak yon kont `online`, rechaj la bay yon lyen peman san kredite anyen", async (t) => {
  const { service } = makeService({ allowCashIn: true });
  t.after(() => service.close());

  const agent = await seedAgent(service.store, { balanceMinor: 0 });

  const { topup, paymentUrl } = await service.topups.create({
    targetUid: agent.uid,
    enterpriseId: agent.enterpriseId,
    amountMinor: USD(10),
    phone: "37123456",
    idempotencySeed: "tu2",
  });

  assert.equal(topup.status, "awaiting_payment");
  assert.match(paymentUrl, /^https:\/\//);
  assert.equal(await balanceOf(service.store, agent), 0, "wallet la pa kredite anvan peman an");
});

test("wallet la kredite yon sèl fwa, menm si nou verifye plizyè fwa", async (t) => {
  const { service, client } = makeService({ allowCashIn: true });
  t.after(() => service.close());

  const agent = await seedAgent(service.store, { balanceMinor: 0 });

  const { topup } = await service.topups.create({
    targetUid: agent.uid,
    enterpriseId: agent.enterpriseId,
    amountMinor: USD(10),
    phone: "37123456",
    idempotencySeed: "tu3",
  });

  // Anvan peman an: anyen.
  const notYet = await service.topups.verify(topup.requestId);
  assert.equal(notYet.changed, false);
  assert.equal(await balanceOf(service.store, agent), 0);

  client._markCompleted(topup.requestId);

  const first = await service.topups.verify(topup.requestId);
  const second = await service.topups.verify(topup.requestId);

  assert.equal(first.changed, true);
  assert.equal(second.changed, false);
  assert.equal(await balanceOf(service.store, agent), USD(10), "yon sèl kredi");
});

test("peman ki echwe pa kredite anyen", async (t) => {
  const { service, client } = makeService({ allowCashIn: true });
  t.after(() => service.close());

  const agent = await seedAgent(service.store, { balanceMinor: 0 });

  const { topup } = await service.topups.create({
    targetUid: agent.uid,
    enterpriseId: agent.enterpriseId,
    amountMinor: USD(10),
    phone: "37123456",
    idempotencySeed: "tu4",
  });

  client._markFailed(topup.requestId);
  const result = await service.topups.verify(topup.requestId);

  assert.equal(result.topup.status, "failed");
  assert.equal(result.credit, null);
  assert.equal(await balanceOf(service.store, agent), 0);
});
