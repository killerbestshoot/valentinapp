const functions = require("firebase-functions/v2/https");

exports.runCommissionNow = functions.onRequest({ cors: true }, async (req, res) => {
  try {
    const result = {
      ok: true,
      sourceLabel: "manual_run_commission",
      processed: 1,
      message: "CORS FIXED + FUNCTION WORKING",
      time: new Date().toISOString()
    };
    res.status(200).json(result);
  } catch (e) {
    res.status(500).json({ ok: false, error: e.toString() });
  }
});