"use strict";

/**
 * Kreye yon itilizatè nan baz SQLite la, depi liy kòmand lan.
 *
 *   node server/scripts/create_user.js --email admin@x.com --password secret123 --role admin
 *   node server/scripts/create_user.js --list
 *
 * Poukisa yon script epi pa yon wout HTTP: premye kont yo dwe egziste AVAN
 * yon moun ka konekte. Epi kreye yon kont ak dwa admin pa dwe janm posib
 * depi yon navigatè san otantifikasyon.
 *
 * Si pa gen okenn antrepriz, script la kreye youn otomatikman: san
 * `enterpriseId`, yon itilizatè pa ka gen wallet ni fè tranzaksyon.
 */

const path = require("node:path");

// Baz la: menm fichye ak serveur a ak Bazik.
process.env.APP_DB_PATH =
  process.env.APP_DB_PATH || path.join(__dirname, "..", "data", "app.db");

const { getDb, getDbFile, now } = require("../src/db/db");
const users = require("../src/auth/users");
const AppIds = require("../../bazik/src/ids");

function parseArgs(argv) {
  const args = {};
  for (let i = 0; i < argv.length; i++) {
    const token = argv[i];
    if (!token.startsWith("--")) continue;

    const key = token.slice(2);
    const next = argv[i + 1];

    if (next === undefined || next.startsWith("--")) {
      args[key] = true;
    } else {
      args[key] = next;
      i++;
    }
  }
  return args;
}

function listUsers() {
  const rows = getDb()
    .prepare(
      `SELECT u.uid, u.email, u.role, u.is_active, u.display_name,
              eu.enterprise_id, eu.enterprise_name
         FROM users u
         LEFT JOIN enterprise_users eu ON eu.uid = u.uid AND eu.is_active = 1
        ORDER BY u.created_at ASC`
    )
    .all();

  if (rows.length === 0) {
    console.log("\nBaz la vid: pa gen okenn itilizatè.\n");
    return;
  }

  console.log(`\n${rows.length} itilizatè nan ${getDbFile()}:\n`);
  for (const row of rows) {
    const status = row.is_active === 1 ? "aktif" : "dezaktive";
    console.log(
      `  ${row.role.padEnd(14)} ${row.email.padEnd(30)} ${status.padEnd(11)} ` +
        `${row.enterprise_name || "— san antrepriz —"}`
    );
  }
  console.log("");
}

/** Jwenn antrepriz la, oswa kreye youn si baz la vid. */
function ensureEnterprise(name) {
  const db = getDb();
  const existing = db
    .prepare("SELECT * FROM enterprises WHERE is_active = 1 ORDER BY created_at ASC LIMIT 1")
    .get();

  if (existing) {
    return {
      enterpriseId: existing.enterprise_id,
      enterpriseName: existing.name,
      created: false,
    };
  }

  const enterpriseId = AppIds.enterprise(`${name}:${Date.now()}`);

  db.prepare(
    `INSERT INTO enterprises
      (enterprise_id, name, owner_uid, currency, is_active, created_at, updated_at)
     VALUES (?, ?, '', 'USD', 1, ?, ?)`
  ).run(enterpriseId, name, now(), now());

  return { enterpriseId, enterpriseName: name, created: true };
}

async function main() {
  const args = parseArgs(process.argv.slice(2));

  if (args.list) {
    listUsers();
    return;
  }

  const email = args.email && args.email !== true ? String(args.email) : "";
  const password = args.password && args.password !== true ? String(args.password) : "";
  const role = String(args.role || "admin");
  const displayName =
    args.name && args.name !== true ? String(args.name) : role.toUpperCase();

  if (!email || !password) {
    console.error(
      "\nSèvi ak:\n" +
        "  node server/scripts/create_user.js --email <imel> --password <modpas> " +
        "[--role owner|admin|agent|client] [--name \"Non Konplè\"]\n" +
        "  node server/scripts/create_user.js --list\n"
    );
    process.exit(1);
  }

  const enterprise = ensureEnterprise(
    String(args.enterprise || "VOUPVAPCASH")
  );

  try {
    const user = await users.createUser({
      email,
      password,
      displayName,
      role,
      enterpriseId: enterprise.enterpriseId,
      enterpriseName: enterprise.enterpriseName,
      createdBy: "cli",
    });

    // Yon owner vin mèt antrepriz la si pa gen youn.
    if (role === "owner") {
      const db = getDb();
      const current = db
        .prepare("SELECT owner_uid FROM enterprises WHERE enterprise_id = ?")
        .get(enterprise.enterpriseId);

      if (!current?.owner_uid) {
        db.prepare(
          "UPDATE enterprises SET owner_uid = ?, updated_at = ? WHERE enterprise_id = ?"
        ).run(user.uid, now(), enterprise.enterpriseId);
      }
    }

    console.log(`\n✅ Itilizatè kreye nan ${getDbFile()}\n`);
    console.log(`  imel        ${user.email}`);
    console.log(`  modpas      ${password}`);
    console.log(`  wòl         ${user.role}`);
    console.log(`  uid         ${user.uid}`);
    console.log(`  antrepriz   ${enterprise.enterpriseName} (${enterprise.enterpriseId})`);

    if (enterprise.created) {
      console.log("\n  ℹ️  Antrepriz la te kreye otomatikman (baz la te vid).");
    }

    console.log("\n  Wallet li kreye vid. Pou ba l kòb pou tès:");
    console.log(
      `  node bazik/scripts/seed_dev_db.js ${user.uid} ${enterprise.enterpriseId} 500\n`
    );
  } catch (err) {
    console.error(`\n❌ ${err.code || "erreur"}: ${err.message}\n`);
    process.exit(1);
  }
}

main().catch((err) => {
  console.error("\n❌", err.message, "\n");
  process.exit(1);
});
