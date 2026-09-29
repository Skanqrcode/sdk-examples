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
        body = json.loads(exc.read())
        error = body.get("error", {})
        print(
            f"error: {error.get('code')}: {error.get('message')} "
            f"(requestId={error.get('requestId')})",
            file=sys.stderr,
        )
        sys.exit(1)


def main() -> None:
    api_key = os.environ.get("SKANQRCODE_API_KEY")
    if not api_key:
        print("error: SKANQRCODE_API_KEY is not set", file=sys.stderr)
        sys.exit(1)

    target = sys.argv[1] if len(sys.argv) > 1 else "https://example.com/login"
    result = check_url(target, api_key)

    print(f"target:     {target}")
    print(f"verdict:    {result['verdict']}")
    print(f"mode:       {result['mode']}")
    print(f"score:      {result['score']}")
    print(f"reasons:    {result['reasons']}")
    print(f"cached:     {result['cached']}")
    print(f"partial:    {result['partial']}")
    print(f"requestId:  {result['requestId']}")


if __name__ == "__main__":
    main()
