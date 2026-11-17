import 'dart:async';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class Api {
  Api._();
  static final Api instance = Api._();
  static const baseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'https://darb-api-yapv.onrender.com/api/v1');
  static const _storage = FlutterSecureStorage();
  String? _accessToken;
  Future<bool>? _refreshing;
  String? get accessToken => _accessToken;

  Future<void> restore() async {
    _accessToken = await _storage.read(key: 'accessToken');
    if (_accessToken == null) await _refreshAccessToken();
  }

  Future<void> saveTokens(Map<String, dynamic> tokens) async {
    _accessToken = tokens['accessToken'] as String?;
    if (_accessToken != null) await _storage.write(key: 'accessToken', value: _accessToken);
    final refresh = tokens['refreshToken'] as String?;
    if (refresh != null) await _storage.write(key: 'refreshToken', value: refresh);
  }

  Future<void> clear() async {
    final refreshToken = await _storage.read(key: 'refreshToken');
    if (refreshToken != null && refreshToken.isNotEmpty) {
      try {
        await http.post(
          Uri.parse('$baseUrl/auth/logout'),
          headers: const {'Content-Type': 'application/json', 'Accept': 'application/json'},
          body: jsonEncode({'refreshToken': refreshToken}),
        ).timeout(const Duration(seconds: 8));
      } catch (_) {}
    }
    _accessToken = null;
    await _storage.deleteAll();
  }

  Future<dynamic> get(String path) => _request('GET', path);
  Future<dynamic> post(String path, Map<String, dynamic> body) => _request('POST', path, body: body);
  Future<dynamic> patch(String path, Map<String, dynamic> body) => _request('PATCH', path, body: body);
  Future<dynamic> delete(String path, Map<String, dynamic> body) => _request('DELETE', path, body: body);

  Future<bool> _refreshAccessToken() async {
    if (_refreshing != null) return _refreshing!;
    _refreshing = _performRefresh();
    try { return await _refreshing!; }
    finally { _refreshing = null; }
  }

  Future<bool> _performRefresh() async {
    final refreshToken = await _storage.read(key: 'refreshToken');
    if (refreshToken == null || refreshToken.isEmpty) return false;
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/refresh'),
        headers: const {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({'refreshToken': refreshToken}),
      ).timeout(const Duration(seconds: 20));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        await clear();
        return false;
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      await saveTokens(data);
      return _accessToken != null;
    } catch (_) {
      return false;
    }
  }

  Future<http.Response> _send(String method, Uri uri, Map<String, dynamic>? body) async {
    final headers = <String, String>{'Content-Type': 'application/json', 'Accept': 'application/json'};
    if (_accessToken != null) headers['Authorization'] = 'Bearer $_accessToken';
    final request = http.Request(method, uri)..headers.addAll(headers);
    if (body != null) request.body = jsonEncode(body);
    final streamed = await request.send().timeout(const Duration(seconds: 20));
    return http.Response.fromStream(streamed);
  }

  Future<dynamic> _request(String method, String path, {Map<String, dynamic>? body}) async {
    final uri = Uri.parse('$baseUrl$path');
    late http.Response response;
    try {
      response = await _send(method, uri, body);
      if (response.statusCode == 401 && (path == '/auth/me' || !path.startsWith('/auth/'))) {
        if (await _refreshAccessToken()) response = await _send(method, uri, body);
      }
    } catch (_) {
      throw const ApiException('تعذر الاتصال بالخادم. تحقق من الإنترنت وحاول مجدداً.');
    }
    dynamic data;
    try { data = response.body.isEmpty ? null : jsonDecode(response.body); } catch (_) { data = null; }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = data is Map ? (data['message'] is List ? (data['message'] as List).join('\\n') : data['message']) : null;
      throw ApiException(message?.toString() ?? 'حدث خطأ (${response.statusCode})');
    }
    return data;
  }
}

class ApiException implements Exception {
  final String message;
  const ApiException(this.message);
  @override String toString() => message;
}

