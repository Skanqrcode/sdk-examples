"use strict";

/**
 * skanqrcode — plain-JS (CommonJS) client for the SkanQRCode API (OpenAPI 1.7.0).
 * Contract: ../../docs/api-contract.md
 *
 * @typedef {"malicious"|"suspicious"|"not_malicious"} Verdict
 * @typedef {"allow"|"warn"|"block"} Action
 * @typedef {"url"|"ip"} Mode
 * @typedef {"sandbox"|"production"} Environment
 * @typedef {"url"|"host"|"domain"|"ip"} MatchType
 * @typedef {"pro"|"business"} PlanId
 * @typedef {"invalid_request"|"unauthorized"|"forbidden"|"not_found"|"plan_feature_unavailable"|"payment_required"|"rate_limited"|"quota_exceeded"|"auth_unavailable"|"internal"} ErrorCode
 *
 * @typedef {Object} RelatedHost
 * @property {string} host
 * @property {Verdict} verdict
 *
 * @typedef {Object} CheckResult
 * @property {Verdict} verdict
 * @property {Action} action allow / warn / block — branch on this
 * @property {Mode} mode
 * @property {string[]} reasons reason codes as plain strings
 * @property {string|null} finalUrl
 * @property {boolean} cached
 * @property {number} executionTimeMs Server-side evaluation time in milliseconds
 * @property {Environment} environment
 * @property {boolean} licensedForProduction
 * @property {string} requestId
 * @property {RelatedHost[]} [related] IP mode only
 *
 * @typedef {Object} UsageResponse
 * @property {string} tenantId
 * @property {string} month YYYY-MM
 * @property {number} monthlyQuota
 * @property {number} totalRequests
 * @property {number} availableRequests
 *
 * @typedef {Object} UsageHour
 * @property {string} hour
 * @property {Mode} mode
 * @property {number} total
 * @property {number} capacityUsedPercent
 * @property {number} blockedRpm
 * @property {number} blockedQuota
 * @property {number} malicious
 * @property {number} suspicious
 * @property {number} notMalicious
 * @property {number} cached
 *
 * @typedef {Object} UsageHourlyResponse
 * @property {string} tenantId
 * @property {string} month
 * @property {number} rpmLimit
 * @property {number} hourlyCapacity
 * @property {UsageHour[]} hours
 *
 * @typedef {Object} ListEntry
 * @property {string} id
 * @property {MatchType} matchType
 * @property {string} value
 * @property {string} createdAt
 *
 * @typedef {Object} ListPage
 * @property {ListEntry[]} entries
 * @property {string|null} nextCursor null on the last page
 */

const DEFAULT_BASE_URL = "https://api.skanqrcode.com";
const DEFAULT_TIMEOUT_MS = 5000;

/** The documented error codes, for runtime checks. */
const ERROR_CODES = [
  "invalid_request",
  "unauthorized",
  "forbidden",
  "not_found",
  "plan_feature_unavailable",
  "payment_required",
  "rate_limited",
  "quota_exceeded",
  "auth_unavailable",
  "internal",
];

class SkanQRCodeError extends Error {
  /**
   * @param {ErrorCode|string} code one of ERROR_CODES; unknown strings still work
   * @param {string} message
   * @param {string} requestId
   * @param {number} status
   * @param {number|null} [retryAfter] seconds from the Retry-After header (429s)
   */
  constructor(code, message, requestId, status, retryAfter = null) {
    super(message);
    this.name = "SkanQRCodeError";
    this.code = code;
    this.requestId = requestId;
    this.status = status;
    this.retryAfter = retryAfter;
  }
}

/** @param {Record<string, string|number|undefined>} params */
function query(params) {
  const search = new URLSearchParams();
  for (const [key, value] of Object.entries(params)) {
    if (value !== undefined) search.set(key, String(value));
  }
  const qs = search.toString();
  return qs ? `?${qs}` : "";
}

class SkanQRCodeClient {
  /**
   * @param {{ apiKey: string, baseUrl?: string, timeoutMs?: number }} options
   *   apiKey is sk_test_... (sandbox) or sk_live_... (production)
   */
  constructor(options) {
    this.apiKey = options.apiKey;
    this.baseUrl = options.baseUrl || DEFAULT_BASE_URL;
    this.timeoutMs = options.timeoutMs || DEFAULT_TIMEOUT_MS;
  }

  /**
   * POST /v1/check. Consumes one quota unit. `userId` (opaque, 1-128 chars) enables per-user caching.
   * @param {string} target
   * @param {string} [userId]
   * @returns {Promise<CheckResult>}
   */
  async checkUrl(target, userId) {
    const body = { target };
    if (userId !== undefined) body.userId = userId;
    return this._request("/v1/check", {
      method: "POST",
      body: JSON.stringify(body),
    });
  }

  /**
   * GET /v1/usage. `month` is YYYY-MM (UTC); defaults to the current month.
   * @param {string} [month]
   * @returns {Promise<UsageResponse>}
   */
  async getUsage(month) {
    return this._request(`/v1/usage${query({ month })}`, { method: "GET" });
  }

  /**
   * GET /v1/usage/hourly. `month` is YYYY-MM (UTC); defaults to the current month.
   * @param {string} [month]
   * @returns {Promise<UsageHourlyResponse>}
   */
  async getUsageHourly(month) {
    return this._request(`/v1/usage/hourly${query({ month })}`, { method: "GET" });
  }

  /**
   * GET /v1/allow-list (Pro & Business plans only). `limit` is 1-500, default 100.
   * @param {number} [limit]
   * @param {string} [cursor]
   * @returns {Promise<ListPage>}
   */
  async listAllowList(limit, cursor) {
    return this._request(`/v1/allow-list${query({ limit, cursor })}`, { method: "GET" });
  }

  /**
   * POST /v1/allow-list (Pro & Business plans only; needs an admin-scope key). Idempotent.
   * @param {MatchType} matchType
   * @param {string} value
   * @returns {Promise<ListEntry>}
   */
  async addAllowListEntry(matchType, value) {
    return this._request("/v1/allow-list", {
      method: "POST",
      body: JSON.stringify({ matchType, value }),
    });
  }

  /**
   * DELETE /v1/allow-list/{entryId} (Pro & Business plans only; needs an admin-scope key).
   * @param {string} entryId
   * @returns {Promise<void>}
   */
  async deleteAllowListEntry(entryId) {
    await this._request(`/v1/allow-list/${encodeURIComponent(entryId)}`, { method: "DELETE" });
  }

  /**
   * GET /v1/block-list (every plan). `limit` is 1-500, default 100.
   * @param {number} [limit]
   * @param {string} [cursor]
   * @returns {Promise<ListPage>}
   */
  async listBlockList(limit, cursor) {
    return this._request(`/v1/block-list${query({ limit, cursor })}`, { method: "GET" });
  }

  /**
   * POST /v1/block-list (every plan; needs an admin-scope key). Idempotent.
   * @param {MatchType} matchType
   * @param {string} value
   * @returns {Promise<ListEntry>}
   */
  async addBlockListEntry(matchType, value) {
    return this._request("/v1/block-list", {
      method: "POST",
      body: JSON.stringify({ matchType, value }),
    });
  }

  /**
   * DELETE /v1/block-list/{entryId} (every plan; needs an admin-scope key).
   * @param {string} entryId
   * @returns {Promise<void>}
   */
  async deleteBlockListEntry(entryId) {
    await this._request(`/v1/block-list/${encodeURIComponent(entryId)}`, { method: "DELETE" });
  }

  /**
   * POST /v1/billing/checkout. Needs an admin-scope key and a Turnstile token minted by a real
   * browser flow. Human-in-the-loop: hand the returned URL to a person; an autonomous agent
   * must never complete checkout itself.
   * @param {PlanId} planId
   * @param {string} turnstileToken
   * @returns {Promise<{ url: string }>}
   */
  async createCheckoutSession(planId, turnstileToken) {
    return this._request("/v1/billing/checkout", {
      method: "POST",
      body: JSON.stringify({ planId, turnstileToken }),
    });
  }

  /**
   * POST /v1/billing/portal. Needs an admin-scope key. Human-in-the-loop: hand the returned URL
   * to a person.
   * @returns {Promise<{ url: string }>}
   */
  async createPortalSession() {
    return this._request("/v1/billing/portal", { method: "POST" });
  }

  /**
   * GET /health. Liveness only; needs no API key.
   * @returns {Promise<{ status: "ok" }>}
   */
  async getHealth() {
    return this._request("/health", { method: "GET" }, false);
  }

  async _request(path, init, auth = true) {
    const headers = {};
    if (init.body !== undefined) headers["Content-Type"] = "application/json";
    if (auth) headers.Authorization = `Bearer ${this.apiKey}`;

    const response = await fetch(`${this.baseUrl}${path}`, {
      ...init,
      headers,
      signal: AbortSignal.timeout(this.timeoutMs),
    });

    if (!response.ok) {
      throw await this._toError(response);
    }

    // 204 No Content (deletes): success, nothing to parse.
    if (response.status === 204) {
      return undefined;
    }

    return response.json();
  }

  /** Builds the typed error; falls back to a synthetic `internal` if the body isn't the documented JSON. */
  async _toError(response) {
    const retryAfterHeader = response.headers.get("Retry-After");
    const retryAfterSeconds = retryAfterHeader === null ? NaN : Number(retryAfterHeader);
    const retryAfter = Number.isFinite(retryAfterSeconds) ? retryAfterSeconds : null;

    let body;
    try {
      body = JSON.parse(await response.text());
    } catch {
      body = undefined;
    }

    const err = body && body.error;
    if (err && typeof err.code === "string") {
      return new SkanQRCodeError(
        err.code,
        err.message || "",
        err.requestId || response.headers.get("X-Request-Id") || "",
        response.status,
        retryAfter,
      );
    }

    return new SkanQRCodeError(
      "internal",
      `Unexpected ${response.status} response from the API (body was not the documented error JSON).`,
      response.headers.get("X-Request-Id") || "",
      response.status,
      retryAfter,
    );
  }
}

/**
 * not_malicious -> allow, suspicious -> warn, malicious -> block. True only for `block`.
 * @param {CheckResult} result
 * @returns {boolean}
 */
function shouldBlock(result) {
  return result.action === "block";
}

/**
 * True only for `allow`; `warn` is neither safe nor blocked, so surface it to the user.
 * @param {CheckResult} result
 * @returns {boolean}
 */
function isSafe(result) {
  return result.action === "allow";
}

module.exports = { SkanQRCodeClient, SkanQRCodeError, ERROR_CODES, shouldBlock, isSafe };
