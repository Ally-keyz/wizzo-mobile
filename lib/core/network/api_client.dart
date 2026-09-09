import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_exception.dart';
import '../config/app_config.dart';

typedef Json = Map<String, dynamic>;

/// Thin HTTP wrapper around the Wizzo backend.
///
/// Every success is expected in the `{success, data}` envelope. 401s trigger
/// a single token refresh and a retry; if refresh fails the session callback
/// fires so the app can log the user out.
class ApiClient {
  ApiClient({String? baseUrl}) : baseUrl = baseUrl ?? AppConfig.apiBaseUrl;

  final String baseUrl;
  final http.Client _client = http.Client();

  /// Session hooks wired by the auth controller at startup.
  Future<String?> Function()? onAccessToken;
  Future<String?> Function()? onRefresh;
  void Function()? onSessionExpired;

  Duration get _timeout => const Duration(seconds: AppConfig.requestTimeoutSeconds);

  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) async {
    final uri = Uri.parse('$baseUrl$path').replace(
      queryParameters: _stringify(query),
    );
    return _send('GET', uri, headers: headers);
  }

  Future<dynamic> post(
    String path, {
    Object? body,
    Map<String, String>? headers,
    bool multipart = false,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    return _send(
      'POST',
      uri,
      body: body,
      headers: headers,
      multipart: multipart,
    );
  }

  Future<dynamic> patch(
    String path, {
    Object? body,
    Map<String, String>? headers,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    return _send('PATCH', uri, body: body, headers: headers);
  }

  Future<dynamic> put(
    String path, {
    Object? body,
    Map<String, String>? headers,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    return _send('PUT', uri, body: body, headers: headers);
  }

  Future<dynamic> delete(
    String path, {
    Object? body,
    Map<String, String>? headers,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    return _send('DELETE', uri, body: body, headers: headers);
  }

  Future<dynamic> _send(
    String method,
    Uri uri, {
    Object? body,
    Map<String, String>? headers,
    bool multipart = false,
  }) async {
    final token = await onAccessToken?.call();
    final finalHeaders = <String, String>{
      'Accept': 'application/json',
      if (!multipart) 'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty)
        'Authorization': 'Bearer $token',
      ...?headers,
    };

    var response = await _perform(method, uri, body, finalHeaders, multipart);
    if (!multipart && response.statusCode == 401) {
      final refreshed = await _tryRefresh();
      if (refreshed) {
        final newToken = await onAccessToken?.call();
        if (newToken != null && newToken.isNotEmpty) {
          finalHeaders['Authorization'] = 'Bearer $newToken';
          response = await _perform(method, uri, body, finalHeaders, multipart);
        }
      } else {
        onSessionExpired?.call();
        throw const ApiException(
          status: 401,
          code: 'unauthorized',
          message: 'Your session has expired. Please sign in again.',
        );
      }
    }
    return _decode(response);
  }

  Future<http.Response> _perform(
    String method,
    Uri uri,
    Object? body,
    Map<String, String> headers,
    bool multipart,
  ) async {
    final Future<http.Response> Function() call = switch (method) {
      'GET' => () => _client.get(uri, headers: headers).timeout(_timeout),
      'POST' when multipart && body is http.MultipartRequest =>
        () => _client.send(body).then((s) => http.Response.fromStream(s)).timeout(_timeout),
      'POST' => () => _client
          .post(uri, headers: headers, body: _encode(body))
          .timeout(_timeout),
      'PATCH' => () => _client
          .patch(uri, headers: headers, body: _encode(body))
          .timeout(_timeout),
      'PUT' => () => _client
          .put(uri, headers: headers, body: _encode(body))
          .timeout(_timeout),
      'DELETE' => () => _client
          .delete(uri, headers: headers, body: _encode(body))
          .timeout(_timeout),
      _ => throw UnsupportedError(method),
    };
    try {
      return await call();
    } on TimeoutException {
      throw const ApiException(
        status: 0,
        code: 'timeout',
        message: 'The request timed out. Check your connection and try again.',
      );
    } on http.ClientException {
      throw const ApiException(
        status:0,
        code:'network',
        message:'Could not reach the server. Check your connection.',
      );
    }
  }

  Future<bool> _tryRefresh() async {
    final refresh = await onRefresh?.call();
    return refresh != null && refresh.isNotEmpty;
  }

  dynamic _decode(http.Response response) {
    dynamic data;
    var detailMessage = '';
    try {
      final json = jsonDecode(utf8.decode(response.bodyBytes));
      if (json is Map<String, dynamic>) {
        if (json['success'] == false || json['data'] == null && json['success'] != true) {
          final err = json['error'];
          if (err is Map<String, dynamic>) {
            detailMessage = (err['message'] ?? err['email'] ?? '').toString();
          } else if (err is String) {
            detailMessage = err;
          } else {
            detailMessage = json['message']?.toString() ?? '';
          }
          data = json['data'];
        } else {
          data = json['data'];
        }
      } else {
        data = json;
      }
    } catch (_) {
      // Non-JSON payload (e.g. 500 HTML page) — treat as server error.
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    }

    throw ApiException(
      status: response.statusCode,
      code: _statusCode(response),
      message: detailMessage.isNotEmpty
          ? detailMessage
          : 'Something went wrong (${response.statusCode}). Please try again.',
    );
  }

  String _statusCode(http.Response response) {
    try {
      final json = jsonDecode(utf8.decode(response.bodyBytes));
      if (json is Map<String, dynamic> && json['error'] is Map<String, dynamic>) {
        final err = json['error'] as Map<String, dynamic>;
        if (err['code'] is String) return err['code'] as String;
      }
    } catch (_) {}
    return 'http_${response.statusCode}';
  }

  Object? _encode(Object? body) {
    if (body == null) return null;
    if (body is String || body is List) return body;
    if (body is Map) return jsonEncode(body);
    return body;
  }

  Map<String, String>? _stringify(Map<String, dynamic>? query) {
    if (query == null || query.isEmpty) return null;
    return query.map((k, v) => MapEntry(k, v.toString()));
  }
}