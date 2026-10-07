import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { describe, it } from "node:test";
import { ApiError, createApiClient, VERSION } from "../src/api.ts";
import { CHECK_RESULT, fakeFetch, USAGE } from "./fake-api.ts";

const BASE = { apiKey: "sk_test_abc", baseUrl: "https://api.skanqrcode.com" };
const TARGET = "https://phish.example/login?session=secret-token";

async function rejection(promise: Promise<unknown>): Promise<ApiError> {
  try {
    await promise;
  } catch (err) {
    assert.ok(err instanceof ApiError);
    return err;
  }
  assert.fail("expected the call to fail");
}

describe("createApiClient", () => {
  it("posts the target with the key and an MCP User-Agent", async () => {
    const fake = fakeFetch(200, CHECK_RESULT);
    const result = await createApiClient({ ...BASE, fetch: fake.fetch }).checkUrl({ target: TARGET });
    assert.deepEqual(result, CHECK_RESULT);
    const call = fake.calls[0];
    assert.equal(call?.url, "https://api.skanqrcode.com/v1/check");
    assert.equal(call?.init.method, "POST");
    assert.equal(call?.init.body, JSON.stringify({ target: TARGET }));
    const headers = call?.init.headers as Record<string, string>;
    assert.equal(headers["Authorization"], "Bearer sk_test_abc");
    // The API tags usage as MCP by this prefix (skanqrcode-api apps/api/src/app.ts).
    assert.ok(headers["User-Agent"]?.startsWith(`skanqrcode-mcp-server/${VERSION} `));
  });

  it("sends userId only when given", async () => {
    const fake = fakeFetch(200, CHECK_RESULT);
    await createApiClient({ ...BASE, fetch: fake.fetch }).checkUrl({ target: TARGET, userId: "u1" });
    assert.equal(fake.calls[0]?.init.body, JSON.stringify({ target: TARGET, userId: "u1" }));
  });

  it("keeps fields the API adds later", async () => {
    const fake = fakeFetch(200, { ...CHECK_RESULT, newField: 1 });
    const result = await createApiClient({ ...BASE, fetch: fake.fetch }).checkUrl({ target: TARGET });
    assert.equal((result as Record<string, unknown>)["newField"], 1);
  });

  it("turns a 429 into its error code with Retry-After", async () => {
    const fake = fakeFetch(429, { error: { code: "rate_limited", message: "Slow down.", requestId: "req_1" } }, {
      "retry-after": "12",
    });
    const err = await rejection(createApiClient({ ...BASE, fetch: fake.fetch }).checkUrl({ target: TARGET }));
    assert.deepEqual(err.toJSON(), {
      error: { code: "rate_limited", message: "Slow down.", requestId: "req_1", retryAfterSeconds: 12 },
    });
  });

  it("handles a non-JSON error body", async () => {
    const fake = fakeFetch(502, "<html>bad gateway</html>");
    const err = await rejection(createApiClient({ ...BASE, fetch: fake.fetch }).checkUrl({ target: TARGET }));
    assert.equal(err.code, "internal");
  });

  it("never puts the checked URL in a network error", async () => {
    const failing = (async () => {
      throw new TypeError(`fetch failed for ${TARGET}`);
    }) as typeof fetch;
    const err = await rejection(createApiClient({ ...BASE, fetch: failing }).checkUrl({ target: TARGET }));
    assert.equal(err.code, "network_error");
    assert.ok(!JSON.stringify(err).includes("phish.example"));
  });

  it("reports a timeout as its own code", async () => {
    const slow = ((_: unknown, init: RequestInit = {}) =>
      new Promise((_resolve, reject) => {
        // AbortSignal.timeout doesn't keep Node's event loop alive; this timer does until the abort.
        const keepAlive = setInterval(() => {}, 1000);
        init.signal?.addEventListener("abort", () => {
          clearInterval(keepAlive);
          reject(init.signal?.reason);
        });
      })) as typeof fetch;
    const err = await rejection(createApiClient({ ...BASE, fetch: slow, timeoutMs: 20 }).checkUrl({ target: TARGET }));
    assert.equal(err.code, "timeout");
  });

  it("rejects a response that does not match the contract", async () => {
    const fake = fakeFetch(200, { verdict: "maybe" });
    const err = await rejection(createApiClient({ ...BASE, fetch: fake.fetch }).checkUrl({ target: TARGET }));
    assert.equal(err.code, "unexpected_response");
  });

  it("reads usage for a given month", async () => {
    const fake = fakeFetch(200, USAGE);
    assert.deepEqual(await createApiClient({ ...BASE, fetch: fake.fetch }).getUsage({ month: "2026-10" }), USAGE);
    assert.equal(fake.calls[0]?.url, "https://api.skanqrcode.com/v1/usage?month=2026-10");
    assert.equal(fake.calls[0]?.init.method, "GET");
  });

  it("VERSION matches package.json and the registry manifest", () => {
    const read = (file: string) => JSON.parse(readFileSync(new URL(`../${file}`, import.meta.url), "utf8"));
    const pkg = read("package.json") as { version: string; mcpName: string };
    const manifest = read("server.json") as { name: string; version: string; packages: Array<{ version: string }> };
    assert.equal(VERSION, pkg.version);
    assert.equal(manifest.version, pkg.version);
    assert.equal(manifest.packages[0]?.version, pkg.version);
    // The registry checks that the npm package claims this server name.
    assert.equal(manifest.name, pkg.mcpName);
  });
});
