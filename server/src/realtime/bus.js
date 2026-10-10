"use strict";

/**
 * Bis evènman tan reyèl — yon sèl pwosesis Node, donk yon EventEmitter ase.
 *
 * Evènman yo pa pote DONE: sèlman "kisa ki chanje" (`topics`) ak pou ki
 * antrepriz. Ekran ki konekte yo rechaje sa yo afiche a, ak menm dwa ak
 * anvan (wout API yo). Konsa yon ajan pa janm resevwa chif yon lòt moun pa
 * mwayen kanal sa a.
 *
 * `enterpriseId: "*"` = tout antrepriz (webhook Bazik/PSL, pasaj otomatik:
 * nou pa toujou konnen antrepriz la la, e se jis yon siyal pou rechaje).
 */

const { EventEmitter } = require("node:events");

const bus = new EventEmitter();
bus.setMaxListeners(0);

const TOPICS_BY_PATH = [
  ["/api/transactions", ["transactions"]],
  ["/api/bazik", ["transfers", "transactions", "wallets", "commissions"]],
  ["/api/psl", ["transfers", "transactions", "wallets", "commissions"]],
  ["/api/airtime", ["transactions", "wallets", "commissions"]],
  ["/api/wallets", ["wallets", "topups"]],
  ["/api/payouts", ["payouts", "wallets"]],
  ["/api/commissions", ["commissions", "wallets"]],
  ["/api/services", ["services"]],
  ["/api/users", ["users", "wallets"]],
  ["/api/settings", ["settings"]],
];

function topicsFor(path) {
  const hit = TOPICS_BY_PATH.find(([prefix]) => path.startsWith(prefix));
  return hit ? hit[1] : [];
}

let seq = 0;
function publish(enterpriseId, topics, extra = {}) {
  if (!enterpriseId || !topics?.length) return;
  seq += 1;
  bus.emit("change", { id: seq, enterpriseId, topics: [...new Set(topics)], at: Date.now(), ...extra });
}

/**
 * Middleware: chak demann ki CHANJE yon bagay (pa GET) e ki reyisi pibliye
 * yon evènman. Webhook yo (san itilizatè) pibliye pou tout antrepriz.
 */
function publishMutations(req, res, next) {
  if (req.method === "GET" || req.method === "HEAD" || req.method === "OPTIONS") return next();
  res.on("finish", () => {
    if (res.statusCode >= 400) return;
    const path = req.originalUrl.split("?")[0];
    if (path.startsWith("/api/events") || path.startsWith("/api/auth") || path.startsWith("/api/otp")) return;
    // Devi yo se POST men yo pa chanje anyen: ajan an rele yo sou chak lèt li
    // tape. Pibliye yo ta fè tout ekran yo rechaje san rezon.
    if (/\/quote$/.test(path) || /\/quotes?\//.test(path)) return;
    const topics = topicsFor(path);
    if (!topics.length) return;
    const enterpriseId = req.user?.enterpriseId || (/\/webhook/.test(path) ? "*" : "");
    publish(enterpriseId, topics, { source: path.replace(/\/[A-Za-z0-9_-]{20,}/g, "/:id") });
  });
  next();
}

function subscribe(listener) {
  bus.on("change", listener);
  return () => bus.off("change", listener);
}

function listenerCount() {
  return bus.listenerCount("change");
}

module.exports = { publish, publishMutations, subscribe, topicsFor, listenerCount };
