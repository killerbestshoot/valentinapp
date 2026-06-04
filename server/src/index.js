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

const PORT = Number(process.env.PORT || 4700);
const HOST = process.env.HOST || "127.0.0.1";

app.listen(PORT, HOST, () => {
  console.log(`Server running on http://${HOST}:${PORT}`);
});
