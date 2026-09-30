# skanqrcode

Python SDK for the SkanQRCode URL/QR-code safety API.

## Install

```
pip install skanqrcode
```

Use an `sk_test_` key (free sandbox plan) while integrating; paid plans get an `sk_live_` key.

## Usage (sync)

```python
import os
from skanqrcode import Action, SkanQRCodeClient

with SkanQRCodeClient(api_key=os.environ["SKANQRCODE_API_KEY"]) as client:
    result = client.check_url("https://example.com/login", user_id="user-4821")  # user_id optional
    print(result.verdict, result.action, result.reasons, result.execution_time_ms)

    if result.should_block:
        print("blocked")
    elif result.action == Action.WARN:
        print("warn the user before proceeding")
    elif result.is_safe:
        print("safe to open")
```

`CheckResult` fields: `verdict`, `action` (`allow` / `warn` / `block`), `mode`, `reasons` (plain
strings), `final_url`, `cached`, `execution_time_ms`, `environment` (`sandbox` / `production`),
`licensed_for_production`, `request_id`, and `related` (IP mode only). Branch on `action`;
`warn` is neither safe nor blocked. `execution_time_ms >= 180` means the evaluation deadline was
hit and the result is best-effort. Sandbox results are for integration testing only.

## Usage (async)

```python
import asyncio
import os
from skanqrcode import AsyncSkanQRCodeClient


async def main() -> None:
    async with AsyncSkanQRCodeClient(api_key=os.environ["SKANQRCODE_API_KEY"]) as client:
        result = await client.check_url("https://example.com/login")
        print(result.verdict, result.action)


asyncio.run(main())
```

## Usage and lists

```python
usage = client.get_usage("2026-09")  # month is optional, defaults to the current one
print(usage.total_requests, usage.available_requests, usage.monthly_quota)

hourly = client.get_usage_hourly("2026-09")
for hour in hourly.hours:
    print(hour.hour, hour.total, hour.capacity_used_percent, hour.blocked_rpm)

# Block list (every plan); the allow list (Pro and Business) has the same methods.
entry = client.add_block_list_entry("domain", "malicious-example.com")  # needs an admin-scope key
page = client.list_block_list(limit=100)
while True:
    for e in page.entries:
        print(e.id, e.match_type, e.value)
    if page.next_cursor is None:
        break
    page = client.list_block_list(limit=100, cursor=page.next_cursor)
client.delete_block_list_entry(entry.id)
```

Also available: `list_allow_list`, `add_allow_list_entry`, `delete_allow_list_entry`, and
`get_health()` (no key needed). `create_checkout_session(plan_id, turnstile_token)` and
`create_portal_session()` are human-in-the-loop, admin-scope calls: hand the returned URL to a
person rather than completing checkout from an agent.

## Error handling

```python
from skanqrcode import ErrorCode, SkanQRCodeClient, SkanQRCodeError

with SkanQRCodeClient(api_key=os.environ["SKANQRCODE_API_KEY"]) as client:
    try:
        result = client.check_url("https://example.com/login")
    except SkanQRCodeError as exc:
        print(exc.code, exc.message, exc.request_id, exc.status_code)
        if exc.code == ErrorCode.RATE_LIMITED:
            print("retry in", exc.retry_after, "seconds")
```

`exc.code` is a plain string, one of the `ErrorCode` constants (`invalid_request`, `unauthorized`,
`forbidden`, `not_found`, `plan_feature_unavailable`, `payment_required`, `rate_limited`,
`quota_exceeded`, `auth_unavailable`, `internal`); a code added later still comes through as a
string. A non-JSON error body (such as a proxy's HTML 502) is raised as code `internal` with the
HTTP status. The SDK doesn't retry: retry `rate_limited` after `retry_after`, `auth_unavailable`
shortly and 5xx with backoff, never `quota_exceeded` or 4xx. Fail closed if a check errors.

See [`../../docs/api-contract.md`](../../docs/api-contract.md) for the full
API contract.
