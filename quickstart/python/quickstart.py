#!/usr/bin/env python3
"""Minimal, dependency-free example of calling POST /v1/check."""
import json
import os
import sys
import urllib.error
import urllib.request

BASE_URL = "https://api.skanqrcode.com"


def check_url(target: str, api_key: str) -> dict:
    request = urllib.request.Request(
        f"{BASE_URL}/v1/check",
        data=json.dumps({"target": target}).encode("utf-8"),
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=5) as response:
            return json.loads(response.read())
    except urllib.error.HTTPError as exc:
        raw = exc.read()
        try:
            error = json.loads(raw)["error"]
        except (ValueError, KeyError, TypeError):
            # Not the documented JSON (e.g. an HTML 502 from a proxy).
            error = {"code": "internal", "message": raw.decode("utf-8", "replace")[:200]}
        print(
            f"error: {error.get('code')}: {error.get('message')} "
            f"(http {exc.code}, requestId={error.get('requestId')})",
            file=sys.stderr,
        )
        if error.get("code") == "rate_limited":
            print(f"retry in {exc.headers.get('Retry-After')}s", file=sys.stderr)
        elif error.get("code") == "quota_exceeded":
            print("monthly quota exhausted; retrying won't help", file=sys.stderr)
        sys.exit(1)


def main() -> None:
    api_key = os.environ.get("SKANQRCODE_API_KEY")
    if not api_key:
        print("error: SKANQRCODE_API_KEY is not set", file=sys.stderr)
        sys.exit(1)

    target = sys.argv[1] if len(sys.argv) > 1 else "https://example.com/login"
    result = check_url(target, api_key)

    print(f"target:          {target}")
    print(f"verdict:         {result['verdict']}")
    print(f"action:          {result['action']}")
    print(f"mode:            {result['mode']}")
    print(f"reasons:         {result['reasons']}")
    print(f"cached:          {result['cached']}")
    print(f"executionTimeMs: {result['executionTimeMs']}")
    print(f"environment:     {result['environment']}")
    print(f"requestId:       {result['requestId']}")

    if result["action"] == "block":
        print("\nBLOCK: do not open this link.")
    elif result["action"] == "warn":
        print("\nWARN: proceed with caution.")
    if result["environment"] == "sandbox":
        print("(sandbox key: results are for integration testing only)")


if __name__ == "__main__":
    main()
