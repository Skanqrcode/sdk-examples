import 'dart:convert';

import 'package:http/http.dart' as http;

import 'exceptions.dart';
import 'models.dart';

/// Client for the SkanQRCode URL/QR-code safety API.
///
/// See `docs/api-contract.md` in the sdk-examples repo for the full HTTP
/// contract this client implements.
class SkanQRCodeClient {
  SkanQRCodeClient({
    required String apiKey,
    String baseUrl = 'https://api.skanqrcode.com',
    this.timeout = const Duration(seconds: 5),
    http.Client? httpClient,
  })  : _apiKey = apiKey,
        _baseUrl = baseUrl.endsWith('/')
            ? baseUrl.substring(0, baseUrl.length - 1)
            : baseUrl,
        _httpClient = httpClient ?? http.Client();

  final String _apiKey;
  final String _baseUrl;
  final http.Client _httpClient;

  /// Request timeout. Defaults to 5s: this call gates a synchronous
  /// "open this URL?" decision, so a hung request shouldn't hang the caller.
  final Duration timeout;

  /// Classifies [target] (a URL or IPv4/IPv6 address) as malicious,
  /// suspicious, or not malicious, and says what to do about it via
  /// [CheckResult.action]. Consumes one quota unit per successful call.
  ///
  /// [userId] is an opaque end-user identifier that enables per-user result
  /// caching; it is only sent when provided.
  ///
  /// Throws [SkanQRCodeException] for any non-2xx API response.
  /// Network failures and timeouts propagate as their underlying exceptions
  /// (e.g. [TimeoutException], [SocketException]) rather than being wrapped,
  /// since there's no server-issued requestId to attach to them — callers
  /// should treat both cases as "couldn't verify" and fail closed.
  Future<CheckResult> checkUrl(String target, {String? userId}) async {
    final json = await _json('POST', '/v1/check', body: {
      'target': target,
      if (userId != null) 'userId': userId,
    });
    return CheckResult.fromJson(json);
  }

  /// Monthly quota summary. [month] is `YYYY-MM` (UTC) and defaults to the
  /// current month. Lags real-time usage by up to about an hour.
  Future<UsageResponse> getUsage({String? month}) async {
    final json = await _json('GET', '/v1/usage', query: _monthQuery(month));
    return UsageResponse.fromJson(json);
  }

  /// Hour-by-hour usage with per-minute rate-limit utilization. [month] is
  /// `YYYY-MM` (UTC) and defaults to the current month.
  Future<UsageHourlyResponse> getUsageHourly({String? month}) async {
    final json =
        await _json('GET', '/v1/usage/hourly', query: _monthQuery(month));
    return UsageHourlyResponse.fromJson(json);
  }

  /// Allow list (Pro & Business plans only; otherwise `plan_feature_unavailable`).
  /// Newest first. [limit] is 1-500 (default 100); pass the previous page's
  /// `nextCursor` as [cursor].
  Future<ListEntriesPage> listAllowList({int? limit, String? cursor}) =>
      _list('/v1/allow-list', limit, cursor);

  /// Needs an `admin`-scope key. Adding is idempotent: 201 (created) and 200
  /// (already existed) both succeed.
  Future<ListEntry> addAllowListEntry({
    required MatchType matchType,
    required String value,
  }) =>
      _add('/v1/allow-list', matchType, value);

  /// Needs an `admin`-scope key. Throws `not_found` if the entry doesn't exist
  /// for this tenant.
  Future<void> deleteAllowListEntry(String entryId) =>
      _delete('/v1/allow-list', entryId);

  /// Block list (every plan). Same paging as [listAllowList].
  Future<ListEntriesPage> listBlockList({int? limit, String? cursor}) =>
      _list('/v1/block-list', limit, cursor);

  /// Needs an `admin`-scope key. Adding is idempotent: 201 (created) and 200
  /// (already existed) both succeed.
  Future<ListEntry> addBlockListEntry({
    required MatchType matchType,
    required String value,
  }) =>
      _add('/v1/block-list', matchType, value);

  /// Needs an `admin`-scope key. Throws `not_found` if the entry doesn't exist
  /// for this tenant.
  Future<void> deleteBlockListEntry(String entryId) =>
      _delete('/v1/block-list', entryId);

  /// Human-in-the-loop, `admin` scope. Returns a checkout URL to hand to a
  /// person — an autonomous agent must never complete checkout itself.
  /// [turnstileToken] is a bot-challenge token minted by the checkout-start
  /// page, so this is only callable from a flow with a real browser in the
  /// loop.
  Future<SessionUrl> createCheckoutSession({
    required PlanId planId,
    required String turnstileToken,
  }) async {
    final json = await _json('POST', '/v1/billing/checkout', body: {
      'planId': planId.toJson(),
      'turnstileToken': turnstileToken,
    });
    return SessionUrl.fromJson(json);
  }

  /// Human-in-the-loop, `admin` scope. Returns a billing-portal URL to hand to
  /// a person.
  Future<SessionUrl> createPortalSession() async {
    final json = await _json('POST', '/v1/billing/portal');
    return SessionUrl.fromJson(json);
  }

  /// Liveness only (no API key needed) — says nothing about the freshness of
  /// verdict data.
  Future<HealthResponse> getHealth() async {
    final json = await _json('GET', '/health', authenticated: false);
    return HealthResponse.fromJson(json);
  }

  Map<String, String>? _monthQuery(String? month) =>
      month == null ? null : {'month': month};

  Future<ListEntriesPage> _list(String path, int? limit, String? cursor) async {
    final json = await _json('GET', path, query: {
      if (limit != null) 'limit': '$limit',
      if (cursor != null) 'cursor': cursor,
    });
    return ListEntriesPage.fromJson(json);
  }

  Future<ListEntry> _add(String path, MatchType matchType, String value) async {
    // 200 and 201 are both success.
    final json = await _json('POST', path, body: {
      'matchType': matchType.toJson(),
      'value': value,
    });
    return ListEntry.fromJson(json);
  }

  Future<void> _delete(String path, String entryId) async {
    // 204: no body to parse.
    await _send('DELETE', '$path/${Uri.encodeComponent(entryId)}');
  }

  Future<Map<String, dynamic>> _json(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, Object?>? body,
    bool authenticated = true,
  }) async {
    final response = await _send(
      method,
      path,
      query: query,
      body: body,
      authenticated: authenticated,
    );
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Sends the request and returns a 2xx response; any other status throws
  /// [SkanQRCodeException].
  Future<http.Response> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, Object?>? body,
    bool authenticated = true,
  }) async {
    var uri = Uri.parse('$_baseUrl$path');
    // `replace(queryParameters: {})` would leave a dangling "?".
    if (query != null && query.isNotEmpty) {
      uri = uri.replace(queryParameters: query);
    }

    final request = http.Request(method, uri);
    if (authenticated) request.headers['Authorization'] = 'Bearer $_apiKey';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }

    // The timeout covers the whole exchange (headers and body), not just the body.
    Future<http.Response> exchange() async =>
        http.Response.fromStream(await _httpClient.send(request));
    final response = await exchange().timeout(timeout);

    if (response.statusCode < 200 || response.statusCode > 299) {
      throw _exceptionFrom(response);
    }
    return response;
  }

  /// Never throws a decode error: if the body isn't the documented JSON (e.g.
  /// HTML from a proxy's 502), this yields a synthetic `internal` error
  /// carrying the HTTP status.
  SkanQRCodeException _exceptionFrom(http.Response response) {
    final headerRequestId = response.headers['x-request-id'];
    final retryAfterHeader = response.headers['retry-after']?.trim();
    final retryAfter = retryAfterHeader == null
        ? null
        : int.tryParse(retryAfterHeader) ??
            double.tryParse(retryAfterHeader)?.ceil();

    try {
      final error = (jsonDecode(response.body) as Map<String, dynamic>)['error']
          as Map<String, dynamic>;
      return SkanQRCodeException(
        code: error['code'] as String,
        message: error['message'] as String,
        requestId: (error['requestId'] as String?) ?? headerRequestId,
        httpStatus: response.statusCode,
        retryAfter: retryAfter,
      );
    } catch (_) {
      return SkanQRCodeException(
        code: ErrorCode.internal,
        message: 'Unexpected HTTP ${response.statusCode} response',
        requestId: headerRequestId,
        httpStatus: response.statusCode,
        retryAfter: retryAfter,
      );
    }
  }

  /// Releases the underlying HTTP client's resources.
  void close() => _httpClient.close();
}
