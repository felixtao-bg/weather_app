import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:weather_app/core/app_exception.dart';
import 'package:weather_app/app/theme.dart';
import 'package:weather_app/features/weather/widgets/current_conditions.dart';
import 'package:weather_app/features/weather/widgets/hourly_forecast_card.dart';
import 'package:weather_app/ui/common_widgets.dart';

import '../support/fakes.dart';
import '../support/test_app.dart';

/// Widget 测试在 Linux 宿主上以“模拟目标平台”的方式运行（非真机/模拟器），
/// 用于验证双端共享 UI 与平台差异（返回按钮图标、页面转场）的行为一致。
final bothPlatforms = TargetPlatformVariant({TargetPlatform.iOS, TargetPlatform.android});

Finder heroText(String text) =>
    find.descendant(of: find.byType(CurrentConditions), matching: find.text(text));

void main() {
  testWidgets('first launch shows empty state; a popular chip loads weather', (tester) async {
    usePhoneViewport(tester);
    final h = TestHarness();
    await tester.pumpWidget(h.app);
    await settle(tester);

    expect(find.text('发现你的天气'), findsOneWidget);
    await tester.tap(find.text('东京'));
    await settle(tester);

    expect(find.text('东京'), findsOneWidget);
    expect(find.text('多云'), findsOneWidget);
    expect(heroText('14°'), findsOneWidget);
    expect(find.text('未来24小时'), findsOneWidget);
    expect(find.textContaining('当地时间 下午9:00 · JST'), findsOneWidget);
    expect(h.store.selected?.name, '东京');
  }, variant: bothPlatforms);

  testWidgets('search → disambiguated results → select → weather for that place', (tester) async {
    usePhoneViewport(tester);
    final h = TestHarness();
    await tester.pumpWidget(h.app);
    await settle(tester);

    await tester.tap(find.byTooltip('搜索地点'));
    await settle(tester, 5);
    await tester.enterText(find.byType(TextField), 'Spring');
    await settle(tester, 5); // 500ms > 350ms 防抖

    expect(h.geocoding.queries, ['Spring']);
    expect(find.text('Missouri, United States'), findsOneWidget);
    expect(find.text('Illinois, United States'), findsOneWidget);

    await tester.tap(find.text('Illinois, United States'));
    await settle(tester);

    expect(find.byType(TextField), findsNothing, reason: 'search page popped');
    expect(h.weather.requests.single, springfieldIl);
    expect(find.text('Illinois, United States'), findsOneWidget);
    expect(h.store.recents.first, springfieldIl);
  }, variant: bothPlatforms);

  testWidgets('double-tapping a result pops the search page only once', (tester) async {
    usePhoneViewport(tester);
    final h = TestHarness();
    await tester.pumpWidget(h.app);
    await settle(tester);

    await tester.tap(find.byTooltip('搜索地点'));
    await settle(tester, 5);
    await tester.enterText(find.byType(TextField), 'Spring');
    await settle(tester, 5);

    final resultCenter = tester.getCenter(find.text('Illinois, United States'));
    await tester.tapAt(resultCenter);
    await tester.pump(const Duration(milliseconds: 16));
    await tester.tapAt(resultCenter);
    await settle(tester);

    expect(find.byTooltip('搜索地点'), findsOneWidget, reason: 'home route still present');
    expect(h.weather.requests.single, springfieldIl);
  });

  testWidgets('system back from search returns home without changing selection', (tester) async {
    usePhoneViewport(tester);
    final h = TestHarness(initialLocation: tokyo);
    await tester.pumpWidget(h.app);
    await settle(tester);

    await tester.tap(find.byTooltip('搜索地点'));
    await settle(tester, 5);
    expect(find.byType(TextField), findsOneWidget);
    // iOS: ‹ chevron；Android: ← arrow —— BackButton 按平台取图标。
    expect(find.byType(BackButton), findsOneWidget);

    // 模拟 Android 系统返回键 / iOS 侧滑等价的 pop 事件。
    await tester.binding.handlePopRoute();
    await settle(tester, 8);

    expect(find.byType(TextField), findsNothing);
    expect(find.text('东京'), findsOneWidget);
    expect(h.weather.requests, hasLength(1));
  }, variant: bothPlatforms);

  testWidgets('recent searches show when the query is empty and can be cleared', (tester) async {
    usePhoneViewport(tester);
    final h = TestHarness(recents: [springfieldMo]);
    await tester.pumpWidget(h.app);
    await settle(tester);
    await tester.tap(find.byTooltip('搜索地点'));
    await settle(tester, 5);

    expect(find.text('最近搜索'), findsOneWidget);
    expect(find.text('Springfield'), findsOneWidget);
    await tester.tap(find.text('清除'));
    await settle(tester, 3);
    expect(find.text('最近搜索'), findsNothing);
  });

  testWidgets('no results message names the query', (tester) async {
    usePhoneViewport(tester);
    final h = TestHarness();
    await tester.pumpWidget(h.app);
    await settle(tester);
    await tester.tap(find.byTooltip('搜索地点'));
    await settle(tester, 5);
    await tester.enterText(find.byType(TextField), 'Atlantis');
    await settle(tester, 5);
    expect(find.text('未找到与“Atlantis”匹配的地点'), findsOneWidget);
  });

  testWidgets('initial load error → full-page error → retry succeeds', (tester) async {
    usePhoneViewport(tester);
    final h = TestHarness(initialLocation: tokyo);
    h.weather.handler = (_) async => throw const NetworkException('offline');
    await tester.pumpWidget(h.app);
    await settle(tester);

    expect(find.text('网络连接不可用'), findsOneWidget);
    expect(find.text('东京'), findsOneWidget, reason: 'error names the place');
    expect(find.text('选择其他地点'), findsOneWidget);

    h.weather.handler = null;
    await tester.tap(find.text('重试'));
    await settle(tester);
    expect(find.text('东京'), findsOneWidget);
    expect(find.text('网络连接不可用'), findsNothing);
  });

  testWidgets('loading shows a skeleton, then content', (tester) async {
    usePhoneViewport(tester);
    final h = TestHarness(initialLocation: tokyo);
    h.weather.handler = (_) => Future.delayed(const Duration(seconds: 1), () => sampleForecast());
    await tester.pumpWidget(h.app);
    await tester.pump();
    expect(find.bySemanticsLabel('正在加载天气'), findsOneWidget);
    await settle(tester, 15);
    expect(find.bySemanticsLabel('正在加载天气'), findsNothing);
    expect(find.text('东京'), findsOneWidget);
  });

  testWidgets('failed pull-to-refresh keeps data and shows a stale banner', (tester) async {
    usePhoneViewport(tester);
    final h = TestHarness(initialLocation: tokyo);
    await tester.pumpWidget(h.app);
    await settle(tester);

    h.weather.handler = (_) async => throw const ServerException(503, 'down');
    await tester.fling(find.text('东京'), const Offset(0, 400), 1000);
    await settle(tester, 20);

    expect(find.textContaining('刷新失败'), findsOneWidget);
    expect(heroText('14°'), findsOneWidget, reason: 'old data still visible');
    expect(h.weather.requests, hasLength(2));
  });

  testWidgets('large text (2.0x) on a small phone does not overflow', (tester) async {
    usePhoneViewport(tester, size: const Size(360, 690), dpr: 2);
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final h = TestHarness(initialLocation: tokyo);
    await tester.pumpWidget(h.app);
    await settle(tester);

    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1500));
    await settle(tester, 5);
    expect(tester.takeException(), isNull);
    expect(find.textContaining('Open-Meteo'), findsOneWidget);
  });

  testWidgets('honours the system 24-hour setting', (tester) async {
    usePhoneViewport(tester);
    final app = TestHarness(initialLocation: tokyo).app;
    await tester.pumpWidget(
      Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: app,
        ),
      ),
    );
    await settle(tester);
    expect(find.textContaining('当地时间 21:00 · JST'), findsOneWidget);
  });

  testWidgets('hero exposes a single meaningful semantics label', (tester) async {
    usePhoneViewport(tester);
    final handle = tester.ensureSemantics();
    final h = TestHarness(initialLocation: tokyo);
    await tester.pumpWidget(h.app);
    await settle(tester);

    expect(find.bySemanticsLabel(RegExp(r'^东京\. 14°, 多云\. 体感温度 12°')), findsOneWidget);
    handle.dispose();
  });

  testWidgets('hourly card title lines up with the 7-day title; hour columns keep their inset', (
    tester,
  ) async {
    // 足够高的视口，让两张卡片都在首屏内构建出来。
    usePhoneViewport(tester, size: const Size(390, 1800));
    final h = TestHarness(initialLocation: tokyo);
    await tester.pumpWidget(h.app);
    await settle(tester);

    double insetFromCard(Finder target) {
      final card = find.ancestor(of: target, matching: find.byType(GlassCard));
      return tester.getTopLeft(target).dx - tester.getTopLeft(card).dx;
    }

    final hourlyIcon = find.byIcon(Icons.schedule_rounded);
    final dailyIcon = find.byIcon(Icons.calendar_today_rounded);
    expect(insetFromCard(hourlyIcon), AppSpacing.lg);
    expect(insetFromCard(hourlyIcon), insetFromCard(dailyIcon));

    final hourlyTitle = find.text('未来24小时');
    expect(
      tester.getTopLeft(hourlyTitle).dx - tester.getTopRight(hourlyIcon).dx,
      AppSpacing.sm,
      reason: 'icon-to-text gap unchanged',
    );

    final nowLabel = find.descendant(
      of: find.byType(HourlyForecastCard),
      matching: find.text('现在'),
    );
    final firstColumn = find.ancestor(of: nowLabel, matching: find.byType(SizedBox)).first;
    expect(insetFromCard(firstColumn), AppSpacing.sm, reason: 'hour columns are not shifted');
  });

  testWidgets('wide layout (tablet) constrains content width', (tester) async {
    usePhoneViewport(tester, size: const Size(1024, 768), dpr: 2);
    final h = TestHarness(initialLocation: tokyo);
    await tester.pumpWidget(h.app);
    await settle(tester);
    final card = tester.getSize(find.text('未来24小时').first);
    expect(card.width, lessThan(640));
    expect(tester.takeException(), isNull);
  });
}
