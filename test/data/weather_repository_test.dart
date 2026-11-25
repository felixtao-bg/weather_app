import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:weather_app/core/app_exception.dart';
import 'package:weather_app/data/weather_repository.dart';

import '../support/fakes.dart';

void main() {
  late FakeWeatherService service;
  late DateTime now;
  late WeatherRepository repo;

  setUp(() {
    service = FakeWeatherService();
    now = fixedNow;
    repo = WeatherRepository(service, clock: () => now);
  });

  test('serves from cache within TTL', () async {
    await repo.getForecast(tokyo);
    now = now.add(const Duration(minutes: 9));
    await repo.getForecast(tokyo);
    expect(service.requests, hasLength(1));
  });

  test('refetches after TTL and when forced', () async {
    await repo.getForecast(tokyo);
    now = now.add(const Duration(minutes: 10));
    await repo.getForecast(tokyo);
    await repo.getForecast(tokyo, forceRefresh: true);
    expect(service.requests, hasLength(3));
  });

  test('deduplicates concurrent requests for the same place', () async {
    final completer = Completer<void>();
    service.handler = (_) async {
      await completer.future;
      return sampleForecast();
    };
    final a = repo.getForecast(tokyo);
    final b = repo.getForecast(tokyo, forceRefresh: true);
    completer.complete();
    expect(identical(await a, await b), isTrue);
    expect(service.requests, hasLength(1));
  });

  test('a failure is not cached and the next call retries', () async {
    service.handler = (_) async => throw const NetworkException('offline');
    await expectLater(repo.getForecast(tokyo), throwsA(isA<NetworkException>()));
    service.handler = null;
    await repo.getForecast(tokyo);
    expect(service.requests, hasLength(2));
  });

  test('evicts least recently written entries beyond maxEntries', () async {
    repo = WeatherRepository(service, clock: () => now, maxEntries: 1);
    await repo.getForecast(tokyo);
    await repo.getForecast(springfieldMo);
    expect(repo.peek(tokyo), isNull);
    expect(repo.peek(springfieldMo), isNotNull);
  });
}
