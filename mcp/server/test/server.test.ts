import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { InMemoryTransport } from "@modelcontextprotocol/sdk/inMemory.js";
import { createApiClient } from "../src/api.ts";
import { createServer } from "../src/server.ts";
import { CHECK_RESULT, fakeFetch, USAGE } from "./fake-api.ts";

/** A real MCP client talking to the server over an in-memory transport, with a fake API behind it. */
async function connect(status: number, body: unknown, headers: Record<string, string> = {}) {
  const fake = fakeFetch(status, body, headers);
  const server = createServer(createApiClient({ apiKey: "sk_test_abc", baseUrl: "https://api.test", fetch: fake.fetch }));
  const client = new Client({ name: "test-client", version: "0.0.0" });
  const [clientSide, serverSide] = InMemoryTransport.createLinkedPair();
  await Promise.all([server.connect(serverSide), client.connect(clientSide)]);
  return { client, calls: fake.calls };
}

describe("MCP server", () => {
  it("exposes exactly the two read-only tools", async () => {
    const { client } = await connect(200, CHECK_RESULT);
    const { tools } = await client.listTools();
    assert.deepEqual(tools.map((t) => t.name).sort(), ["check_url", "get_usage"]);
    for (const tool of tools) {
      assert.equal(tool.annotations?.readOnlyHint, true);
      assert.equal(tool.annotations?.destructiveHint, false);
      assert.ok(tool.outputSchema, `${tool.name} declares an output schema`);
    }
  });

  it("check_url returns the verdict as structured content and text", async () => {
    const { client, calls } = await connect(200, CHECK_RESULT);
    const result = await client.callTool({ name: "check_url", arguments: { target: "https://phish.example/" } });
    assert.equal(result.isError, undefined);
    assert.deepEqual(result.structuredContent, CHECK_RESULT);
    assert.deepEqual(JSON.parse((result.content as Array<{ text: string }>)[0]?.text ?? ""), CHECK_RESULT);
    assert.equal(calls[0]?.url, "https://api.test/v1/check");
  });

  it("check_url reports API errors with their code instead of throwing", async () => {
    const { client } = await connect(429, { error: { code: "quota_exceeded", message: "Monthly quota used." } }, {
      "retry-after": "3600",
    });
    const result = await client.callTool({ name: "check_url", arguments: { target: "https://phish.example/" } });
    assert.equal(result.isError, true);
    const body = JSON.parse((result.content as Array<{ text: string }>)[0]?.text ?? "") as {
      error: { code: string; retryAfterSeconds: number };
    };
    assert.equal(body.error.code, "quota_exceeded");
    assert.equal(body.error.retryAfterSeconds, 3600);
  });

  it("check_url rejects an empty target before calling the API", async () => {
    const { client, calls } = await connect(200, CHECK_RESULT);
    const result = await client.callTool({ name: "check_url", arguments: { target: "" } });
    assert.equal(result.isError, true);
    assert.equal(calls.length, 0);
  });

  it("get_usage returns the month's figures", async () => {
    const { client } = await connect(200, USAGE);
    const result = await client.callTool({ name: "get_usage", arguments: {} });
    assert.deepEqual(result.structuredContent, USAGE);
  });
});
