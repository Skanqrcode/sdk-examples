from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from enum import Enum


class Verdict(str, Enum):
    MALICIOUS = "malicious"
    SUSPICIOUS = "suspicious"
    NOT_MALICIOUS = "not_malicious"


class Mode(str, Enum):
    URL = "url"
    IP = "ip"


class Recommendation(str, Enum):
    PROCEED = "proceed"
    WARN = "warn"
    BLOCK = "block"


_RECOMMENDATION_BY_VERDICT = {
    Verdict.MALICIOUS: Recommendation.BLOCK,
    Verdict.SUSPICIOUS: Recommendation.WARN,
    Verdict.NOT_MALICIOUS: Recommendation.PROCEED,
}


@dataclass(frozen=True)
class CheckResult:
    verdict: Verdict
    mode: Mode
    score: int
    reasons: list[str]
    cached: bool
    partial: bool
    request_id: str

    @classmethod
    def from_api(cls, data: dict) -> CheckResult:
        return cls(
            verdict=Verdict(data["verdict"]),
            mode=Mode(data["mode"]),
            score=data["score"],
            reasons=list(data["reasons"]),
            cached=data["cached"],
            partial=data["partial"],
            request_id=data["requestId"],
        )

    @property
    def recommendation(self) -> Recommendation:
        return _RECOMMENDATION_BY_VERDICT[self.verdict]


@dataclass(frozen=True)
class UsageHour:
    hour: datetime
    mode: Mode
    total: int
    malicious: int
    suspicious: int
    not_malicious: int
    cached: int
    partial: int

    @classmethod
    def from_api(cls, data: dict) -> UsageHour:
        return cls(
            hour=datetime.fromisoformat(data["hour"].replace("Z", "+00:00")),
            mode=Mode(data["mode"]),
            total=data["total"],
            malicious=data["malicious"],
            suspicious=data["suspicious"],
            not_malicious=data["notMalicious"],
            cached=data["cached"],
            partial=data["partial"],
        )


@dataclass(frozen=True)
class UsageResponse:
    tenant_id: str
    from_: datetime
    to: datetime
    hours: list[UsageHour]

    @classmethod
    def from_api(cls, data: dict) -> UsageResponse:
        return cls(
            tenant_id=data["tenantId"],
            from_=datetime.fromisoformat(data["from"].replace("Z", "+00:00")),
            to=datetime.fromisoformat(data["to"].replace("Z", "+00:00")),
            hours=[UsageHour.from_api(hour) for hour in data.get("hours", [])],
        )
