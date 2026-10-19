"use strict";

/**
 * Wallet KOMISYON: apa sòld prensipal la, pou ajan ak owner.
 *
 * Se yon wallet nòmal (menm rejis, menm idempotans) ki gen pwòp uid li:
 * `{uid}#commission`, wòl `commission`. Konsa tout zouti wallet yo mache san
 * chanjman, e kontwòl solvabilite a konte l kòm yon dèt (kòb ki pwomèt).
 *
 * Kòb sa a BLOKE sou pasrèl yo (`lockedHtgMinor` nan transfer.js): yon transfè
 * nòmal pa ka depanse l; sèl yon retrè komisyon (payout) ka itilize l.
 */

const COMMISSION_SUFFIX = "#commission";
const COMMISSION_ROLE = "commission";

const commissionUid = (uid) => `${uid}${COMMISSION_SUFFIX}`;
const isCommissionUid = (uid) => String(uid || "").endsWith(COMMISSION_SUFFIX);
const ownerUidOf = (uid) => (isCommissionUid(uid) ? String(uid).slice(0, -COMMISSION_SUFFIX.length) : uid);

module.exports = { COMMISSION_SUFFIX, COMMISSION_ROLE, commissionUid, isCommissionUid, ownerUidOf };
