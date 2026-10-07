import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { loadConfig } from "../src/config.ts";

const KEY = "sk_test_abc123secret";

describe("loadConfig", () => {
  it("uses the production API by default", () => {
    assert.deepEqual(loadConfig({ SKANQRCODE_API_KEY: KEY }), {
      ok: true,
      config: { apiKey: KEY, baseUrl: "https://api.skanqrcode.com" },
    });
  });

  it("requires a key", () => {
    const result = loadConfig({});
    assert.equal(result.ok, false);
  });

  it("rejects something that is not a SkanQRCode key, without echoing it", () => {
    const result = loadConfig({ SKANQRCODE_API_KEY: "ghp_notourkey" });
    assert.equal(result.ok, false);
    assert.ok(!result.ok && !result.error.includes("ghp_notourkey"));
  });

  it("refuses to send the key over plain http to another host", () => {
    assert.equal(loadConfig({ SKANQRCODE_API_KEY: KEY, SKANQRCODE_BASE_URL: "http://api.example.com" }).ok, false);
  });

  it("allows plain http only to this machine, for local development", () => {
    const result = loadConfig({ SKANQRCODE_API_KEY: KEY, SKANQRCODE_BASE_URL: "http://localhost:8787/" });
    assert.deepEqual(result, { ok: true, config: { apiKey: KEY, baseUrl: "http://localhost:8787" } });
  });
});
