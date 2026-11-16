import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class Api {
  Api._();
  static final Api instance = Api._();
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000/api/v1',
  );
  static const _storage = FlutterSecureStorage();

  String? _accessToken;
  String? _refreshToken;
  Future<bool>? _refreshInFlight;

  String? get accessToken => _accessToken;

  Future<void> restore() async {
    _accessToken = await _storage.read(key: 'accessToken');
    _refreshToken = await _storage.read(key: 'refreshToken');
  }

  Future<void> saveTokens(Map<String, dynamic> tokens) async {
    final access = tokens['accessToken'] as String?;
    final refresh = tokens['refreshToken'] as String?;
    if (access != null && access.isNotEmpty) {
      _accessToken = access;
      await _storage.write(key: 'accessToken', value: access);
    }
    if (refresh != null && refresh.isNotEmpty) {
      _refreshToken = refresh;
      await _storage.write(key: 'refreshToken', value: refresh);
    }
  }

  Future<void> clear() async {
    _accessToken = null;
    _refreshToken = null;
    await _storage.deleteAll();
  }

  Future<dynamic> get(String path) => _request('GET', path);
  Future<dynamic> post(String path, Map<String, dynamic> body) =>
      _request('POST', path, body: body);
  Future<dynamic> patch(String path, Map<String, dynamic> body) =>
      _request('PATCH', path, body: body);

  Future<dynamic> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool retryAfterRefresh = true,
  }) async {
    Future<http.Response> send() async {
      final uri = Uri.parse('$baseUrl$path');
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      if (_accessToken != null) {
        headers['Authorization'] = 'Bearer $_accessToken';
      }
      final request = http.Request(method, uri)..headers.addAll(headers);
      if (body != null) request.body = jsonEncode(body);
      final streamed = await request.send().timeout(
        const Duration(seconds: 20),
      );
      return http.Response.fromStream(streamed);
    }

    late http.Response response;
    try {
      response = await send();
      if (response.statusCode == 401 &&
          retryAfterRefresh &&
          path != '/auth/refresh' &&
          _refreshToken != null) {
        final refreshed = await _refreshAccessToken();
        if (refreshed) {
          response = await send();
        } else {
          await clear();
          throw const ApiException(
            'انتهت جلسة الدخول. سجّل الدخول مجدداً للمتابعة.',
          );
        }
      }
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        'تعذر الاتصال بالخادم. تحقق من الإنترنت وحاول مجدداً.',
      );
    }

    dynamic data;
    try {
      data = response.body.isEmpty ? null : jsonDecode(response.body);
    } catch (_) {
      data = null;
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = data is Map
          ? (data['message'] is List
              ? (data['message'] as List).join('\n')
              : data['message'])
          : null;
      throw ApiException(
        message?.toString() ?? 'حدث خطأ (${response.statusCode})',
      );
    }
    return data;
  }

  Future<bool> _refreshAccessToken() async {
    final pending = _refreshInFlight;
    if (pending != null) return pending;

    final refreshFuture = _performRefresh();
    _refreshInFlight = refreshFuture;
    try {
      return await refreshFuture;
    } finally {
      if (identical(_refreshInFlight, refreshFuture)) {
        _refreshInFlight = null;
      }
    }
  }

  Future<bool> _performRefresh() async {
    final token = _refreshToken;
    if (token == null || token.isEmpty) return false;

    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/refresh'),
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({'refreshToken': token}),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return false;
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return false;
      await saveTokens(decoded);
      return _accessToken != null && _refreshToken != null;
    } catch (_) {
      return false;
    }
  }
}

class ApiException implements Exception {
  final String message;
  const ApiException(this.message);

  @override
  String toString() => message;
}
