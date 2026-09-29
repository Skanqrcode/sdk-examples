# SkanQRCode SDK examples

Code examples and installable SDK packages for [SkanQRCode](https://skanqrcode.com), a
real-time URL/QR-code safety API — POST a URL or IP to `/v1/check` and get back
`malicious` / `suspicious` / `not_malicious` in under 200ms, meant to gate "should I open
this link" decisions right after scanning a QR code or following an inbound link.

**Start here:** [`docs/api-contract.md`](docs/api-contract.md) — the exact request/response
contract every example in this repo follows, and why it doesn't match the copy on
[skanqrcode.com](https://skanqrcode.com) and [skanqrcode.com/mcp](https://skanqrcode.com/mcp)
word for word (short version: the marketing pages describe a `{content}`/`{action}` shape and
an already-published MCP server; the only implemented, reviewed contract is
`skanqrcode-api/docs/openapi.yaml`, which uses `{target}`/`{verdict, mode, score, ...}` — these
examples follow that one).

## Layout

```
docs/
  api-contract.md      the canonical request/response contract (read this first)

quickstart/<lang>/      raw HTTP usage, no SDK — good for a 5-minute "does this work" test
sdk/<lang>/              installable SDK package with a typed SkanQRCodeClient
mobile/<platform>/       a QR-scan-then-check screen for a real mobile app
mcp/                      MCP server + client examples for agent/LLM tool-calling
```

| Language | Quickstart | SDK package | Mobile example |
|---|---|---|---|
| Swift | [`quickstart/swift`](quickstart/swift) | [`sdk/swift`](sdk/swift) — SPM `SkanQRCode` | [`mobile/ios-swift`](mobile/ios-swift) |
| Kotlin | [`quickstart/kotlin`](quickstart/kotlin) | [`sdk/kotlin`](sdk/kotlin) — Gradle `com.skanqrcode:skanqrcode-sdk` | [`mobile/android-kotlin`](mobile/android-kotlin) |
| Java | [`quickstart/java`](quickstart/java) | [`sdk/java`](sdk/java) — Maven `com.skanqrcode:skanqrcode-sdk` | [`mobile/android-java`](mobile/android-java) |
| JavaScript | [`quickstart/javascript`](quickstart/javascript) | [`sdk/javascript`](sdk/javascript) — npm `skanqrcode` | [`mobile/react-native`](mobile/react-native) |
| TypeScript | [`quickstart/typescript`](quickstart/typescript) | [`sdk/typescript`](sdk/typescript) — npm `@skanqrcode/sdk` | — |
| Dart | [`quickstart/dart`](quickstart/dart) | [`sdk/dart`](sdk/dart) — pub `skanqrcode` | [`mobile/flutter-dart`](mobile/flutter-dart) |
| Python | [`quickstart/python`](quickstart/python) | [`sdk/python`](sdk/python) — pip `skanqrcode` | — |
| Go | [`quickstart/go`](quickstart/go) | [`sdk/go`](sdk/go) — `github.com/skanqrcode/skanqrcode-go` | — |
| Rust | [`quickstart/rust`](quickstart/rust) | [`sdk/rust`](sdk/rust) — crate `skanqrcode` | — |

Every SDK exposes the same shape adapted to its language's conventions: a `SkanQRCodeClient`
(or `Client`) constructed with an API key, `checkUrl`/`CheckURL`/`check_url` returning a typed
`CheckResult`, `getUsage`/`GetUsage`/`get_usage` for the usage-aggregates endpoint, a typed
error carrying `code`/`message`/`requestId`, and a `recommendation` (`proceed`/`warn`/`block`)
derived from `verdict` so callers don't have to switch on the raw enum themselves. Every mobile
example scans a QR code with the platform's standard local decoder, calls `checkUrl` before
opening the link, and fails closed (doesn't auto-open) on a network error or timeout.

## MCP

[`mcp/`](mcp) has a reference MCP server (`check_url` tool over stdio) plus TypeScript and
Python examples for calling it programmatically, and the Claude Desktop config snippet. See
[`mcp/README.md`](mcp/README.md) for why it's *a* reference implementation rather than *the*
`@skanqrcode/mcp-server` package advertised on the landing page.

## Picking an SDK vs. the raw API

Use a `quickstart/<lang>` example if you just want to see the HTTP call work. Use an
`sdk/<lang>` package if you're integrating this into a real app — it gives you typed
responses, a typed error, request timeouts, and the `recommendation` helper instead of hand-
parsing JSON on every call site.
