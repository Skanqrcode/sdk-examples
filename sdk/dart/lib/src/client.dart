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
        _baseUrl = baseUrl,
        _httpClient = httpClient ?? http.Client();

  final String _apiKey;
  final String _baseUrl;
  final http.Client _httpClient;

  /// Request timeout. Defaults to 5s: this call gates a synchronous
  /// "open this URL?" decision, so a hung request shouldn't hang the caller.
  final Duration timeout;

  /// Classifies [target] (a URL or IPv4/IPv6 address) as malicious,
  /// suspicious, or not malicious.
  ///
  /// Throws [SkanQRCodeException] for any non-2xx API response.
  /// Network failures and timeouts propagate as their underlying exceptions
  /// (e.g. [TimeoutException], [SocketException]) rather than being wrapped,
  /// since there's no server-issued requestId to attach to them — callers
  /// should treat both cases as "couldn't verify" and fail closed.
  Future<CheckResult> checkUrl(String target) async {
    final response = await _httpClient
        .post(
          Uri.parse('$_baseUrl/v1/check'),
          headers: _headers,
          body: jsonEncode({'target': target}),
        )
        .timeout(timeout);

    final body = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode != 200) {
      throw _exceptionFrom(response.statusCode, body);
    }

    return CheckResult.fromJson(body);
  }

  /// Returns hourly usage/verdict aggregates for the calling tenant between
  /// [from] and [to]. Lags real-time usage by up to about an hour.
  Future<UsageResponse> getUsage({
    required DateTime from,
    required DateTime to,
  }) async {
    final uri = Uri.parse('$_baseUrl/v1/usage').replace(queryParameters: {
      'from': from.toUtc().toIso8601String(),
      'to': to.toUtc().toIso8601String(),
    });

    final response = await _httpClient.get(uri, headers: _headers).timeout(timeout);

    final body = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode != 200) {
      throw _exceptionFrom(response.statusCode, body);
    }

    return UsageResponse.fromJson(body);
  }

  Map<String, String> get _headers => {
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
      };

  SkanQRCodeException _exceptionFrom(int statusCode, Map<String, dynamic> body) {
    final error = body['error'] as Map<String, dynamic>;
    return SkanQRCodeException(
      code: error['code'] as String,
      message: error['message'] as String,
      requestId: error['requestId'] as String,
      httpStatus: statusCode,
    );
  }

  /// Releases the underlying HTTP client's resources.
  void close() => _httpClient.close();
}
