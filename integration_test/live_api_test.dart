import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:flutter/material.dart';
import 'package:weather_app/app/app.dart';
import 'package:weather_app/app/dependencies.dart';
import 'package:weather_app/data/open_meteo/open_meteo_forecast_api.dart';
import 'package:weather_app/data/open_meteo/open_meteo_geocoding_api.dart';
import 'package:weather_app/data/open_meteo/open_meteo_http.dart';
import 'package:weather_app/data/weather_repository.dart';
import 'package:weather_app/features/weather/widgets/current_conditions.dart';

import '../test/support/fakes.dart';

/// 真实网络冒烟测试：设备上直连 Open-Meteo（需要网络，结果随实时天气变化）。
/// 只断言结构与流程，不断言具体温度。
/// 运行：flutter test integration_test/live_api_test.dart -d DEVICE_ID
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('live: search "Shanghai" and load real weather', (tester) async {
    final httpHelper = OpenMeteoHttp(http.Client());
    final deps = AppDependencies(
      geocoding: OpenMeteoGeocodingApi(httpHelper),
      weatherRepository: WeatherRepository(OpenMeteoForecastApi(httpHelper)),
      locationStore: InMemoryLocationStore(),
    );
    await tester.pumpWidget(WeatherApp(dependencies: deps));
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.byTooltip('搜索地点'));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.enterText(find.byType(TextField), 'Shanghai');
    await _pumpUntil(tester, find.textContaining('中国'));
    await tester.tap(find.textContaining('中国').first);

    await _pumpUntil(tester, find.byType(CurrentConditions));
    final temp = find.descendant(
      of: find.byType(CurrentConditions),
      matching: find.textContaining(RegExp(r'^-?\d+°$')),
    );
    expect(temp, findsOneWidget);
    expect(find.textContaining('GMT+8'), findsOneWidget, reason: 'Shanghai timezone');
    final text = tester.widget<Text>(temp).data;
    debugPrint('LIVE_RESULT Shanghai current temperature: $text');
  });
}

Future<void> _pumpUntil(WidgetTester tester, Finder finder, {int seconds = 20}) async {
  for (var i = 0; i < seconds * 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
  }
  throw TestFailure('Timed out waiting for $finder');
}
