import 'dart:async';

import 'package:weather_app/data/location_store.dart';
import 'package:weather_app/domain/forecast.dart';
import 'package:weather_app/domain/location.dart';
import 'package:weather_app/domain/services.dart';
import 'package:weather_app/domain/weather_condition.dart';

/// 可编程的地理编码 Fake：用 [handler] 决定每次查询返回什么/何时返回。
class FakeGeocodingService implements GeocodingService {
  FakeGeocodingService([this.handler]);

  Future<List<Location>> Function(String query)? handler;
  final List<String> queries = [];

  @override
  Future<List<Location>> search(String query, {String languageCode = 'en'}) {
    queries.add(query);
    return handler?.call(query) ?? Future.value(const []);
  }
}

class FakeWeatherService implements WeatherService {
  FakeWeatherService([this.handler]);

  Future<Forecast> Function(Location location)? handler;
  final List<Location> requests = [];

  @override
  Future<Forecast> fetchForecast(Location location) {
    requests.add(location);
    return handler?.call(location) ?? Future.value(sampleForecast());
  }
}

class InMemoryLocationStore implements LocationStore {
  InMemoryLocationStore({this.selected, List<Location>? recents}) : recents = [...?recents];

  Location? selected;
  List<Location> recents;

  @override
  Future<Location?> loadSelected() async => selected;

  @override
  Future<void> saveSelected(Location location) async => selected = location;

  @override
  Future<List<Location>> loadRecents() async => recents;

  @override
  Future<List<Location>> addRecent(Location location) async =>
      recents = mergeRecent(recents, location, 6);

  @override
  Future<void> clearRecents() async => recents = [];
}

const springfieldMo = Location(
  id: 'geonames:4409896',
  name: 'Springfield',
  latitude: 37.21533,
  longitude: -93.29824,
  region: 'Missouri',
  subregion: 'Greene',
  country: 'United States',
  countryCode: 'US',
);

const springfieldIl = Location(
  id: 'geonames:4250542',
  name: 'Springfield',
  latitude: 39.80172,
  longitude: -89.64371,
  region: 'Illinois',
  subregion: 'Sangamon',
  country: 'United States',
  countryCode: 'US',
);

const tokyo = Location(
  id: 'geonames:1850147',
  name: '东京',
  latitude: 35.6895,
  longitude: 139.69171,
  region: '东京',
  country: 'Japan',
  countryCode: 'JP',
);

/// 固定时钟：2026-11-24 12:00 UTC（= 东京 21:00，= Springfield 06:00）。
final fixedNow = DateTime.utc(2026, 11, 24, 12);

/// 确定性的示例预报：从 [start]（地点墙上时间）起 48 小时 + 7 天。
Forecast sampleForecast({
  Duration utcOffset = const Duration(hours: 9),
  String timezone = 'Asia/Tokyo',
  String abbreviation = 'JST',
  double temperature = 14.2,
  WeatherCondition condition = WeatherCondition.partlyCloudy,
  bool isDay = false,
}) {
  final localNow = fixedNow.add(utcOffset);
  final startOfDay = DateTime.utc(localNow.year, localNow.month, localNow.day);
  return Forecast(
    timezone: timezone,
    timezoneAbbreviation: abbreviation,
    utcOffset: utcOffset,
    current: CurrentWeather(
      time: DateTime.utc(localNow.year, localNow.month, localNow.day, localNow.hour),
      condition: condition,
      isDay: isDay,
      temperature: temperature,
      apparentTemperature: temperature - 2.6,
      relativeHumidity: 62,
      windSpeed: 11.4,
      windDirection: 315,
      precipitation: 0,
    ),
    hourly: [
      for (var h = 0; h < 72; h++)
        HourlyForecast(
          time: startOfDay.add(Duration(hours: h)),
          temperature: 10 + (h % 24 - 12).abs() * -0.4 + 6,
          condition: h % 24 < 6
              ? WeatherCondition.clear
              : h % 24 < 15
              ? WeatherCondition.partlyCloudy
              : WeatherCondition.lightRain,
          isDay: h % 24 >= 7 && h % 24 < 17,
          precipitationProbability: (h * 7) % 90,
        ),
    ],
    daily: [
      for (var d = 0; d < 7; d++)
        DailyForecast(
          date: startOfDay.add(Duration(days: d)),
          condition: WeatherCondition.values[(d * 5) % 22],
          temperatureMax: 15.0 + d,
          temperatureMin: 6.0 + (d % 3),
          precipitationProbabilityMax: (d * 23) % 100,
          sunrise: startOfDay.add(Duration(days: d, hours: 6, minutes: 28)),
          sunset: startOfDay.add(Duration(days: d, hours: 16, minutes: 31)),
          uvIndexMax: 2.5 + d * 0.4,
        ),
    ],
  );
}
