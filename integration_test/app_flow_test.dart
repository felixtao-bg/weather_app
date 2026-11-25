import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter/material.dart';
import 'package:weather_app/core/app_exception.dart';

import '../test/support/fakes.dart';
import '../test/support/test_app.dart';

/// 在真实设备/模拟器上运行（真实渲染引擎、真实平台通道），数据用 Fake 保证确定性。
/// 运行：flutter test integration_test/app_flow_test.dart -d DEVICE_ID
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('core flow on device: empty → search → select → refresh → back', (tester) async {
    final h = TestHarness();
    await tester.pumpWidget(h.app);
    await settle(tester);
    expect(find.text('发现你的天气'), findsOneWidget);

    await tester.tap(find.byTooltip('搜索地点'));
    await settle(tester, 6);
    await tester.enterText(find.byType(TextField), 'Springfield');
    await settle(tester, 6);
    expect(find.text('Illinois, United States'), findsOneWidget);

    await tester.tap(find.text('Illinois, United States'));
    await settle(tester);
    expect(find.text('Springfield'), findsOneWidget);
    expect(find.text('未来24小时'), findsOneWidget);

    await tester.fling(find.text('Springfield'), const Offset(0, 400), 1000);
    await settle(tester, 20);
    expect(h.weather.requests, hasLength(2), reason: 'pull-to-refresh bypasses cache');

    await tester.tap(find.byTooltip('搜索地点'));
    await settle(tester, 6);
    expect(find.text('最近搜索'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await settle(tester, 8);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Springfield'), findsOneWidget);
  });

  testWidgets('offline error and recovery on device', (tester) async {
    final h = TestHarness(initialLocation: tokyo);
    h.weather.handler = (_) async => throw const NetworkException('offline');
    await tester.pumpWidget(h.app);
    await settle(tester);
    expect(find.text('网络连接不可用'), findsOneWidget);

    h.weather.handler = null;
    await tester.tap(find.text('重试'));
    await settle(tester);
    expect(find.text('东京'), findsOneWidget);
  });
}
