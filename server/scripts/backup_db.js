"use strict";

/**
 * Sovgad baz SQLite la, pandan serveur a ap kouri.
 *
 *   node server/scripts/backup_db.js                     # → <dosye baz la>/backups
 *   node server/scripts/backup_db.js --dir /backups --keep 30
 *
 * Nou itilize `VACUUM INTO`, pa yon `cp`: kopye fichye a pandan yon ekriti ka
 * bay yon baz koupe an de (yon sòld debite san liy ledger li). `VACUUM INTO`
 * ekri yon foto KOERAN, nan yon tranzaksyon lekti.
 *
 * Chak sovgad verifye ak `PRAGMA integrity_check` anvan nou efase ansyen yo:
 * nou pa janm jete yon bon kopi pou ranplase l ak yon kopi kraze.
 */

const fs = require("node:fs");
const path = require("node:path");
const { DatabaseSync } = require("node:sqlite");

const FILE_PATTERN = /^app-\d{8}-\d{6}\.db$/;

function parseArgs(argv) {
  const args = {};
  for (let i = 0; i < argv.length; i++) {
    const token = argv[i];
    if (!token.startsWith("--")) continue;
    const next = argv[i + 1];
    if (next === undefined || next.startsWith("--")) {
      args[token.slice(2)] = true;
    } else {
      args[token.slice(2)] = next;
      i++;
    }
  }
  return args;
}

function timestamp(date = new Date()) {
  const pad = (n) => String(n).padStart(2, "0");
  return (
    `${date.getUTCFullYear()}${pad(date.getUTCMonth() + 1)}${pad(date.getUTCDate())}-` +
    `${pad(date.getUTCHours())}${pad(date.getUTCMinutes())}${pad(date.getUTCSeconds())}`
  );
}

function backup({ source, dir, keep }) {
  if (!fs.existsSync(source)) {
    throw new Error(`Baz la pa egziste: ${source}`);
  }

  fs.mkdirSync(dir, { recursive: true });
  const target = path.join(dir, `app-${timestamp()}.db`);

  const db = new DatabaseSync(source);
  try {
    db.prepare("VACUUM INTO ?").run(target);
  } finally {
    db.close();
  }

  const copy = new DatabaseSync(target, { readOnly: true });
  let integrity;
  try {
    integrity = copy.prepare("PRAGMA integrity_check").get();
  } finally {
    copy.close();
  }

  const status = integrity && Object.values(integrity)[0];
  if (status !== "ok") {
    fs.rmSync(target, { force: true });
    throw new Error(`Sovgad la kraze (integrity_check: ${status}). Ansyen kopi yo pa touche.`);
  }

  const removed = [];
  if (keep > 0) {
    const existing = fs
      .readdirSync(dir)
      .filter((name) => FILE_PATTERN.test(name))
      .sort();
    for (const name of existing.slice(0, Math.max(0, existing.length - keep))) {
      fs.rmSync(path.join(dir, name), { force: true });
      removed.push(name);
    }
  }

  return { target, bytes: fs.statSync(target).size, removed };
}

function main() {
  const args = parseArgs(process.argv.slice(2));
  const source =
    process.env.APP_DB_PATH || path.join(__dirname, "..", "data", "app.db");
  const dir = args.dir || process.env.BACKUP_DIR || path.join(path.dirname(source), "backups");
  const keep = Number(args.keep || process.env.BACKUP_KEEP || 14);

  if (!Number.isInteger(keep) || keep < 0) {
    throw new Error("--keep dwe yon nonm antye pozitif (0 = kenbe tout).");
  }

  const result = backup({ source, dir, keep });
  console.log(`✅ Sovgad: ${result.target} (${(result.bytes / 1024).toFixed(1)} Kio)`);
  if (result.removed.length > 0) {
    console.log(`   Ansyen kopi efase: ${result.removed.join(", ")}`);
  }
}

if (require.main === module) {
  try {
    main();
  } catch (err) {
    console.error(`❌ ${err.message}`);
    process.exit(1);
  }
}

module.exports = { backup, timestamp };
