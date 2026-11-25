import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:weather_app/core/app_exception.dart';
import 'package:weather_app/data/open_meteo/open_meteo_forecast_api.dart';
import 'package:weather_app/data/open_meteo/open_meteo_http.dart';
import 'package:weather_app/domain/weather_condition.dart';

import '../support/fakes.dart';

/// 2026-11-24 从真实 Open-Meteo 接口录制的上海预报。
Map<String, Object?> loadShanghai() =>
    jsonDecode(File('test/fixtures/forecast_shanghai.json').readAsStringSync())
        as Map<String, Object?>;

void main() {
  group('parseForecast (recorded fixture)', () {
    test('parses current, hourly and daily blocks in location wall time', () {
      final f = OpenMeteoForecastApi.parseForecast(loadShanghai());

      expect(f.timezone, 'Asia/Shanghai');
      expect(f.utcOffset, const Duration(hours: 8));
      expect(f.current.time, DateTime.utc(2026, 11, 24, 20, 15));
      expect(f.current.temperature, 7.3);
      expect(f.current.condition, WeatherCondition.clear);
      expect(f.current.isDay, isFalse);
      expect(f.hourly, hasLength(168));
      expect(f.daily, hasLength(7));
      expect(f.daily.first.date, DateTime.utc(2026, 11, 24));
      expect(f.daily.first.sunrise!.isUtc, isTrue, reason: 'wall-time container');
    });

    test('upcomingHours starts at the location current hour', () {
      final f = OpenMeteoForecastApi.parseForecast(loadShanghai());
      // 12:15 UTC = 上海 20:15
      final hours = f.upcomingHours(DateTime.utc(2026, 11, 24, 12, 15));
      expect(hours, hasLength(24));
      expect(hours.first.time, DateTime.utc(2026, 11, 24, 20));
      expect(hours.last.time, DateTime.utc(2026, 11, 25, 19));
    });

    test('today/upcomingDays follow the location date, not the device date', () {
      final f = OpenMeteoForecastApi.parseForecast(loadShanghai());
      // 17:30 UTC 11-24 已是上海 11-25 01:30
      final now = DateTime.utc(2026, 11, 24, 17, 30);
      expect(f.today(now)!.date, DateTime.utc(2026, 11, 25));
      expect(f.upcomingDays(now).first.date, DateTime.utc(2026, 11, 25));
    });
  });

  group('parseForecast (defensive)', () {
    Map<String, Object?> minimal() => {
      'utc_offset_seconds': 3600,
      'timezone': 'Europe/Berlin',
      'current': {'time': '2026-03-29T02:30', 'weather_code': 999},
      'hourly': {
        'time': ['2026-03-29T00:00', '2026-03-29T01:00', '2026-03-29T02:00'],
        'temperature_2m': [3.1, null, 4.0],
        'weather_code': [0, 1],
      },
      'daily': {
        'time': ['2026-03-29'],
        'temperature_2m_max': [2.0],
        'temperature_2m_min': [9.0],
      },
    };

    test('null values become null, hourly points without temperature are dropped', () {
      final f = OpenMeteoForecastApi.parseForecast(minimal());
      expect(f.current.temperature, isNull);
      expect(f.current.condition, WeatherCondition.unknown);
      expect(f.hourly.map((h) => h.time.hour), [0, 2]);
      expect(f.hourly.last.condition, WeatherCondition.unknown, reason: 'short array');
      expect(f.timezoneAbbreviation, 'Europe/Berlin');
    });

    test('wall time is not shifted by device DST rules', () {
      // 02:30 在中欧夏令时切换日“不存在”，用 DateTime.parse 会被设备时区平移。
      final f = OpenMeteoForecastApi.parseForecast(minimal());
      expect(f.current.time.hour, 2);
      expect(f.current.time.minute, 30);
    });

    test('swapped daily min/max is corrected', () {
      final d = OpenMeteoForecastApi.parseForecast(minimal()).daily.single;
      expect(d.temperatureMin, 2.0);
      expect(d.temperatureMax, 9.0);
    });

    test('missing required blocks throw DataFormatException', () {
      expect(
        () => OpenMeteoForecastApi.parseForecast({'timezone': 'UTC'}),
        throwsA(isA<DataFormatException>()),
      );
      expect(
        () => OpenMeteoForecastApi.parseForecast({
          'timezone': 'UTC',
          'utc_offset_seconds': 0,
          'current': {'time': 'not-a-date'},
        }),
        throwsA(isA<DataFormatException>()),
      );
    });
  });

  group('fetchForecast HTTP behaviour', () {
    test('retries once on transient 503, then succeeds', () async {
      var calls = 0;
      final api = OpenMeteoForecastApi(
        OpenMeteoHttp(
          MockClient((_) async {
            calls++;
            return calls == 1
                ? http.Response('{"error":true,"reason":"busy"}', 503)
                : http.Response.bytes(utf8.encode(jsonEncode(loadShanghai())), 200);
          }),
          retryDelay: Duration.zero,
        ),
      );
      final f = await api.fetchForecast(tokyo);
      expect(f.timezone, 'Asia/Shanghai');
      expect(calls, 2);
    });

    test('does not retry 4xx or timeouts; gives up after one retry', () async {
      var calls = 0;
      Future<void> expectCalls(http.Client client, int expected, Matcher error) async {
        calls = 0;
        final api = OpenMeteoForecastApi(
          OpenMeteoHttp(
            client,
            retryDelay: Duration.zero,
            timeout: const Duration(milliseconds: 10),
          ),
        );
        await expectLater(api.fetchForecast(tokyo), throwsA(error));
        expect(calls, expected);
      }

      await expectCalls(
        MockClient((_) async {
          calls++;
          return http.Response('{}', 400);
        }),
        1,
        isA<ServerException>(),
      );
      await expectCalls(
        MockClient((_) {
          calls++;
          return Completer<http.Response>().future;
        }),
        1,
        isA<NetworkException>().having((e) => e.isTimeout, 'timeout', true),
      );
      await expectCalls(
        MockClient((_) async {
          calls++;
          return http.Response('', 503);
        }),
        2,
        isA<ServerException>(),
      );
    });

    test('builds the expected query', () async {
      late Uri captured;
      final api = OpenMeteoForecastApi(
        OpenMeteoHttp(
          MockClient((req) async {
            captured = req.url;
            return http.Response.bytes(utf8.encode(jsonEncode(loadShanghai())), 200);
          }),
        ),
      );
      await api.fetchForecast(tokyo);
      expect(captured.host, 'api.open-meteo.com');
      expect(captured.queryParameters['timezone'], 'auto');
      expect(captured.queryParameters['forecast_days'], '7');
      expect(captured.queryParameters['latitude'], '35.6895');
      expect(captured.queryParameters['current'], contains('weather_code'));
    });

    test('maps HTTP 400 with reason to ServerException', () async {
      final api = OpenMeteoForecastApi(
        OpenMeteoHttp(
          MockClient(
            (_) async => http.Response('{"error":true,"reason":"Latitude must be in range"}', 400),
          ),
        ),
      );
      await expectLater(
        api.fetchForecast(tokyo),
        throwsA(
          isA<ServerException>()
              .having((e) => e.statusCode, 'status', 400)
              .having((e) => e.debugMessage, 'reason', contains('Latitude')),
        ),
      );
    });

    test('maps 429 to rate-limited ServerException', () async {
      final api = OpenMeteoForecastApi(
        OpenMeteoHttp(MockClient((_) async => http.Response('<html>', 429))),
      );
      await expectLater(
        api.fetchForecast(tokyo),
        throwsA(isA<ServerException>().having((e) => e.isRateLimited, 'rl', true)),
      );
    });

    test('maps client errors and timeouts to NetworkException', () async {
      final offline = OpenMeteoForecastApi(
        OpenMeteoHttp(
          MockClient((_) => throw http.ClientException('Failed host lookup')),
          retryDelay: Duration.zero,
        ),
      );
      await expectLater(offline.fetchForecast(tokyo), throwsA(isA<NetworkException>()));

      final slow = OpenMeteoForecastApi(
        OpenMeteoHttp(
          MockClient((_) => Completer<http.Response>().future),
          timeout: const Duration(milliseconds: 10),
        ),
      );
      await expectLater(slow.fetchForecast(tokyo), throwsA(isA<NetworkException>()));
    });

    test('unwrapped IO errors (TLS handshake) are network errors and retried once', () async {
      var calls = 0;
      final api = OpenMeteoForecastApi(
        OpenMeteoHttp(
          MockClient((_) {
            calls++;
            throw const HandshakeException('CERTIFICATE_VERIFY_FAILED');
          }),
          retryDelay: Duration.zero,
        ),
      );
      await expectLater(
        api.fetchForecast(tokyo),
        throwsA(isA<NetworkException>().having((e) => e.isTimeout, 'isTimeout', false)),
      );
      expect(calls, 2);
    });

    test('maps invalid JSON to DataFormatException', () async {
      final api = OpenMeteoForecastApi(
        OpenMeteoHttp(MockClient((_) async => http.Response('not json', 200))),
      );
      await expectLater(api.fetchForecast(tokyo), throwsA(isA<DataFormatException>()));
    });
  });
}
