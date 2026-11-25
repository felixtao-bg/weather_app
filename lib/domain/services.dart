import 'forecast.dart';
import 'location.dart';

/// 地点搜索能力的抽象。实现可以是 Open-Meteo、Mapbox、或测试里的 Fake。
abstract interface class GeocodingService {
  /// 返回按相关度排序的候选地点；无结果返回空列表。
  /// 失败时抛出 `AppException` 的某个子类。
  Future<List<Location>> search(String query, {String languageCode = 'zh'});
}

/// 天气数据能力的抽象。UI 和 Controller 只依赖它，便于替换数据源。
abstract interface class WeatherService {
  /// 失败时抛出 `AppException` 的某个子类。
  Future<Forecast> fetchForecast(Location location);
}
