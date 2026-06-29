import 'dart:async' as async;
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:ride_app_mock/core/errors/app_exception.dart';

/// Centralized HTTP client. All network calls go through here so that
/// status-code mapping, timeout handling, and JSON parsing live in one place.
class ApiClient {
  const ApiClient._();

  static const Duration _timeout = Duration(seconds: 10);
  static const Map<String, String> _headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  static Future<Map<String, dynamic>> get(String url) =>
      _execute(() => http.get(Uri.parse(url), headers: _headers));

  static Future<Map<String, dynamic>> post(
    String url, {
    Map<String, dynamic>? body,
  }) =>
      _execute(
        () => http.post(
          Uri.parse(url),
          headers: _headers,
          body: body != null ? jsonEncode(body) : null,
        ),
      );

  // ── internals ──────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> _execute(
    Future<http.Response> Function() request,
  ) async {
    try {
      final response = await request().timeout(_timeout);
      return _handleResponse(response);
    } on async.TimeoutException {
      throw const TimeoutException();
    } on SocketException {
      throw const NetworkException();
    } on AppException {
      rethrow;
    } catch (e) {
      debugPrint('[ApiClient] Unexpected error: $e');
      throw const UnknownException();
    }
  }

  static Map<String, dynamic> _handleResponse(http.Response response) {
    debugPrint(
      '[ApiClient] ${response.request?.method} '
      '${response.request?.url} → ${response.statusCode}',
    );

    Map<String, dynamic> data;
    try {
      data = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw const ParseException();
    }

    final statusCode = response.statusCode;

    if (statusCode == 200 || statusCode == 201) return data;

    final serverMessage = data['message'] as String?;

    if (statusCode == 401 || statusCode == 403) {
      throw const UnauthorizedException();
    }
    if (statusCode == 400) {
      throw ServerException(
        serverMessage ?? 'Bad request.',
        statusCode: statusCode,
        code: 'BAD_REQUEST',
      );
    }
    if (statusCode == 404) {
      throw ServerException(
        serverMessage ?? 'Resource not found.',
        statusCode: statusCode,
        code: 'NOT_FOUND',
      );
    }
    if (statusCode == 422) {
      throw ServerException(
        serverMessage ?? 'Validation failed.',
        statusCode: statusCode,
        code: 'UNPROCESSABLE',
      );
    }
    if (statusCode >= 500) {
      throw ServerException(
        serverMessage ?? 'Server error. Please try again later.',
        statusCode: statusCode,
      );
    }

    throw ServerException(
      serverMessage ?? 'Unexpected error.',
      statusCode: statusCode,
    );
  }
}
