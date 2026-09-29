"use strict";

/**
 * skanqrcode — plain-JS (CommonJS) client for the SkanQRCode API.
 * Contract: ../../docs/api-contract.md
 *
 * @typedef {"malicious"|"suspicious"|"not_malicious"} Verdict
 * @typedef {"url"|"ip"} Mode
 *
 * @typedef {Object} CheckResult
 * @property {Verdict} verdict
 * @property {Mode} mode
 * @property {number} score
 * @property {string[]} reasons
 * @property {boolean} cached
 * @property {boolean} partial
 * @property {string} requestId
 *
 * @typedef {Object} UsageHour
 * @property {string} hour
 * @property {Mode} mode
 * @property {number} total
 * @property {number} malicious
 * @property {number} suspicious
 * @property {number} notMalicious
 * @property {number} cached
 * @property {number} partial
 *
 * @typedef {Object} UsageResponse
 * @property {string} tenantId
 * @property {string} from
 * @property {string} to
 * @property {UsageHour[]} hours
 */

const DEFAULT_BASE_URL = "https://api.skanqrcode.com";
const DEFAULT_TIMEOUT_MS = 5000;

class SkanQRCodeError extends Error {
  /**
   * @param {string} code
   * @param {string} message
   * @param {string} requestId
   * @param {number} status
   */
  constructor(code, message, requestId, status) {
    super(message);
    this.name = "SkanQRCodeError";
    this.code = code;
    this.requestId = requestId;
    this.status = status;
  }
}

class SkanQRCodeClient {
  /**
   * @param {{ apiKey: string, baseUrl?: string, timeoutMs?: number }} options
   */
  constructor(options) {
    this.apiKey = options.apiKey;
    this.baseUrl = options.baseUrl || DEFAULT_BASE_URL;
    this.timeoutMs = options.timeoutMs || DEFAULT_TIMEOUT_MS;
  }

  /**
   * @param {string} target
   * @returns {Promise<CheckResult>}
   */
  async checkUrl(target) {
    return this._request("/v1/check", {
      method: "POST",
      body: JSON.stringify({ target }),
    });
  }

  /**
   * @param {string} from
   * @param {string} to
   * @returns {Promise<UsageResponse>}
   */
  async getUsage(from, to) {
    const params = new URLSearchParams({ from, to });
    return this._request(`/v1/usage?${params.toString()}`, { method: "GET" });
  }

  async _request(path, init) {
    const response = await fetch(`${this.baseUrl}${path}`, {
      ...init,
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${this.apiKey}`,
      },
      signal: AbortSignal.timeout(this.timeoutMs),
    });

    if (!response.ok) {
      const body = await response.json();
      throw new SkanQRCodeError(
        body.error.code,
        body.error.message,
        body.error.requestId,
        response.status,
      );
    }

    return response.json();
  }
}

/**
 * not_malicious -> safe, suspicious -> warn, malicious -> block.
 * @param {CheckResult} result
 * @returns {boolean}
 */
function shouldBlock(result) {
  return result.verdict === "malicious";
}

/**
 * True only for not_malicious; suspicious is a warn, not a pass.
 * @param {CheckResult} result
 * @returns {boolean}
 */
function isSafe(result) {
  return result.verdict === "not_malicious";
}

module.exports = { SkanQRCodeClient, SkanQRCodeError, shouldBlock, isSafe };
