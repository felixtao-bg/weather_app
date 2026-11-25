import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_app/app/app.dart';
import 'package:weather_app/app/dependencies.dart';
import 'package:weather_app/data/weather_repository.dart';
import 'package:weather_app/domain/location.dart';

import 'fakes.dart';

/// 用 Fake 服务组装一个完整 App，供 widget / golden / integration 测试复用。
class TestHarness {
  TestHarness({Location? initialLocation, List<Location> recents = const []})
    : store = InMemoryLocationStore(selected: initialLocation, recents: recents) {
    dependencies = AppDependencies(
      geocoding: geocoding,
      weatherRepository: WeatherRepository(weather, clock: () => fixedNow),
      locationStore: store,
      initialLocation: initialLocation,
      clock: () => fixedNow,
    );
  }

  final geocoding = FakeGeocodingService(
    (q) async => q.toLowerCase().startsWith('spring') ? [springfieldMo, springfieldIl] : const [],
  );
  final weather = FakeWeatherService();
  final InMemoryLocationStore store;
  late final AppDependencies dependencies;

  WeatherApp get app => WeatherApp(dependencies: dependencies);
}

/// 不用 pumpAndSettle：骨架屏/进度条是无限动画，会让它超时。
Future<void> settle(WidgetTester tester, [int frames = 12]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// 设置一个手机尺寸的视口（逻辑像素），测试结束自动复原。
void usePhoneViewport(WidgetTester tester, {Size size = const Size(390, 844), double dpr = 3}) {
  tester.view.physicalSize = size * dpr;
  tester.view.devicePixelRatio = dpr;
  addTearDown(tester.view.reset);
}

/// 让 golden 使用真实字体（Inter + Material Icons），而不是测试默认的方块字体。
Future<void> loadAppFonts() async {
  final manifest = jsonDecode(await rootBundle.loadString('FontManifest.json')) as List<dynamic>;
  for (final entry in manifest.cast<Map<String, dynamic>>()) {
    final family = entry['family'] as String;
    final loader = FontLoader(family.split('/').last);
    for (final font in (entry['fonts'] as List).cast<Map<String, dynamic>>()) {
      loader.addFont(rootBundle.load(font['asset'] as String));
    }
    await loader.load();
  }
}

/// 近似 Android 14+ 的非线性系统字号：小字放大约 2 倍，大字放大得少。
class NonLinearTextScaler extends TextScaler {
  const NonLinearTextScaler();

  @override
  double scale(double fontSize) {
    final factor = fontSize <= 14 ? 2.0 : (2.0 - (fontSize - 14) * 0.035).clamp(1.15, 2.0);
    return fontSize * factor;
  }

  @override
  double get textScaleFactor => 2.0;

  @override
  bool operator ==(Object other) => other is NonLinearTextScaler;

  @override
  int get hashCode => 0;
}

/// 用 [scaler] 覆盖系统字号后挂载 [app]。
Widget withTextScaler(Widget app, TextScaler scaler) => Builder(
  builder: (context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: scaler),
    child: app,
  ),
);
