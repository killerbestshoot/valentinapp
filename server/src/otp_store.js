const fs = require("fs");
const path = require("path");

const dbPath = process.env.OTP_DB_PATH || path.join(__dirname, "..", "data", "otp_db.json");

function readDb() {
  try {
    const raw = fs.readFileSync(dbPath, "utf8");
    return JSON.parse(raw);
  } catch (err) {
    if (err.code === "ENOENT") return {};
    throw err;
  }
}

function writeDb(db) {
  fs.mkdirSync(path.dirname(dbPath), { recursive: true });
  fs.writeFileSync(dbPath, JSON.stringify(db, null, 2));
}

function saveOtp(email, otp, ttlSeconds) {
  const key = String(email).trim().toLowerCase();
  const expiresAt = Date.now() + Number(ttlSeconds) * 1000;
  const db = readDb();
  db[key] = { otp: String(otp), expiresAt };
  writeDb(db);
}

function verifyOtp(email, otp) {
  const key = String(email).trim().toLowerCase();
  const db = readDb();
  const rec = db[key];
  if (!rec) return false;

  if (Date.now() > rec.expiresAt) {
    delete db[key];
    writeDb(db);
    return false;
  }

  const ok = String(rec.otp) === String(otp).trim();
  if (ok) {
    delete db[key];
    writeDb(db);
  }
  return ok;
}

module.exports = { saveOtp, verifyOtp };
