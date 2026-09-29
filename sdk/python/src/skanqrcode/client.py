from __future__ import annotations

from datetime import datetime
from types import TracebackType

import httpx

from .exceptions import SkanQRCodeError
from .models import CheckResult, UsageResponse

DEFAULT_BASE_URL = "https://api.skanqrcode.com"
DEFAULT_TIMEOUT = 5.0


def _raise_for_error(response: httpx.Response) -> None:
    body = response.json()
    error = body.get("error", {})
    raise SkanQRCodeError(
        code=error.get("code", "unknown_error"),
        message=error.get("message", response.text),
        request_id=error.get("requestId"),
        status_code=response.status_code,
    )


class SkanQRCodeClient:
    def __init__(
        self,
        api_key: str,
        base_url: str = DEFAULT_BASE_URL,
        timeout: float = DEFAULT_TIMEOUT,
    ) -> None:
        self._client = httpx.Client(
            base_url=base_url,
            timeout=timeout,
            headers={"Authorization": f"Bearer {api_key}"},
        )

    def __enter__(self) -> SkanQRCodeClient:
        return self

    def __exit__(
        self,
        exc_type: type[BaseException] | None,
        exc: BaseException | None,
        traceback: TracebackType | None,
    ) -> None:
        self.close()

    def close(self) -> None:
        self._client.close()

    def check_url(self, target: str) -> CheckResult:
        response = self._client.post("/v1/check", json={"target": target})
        if response.is_error:
            _raise_for_error(response)
        return CheckResult.from_api(response.json())

    def get_usage(self, from_: datetime, to: datetime) -> UsageResponse:
        response = self._client.get(
            "/v1/usage",
            params={"from": from_.isoformat(), "to": to.isoformat()},
        )
        if response.is_error:
            _raise_for_error(response)
        return UsageResponse.from_api(response.json())


class AsyncSkanQRCodeClient:
    def __init__(
        self,
        api_key: str,
        base_url: str = DEFAULT_BASE_URL,
        timeout: float = DEFAULT_TIMEOUT,
    ) -> None:
        self._client = httpx.AsyncClient(
            base_url=base_url,
            timeout=timeout,
            headers={"Authorization": f"Bearer {api_key}"},
        )

    async def __aenter__(self) -> AsyncSkanQRCodeClient:
        return self

    async def __aexit__(
        self,
        exc_type: type[BaseException] | None,
        exc: BaseException | None,
        traceback: TracebackType | None,
    ) -> None:
        await self.close()

    async def close(self) -> None:
        await self._client.aclose()

    async def check_url(self, target: str) -> CheckResult:
        response = await self._client.post("/v1/check", json={"target": target})
        if response.is_error:
            _raise_for_error(response)
        return CheckResult.from_api(response.json())

    async def get_usage(self, from_: datetime, to: datetime) -> UsageResponse:
        response = await self._client.get(
            "/v1/usage",
            params={"from": from_.isoformat(), "to": to.isoformat()},
        )
        if response.is_error:
            _raise_for_error(response)
        return UsageResponse.from_api(response.json())
