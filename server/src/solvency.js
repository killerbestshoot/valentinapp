"use strict";

/**
 * SOLVABILITE: èske float ajan yo kouvri pa pwovizyon pasrèl yo?
 *
 * Yon float ajan se yon DÈT: ajan an ka depanse l nenpòt lè (MonCash, NatCash,
 * minit). Pou onore l, antrepriz la dwe gen pwovizyon sou Bazik (HTG) ak sou
 * kont Reloadly la (USD). Si dèt yo depase pwovizyon yo, transfè yo ap kòmanse
 * refize an plen jounen — epi kliyan yo gen tan peye kach.
 *
 * Tout bagay konpare an HTG, ak to jounen an (`bazik/src/rates.js`).
 *
 * LIMIT KI ENPÒTAN: pwovizyon Bazik la (HTG) pa ka peye yon rechaj minit, e
 * kont Reloadly la (USD) pa ka peye yon transfè MonCash. Kouvèti global la se
 * yon PLANCHE, pa yon garanti pa sèvis — se poutèt sa nou bay chak pwovizyon
 * apa tou.
 *
 * Wallet owner an PA konte kòm dèt: se antrepriz la menm.
 */

const { getDb } = require("./db/db");
const { getBazikService } = require("./bazik_service");
const { getAirtimeService } = require("./airtime_service");
const { money } = require("../../bazik/index.js");

/** Konbyen pwovizyon anplis nou vle anvan nou rete trankil (10%). */
const DEFAULT_BUFFER = 0.1;

function bufferRatio(env = process.env) {
  const value = Number(env.SOLVENCY_BUFFER);
  return Number.isFinite(value) && value >= 0 ? value : DEFAULT_BUFFER;
}

/** Dèt: sòm float tout staff (ajan ak admin), pa deviz. */
async function liabilities(enterpriseId, rates) {
  const rows = getDb()
    .prepare(
      `SELECT currency, SUM(balance_minor) AS total FROM wallets
        WHERE enterprise_id = ? AND role != 'owner' AND balance_minor > 0
        GROUP BY currency`
    )
    .all(enterpriseId);

  const byCurrency = [];
  const reasons = [];
  let htgMinor = 0;

  for (const row of rows) {
    try {
      const converted = await rates.convert(row.total, row.currency, "HTG");
      htgMinor += converted.amountMinor;
      byCurrency.push({
        currency: row.currency,
        amount: money.fromMinor(row.total),
        htg: money.fromMinor(converted.amountMinor),
      });
    } catch (err) {
      // San to, nou pa ka di si nou solvab: nou pa fè konsa nou solvab.
      reasons.push(`${row.currency}: ${err.code || err.message}`);
      byCurrency.push({ currency: row.currency, amount: money.fromMinor(row.total), htg: null });
    }
  }

  return { htgMinor, byCurrency, reasons };
}

/** Pwovizyon Bazik la (HTG dirèk). */
async function bazikCoverage() {
  try {
    const service = getBazikService();
    const wallet = await service.gatewayWallet();
    return {
      ok: true,
      mode: service.config.mode,
      available: money.fromMinor(wallet.availableMinor),
      currency: wallet.currency,
      htgMinor: wallet.currency === "HTG" ? wallet.availableMinor : null,
      htg: wallet.currency === "HTG" ? money.fromMinor(wallet.availableMinor) : null,
    };
  } catch (err) {
    return { ok: false, error: err.code || err.message, htgMinor: null };
  }
}

/** Pwovizyon Reloadly la (USD -> HTG ak to jounen an). */
async function reloadlyCoverage(rates) {
  const service = getAirtimeService();

  if (service.disabled) {
    return { ok: true, enabled: false, htgMinor: 0, htg: 0, note: "Minit Haiti dezaktive" };
  }

  try {
    const account = await service.topups.accountBalance();
    const converted = await rates.convert(account.balanceMinor, account.currency, "HTG");
    return {
      ok: true,
      enabled: true,
      mode: service.config.mode,
      available: money.fromMinor(account.balanceMinor),
      currency: account.currency,
      htgMinor: converted.amountMinor,
      htg: money.fromMinor(converted.amountMinor),
    };
  } catch (err) {
    return { ok: false, enabled: true, error: err.code || err.message, htgMinor: null };
  }
}

/**
 * @returns {Promise<object>} `status`:
 *   - `covered`   : pwovizyon yo depase dèt yo + tanpon an
 *   - `thin`      : yo kouvri dèt yo, men san tanpon
 *   - `uncovered` : yo PA kouvri dèt yo — alèt
 *   - `unknown`   : nou pa ka konnen (pasrèl pa reponn, to pa ajou)
 */
async function checkSolvency({ enterpriseId }) {
  const rates = getBazikService().rates;
  const buffer = bufferRatio();

  const debt = await liabilities(enterpriseId, rates);
  const [bazik, reloadly] = await Promise.all([bazikCoverage(), reloadlyCoverage(rates)]);

  const reasons = [...debt.reasons];
  if (!bazik.ok) reasons.push(`Bazik: ${bazik.error}`);
  if (!reloadly.ok) reasons.push(`Reloadly: ${reloadly.error}`);
  if (bazik.ok && bazik.htgMinor === null) reasons.push(`Bazik an ${bazik.currency}, pa HTG`);

  const measurable = reasons.length === 0;
  const coverageHtgMinor = (bazik.htgMinor || 0) + (reloadly.htgMinor || 0);
  const gapHtgMinor = debt.htgMinor - coverageHtgMinor;

  let status;
  if (!measurable) {
    status = "unknown";
  } else if (coverageHtgMinor < debt.htgMinor) {
    status = "uncovered";
  } else if (coverageHtgMinor < Math.round(debt.htgMinor * (1 + buffer))) {
    status = "thin";
  } else {
    status = "covered";
  }

  return {
    ok: status === "covered",
    status,
    currency: "HTG",
    bufferRatio: buffer,
    liabilities: { total: money.fromMinor(debt.htgMinor), byCurrency: debt.byCurrency },
    coverage: {
      total: measurable ? money.fromMinor(coverageHtgMinor) : null,
      bazik,
      reloadly,
    },
    /** Pozitif = konbyen HTG ki manke. */
    gap: measurable ? money.fromMinor(gapHtgMinor) : null,
    ratio: measurable && debt.htgMinor > 0 ? Number((coverageHtgMinor / debt.htgMinor).toFixed(4)) : null,
    reasons,
  };
}

/** Yon sèl liy pou onglet notifikasyon yo (owner sèlman). */
function solvencyNotification(result) {
  if (result.status === "covered") return null;

  const amount = (value) => `${Number(value).toLocaleString("fr-FR", { minimumFractionDigits: 2 })} HTG`;

  if (result.status === "unknown") {
    return {
      type: "solvency_unknown",
      severity: "warning",
      title: `Nou pa ka verifye solvabilite a: ${result.reasons.join("; ")}`,
      count: 1,
    };
  }

  if (result.status === "uncovered") {
    return {
      type: "solvency_uncovered",
      severity: "warning",
      title:
        `Float ajan yo PA kouvri: ${amount(result.liabilities.total)} dèt vs ` +
        `${amount(result.coverage.total)} pwovizyon — manke ${amount(result.gap)}`,
      count: 1,
    };
  }

  return {
    type: "solvency_thin",
    severity: "warning",
    title:
      `Pwovizyon yo jis-jis: ${amount(result.coverage.total)} pou ` +
      `${amount(result.liabilities.total)} float ajan (tanpon ${Math.round(result.bufferRatio * 100)}% pa respekte)`,
    count: 1,
  };
}

module.exports = { checkSolvency, solvencyNotification, DEFAULT_BUFFER };
