from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from enum import Enum


class Verdict(str, Enum):
    MALICIOUS = "malicious"
    SUSPICIOUS = "suspicious"
    NOT_MALICIOUS = "not_malicious"


class Action(str, Enum):
    """What the caller should do. Branch on this rather than on `Verdict`."""

    ALLOW = "allow"
    WARN = "warn"
    BLOCK = "block"


class Mode(str, Enum):
    URL = "url"
    IP = "ip"


class Environment(str, Enum):
    SANDBOX = "sandbox"
    PRODUCTION = "production"


class MatchType(str, Enum):
    URL = "url"
    HOST = "host"
    DOMAIN = "domain"
    IP = "ip"


class PlanId(str, Enum):
    PRO = "pro"
    BUSINESS = "business"


def _parse_time(value: str) -> datetime:
    return datetime.fromisoformat(value.replace("Z", "+00:00"))


@dataclass(frozen=True)
class RelatedHost:
    host: str
    verdict: Verdict

    @classmethod
    def from_api(cls, data: dict) -> RelatedHost:
        return cls(host=data["host"], verdict=Verdict(data["verdict"]))


@dataclass(frozen=True)
class CheckResult:
    verdict: Verdict
    action: Action
    mode: Mode
    # Reason codes are plain strings so a new code doesn't break deserialization.
    reasons: list[str]
    final_url: str | None
    cached: bool
    # >= 180 means the evaluation deadline was hit and the result is best-effort.
    execution_time_ms: int
    environment: Environment
    licensed_for_production: bool
    request_id: str
    # IP mode only: recently associated hosts, most recent first.
    related: list[RelatedHost] | None = None

    @classmethod
    def from_api(cls, data: dict) -> CheckResult:
        related = data.get("related")
        return cls(
            verdict=Verdict(data["verdict"]),
            action=Action(data["action"]),
            mode=Mode(data["mode"]),
            reasons=list(data["reasons"]),
            final_url=data.get("finalUrl"),
            cached=data["cached"],
            execution_time_ms=data["executionTimeMs"],
            environment=Environment(data["environment"]),
            licensed_for_production=data["licensedForProduction"],
            request_id=data["requestId"],
            related=None if related is None else [RelatedHost.from_api(r) for r in related],
        )

    @property
    def should_block(self) -> bool:
        return self.action == Action.BLOCK

    @property
    def is_safe(self) -> bool:
        # `warn` is neither safe nor blocked; surface it to the user.
        return self.action == Action.ALLOW


@dataclass(frozen=True)
class UsageResponse:
    tenant_id: str
    month: str
    monthly_quota: int
    total_requests: int
    available_requests: int

    @classmethod
    def from_api(cls, data: dict) -> UsageResponse:
        return cls(
            tenant_id=data["tenantId"],
            month=data["month"],
            monthly_quota=data["monthlyQuota"],
            total_requests=data["totalRequests"],
            available_requests=data["availableRequests"],
        )


@dataclass(frozen=True)
class UsageHour:
    hour: datetime
    mode: Mode
    total: int
    capacity_used_percent: float
    blocked_rpm: int
    blocked_quota: int
    malicious: int
    suspicious: int
    not_malicious: int
    cached: int

    @classmethod
    def from_api(cls, data: dict) -> UsageHour:
        return cls(
            hour=_parse_time(data["hour"]),
            mode=Mode(data["mode"]),
            total=data["total"],
            capacity_used_percent=data["capacityUsedPercent"],
            blocked_rpm=data["blockedRpm"],
            blocked_quota=data["blockedQuota"],
            malicious=data["malicious"],
            suspicious=data["suspicious"],
            not_malicious=data["notMalicious"],
            cached=data["cached"],
        )


@dataclass(frozen=True)
class HourlyUsageResponse:
    tenant_id: str
    month: str
    rpm_limit: int
    # rpm_limit * 60; a reading aid only, limits are enforced per minute.
    hourly_capacity: int
    hours: list[UsageHour]

    @classmethod
    def from_api(cls, data: dict) -> HourlyUsageResponse:
        return cls(
            tenant_id=data["tenantId"],
            month=data["month"],
            rpm_limit=data["rpmLimit"],
            hourly_capacity=data["hourlyCapacity"],
            hours=[UsageHour.from_api(hour) for hour in data.get("hours", [])],
        )


@dataclass(frozen=True)
class ListEntry:
    id: str
    match_type: MatchType
    value: str
    created_at: datetime

    @classmethod
    def from_api(cls, data: dict) -> ListEntry:
        return cls(
            id=data["id"],
            match_type=MatchType(data["matchType"]),
            value=data["value"],
            created_at=_parse_time(data["createdAt"]),
        )


@dataclass(frozen=True)
class ListPage:
    entries: list[ListEntry]
    # None on the last page; pass it back as `cursor` to fetch the next one.
    next_cursor: str | None

    @classmethod
    def from_api(cls, data: dict) -> ListPage:
        return cls(
            entries=[ListEntry.from_api(entry) for entry in data["entries"]],
            next_cursor=data.get("nextCursor"),
        )


@dataclass(frozen=True)
class SessionUrl:
    """A checkout or billing-portal URL to hand to a person."""

    url: str

    @classmethod
    def from_api(cls, data: dict) -> SessionUrl:
        return cls(url=data["url"])


@dataclass(frozen=True)
class Health:
    status: str

    @classmethod
    def from_api(cls, data: dict) -> Health:
        return cls(status=data["status"])
