import 'package:flutter/foundation.dart';

import '../domain/forecast.dart';
import '../domain/location.dart';
import '../domain/services.dart';

/// 一次成功拉取的结果，附带拉取时刻（设备 UTC），用于“更新于 xx:xx”和过期判断。
@immutable
class ForecastSnapshot {
  const ForecastSnapshot({required this.forecast, required this.fetchedAt});

  final Forecast forecast;
  final DateTime fetchedAt;
}

/// 天气数据仓库：在 [WeatherService] 之上加一层**内存缓存 + 并发去重**。
///
/// 取舍：
/// - 只做内存缓存（TTL 默认 10 分钟，与 Open-Meteo 模型更新频率同量级），
///   切换回刚看过的城市时秒开，同时显著减少对免费接口的调用。
/// - 不做磁盘缓存：离线时展示几小时前的天气容易误导，且增加失效/迁移复杂度。
///   最近选择的地点会持久化，所以冷启动只需一次请求。
/// - 同一地点的并发请求复用同一个 Future（例如下拉刷新与回到前台刷新同时触发）。
class WeatherRepository {
  WeatherRepository(
    this._service, {
    DateTime Function()? clock,
    this.ttl = const Duration(minutes: 10),
    this.maxEntries = 12,
  }) : _clock = clock ?? DateTime.now;

  final WeatherService _service;
  final DateTime Function() _clock;
  final Duration ttl;
  final int maxEntries;

  // LinkedHashMap 保持插入顺序，用作简单的 LRU。
  final Map<String, ForecastSnapshot> _cache = {};
  final Map<String, Future<ForecastSnapshot>> _inFlight = {};

  /// 缓存中的快照（可能已过期）；用于切换地点时先展示旧数据。
  ForecastSnapshot? peek(Location location) => _cache[_key(location)];

  bool isFresh(ForecastSnapshot snapshot) => _clock().difference(snapshot.fetchedAt) < ttl;

  Future<ForecastSnapshot> getForecast(Location location, {bool forceRefresh = false}) {
    final key = _key(location);
    final cached = _cache[key];
    if (!forceRefresh && cached != null && isFresh(cached)) {
      return SynchronousFuture(cached);
    }

    final pending = _inFlight[key];
    if (pending != null) return pending;

    final future = _fetch(key, location);
    _inFlight[key] = future;
    // 无论成功失败都要移除，否则失败后会一直复用一个失败的 Future。
    future.whenComplete(() => _inFlight.remove(key)).ignore();
    return future;
  }

  Future<ForecastSnapshot> _fetch(String key, Location location) async {
    final forecast = await _service.fetchForecast(location);
    final snapshot = ForecastSnapshot(forecast: forecast, fetchedAt: _clock());
    _cache
      ..remove(key)
      ..[key] = snapshot;
    while (_cache.length > maxEntries) {
      _cache.remove(_cache.keys.first);
    }
    return snapshot;
  }

  /// 以坐标作键（约 1 km 精度），不同数据源的同一地点也能命中。
  static String _key(Location l) =>
      '${l.latitude.toStringAsFixed(2)},${l.longitude.toStringAsFixed(2)}';
}
