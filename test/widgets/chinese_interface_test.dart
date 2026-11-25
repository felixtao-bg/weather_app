import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_app/app/strings.dart';
import 'package:weather_app/core/app_exception.dart';
import 'package:weather_app/domain/weather_condition.dart';
import 'package:weather_app/ui/formatters.dart';
import '../support/test_app.dart';

void main() {
  test('Chinese weather descriptions cover every WMO condition', () {
    for (final condition in WeatherCondition.values) {
      expect(condition.label, matches(RegExp(r'[\u4e00-\u9fff]')));
    }
    expect(WeatherCondition.fromWmoCode(0).label, '晴');
    expect(WeatherCondition.fromWmoCode(99).label, '雷暴伴冰雹');
    expect(WeatherCondition.fromWmoCode(null).label, '天气未知');
  });
  test('Chinese weekdays, wall clock and units are deterministic', () {
    final t = DateTime.utc(2026, 11, 24, 21, 5);
    expect(Fmt.weekday(t), '周二');
    expect(Fmt.fullWeekday(t), '星期二');
    expect(Fmt.hour(t, use24h: true), '21时');
    expect(Fmt.hour(t, use24h: false), '下午9时');
    expect(Fmt.time(DateTime.utc(2026), use24h: false), '上午12:00');
    expect(Fmt.time(null, use24h: false), '—');
    expect(Fmt.uv(11), '11 · 极高');
    expect(Fmt.compass(315), '西北');
  });
  test('Chinese errors preserve rate-limit and status details', () {
    expect(S.errorTitle(const NetworkException('offline')), '网络连接不可用');
    expect(S.errorMessage(const ServerException(503, 'down')), contains('503'));
    expect(S.errorTitle(const ServerException(429, 'busy')), '请求过于频繁');
    expect(S.errorTitle(const DataFormatException('bad')), '天气数据异常');
    expect(S.highLow('10°', '2°'), contains('最低'));
    expect(S.staleBanner('5分钟前'), contains('5分钟前'));
  });
  testWidgets('Chinese UI and built-in editing actions do not follow system English', (
    tester,
  ) async {
    usePhoneViewport(tester);
    tester.platformDispatcher.localeTestValue = const Locale('en', 'US');
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);
    await tester.pumpWidget(TestHarness().app);
    await settle(tester);
    expect(find.text('发现你的天气'), findsOneWidget);
    expect(find.text('东京'), findsOneWidget);
    final context = tester.element(find.byType(Scaffold).first);
    expect(Localizations.localeOf(context).languageCode, 'zh');
    expect(MaterialLocalizations.of(context).backButtonTooltip, '返回');
    expect(MaterialLocalizations.of(context).pasteButtonLabel, '粘贴');
    expect(find.text('Find your forecast'), findsNothing);
  });
}
