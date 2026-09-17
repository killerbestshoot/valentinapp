"use strict";

/**
 * Vi administratè sou kont Reloadly a, pou onglet "Sante sistèm" la.
 *
 * Chak pèmisyon jeton an (`scope`) bay yon seksyon. Chak seksyon izole: yon
 * erè sou youn (pèmisyon ki manke, 5xx) pa anpeche lòt yo parèt.
 *
 * DONE LAJAN (sòld, komisyon = maj, istorik rechaj ak kou yo) = OWNER SÈLMAN.
 * Filt la fèt ISIT LA, sou serveur a: pou yon admin, nou pa menm rele Reloadly
 * pou seksyon sa yo. Kache yo nan UI a sèlman pa t ap pwoteje anyen.
 */

const { fromMinor } = require("./mapper");

const PERMISSIONS = [
  { scope: "send-topups", label: "Voye rechaj minit", section: null, ownerOnly: false },
  { scope: "read-operators", label: "Li operatè yo", section: "operators", ownerOnly: false },
  { scope: "read-promotions", label: "Li pwomosyon yo", section: "promotions", ownerOnly: false },
  { scope: "read-topups-history", label: "Li istorik rechaj yo", section: "history", ownerOnly: true },
  { scope: "read-prepaid-balance", label: "Li sòld kont lan", section: "balance", ownerOnly: true },
  { scope: "read-prepaid-commissions", label: "Li komisyon (remiz) yo", section: "commissions", ownerOnly: true },
];

const CACHE_TTL_MS = 60 * 1000;

function createAccountInsights({ client, config, now = () => Date.now() }) {
  const cache = new Map();

  async function section(granted, loader) {
    if (!granted) return { ok: false, error: "missing_scope" };
    try {
      return { ok: true, data: await loader() };
    } catch (err) {
      return { ok: false, error: err.code || "error", message: err.message };
    }
  }

  function describeOperatorRow(op) {
    return {
      operatorId: op.operatorId,
      name: op.name,
      status: op.status,
      kind: op.isPin ? "pin" : op.isData ? "data" : op.isBundle ? "bundle" : "airtime",
      denominationType: op.denominationType,
      senderCurrency: op.senderCurrency,
      minAmount: fromMinor(op.minMinor),
      maxAmount: fromMinor(op.maxMinor),
      fixedAmounts: op.fixedMinor.map(fromMinor),
      fxRate: op.fxRate,
      supportsLocalAmounts: op.supportsLocalAmounts,
    };
  }

  async function build(isOwner, historyLimit) {
    let scopes = [];
    let scopesError = null;
    try {
      scopes = await client.scopes();
    } catch (err) {
      scopesError = err.code || "error";
    }

    const has = (scope) => scopes.includes(scope);
    const known = new Set(PERMISSIONS.map((p) => p.scope));

    const permissions = [
      ...PERMISSIONS.map((p) => ({ scope: p.scope, label: p.label, granted: has(p.scope), ownerOnly: p.ownerOnly })),
      // Yon pèmisyon Reloadly ajoute pita parèt tou, pou nou pa rate l.
      ...scopes.filter((s) => !known.has(s)).map((s) => ({ scope: s, label: s, granted: true, ownerOnly: false })),
    ];

    const restricted = { ok: false, restricted: true };

    const operators = await section(has("read-operators"), async () =>
      (await client.operatorsByCountry(config.countryCode)).map(describeOperatorRow)
    );

    const [promotions, balance, commissions, history] = await Promise.all([
      section(has("read-promotions"), () => client.promotionsByCountry(config.countryCode)),
      isOwner
        ? section(has("read-prepaid-balance"), async () => {
            const account = await client.balance();
            return {
              balance: fromMinor(account.balanceMinor),
              currency: account.currency,
              lowBalanceThreshold: fromMinor(account.lowBalanceThresholdMinor),
              updatedAt: account.updatedAt,
            };
          })
        : restricted,
      isOwner
        ? section(has("read-prepaid-commissions"), async () => {
            // Komisyon operatè Ayiti yo. San lis operatè, nou pran de prensipal yo.
            const ids = operators.ok ? operators.data.map((op) => op.operatorId) : [173, 174];
            const rows = await Promise.allSettled(ids.map((id) => client.commission(id)));
            return rows.filter((r) => r.status === "fulfilled").map((r) => r.value);
          })
        : restricted,
      isOwner
        ? section(has("read-topups-history"), async () =>
            (await client.recentTopups(historyLimit)).map((t) => ({
              transactionId: t.gatewayId,
              status: t.status,
              rawStatus: t.rawStatus,
              customIdentifier: t.customIdentifier,
              operatorName: t.operatorName,
              requestedAmount: fromMinor(t.requestedMinor),
              requestedCurrency: t.requestedCurrency,
              deliveredAmount: fromMinor(t.deliveredMinor),
              deliveredCurrency: t.deliveredCurrency,
              discount: fromMinor(t.discountMinor),
              discountCurrency: t.discountCurrency,
              date: String(t.raw?.transactionDate || ""),
            }))
          )
        : restricted,
    ]);

    return {
      mode: client.mode,
      countryCode: config.countryCode,
      isOwner,
      scopesError,
      permissions,
      sections: { operators, promotions, balance, commissions, history },
      fetchedAt: now(),
    };
  }

  /**
   * @param {object} options
   * @param {boolean} options.isOwner `false` = seksyon lajan yo PA rele menm
   * @param {boolean} [options.force] inyore cache 60 s la
   */
  async function overview({ isOwner, historyLimit = 10, force = false }) {
    const key = `${isOwner ? "owner" : "admin"}:${historyLimit}`;
    const hit = cache.get(key);
    if (!force && hit && hit.at > now() - CACHE_TTL_MS) return hit.value;

    const value = await build(Boolean(isOwner), historyLimit);
    cache.set(key, { at: now(), value });
    return value;
  }

  return { overview };
}

module.exports = { createAccountInsights, PERMISSIONS };
