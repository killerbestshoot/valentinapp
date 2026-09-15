"use strict";

/**
 * Koneksyon SQLite aplikasyon an.
 *
 * MENM FICHYE ak baz Bazik la: sòld yo, `wallet_ledger` ak `transactions` se
 * menm tab yo. De fichye separe ta vle di de verite sou menm kòb la.
 *
 * Nou aplike de schema youn apre lòt:
 *   1. `bazik/src/store/schema.sql`  (wallets, ledger, transfers, transactions)
 *   2. `app_schema.sql`              (users, sessions, enterprises, services)
 */

const fs = require("node:fs");
const path = require("node:path");
const { DatabaseSync } = require("node:sqlite");

const BAZIK_SCHEMA = path.join(__dirname, "..", "..", "..", "bazik", "src", "store", "schema.sql");
const APP_SCHEMA = path.join(__dirname, "app_schema.sql");

/** Chan nou ajoute sou tab `transactions` bazik la bay la. */
const TRANSACTION_EXTRA_COLUMNS = [
  ["service_id", "TEXT NOT NULL DEFAULT ''"],
  ["customer_name", "TEXT NOT NULL DEFAULT ''"],
  ["country", "TEXT NOT NULL DEFAULT ''"],
  ["staff_name", "TEXT NOT NULL DEFAULT ''"],
  ["staff_role", "TEXT NOT NULL DEFAULT ''"],
  ["enterprise_name", "TEXT NOT NULL DEFAULT ''"],
  ["commission_agent_minor", "INTEGER NOT NULL DEFAULT 0"],
  ["commission_owner_minor", "INTEGER NOT NULL DEFAULT 0"],
  ["note", "TEXT NOT NULL DEFAULT ''"],
  ["agent_commission_pct", "REAL NOT NULL DEFAULT 0"],
  ["owner_commission_pct", "REAL NOT NULL DEFAULT 0"],
  ["commission_applied_at", "INTEGER"],
];

let db = null;
let dbFile = null;

/** SQLite pa gen `ADD COLUMN IF NOT EXISTS`: nou verifye tèt nou. */
function ensureColumns(database, table, columns) {
  const existing = new Set(
    database.prepare(`PRAGMA table_info(${table})`).all().map((row) => row.name)
  );

  for (const [name, definition] of columns) {
    if (!existing.has(name)) {
      database.exec(`ALTER TABLE ${table} ADD COLUMN ${name} ${definition}`);
    }
  }
}

/**
 * To echanj yo DWE egziste depi premye demaraj la.
 *
 * Anvan, sèl `sqlite_store.js` te semen yo — e li kreye sèlman lè yon wout
 * Bazik rele pou premye fwa, dèyè `requireAuth`. Sou yon baz vid:
 * pa gen itilizatè → pa gen jeton → pa gen to → `bootstrap` refize ak
 * `unknown_currency` → pa gen itilizatè. Yon sèk ki pa ka kase.
 */
function seedExchangeRates(database) {
  const rates = { HTG: 1, USD: 132, MXN: 7.25, DOP: 2.25, CLP: 0.14, BRL: 24 };
  const stmt = database.prepare(
    `INSERT INTO exchange_rates (currency, rate_to_htg, updated_at) VALUES (?, ?, ?)
     ON CONFLICT(currency) DO NOTHING`
  );
  for (const [currency, rate] of Object.entries(rates)) stmt.run(currency, rate, Date.now());
}

/**
 * Katalòg sèvis yo, ak to komisyon LEGACY yo (10% ajan, 20% owner).
 *
 * Se to sa yo `commission_service.dart` te aplike pa default. Yo semen yon
 * sèl fwa (`DO NOTHING`): yon admin ki chanje yon to pa wè l ekraze.
 */
function seedServices(database) {
  const services = [
    ["moncash_ht", "MonCash", "MONCASH", "moncash"],
    ["natcash_ht", "NatCash", "NATCASH", "natcash"],
    ["minit_ht", "Minit Haiti", "MINIT", ""],
    ["western_union", "Western Union", "WU", ""],
    ["cam_transf", "CAM Transf", "CAM", ""],
  ];

  const stmt = database.prepare(
    `INSERT INTO services
      (service_id, name, code, network, is_active, commission_agent_pct,
       commission_owner_pct, created_at, updated_at)
     VALUES (?, ?, ?, ?, 1, 10, 20, ?, ?)
     ON CONFLICT(service_id) DO NOTHING`
  );

  for (const [id, name, code, network] of services) {
    stmt.run(id, name, code, network, Date.now(), Date.now());
  }
}

function resolveDbFile() {
  return (
    process.env.APP_DB_PATH ||
    process.env.BAZIK_DB_PATH ||
    path.join(__dirname, "..", "..", "data", "app.db")
  );
}

function getDb() {
  if (db) return db;

  dbFile = resolveDbFile();

  if (dbFile !== ":memory:") {
    fs.mkdirSync(path.dirname(dbFile), { recursive: true });
  }

  db = new DatabaseSync(dbFile);

  db.exec(fs.readFileSync(BAZIK_SCHEMA, "utf8"));
  db.exec(fs.readFileSync(APP_SCHEMA, "utf8"));
  ensureColumns(db, "transactions", TRANSACTION_EXTRA_COLUMNS);
  seedExchangeRates(db);
  seedServices(db);

  return db;
}

function getDbFile() {
  if (!dbFile) getDb();
  return dbFile;
}

/** Operasyon konpoze. `fn` dwe sinkwòn (API `node:sqlite` a sinkwòn). */
function transaction(fn) {
  const database = getDb();
  database.exec("BEGIN IMMEDIATE");
  try {
    const result = fn(database);
    database.exec("COMMIT");
    return result;
  } catch (err) {
    database.exec("ROLLBACK");
    throw err;
  }
}

/** Pou tès yo: fèmen epi bliye koneksyon an. */
function resetDb() {
  if (db) db.close();
  db = null;
  dbFile = null;
}

function now() {
  return Date.now();
}

module.exports = { getDb, getDbFile, transaction, resetDb, now };
