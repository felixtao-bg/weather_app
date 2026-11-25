import 'dart:async';
import 'dart:convert';
import 'dart:io' show IOException;

import 'package:http/http.dart' as http;

import '../../core/app_exception.dart';

/// Open-Meteo 两个接口共享的 HTTP 细节：超时、状态码、JSON 解码与错误翻译。
///
/// 注入 [http.Client] 而不是直接调用 `http.get`，测试里可换成 `MockClient`。
class OpenMeteoHttp {
  OpenMeteoHttp(
    this._client, {
    this.timeout = const Duration(seconds: 12),
    this.retryDelay = const Duration(milliseconds: 800),
  });

  final http.Client _client;
  final Duration timeout;

  /// 首次遇到 502/503/504 或连接错误后，等待该时长自动重试**一次**。
  /// 实测免费接口偶发 503 并在数秒内恢复；GET 幂等，重试安全。
  /// 超时不重试：否则用户最长要等 2 倍超时才看到错误。
  final Duration retryDelay;

  Future<Map<String, Object?>> getJson(Uri uri) async {
    try {
      return await _getOnce(uri);
    } on AppException catch (e) {
      final transient =
          (e is ServerException && const {502, 503, 504}.contains(e.statusCode)) ||
          (e is NetworkException && !e.isTimeout);
      if (!transient) rethrow;
      await Future<void>.delayed(retryDelay);
      return _getOnce(uri);
    }
  }

  Future<Map<String, Object?>> _getOnce(Uri uri) async {
    final http.Response response;
    try {
      response = await _client
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(timeout);
    } on TimeoutException {
      throw NetworkException('Timed out after ${timeout.inSeconds}s: ${uri.path}', isTimeout: true);
    } on http.ClientException catch (e) {
      // http 1.6 的 IOClient 只把 SocketException / HttpException 包装成 ClientException。
      throw NetworkException(e.message);
    } on IOException catch (e) {
      // 未被包装的 IO 错误（如 TLS HandshakeException：公共 Wi‑Fi 认证页、证书问题）也按网络错误处理，
      // 否则会落到“Something went wrong”且不会重试。
      throw NetworkException(e.toString());
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ServerException(
        response.statusCode,
        _errorReason(response) ?? 'HTTP ${response.statusCode}',
      );
    }

    try {
      // 必须按 bodyBytes 解码：响应头缺少 charset 时 `response.body` 会按 latin1 解码，
      // 导致“北京”“São Paulo”等非 ASCII 地名乱码。
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, Object?>) return decoded;
      throw const DataFormatException('Top-level JSON is not an object');
    } on FormatException catch (e) {
      throw DataFormatException('Invalid JSON: ${e.message}');
    }
  }

  /// Open-Meteo 的错误体形如 `{"error": true, "reason": "..."}`。
  String? _errorReason(http.Response response) {
    try {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body is Map && body['reason'] is String) return body['reason'] as String;
    } on FormatException {
      // 错误体不是 JSON（如网关返回的 HTML），忽略即可。
    }
    return null;
  }
}
