# Kotlin quickstart

Raw `POST /v1/check` usage with the JDK's built-in `java.net.http.HttpClient` — no
dependencies. See [`../../docs/api-contract.md`](../../docs/api-contract.md) for the full
contract, and [`../../sdk/kotlin`](../../sdk/kotlin) for a typed client.

## Run it

Requires a Kotlin compiler (`brew install kotlin` or see [kotlinlang.org](https://kotlinlang.org/docs/command-line.html)) and JDK 11+.

```bash
export SKANQRCODE_API_KEY=lure_test_...
kotlin Main.kt
```
