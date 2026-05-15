const express = require("express");
const cors = require("cors");
require("dotenv").config();

const otpRoutes = require("./routes/otp.routes");

const app = express();

app.use(cors({ origin: "*", credentials: false }));
app.use(express.json());

app.get("/", (req, res) => {
  res.json({ ok: true, service: "voupvapcash-server" });
});

app.use("/api/otp", otpRoutes);

// 🔴 PORT FORCÉ ICI (PA DEPANN DE .env)
const PORT = 4700;

app.listen(PORT, () => {
  console.log(`✅ Server running on http://localhost:${PORT}`);
});