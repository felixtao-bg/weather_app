import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

import '../data/location_store.dart';
import '../data/open_meteo/open_meteo_forecast_api.dart';
import '../data/open_meteo/open_meteo_geocoding_api.dart';
import '../data/open_meteo/open_meteo_http.dart';
import '../data/weather_repository.dart';
import '../domain/location.dart';
import '../domain/services.dart';

/// 组合根（Composition Root）：唯一知道“具体用哪个实现”的地方。
///
/// 替换数据源（例如换成付费 API 或 Mock 服务器）只需改 [production]；
/// 测试与集成测试直接用构造函数传入 Fake。
class AppDependencies {
  AppDependencies({
    required this.geocoding,
    required this.weatherRepository,
    required this.locationStore,
    this.initialLocation,
    this.languageCode = 'zh',
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;

  final GeocodingService geocoding;
  final WeatherRepository weatherRepository;
  final LocationStore locationStore;

  /// 启动前从本地读取的上次地点，避免首帧先闪“空状态”再跳到天气。
  final Location? initialLocation;

  /// 地理编码结果的语言（地名本地化）；本地版本 UI 默认简体中文。
  final String languageCode;

  /// UI 中所有“现在”都经由此时钟，Golden/Widget 测试可固定时间。
  final DateTime Function() clock;

  static Future<AppDependencies> production() async {
    final httpHelper = OpenMeteoHttp(http.Client());
    final store = SharedPrefsLocationStore();
    return AppDependencies(
      geocoding: OpenMeteoGeocodingApi(httpHelper),
      weatherRepository: WeatherRepository(OpenMeteoForecastApi(httpHelper)),
      locationStore: store,
      initialLocation: await store.loadSelected(),
      languageCode: 'zh',
    );
  }
}

/// 轻量依赖注入：子树通过 `AppScope.of(context)` 取依赖，无需第三方 DI 库。
class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.dependencies, required super.child});

  final AppDependencies dependencies;

  static AppDependencies of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope not found in widget tree');
    return scope!.dependencies;
  }

  /// 不建立依赖关系的读取，可在 `initState` 中使用。
  static AppDependencies read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope not found in widget tree');
    return scope!.dependencies;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) => dependencies != oldWidget.dependencies;
}
