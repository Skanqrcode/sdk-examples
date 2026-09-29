# skanqrcode

Python SDK for the SkanQRCode URL/QR-code safety API.

## Install

```
pip install skanqrcode
```

## Usage (sync)

```python
import os
from skanqrcode import SkanQRCodeClient

with SkanQRCodeClient(api_key=os.environ["SKANQRCODE_API_KEY"]) as client:
    result = client.check_url("https://example.com/login")
    print(result.verdict, result.recommendation)
```

## Usage (async)

```python
import asyncio
import os
from skanqrcode import AsyncSkanQRCodeClient


async def main() -> None:
    async with AsyncSkanQRCodeClient(api_key=os.environ["SKANQRCODE_API_KEY"]) as client:
        result = await client.check_url("https://example.com/login")
        print(result.verdict, result.recommendation)


asyncio.run(main())
```

## Error handling

```python
from skanqrcode import SkanQRCodeClient, SkanQRCodeError

with SkanQRCodeClient(api_key=os.environ["SKANQRCODE_API_KEY"]) as client:
    try:
        result = client.check_url("https://example.com/login")
    except SkanQRCodeError as exc:
        print(exc.code, exc.message, exc.request_id)
```

See [`../../docs/api-contract.md`](../../docs/api-contract.md) for the full
API contract.
