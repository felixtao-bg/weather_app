import 'package:flutter_test/flutter_test.dart';
import 'package:weather_app/data/location_store.dart';
import 'package:weather_app/domain/forecast.dart';
import 'package:weather_app/domain/location.dart';
import 'package:weather_app/domain/weather_condition.dart';
import 'package:weather_app/ui/formatters.dart';

import '../support/fakes.dart';

void main() {
  group('WeatherCondition.fromWmoCode', () {
    test('maps documented codes and falls back to unknown', () {
      expect(WeatherCondition.fromWmoCode(0), WeatherCondition.clear);
      expect(WeatherCondition.fromWmoCode(3).kind, WeatherKind.cloudy);
      expect(WeatherCondition.fromWmoCode(65), WeatherCondition.heavyRain);
      expect(WeatherCondition.fromWmoCode(86).kind, WeatherKind.snow);
      expect(WeatherCondition.fromWmoCode(99), WeatherCondition.thunderstormHail);
      expect(WeatherCondition.fromWmoCode(null), WeatherCondition.unknown);
      expect(WeatherCondition.fromWmoCode(42), WeatherCondition.unknown);
    });
  });

  group('disambiguatedSubtitles', () {
    test('keeps short subtitles when they are already unique', () {
      expect(disambiguatedSubtitles([springfieldMo, springfieldIl]), [
        'Missouri, United States',
        'Illinois, United States',
      ]);
    });

    test('adds admin2 for same name + region, then coordinates', () {
      const a = Location(
        id: '1',
        name: 'Franklin',
        latitude: 1,
        longitude: 2,
        region: 'Ohio',
        subregion: 'Warren',
        country: 'US',
      );
      const b = Location(
        id: '2',
        name: 'Franklin',
        latitude: 3,
        longitude: 4,
        region: 'Ohio',
        subregion: 'Franklin County',
        country: 'US',
      );
      expect(disambiguatedSubtitles([a, b]), ['Warren, Ohio, US', 'Franklin County, Ohio, US']);
    });

    test('falls back to coordinates when no admin info exists (real "Hong Kong" case)', () {
      const hk1 = Location(id: '1', name: 'Hong Kong', latitude: 22.27832, longitude: 114.17469);
      const hk2 = Location(id: '2', name: 'Hong Kong', latitude: 22.25, longitude: 114.16667);
      expect(disambiguatedSubtitles([hk1, hk2]), ['22.28°N 114.17°E', '22.25°N 114.17°E']);
    });
  });

  group('Location', () {
    test('json round-trip and corrupted data', () {
      expect(Location.tryFromJson(springfieldMo.toJson())!.subtitle, springfieldMo.subtitle);
      expect(Location.tryFromJson({'id': 1}), isNull);
      expect(Location.tryFromJson('oops'), isNull);
    });

    test('flag emoji only for valid ISO codes', () {
      expect(tokyo.flagEmoji, '🇯🇵');
      expect(
        const Location(id: 'x', name: 'x', latitude: 0, longitude: 0, countryCode: '1').flagEmoji,
        isNull,
      );
    });

    test('mergeRecent puts newest first, dedupes and caps', () {
      final merged = mergeRecent([tokyo, springfieldMo], springfieldMo, 6);
      expect(merged, [springfieldMo, tokyo]);
      expect(mergeRecent([tokyo, springfieldIl], springfieldMo, 2), [springfieldMo, tokyo]);
    });
  });

  group('parseWallTime', () {
    test('accepts date and date-time, rejects garbage', () {
      expect(parseWallTime('2026-11-24'), DateTime.utc(2026, 11, 24));
      expect(parseWallTime('2026-11-24T05:30'), DateTime.utc(2026, 11, 24, 5, 30));
      expect(parseWallTime('yesterday'), isNull);
      expect(parseWallTime(null), isNull);
    });
  });

  group('Fmt', () {
    test('temperatures, missing values and units', () {
      expect(Fmt.temp(7.4), '7°');
      expect(Fmt.temp(-0.4), '0°');
      expect(Fmt.temp(-2.6), '\u22123°');
      expect(Fmt.temp(-4.5), '\u22125°', reason: 'round half away from zero');
      expect(Fmt.temp(null), Fmt.missing);
      expect(Fmt.percent(null), '—');
      expect(Fmt.windSpeed(11.4), '11 公里/小时');
      expect(Fmt.precipitation(0), '0 毫米');
      expect(Fmt.precipitation(1.25), '1.3 毫米');
      expect(Fmt.uv(6.2), '6 · 高');
    });

    test('relative "updated" time', () {
      final t = DateTime.utc(2026, 1, 1, 12);
      expect(Fmt.ago(t, t.add(const Duration(seconds: 30))), '刚刚');
      expect(Fmt.ago(t, t.add(const Duration(minutes: 5))), '5分钟前');
      expect(Fmt.ago(t, t.add(const Duration(minutes: 61))), '1小时前');
      expect(Fmt.ago(t, t.add(const Duration(hours: 3))), '3小时前');
    });

    test('compass points', () {
      expect(Fmt.compass(0), '北');
      expect(Fmt.compass(359), '北');
      expect(Fmt.compass(135), '东南');
      expect(Fmt.compass(null), '');
    });

    test('time follows 12/24h preference and uses wall time as-is', () {
      final t = DateTime.utc(2026, 11, 24, 21, 5);
      expect(Fmt.time(t, use24h: true), '21:05');
      expect(Fmt.time(t, use24h: false), '下午9:05');
      expect(Fmt.hour(t, use24h: true), '21时');
    });
  });
}
