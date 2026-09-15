"use strict";

/**
 * Transpò Hostinger Mail API.
 *
 * Kontra a soti nan spec OpenAPI ofisyèl la
 * (https://github.com/hostinger/mail-api/blob/main/openapi.json):
 *
 *   POST {base}/api/v1/mailboxes/{mailboxResourceId}/send
 *   Authorization: Bearer <token>
 *   { to: [email], displayName?, cc?, bcc?, subject?, text?, html? }
 *   -> 204 No Content (siksè), 401, 403, 422, 500, 502
 *
 * Remake: adrès ekspeditè a PA nan kò a — se mailbox token an otorize a.
 * `displayName` se sèlman non ki parèt.
 */

const SEND_PATH = (mailboxId) => `/api/v1/mailboxes/${encodeURIComponent(mailboxId)}/send`;

class MailError extends Error {
  constructor(code, message, { status = 0, retryable = false, body = null } = {}) {
    super(message);
    this.name = "MailError";
    this.code = code;
    this.status = status;
    this.retryable = retryable;
    this.body = body;
  }
}

function createApiTransport(config, { fetchImpl = globalThis.fetch } = {}) {
  const { baseUrl, token, mailboxId } = config.api;

  return {
    provider: "hostinger_api",

    async send({ to, subject, text, html }) {
      const controller = new AbortController();
      const timer = setTimeout(() => controller.abort(), config.timeoutMs);

      let response;
      try {
        response = await fetchImpl(`${baseUrl}${SEND_PATH(mailboxId)}`, {
          method: "POST",
          headers: {
            Authorization: `Bearer ${token}`,
            "Content-Type": "application/json",
            Accept: "application/json",
          },
          body: JSON.stringify({
            to: Array.isArray(to) ? to : [to],
            displayName: config.fromName,
            subject,
            text,
            html,
          }),
          signal: controller.signal,
        });
      } catch (err) {
        throw new MailError("network_error", `Hostinger Mail API pa reponn: ${err.message}`, {
          retryable: true,
        });
      } finally {
        clearTimeout(timer);
      }

      // 204 = siksè, san kò.
      if (response.status === 204 || response.ok) return { ok: true, status: response.status };

      let body = null;
      try {
        body = JSON.parse(await response.text());
      } catch {
        body = null;
      }

      const message = body?.message || body?.error || `Hostinger reponn ${response.status}`;

      // 401/403 = pwoblèm token: re-eseye pa gen sans.
      // 422 = payload nou an move: re-eseye pa gen sans non plis.
      const retryable = response.status >= 500 || response.status === 429;

      const code =
        response.status === 401 || response.status === 403
          ? "unauthorized"
          : response.status === 422
            ? "invalid_payload"
            : `http_${response.status}`;

      throw new MailError(code, message, { status: response.status, retryable, body });
    },

    async verify() {
      // Pa gen endpoint "ping". Nou konfime sèlman konfigirasyon an konplè;
      // vre verifikasyon an fèt sou premye imel la.
      return { ok: Boolean(token && mailboxId), provider: "hostinger_api" };
    },

    async close() {},
  };
}

module.exports = { createApiTransport, MailError, SEND_PATH };
