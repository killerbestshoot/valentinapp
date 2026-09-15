const express = require("express");
const cors = require("cors");
require("dotenv").config();

const otpRoutes = require("./routes/otp.routes");
const bazikRoutes = require("./routes/bazik.routes");
const authRoutes = require("./routes/auth.routes");
const transactionRoutes = require("./routes/transactions.routes");
const userRoutes = require("./routes/users.routes");
const walletRoutes = require("./routes/wallets.routes");
const { commissions: commissionRoutes, services: serviceRoutes } = require("./routes/commissions.routes");
const payoutRoutes = require("./routes/payouts.routes");
const systemRoutes = require("./routes/system.routes");
const { attachUser } = require("./auth/middleware");
const { getDb, resetDb } = require("./db/db");
const { checkProductionConfig } = require("./preflight");

const preflight = checkProductionConfig();
for (const warning of preflight.warnings) console.warn(`⚠️  ${warning}`);
if (preflight.errors.length > 0) {
  console.error("Serveur a refize demare — konfigirasyon pwodiksyon an pa konplè:");
  for (const error of preflight.errors) console.error(`  ✗ ${error}`);
  process.exit(1);
}

const app = express();
app.disable("x-powered-by");

// Lis orijin separe pa vigil. Vid oswa `*` = tout orijin (devlopman). Jeton an
// voye nan `Authorization`, pa nan yon cookie: CORS pa pwoteje kont CSRF isit
// la, li jis limite ki sit ka rele API a.
const corsOrigins = String(process.env.CORS_ORIGINS || "*")
  .split(",")
  .map((origin) => origin.trim())
  .filter(Boolean);
app.use(
  cors({
    origin: corsOrigins.length === 0 || corsOrigins.includes("*") ? "*" : corsOrigins,
    credentials: false,
  })
);

// `verify` kenbe kò a tel kel li rive: siyati webhook Bazik la kalkile sou
// bytes orijinal yo, donk yon JSON.parse -> stringify t ap kase verifikasyon an.
app.use(
  express.json({
    verify: (req, res, buf) => {
      req.rawBody = buf.toString("utf8");
    },
  })
);

// Idantite a soti nan jeton an, sou chak demand.
app.use(attachUser);

app.get("/", (req, res) => {
  res.json({ ok: true, service: "voupvapcash-server" });
});

// Pou Docker ak load balancer yo: san otantifikasyon, e li pa bay okenn detay.
// `/api/system/health` la (otantifye) se pou moun.
app.get("/healthz", (req, res) => {
  try {
    getDb().prepare("SELECT 1").get();
    res.json({ ok: true });
  } catch {
    res.status(503).json({ ok: false });
  }
});

app.use("/api/auth", authRoutes);
app.use("/api/transactions", transactionRoutes);
app.use("/api/users", userRoutes);
app.use("/api/wallets", walletRoutes);
app.use("/api/commissions", commissionRoutes);
app.use("/api/services", serviceRoutes);
app.use("/api/payouts", payoutRoutes);
app.use("/api/system", systemRoutes);
app.use("/api/otp", otpRoutes);
app.use("/api/bazik", bazikRoutes);

const PORT = Number(process.env.PORT || 4700);
const HOST = process.env.HOST || "127.0.0.1";

const server = app.listen(PORT, HOST, () => {
  console.log(`Server running on http://${HOST}:${PORT}`);
});

// `docker stop` voye SIGTERM. Nou sispann aksepte demand, men nou kite sa ki
// deja kòmanse fini: yon transfè Bazik koupe nan mitan an ta rete an
// verifikasyon olye li regle.
const SHUTDOWN_GRACE_MS = Number(process.env.SHUTDOWN_GRACE_MS || 25000);
let shuttingDown = false;

function shutdown(signal) {
  if (shuttingDown) return;
  shuttingDown = true;
  console.log(`${signal} resevwa — n ap fèmen serveur a...`);

  const force = setTimeout(() => {
    console.error("Demand yo pa fini alè — nou fèmen kanmenm.");
    process.exit(1);
  }, SHUTDOWN_GRACE_MS);
  force.unref();

  server.close(() => {
    resetDb();
    process.exit(0);
  });
  server.closeIdleConnections();
}

process.on("SIGTERM", () => shutdown("SIGTERM"));
process.on("SIGINT", () => shutdown("SIGINT"));
