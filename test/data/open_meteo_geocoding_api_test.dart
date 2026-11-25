import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:weather_app/data/open_meteo/open_meteo_geocoding_api.dart';
import 'package:weather_app/data/open_meteo/open_meteo_http.dart';
import 'package:weather_app/domain/location.dart';

OpenMeteoGeocodingApi apiReturning(String body, {void Function(Uri)? onRequest}) =>
    OpenMeteoGeocodingApi(
      OpenMeteoHttp(
        MockClient((req) async {
          onRequest?.call(req.url);
          // 故意不带 charset，验证按 UTF-8 解码。
          return http.Response.bytes(utf8.encode(body), 200);
        }),
      ),
    );

void main() {
  test('requests Chinese place names by default and preserves server fallback names', () async {
    late Uri uri;
    final api = apiReturning(
      '{"results": [{"id": 1, "name": "Untranslated Place", "latitude": 1, "longitude": 2}]}',
      onRequest: (u) => uri = u,
    );
    final result = await api.search('城市');
    expect(uri.queryParameters['language'], 'zh');
    expect(result.single.name, 'Untranslated Place');
  });
  test('parses recorded "Springfield" results (fixture, 2026-11-24)', () async {
    late Uri uri;
    final api = apiReturning(
      File('test/fixtures/geocoding_springfield.json').readAsStringSync(),
      onRequest: (u) => uri = u,
    );
    final results = await api.search('Springfield', languageCode: 'en');

    expect(uri.queryParameters, containsPair('name', 'Springfield'));
    expect(uri.queryParameters, containsPair('language', 'en'));
    expect(results, hasLength(10));
    expect(results.first.id, 'geonames:4409896');
    expect(results.first.subtitle, 'Missouri, United States');
    expect(results.first.flagEmoji, '🇺🇸');
  });

  test('decodes non-ASCII names as UTF-8 even without charset header', () async {
    final api = apiReturning(File('test/fixtures/geocoding_beijing_zh.json').readAsStringSync());
    final results = await api.search('北京', languageCode: 'zh');
    expect(results.first.name, '北京');
    expect(results.first.country, '中国');
    // 三个“北京”靠省级行政区区分。
    expect(disambiguatedSubtitles(results), ['北京市, 中国', '重庆市, 中国', '四川, 中国']);
  });

  test('missing "results" key means no matches', () async {
    final api = apiReturning('{"generationtime_ms":0.09}');
    expect(await api.search('zzzzqqq'), isEmpty);
  });

  test('skips malformed entries instead of failing the whole search', () async {
    final api = apiReturning(
      jsonEncode({
        'results': [
          {'id': 1, 'name': 'Ok', 'latitude': 1.0, 'longitude': 2.0},
          {'id': 2, 'name': 'No coords'},
          {'id': 3, 'name': '  ', 'latitude': 1.0, 'longitude': 2.0},
          {'id': 4, 'name': 'Bad lat', 'latitude': 123.0, 'longitude': 2.0},
          'garbage',
        ],
      }),
    );
    final results = await api.search('x');
    expect(results.map((l) => l.name), ['Ok']);
  });
}
