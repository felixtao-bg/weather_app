@Tags(['golden'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:weather_app/core/app_exception.dart';
import 'package:weather_app/domain/weather_condition.dart';

import '../support/fakes.dart';
import '../support/test_app.dart';

/// 视觉回归（Fake 数据 + 固定时钟）。基准图在 Linux 上生成，
/// macOS/Windows 字体光栅化有细微差异，因此非 Linux 跳过。
/// 更新基准：flutter test --update-goldens test/goldens
final _skip = !Platform.isLinux;

void main() {
  setUpAll(loadAppFonts);

  Future<void> pumpHome(WidgetTester tester, TestHarness h) async {
    usePhoneViewport(tester, dpr: 2);
    await tester.pumpWidget(h.app);
    await settle(tester);
  }

  testWidgets('home – night, partly cloudy', (tester) async {
    await pumpHome(tester, TestHarness(initialLocation: tokyo));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('home_night.png'));
  }, skip: _skip);

  testWidgets('home – clear day, scrolled to details', (tester) async {
    final h = TestHarness(initialLocation: springfieldMo);
    h.weather.handler = (_) async => sampleForecast(
      utcOffset: const Duration(hours: -6),
      timezone: 'America/Chicago',
      abbreviation: 'CST',
      condition: WeatherCondition.clear,
      isDay: true,
      temperature: 21.6,
    );
    await pumpHome(tester, h);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -520));
    await settle(tester, 5);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('home_day_details.png'));
  }, skip: _skip);

  testWidgets('home – 2x non-linear system text size (stacked day rows)', (tester) async {
    usePhoneViewport(tester, dpr: 2);
    final h = TestHarness(initialLocation: springfieldMo);
    h.weather.handler = (_) async => sampleForecast(
      utcOffset: const Duration(hours: -6),
      abbreviation: 'GMT-6',
      temperature: -4.1,
      condition: WeatherCondition.partlyCloudy,
    );
    await tester.pumpWidget(withTextScaler(h.app, const NonLinearTextScaler()));
    await settle(tester);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -380));
    await settle(tester, 5);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('home_large_text.png'));
  }, skip: _skip);

  testWidgets('empty state', (tester) async {
    await pumpHome(tester, TestHarness());
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('empty.png'));
  }, skip: _skip);

  testWidgets('error state', (tester) async {
    final h = TestHarness(initialLocation: tokyo);
    h.weather.handler = (_) async => throw const NetworkException('offline');
    await pumpHome(tester, h);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('error.png'));
  }, skip: _skip);

  testWidgets('search results', (tester) async {
    await pumpHome(tester, TestHarness());
    await tester.tap(find.byTooltip('搜索地点'));
    await settle(tester, 5);
    await tester.enterText(find.byType(TextField), 'Spring');
    await settle(tester, 6);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('search_results.png'));
  }, skip: _skip);
}
