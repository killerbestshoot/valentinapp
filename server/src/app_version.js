"use strict";

/**
 * Vèsyon app la: yon APK twò ansyen PA MACHE.
 *
 * Chak apèl app la voye `X-App-Build` (nimewo build pubspec la) ak
 * `X-App-Platform` (android / web). Anba vèsyon minimòm lan, sèvè a reponn
 * 426 `app_outdated`: app la montre ekran "Mete ajou" e li pa ka fè anyen
 * ankò. Se SÈVÈ A ki bloke, pa sèlman app la: yon APK ansyen pa ka kontounen l.
 *
 * APK anvan mekanis sa a (≤ 1.1.2+6) pa voye `X-App-Build`: nou rekonèt yo pa
 * `User-Agent: Dart/…` (kliyan dart:io) san tèt la, epi nou bloke yo tou.
 *
 * NOUVO VÈSYON: monte `version:` nan pubspec.yaml, LATEST_BUILD isit la, epi
 * MIN_BUILD si vèsyon anvan an pa dwe mache ankò (oswa APP_MIN_BUILD nan .env).
 */

const LATEST_VERSION = "1.2.0";
const LATEST_BUILD = 7;
const MIN_BUILD = 7;
const DOWNLOAD_URL = "https://voupvapcash.com/download/voupvapcash.apk";

/** Wout ki pa soti nan app la (webhook pasrèl yo) oswa ki deja kontwole. */
const EXEMPT = [/^\/api\/app\/version$/, /^\/api\/bazik\/webhook/, /^\/api\/psl\/webhook/, /^\/api\/events$/];

function minBuild(env = process.env) {
  const value = Number(env.APP_MIN_BUILD);
  return Number.isInteger(value) && value > 0 ? value : MIN_BUILD;
}

function versionInfo(env = process.env) {
  return {
    latestVersion: LATEST_VERSION,
    latestBuild: LATEST_BUILD,
    minBuild: minBuild(env),
    downloadUrl: DOWNLOAD_URL,
  };
}

function outdatedBody(env) {
  const info = versionInfo(env);
  return {
    ok: false,
    code: "app_outdated",
    message:
      `Vèsyon app ou a twò ansyen. Telechaje vèsyon ${info.latestVersion} la sou ${info.downloadUrl} ` +
      `(oswa rechaje paj la sou navigatè a).`,
    ...info,
  };
}

/** Middleware: bloke yon app ki pi ansyen pase vèsyon minimòm lan. */
function requireAppVersion(req, res, next) {
  const path = req.originalUrl.split("?")[0];
  if (EXEMPT.some((re) => re.test(path))) return next();

  const raw = req.get("X-App-Build");
  if (raw === undefined) {
    // APK anvan mekanis la: kliyan dart:io san tèt vèsyon.
    if (/^Dart\//.test(req.get("User-Agent") || "")) return res.status(426).json(outdatedBody());
    return next(); // webhook, curl, navigatè ki poko rechaje...
  }

  const build = Number(raw);
  if (!Number.isInteger(build) || build < minBuild()) return res.status(426).json(outdatedBody());
  return next();
}

module.exports = { requireAppVersion, versionInfo, LATEST_VERSION, LATEST_BUILD, MIN_BUILD };
