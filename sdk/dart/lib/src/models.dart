/// The classification decision returned for a target.
enum Verdict {
  malicious,
  suspicious,
  notMalicious;

  static Verdict fromJson(String value) => switch (value) {
        'malicious' => Verdict.malicious,
        'suspicious' => Verdict.suspicious,
        'not_malicious' => Verdict.notMalicious,
        _ => throw ArgumentError('Unknown verdict: $value'),
      };

  String toJson() => switch (this) {
        Verdict.malicious => 'malicious',
        Verdict.suspicious => 'suspicious',
        Verdict.notMalicious => 'not_malicious',
      };
}

/// What kind of target was classified.
enum Mode {
  url,
  ip;

  static Mode fromJson(String value) => switch (value) {
        'url' => Mode.url,
        'ip' => Mode.ip,
        _ => throw ArgumentError('Unknown mode: $value'),
      };

  String toJson() => name;
}

/// Convenience allow/warn/block decision derived from [Verdict], for callers
/// that don't want to switch on the enum themselves.
enum Recommendation { proceed, warn, block }

/// Response of `POST /v1/check`.
class CheckResult {
  const CheckResult({
    required this.verdict,
    required this.mode,
    required this.score,
    required this.reasons,
    required this.cached,
    required this.partial,
    required this.requestId,
  });

  factory CheckResult.fromJson(Map<String, dynamic> json) => CheckResult(
        verdict: Verdict.fromJson(json['verdict'] as String),
        mode: Mode.fromJson(json['mode'] as String),
        score: json['score'] as int,
        reasons: (json['reasons'] as List).cast<String>(),
        cached: json['cached'] as bool,
        partial: json['partial'] as bool,
        requestId: json['requestId'] as String,
      );

  final Verdict verdict;
  final Mode mode;

  /// Weighted heuristic score backing the verdict, 0-100.
  final int score;

  /// Closed set of reason codes that contributed to the verdict.
  final List<String> reasons;

  /// `true` if served from the per-user verdict cache.
  final bool cached;

  /// `true` if a signal source missed the internal ~180ms deadline.
  final bool partial;

  final String requestId;

  /// Allow/warn/block decision derived from [verdict].
  Recommendation get recommendation => switch (verdict) {
        Verdict.notMalicious => Recommendation.proceed,
        Verdict.suspicious => Recommendation.warn,
        Verdict.malicious => Recommendation.block,
      };

  /// `true` if [verdict] is [Verdict.notMalicious].
  bool get isSafe => verdict == Verdict.notMalicious;

  /// `true` if [verdict] is [Verdict.malicious].
  bool get shouldBlock => verdict == Verdict.malicious;
}

/// One `(hour, mode)` bucket of `GET /v1/usage` aggregates.
class UsageHour {
  const UsageHour({
    required this.hour,
    required this.mode,
    required this.total,
    required this.malicious,
    required this.suspicious,
    required this.notMalicious,
    required this.cached,
    required this.partial,
  });

  factory UsageHour.fromJson(Map<String, dynamic> json) => UsageHour(
        hour: DateTime.parse(json['hour'] as String),
        mode: Mode.fromJson(json['mode'] as String),
        total: json['total'] as int,
        malicious: json['malicious'] as int,
        suspicious: json['suspicious'] as int,
        notMalicious: json['notMalicious'] as int,
        cached: json['cached'] as int,
        partial: json['partial'] as int,
      );

  final DateTime hour;
  final Mode mode;
  final int total;
  final int malicious;
  final int suspicious;
  final int notMalicious;
  final int cached;
  final int partial;
}

/// Response of `GET /v1/usage`. Lags real-time usage by up to about an hour.
class UsageResponse {
  const UsageResponse({
    required this.tenantId,
    required this.from,
    required this.to,
    required this.hours,
  });

  factory UsageResponse.fromJson(Map<String, dynamic> json) => UsageResponse(
        tenantId: json['tenantId'] as String,
        from: DateTime.parse(json['from'] as String),
        to: DateTime.parse(json['to'] as String),
        hours: (json['hours'] as List)
            .cast<Map<String, dynamic>>()
            .map(UsageHour.fromJson)
            .toList(),
      );

  final String tenantId;
  final DateTime from;
  final DateTime to;
  final List<UsageHour> hours;
}
