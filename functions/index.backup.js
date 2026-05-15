exports.onCommissionPayoutRequest = onDocumentCreated(
  "payout_requests/{requestId}",
  async (event) => {
    console.log("🔥 FUNCTION TRIGGERED:", event.params.requestId);

    const snap = event.data;
    if (!snap) {
      console.log("❌ Pa gen event.data");
      return;
    }

    const requestId = event.params.requestId;
    const request = snap.data();

    console.log("📦 REQUEST DATA:", JSON.stringify(request));