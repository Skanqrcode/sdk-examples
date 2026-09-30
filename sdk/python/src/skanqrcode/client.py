from __future__ import annotations

from types import TracebackType
from typing import Any
from urllib.parse import quote

import httpx

from .exceptions import ErrorCode, SkanQRCodeError
from .models import (
    CheckResult,
    Health,
    HourlyUsageResponse,
    ListEntry,
    ListPage,
    MatchType,
    PlanId,
    SessionUrl,
    UsageResponse,
)

DEFAULT_BASE_URL = "https://api.skanqrcode.com"
DEFAULT_TIMEOUT = 5.0


def _retry_after(response: httpx.Response) -> float | None:
    # Retry-After is delta-seconds on 429s; an HTTP-date form is ignored.
    try:
        return float(response.headers["Retry-After"])
    except (KeyError, ValueError):
        return None


def _raise_for_error(response: httpx.Response) -> None:
    code, message, request_id = ErrorCode.INTERNAL, response.text, None
    try:
        error = response.json()["error"]
        code = error.get("code", code)
        message = error.get("message", message)
        request_id = error.get("requestId")
    except (ValueError, KeyError, TypeError, AttributeError):
        # Not the documented JSON (e.g. an HTML 502 from a proxy): keep the synthetic
        # `internal` code and the HTTP status.
        pass
    raise SkanQRCodeError(
        code=code,
        message=message,
        request_id=request_id or response.headers.get("X-Request-Id"),
        status_code=response.status_code,
        retry_after=_retry_after(response),
    )


def _parse(response: httpx.Response, parse: Any) -> Any:
    if response.is_error:
        _raise_for_error(response)
    return parse(response.json())


def _expect_no_content(response: httpx.Response) -> None:
    # 204 has no body to parse.
    if response.is_error:
        _raise_for_error(response)


def _entry_path(list_path: str, entry_id: str) -> str:
    return f"{list_path}/{quote(entry_id, safe='')}"


def _params(**values: Any) -> dict[str, Any] | None:
    params = {key: value for key, value in values.items() if value is not None}
    return params or None


def _check_body(target: str, user_id: str | None) -> dict[str, str]:
    body = {"target": target}
    if user_id is not None:
        body["userId"] = user_id
    return body


def _entry_body(match_type: MatchType | str, value: str) -> dict[str, str]:
    return {"matchType": MatchType(match_type).value, "value": value}


def _checkout_body(plan_id: PlanId | str, turnstile_token: str) -> dict[str, str]:
    return {"planId": PlanId(plan_id).value, "turnstileToken": turnstile_token}


class SkanQRCodeClient:
    def __init__(
        self,
        api_key: str,
        base_url: str = DEFAULT_BASE_URL,
        timeout: float = DEFAULT_TIMEOUT,
    ) -> None:
        self._client = httpx.Client(base_url=base_url, timeout=timeout)
        self._auth = {"Authorization": f"Bearer {api_key}"}

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

    def check_url(self, target: str, user_id: str | None = None) -> CheckResult:
        response = self._client.post(
            "/v1/check", json=_check_body(target, user_id), headers=self._auth
        )
        return _parse(response, CheckResult.from_api)

    def get_usage(self, month: str | None = None) -> UsageResponse:
        """Monthly quota summary. `month` is "YYYY-MM" (UTC); defaults to the current month."""
        response = self._client.get(
            "/v1/usage", params=_params(month=month), headers=self._auth
        )
        return _parse(response, UsageResponse.from_api)

    def get_usage_hourly(self, month: str | None = None) -> HourlyUsageResponse:
        """Hour-by-hour usage and rate-limit utilization for `month` ("YYYY-MM")."""
        response = self._client.get(
            "/v1/usage/hourly", params=_params(month=month), headers=self._auth
        )
        return _parse(response, HourlyUsageResponse.from_api)

    def list_allow_list(self, limit: int | None = None, cursor: str | None = None) -> ListPage:
        """Pro and Business plans only."""
        response = self._client.get(
            "/v1/allow-list", params=_params(limit=limit, cursor=cursor), headers=self._auth
        )
        return _parse(response, ListPage.from_api)

    def add_allow_list_entry(self, match_type: MatchType | str, value: str) -> ListEntry:
        """Needs an `admin`-scope key; Pro and Business plans only. Idempotent (200 or 201)."""
        response = self._client.post(
            "/v1/allow-list", json=_entry_body(match_type, value), headers=self._auth
        )
        return _parse(response, ListEntry.from_api)

    def delete_allow_list_entry(self, entry_id: str) -> None:
        """Needs an `admin`-scope key; Pro and Business plans only."""
        response = self._client.delete(
            _entry_path("/v1/allow-list", entry_id), headers=self._auth
        )
        _expect_no_content(response)

    def list_block_list(self, limit: int | None = None, cursor: str | None = None) -> ListPage:
        response = self._client.get(
            "/v1/block-list", params=_params(limit=limit, cursor=cursor), headers=self._auth
        )
        return _parse(response, ListPage.from_api)

    def add_block_list_entry(self, match_type: MatchType | str, value: str) -> ListEntry:
        """Needs an `admin`-scope key. Idempotent (200 or 201)."""
        response = self._client.post(
            "/v1/block-list", json=_entry_body(match_type, value), headers=self._auth
        )
        return _parse(response, ListEntry.from_api)

    def delete_block_list_entry(self, entry_id: str) -> None:
        """Needs an `admin`-scope key."""
        response = self._client.delete(
            _entry_path("/v1/block-list", entry_id), headers=self._auth
        )
        _expect_no_content(response)

    def create_checkout_session(
        self, plan_id: PlanId | str, turnstile_token: str
    ) -> SessionUrl:
        """Human-in-the-loop, `admin` scope: hand the returned URL to a person, never
        complete checkout from an autonomous agent. Needs a Turnstile token from a browser flow."""
        response = self._client.post(
            "/v1/billing/checkout",
            json=_checkout_body(plan_id, turnstile_token),
            headers=self._auth,
        )
        return _parse(response, SessionUrl.from_api)

    def create_portal_session(self) -> SessionUrl:
        """Human-in-the-loop, `admin` scope: hand the returned billing-portal URL to a person."""
        response = self._client.post("/v1/billing/portal", headers=self._auth)
        return _parse(response, SessionUrl.from_api)

    def get_health(self) -> Health:
        """Liveness only. Sends no Authorization header."""
        return _parse(self._client.get("/health"), Health.from_api)


class AsyncSkanQRCodeClient:
    def __init__(
        self,
        api_key: str,
        base_url: str = DEFAULT_BASE_URL,
        timeout: float = DEFAULT_TIMEOUT,
    ) -> None:
        self._client = httpx.AsyncClient(base_url=base_url, timeout=timeout)
        self._auth = {"Authorization": f"Bearer {api_key}"}

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

    async def check_url(self, target: str, user_id: str | None = None) -> CheckResult:
        response = await self._client.post(
            "/v1/check", json=_check_body(target, user_id), headers=self._auth
        )
        return _parse(response, CheckResult.from_api)

    async def get_usage(self, month: str | None = None) -> UsageResponse:
        """Monthly quota summary. `month` is "YYYY-MM" (UTC); defaults to the current month."""
        response = await self._client.get(
            "/v1/usage", params=_params(month=month), headers=self._auth
        )
        return _parse(response, UsageResponse.from_api)

    async def get_usage_hourly(self, month: str | None = None) -> HourlyUsageResponse:
        """Hour-by-hour usage and rate-limit utilization for `month` ("YYYY-MM")."""
        response = await self._client.get(
            "/v1/usage/hourly", params=_params(month=month), headers=self._auth
        )
        return _parse(response, HourlyUsageResponse.from_api)

    async def list_allow_list(
        self, limit: int | None = None, cursor: str | None = None
    ) -> ListPage:
        """Pro and Business plans only."""
        response = await self._client.get(
            "/v1/allow-list", params=_params(limit=limit, cursor=cursor), headers=self._auth
        )
        return _parse(response, ListPage.from_api)

    async def add_allow_list_entry(self, match_type: MatchType | str, value: str) -> ListEntry:
        """Needs an `admin`-scope key; Pro and Business plans only. Idempotent (200 or 201)."""
        response = await self._client.post(
            "/v1/allow-list", json=_entry_body(match_type, value), headers=self._auth
        )
        return _parse(response, ListEntry.from_api)

    async def delete_allow_list_entry(self, entry_id: str) -> None:
        """Needs an `admin`-scope key; Pro and Business plans only."""
        response = await self._client.delete(
            _entry_path("/v1/allow-list", entry_id), headers=self._auth
        )
        _expect_no_content(response)

    async def list_block_list(
        self, limit: int | None = None, cursor: str | None = None
    ) -> ListPage:
        response = await self._client.get(
            "/v1/block-list", params=_params(limit=limit, cursor=cursor), headers=self._auth
        )
        return _parse(response, ListPage.from_api)

    async def add_block_list_entry(self, match_type: MatchType | str, value: str) -> ListEntry:
        """Needs an `admin`-scope key. Idempotent (200 or 201)."""
        response = await self._client.post(
            "/v1/block-list", json=_entry_body(match_type, value), headers=self._auth
        )
        return _parse(response, ListEntry.from_api)

    async def delete_block_list_entry(self, entry_id: str) -> None:
        """Needs an `admin`-scope key."""
        response = await self._client.delete(
            _entry_path("/v1/block-list", entry_id), headers=self._auth
        )
        _expect_no_content(response)

    async def create_checkout_session(
        self, plan_id: PlanId | str, turnstile_token: str
    ) -> SessionUrl:
        """Human-in-the-loop, `admin` scope: hand the returned URL to a person, never
        complete checkout from an autonomous agent. Needs a Turnstile token from a browser flow."""
        response = await self._client.post(
            "/v1/billing/checkout",
            json=_checkout_body(plan_id, turnstile_token),
            headers=self._auth,
        )
        return _parse(response, SessionUrl.from_api)

    async def create_portal_session(self) -> SessionUrl:
        """Human-in-the-loop, `admin` scope: hand the returned billing-portal URL to a person."""
        response = await self._client.post("/v1/billing/portal", headers=self._auth)
        return _parse(response, SessionUrl.from_api)

    async def get_health(self) -> Health:
        """Liveness only. Sends no Authorization header."""
        return _parse(await self._client.get("/health"), Health.from_api)
