// Enums that come back from the server fall back to `unknown` instead of
// throwing, so a value added in a later API version doesn't break an older
// SDK. `unknown` is never "safe" and never "block" — treat it like `warn`
// (surface it, don't auto-open).

/// The classification decision returned for a target.
enum Verdict {
  malicious,
  suspicious,
  notMalicious,
  unknown;

  static Verdict fromJson(String value) => switch (value) {
        'malicious' => Verdict.malicious,
        'suspicious' => Verdict.suspicious,
        'not_malicious' => Verdict.notMalicious,
        _ => Verdict.unknown,
      };

  String toJson() => switch (this) {
        Verdict.malicious => 'malicious',
        Verdict.suspicious => 'suspicious',
        Verdict.notMalicious => 'not_malicious',
        Verdict.unknown => 'unknown',
      };
}

/// What the caller should do with the target. Fixed server-side mapping:
/// `not_malicious` -> [allow], `suspicious` -> [warn], `malicious` -> [block].
/// Branch on this rather than on [Verdict].
///
/// Flutter also exports an `Action` class: in a Flutter file, import
/// `package:flutter/material.dart` with `hide Action`.
enum Action {
  allow,
  warn,
  block,
  unknown;

  static Action fromJson(String value) => switch (value) {
        'allow' => Action.allow,
        'warn' => Action.warn,
        'block' => Action.block,
        _ => Action.unknown,
      };

  String toJson() => name;
}

/// What kind of target was classified.
enum Mode {
  url,
  ip,
  unknown;

  static Mode fromJson(String value) => switch (value) {
        'url' => Mode.url,
        'ip' => Mode.ip,
        _ => Mode.unknown,
      };

  String toJson() => name;
}

/// Derived from the key's plan, never from the request.
enum Environment {
  sandbox,
  production,
  unknown;

  static Environment fromJson(String value) => switch (value) {
        'sandbox' => Environment.sandbox,
        'production' => Environment.production,
        _ => Environment.unknown,
      };

  String toJson() => name;
}

/// How an allow-list/block-list entry matches. A closed set that is also sent
/// in requests, so an unrecognized value from the server throws
/// [ArgumentError] rather than becoming a fake case.
enum MatchType {
  /// Exact URL.
  url,

  /// Hostname.
  host,

  /// Registrable domain, including subdomains.
  domain,
  ip;

  static MatchType fromJson(String value) => switch (value) {
        'url' => MatchType.url,
        'host' => MatchType.host,
        'domain' => MatchType.domain,
        'ip' => MatchType.ip,
        _ => throw ArgumentError('Unknown matchType: $value'),
      };

  String toJson() => name;
}

/// Plans that can be bought through [SkanQRCodeClient.createCheckoutSession].
enum PlanId {
  pro,
  business;

  String toJson() => name;
}

/// A recently associated host. Only returned in IP mode.
class RelatedHost {
  const RelatedHost({required this.host, required this.verdict});

  factory RelatedHost.fromJson(Map<String, dynamic> json) => RelatedHost(
        host: json['host'] as String,
        verdict: Verdict.fromJson(json['verdict'] as String),
      );

  final String host;
  final Verdict verdict;
}

/// Response of `POST /v1/check`.
class CheckResult {
  const CheckResult({
    required this.verdict,
    required this.action,
    required this.mode,
    required this.reasons,
    required this.finalUrl,
    required this.cached,
    required this.executionTimeMs,
    required this.environment,
    required this.licensedForProduction,
    required this.requestId,
    this.related,
  });

  factory CheckResult.fromJson(Map<String, dynamic> json) => CheckResult(
        verdict: Verdict.fromJson(json['verdict'] as String),
        action: Action.fromJson(json['action'] as String),
        mode: Mode.fromJson(json['mode'] as String),
        reasons: (json['reasons'] as List).cast<String>(),
        finalUrl: json['finalUrl'] as String?,
        cached: json['cached'] as bool,
        executionTimeMs: json['executionTimeMs'] as int,
        environment: Environment.fromJson(json['environment'] as String),
        licensedForProduction: json['licensedForProduction'] as bool,
        requestId: json['requestId'] as String,
        related: (json['related'] as List?)
            ?.cast<Map<String, dynamic>>()
            .map(RelatedHost.fromJson)
            .toList(),
      );

  final Verdict verdict;

  /// What to do with the target: allow, warn or block.
  final Action action;

  final Mode mode;

  /// Reason codes that contributed (e.g. `KNOWN_PHISHING_MATCH`), kept as
  /// plain strings so a new code doesn't break decoding. See
  /// `docs/api-contract.md` for the current set.
  final List<String> reasons;

  /// Where a shortened link resolved to, if a redirect was followed.
  final String? finalUrl;

  /// `true` only if served from this tenant's own per-user cache.
  final bool cached;

  /// Server-side evaluation time in milliseconds.
  final int executionTimeMs;

  final Environment environment;

  /// `false` on the free sandbox plan — use those results for integration
  /// testing only.
  final bool licensedForProduction;

  final String requestId;

  /// IP mode only: recently associated hosts, most recent first.
  final List<RelatedHost>? related;

  /// `true` only when the server says [Action.block].
  bool get shouldBlock => action == Action.block;

  /// `true` only when the server says [Action.allow]. [Action.warn] is
  /// neither safe nor blocked — surface it to the user.
  bool get isSafe => action == Action.allow;
}

/// Response of `GET /v1/usage`. Lags real-time usage by up to about an hour.
class UsageResponse {
  const UsageResponse({
    required this.tenantId,
    required this.month,
    required this.monthlyQuota,
    required this.totalRequests,
    required this.availableRequests,
  });

  factory UsageResponse.fromJson(Map<String, dynamic> json) => UsageResponse(
        tenantId: json['tenantId'] as String,
        month: json['month'] as String,
        monthlyQuota: json['monthlyQuota'] as int,
        totalRequests: json['totalRequests'] as int,
        availableRequests: json['availableRequests'] as int,
      );

  final String tenantId;

  /// UTC calendar month, `YYYY-MM`.
  final String month;
  final int monthlyQuota;
  final int totalRequests;

  /// `max(monthlyQuota - totalRequests, 0)`.
  final int availableRequests;
}

/// One `(hour, mode)` bucket of `GET /v1/usage/hourly`.
class UsageHour {
  const UsageHour({
    required this.hour,
    required this.mode,
    required this.total,
    required this.capacityUsedPercent,
    required this.blockedRpm,
    required this.blockedQuota,
    required this.malicious,
    required this.suspicious,
    required this.notMalicious,
    required this.cached,
  });

  factory UsageHour.fromJson(Map<String, dynamic> json) => UsageHour(
        hour: DateTime.parse(json['hour'] as String),
        mode: Mode.fromJson(json['mode'] as String),
        total: json['total'] as int,
        capacityUsedPercent: (json['capacityUsedPercent'] as num).toDouble(),
        blockedRpm: json['blockedRpm'] as int,
        blockedQuota: json['blockedQuota'] as int,
        malicious: json['malicious'] as int,
        suspicious: json['suspicious'] as int,
        notMalicious: json['notMalicious'] as int,
        cached: json['cached'] as int,
      );

  final DateTime hour;
  final Mode mode;
  final int total;

  /// `total / hourlyCapacity * 100`, one decimal. Near 100 means that hour
  /// ran at the rate limit.
  final double capacityUsedPercent;

  /// Requests blocked that hour for exceeding the per-minute limit.
  final int blockedRpm;

  /// Requests blocked that hour for exceeding the monthly quota.
  final int blockedQuota;
  final int malicious;
  final int suspicious;
  final int notMalicious;
  final int cached;
}

/// Response of `GET /v1/usage/hourly`: hour-by-hour usage with per-minute
/// rate-limit utilization.
class UsageHourlyResponse {
  const UsageHourlyResponse({
    required this.tenantId,
    required this.month,
    required this.rpmLimit,
    required this.hourlyCapacity,
    required this.hours,
  });

  factory UsageHourlyResponse.fromJson(Map<String, dynamic> json) =>
      UsageHourlyResponse(
        tenantId: json['tenantId'] as String,
        month: json['month'] as String,
        rpmLimit: json['rpmLimit'] as int,
        hourlyCapacity: json['hourlyCapacity'] as int,
        hours: (json['hours'] as List)
            .cast<Map<String, dynamic>>()
            .map(UsageHour.fromJson)
            .toList(),
      );

  final String tenantId;
  final String month;

  /// The plan's requests-per-minute limit.
  final int rpmLimit;

  /// `rpmLimit * 60`. A reading aid only — limits are enforced per minute.
  final int hourlyCapacity;
  final List<UsageHour> hours;
}

/// One allow-list or block-list entry.
class ListEntry {
  const ListEntry({
    required this.id,
    required this.matchType,
    required this.value,
    required this.createdAt,
  });

  factory ListEntry.fromJson(Map<String, dynamic> json) => ListEntry(
        id: json['id'] as String,
        matchType: MatchType.fromJson(json['matchType'] as String),
        value: json['value'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  final String id;
  final MatchType matchType;

  /// For `url` entries the server returns only the registrable domain and a
  /// short hash hint.
  final String value;
  final DateTime createdAt;
}

/// One page of `GET /v1/allow-list` or `GET /v1/block-list` (newest first).
class ListEntriesPage {
  const ListEntriesPage({required this.entries, required this.nextCursor});

  factory ListEntriesPage.fromJson(Map<String, dynamic> json) =>
      ListEntriesPage(
        entries: (json['entries'] as List)
            .cast<Map<String, dynamic>>()
            .map(ListEntry.fromJson)
            .toList(),
        nextCursor: json['nextCursor'] as String?,
      );

  final List<ListEntry> entries;

  /// Pass to the next call as `cursor`; `null` on the last page.
  final String? nextCursor;
}

/// Response of the billing operations: a URL to hand to a person.
class SessionUrl {
  const SessionUrl({required this.url});

  factory SessionUrl.fromJson(Map<String, dynamic> json) =>
      SessionUrl(url: json['url'] as String);

  final String url;
}

/// Response of `GET /health`.
class HealthResponse {
  const HealthResponse({required this.status});

  factory HealthResponse.fromJson(Map<String, dynamic> json) =>
      HealthResponse(status: json['status'] as String);

  /// Always `ok`.
  final String status;
}
