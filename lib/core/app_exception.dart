/// 应用内统一的错误类型。
///
/// 数据层把 http / 超时 / JSON 等底层异常全部翻译成这几类，
/// UI 层只需 `switch` 这个 sealed class 就能给出对应文案，不依赖任何网络库类型。
sealed class AppException implements Exception {
  const AppException(this.debugMessage);

  /// 仅用于日志与调试，不直接展示给用户。
  final String debugMessage;

  @override
  String toString() => '$runtimeType: $debugMessage';
}

/// 无网络、DNS 失败、连接被重置、请求超时等。用户可以“稍后重试”。
final class NetworkException extends AppException {
  const NetworkException(super.debugMessage, {this.isTimeout = false});

  final bool isTimeout;
}

/// 服务端返回了非 2xx。[statusCode] 为 429 时表示触发了限流。
final class ServerException extends AppException {
  const ServerException(this.statusCode, super.debugMessage);

  final int statusCode;

  bool get isRateLimited => statusCode == 429;
}

/// 响应能拿到但内容不符合预期（非 JSON、缺少必需字段等）。
final class DataFormatException extends AppException {
  const DataFormatException(super.debugMessage);
}

/// 兜底：理论上不该发生的错误（编程错误），会同时上报到 FlutterError。
final class UnexpectedException extends AppException {
  const UnexpectedException(super.debugMessage);
}
