import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_app/core/app_exception.dart';
import 'package:weather_app/data/weather_repository.dart';
import 'package:weather_app/domain/forecast.dart';
import 'package:weather_app/domain/location.dart';
import 'package:weather_app/features/weather/weather_controller.dart';

import '../support/fakes.dart';

void main() {
  late FakeWeatherService service;
  late InMemoryLocationStore store;
  late DateTime now;
  late WeatherController controller;

  WeatherController build({Location? initial}) => WeatherController(
    repository: WeatherRepository(service, clock: () => now),
    store: store,
    initialLocation: initial,
  );

  setUp(() {
    service = FakeWeatherService();
    store = InMemoryLocationStore();
    now = fixedNow;
  });

  tearDown(() => controller.dispose());

  test('no saved location → idle empty state, no request', () async {
    controller = build();
    await controller.start();
    expect(controller.state.location, isNull);
    expect(controller.state.isLoading, isFalse);
    expect(service.requests, isEmpty);
  });

  test('restored location loads immediately (loading → data)', () async {
    controller = build(initial: tokyo);
    final future = controller.start();
    expect(controller.state.isLoading, isTrue);
    expect(controller.state.hasData, isFalse);
    await future;
    expect(controller.state.isLoading, isFalse);
    expect(controller.state.snapshot!.forecast.timezone, 'Asia/Tokyo');
  });

  test('selecting persists the place and adds it to recents', () async {
    controller = build();
    await controller.selectLocation(springfieldMo);
    expect(store.selected, springfieldMo);
    expect(store.recents, [springfieldMo]);
  });

  test('race: a slow earlier request never overwrites a newer selection', () async {
    final slowTokyo = Completer<Forecast>();
    service.handler = (l) =>
        l == tokyo ? slowTokyo.future : Future.value(sampleForecast(timezone: 'America/Chicago'));
    controller = build();

    final first = controller.selectLocation(tokyo);
    await controller.selectLocation(springfieldMo);
    slowTokyo.complete(sampleForecast(timezone: 'Asia/Tokyo'));
    await first;

    expect(controller.state.location, springfieldMo);
    expect(controller.state.snapshot!.forecast.timezone, 'America/Chicago');
  });

  test('initial failure → full error; retry succeeds', () async {
    service.handler = (_) async => throw const NetworkException('offline');
    controller = build(initial: tokyo);
    await controller.start();
    expect(controller.state.error, isA<NetworkException>());
    expect(controller.state.hasData, isFalse);

    service.handler = null;
    await controller.refresh();
    expect(controller.state.error, isNull);
    expect(controller.state.hasData, isTrue);
  });

  test('refresh failure keeps the previous data (stale + error)', () async {
    controller = build(initial: tokyo);
    await controller.start();
    final before = controller.state.snapshot;

    service.handler = (_) async => throw const ServerException(503, 'down');
    await controller.refresh();
    expect(controller.state.snapshot, same(before));
    expect(controller.state.error, isA<ServerException>());
  });

  test('switching back to a cached place shows cached data instantly', () async {
    controller = build();
    await controller.selectLocation(tokyo);
    await controller.selectLocation(springfieldMo);
    unawaited(controller.selectLocation(tokyo));
    expect(controller.state.hasData, isTrue, reason: 'peek() fills before await');
    expect(service.requests, hasLength(2), reason: 'still fresh, no new request');
  });

  test('onAppResumed refreshes only when data is stale', () async {
    controller = build(initial: tokyo);
    await controller.start();
    await controller.onAppResumed();
    expect(service.requests, hasLength(1));

    now = now.add(const Duration(minutes: 11));
    await controller.onAppResumed();
    expect(service.requests, hasLength(2));
  });

  test('unexpected errors are reported and surfaced as UnexpectedException', () async {
    final reported = <Object>[];
    final previous = FlutterErrorHook.install(reported.add);
    addTearDown(previous);
    service.handler = (_) async => throw StateError('bug');
    controller = build(initial: tokyo);
    await controller.start();
    expect(controller.state.error, isA<UnexpectedException>());
    expect(reported.single, isA<StateError>());
  });
}

/// 临时替换 FlutterError.onError，返回恢复函数。
abstract final class FlutterErrorHook {
  static void Function() install(void Function(Object) sink) {
    final original = FlutterError.onError;
    FlutterError.onError = (details) => sink(details.exception);
    return () => FlutterError.onError = original;
  }
}
