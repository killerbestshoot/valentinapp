const store = new Map();

function saveOtp(email, otp, ttlSeconds) {
  const key = String(email).trim().toLowerCase();
  const expiresAt = Date.now() + Number(ttlSeconds) * 1000;
  store.set(key, { otp: String(otp), expiresAt });
}

function verifyOtp(email, otp) {
  const key = String(email).trim().toLowerCase();
  const rec = store.get(key);
  if (!rec) return false;

  if (Date.now() > rec.expiresAt) {
    store.delete(key);
    return false;
  }

  const ok = String(rec.otp) === String(otp).trim();
  if (ok) store.delete(key);
  return ok;
}

module.exports = { saveOtp, verifyOtp };