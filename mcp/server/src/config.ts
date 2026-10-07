export interface Config {
  apiKey: string;
  baseUrl: string;
}

export type ConfigResult = { ok: true; config: Config } | { ok: false; error: string };

const DEFAULT_BASE_URL = "https://api.skanqrcode.com";
const KEY_PATTERN = /^sk_(live|test)_\S+$/;
const LOCAL_HOSTS = new Set(["localhost", "127.0.0.1", "[::1]"]);

/**
 * Reads the server's settings from the environment. Error messages never echo the key: they end up in
 * MCP client logs, which people paste into issues.
 */
export function loadConfig(env: Record<string, string | undefined>): ConfigResult {
  const apiKey = env["SKANQRCODE_API_KEY"]?.trim();
  if (!apiKey) {
    return { ok: false, error: "SKANQRCODE_API_KEY is not set. Create a key at https://app.skanqrcode.com." };
  }
  if (!KEY_PATTERN.test(apiKey)) {
    return { ok: false, error: "SKANQRCODE_API_KEY does not look like a SkanQRCode key (sk_live_... or sk_test_...)." };
  }

  const rawBaseUrl = env["SKANQRCODE_BASE_URL"]?.trim() || DEFAULT_BASE_URL;
  let baseUrl: URL;
  try {
    baseUrl = new URL(rawBaseUrl);
  } catch {
    return { ok: false, error: "SKANQRCODE_BASE_URL is not a valid URL." };
  }
  // The key travels in every request, so it may only go over HTTPS (plain HTTP only to this machine).
  const local = baseUrl.protocol === "http:" && LOCAL_HOSTS.has(baseUrl.hostname);
  if (baseUrl.protocol !== "https:" && !local) {
    return { ok: false, error: "SKANQRCODE_BASE_URL must use https://." };
  }
  return { ok: true, config: { apiKey, baseUrl: baseUrl.href.replace(/\/+$/, "") } };
}
