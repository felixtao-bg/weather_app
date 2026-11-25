import '../../core/app_exception.dart';
import '../../domain/forecast.dart';
import '../../domain/location.dart';
import '../../domain/services.dart';
import '../../domain/weather_condition.dart';
import 'open_meteo_http.dart';

/// Open-Meteo Forecast API，无需 API Key（非商业免费，CC BY 4.0 署名）。
///
/// 文档：https://open-meteo.com/en/docs
///
/// 关键参数：`timezone=auto` 让接口按地点时区返回本地时间字符串及 `utc_offset_seconds`，
/// 这样“今天/明天”“日出日落”都以地点为准，而不是设备所在时区。
class OpenMeteoForecastApi implements WeatherService {
  OpenMeteoForecastApi(this._http, {Uri? baseUri, this.forecastDays = 7})
    : _baseUri = baseUri ?? Uri.parse('https://api.open-meteo.com/v1/forecast');

  final OpenMeteoHttp _http;
  final Uri _baseUri;
  final int forecastDays;

  static const currentFields = [
    'temperature_2m',
    'apparent_temperature',
    'relative_humidity_2m',
    'weather_code',
    'is_day',
    'wind_speed_10m',
    'wind_direction_10m',
    'precipitation',
  ];
  static const hourlyFields = [
    'temperature_2m',
    'weather_code',
    'precipitation_probability',
    'is_day',
  ];
  static const dailyFields = [
    'weather_code',
    'temperature_2m_max',
    'temperature_2m_min',
    'precipitation_probability_max',
    'sunrise',
    'sunset',
    'uv_index_max',
  ];

  @override
  Future<Forecast> fetchForecast(Location location) async {
    final uri = _baseUri.replace(
      queryParameters: {
        'latitude': location.latitude.toStringAsFixed(4),
        'longitude': location.longitude.toStringAsFixed(4),
        'current': currentFields.join(','),
        'hourly': hourlyFields.join(','),
        'daily': dailyFields.join(','),
        'timezone': 'auto',
        'forecast_days': '$forecastDays',
      },
    );
    return parseForecast(await _http.getJson(uri));
  }

  /// 纯函数，便于用 JSON fixture 单测。
  ///
  /// 策略：顶层结构（current.time、时区）缺失视为格式错误；
  /// 单个数值缺失保留为 null 由 UI 显示“—”；逐小时缺温度的点直接丢弃。
  static Forecast parseForecast(Map<String, Object?> json) {
    final offsetSeconds = json['utc_offset_seconds'];
    final timezone = json['timezone'];
    final current = json['current'];
    if (offsetSeconds is! num || timezone is! String || current is! Map) {
      throw const DataFormatException('Missing timezone or current block');
    }
    final currentTime = parseWallTime(current['time'] as String?);
    if (currentTime == null) {
      throw const DataFormatException('Missing current.time');
    }

    return Forecast(
      timezone: timezone,
      timezoneAbbreviation: (json['timezone_abbreviation'] as String?) ?? timezone,
      utcOffset: Duration(seconds: offsetSeconds.toInt()),
      current: CurrentWeather(
        time: currentTime,
        condition: WeatherCondition.fromWmoCode(_int(current['weather_code'])),
        isDay: _int(current['is_day']) != 0,
        temperature: _double(current['temperature_2m']),
        apparentTemperature: _double(current['apparent_temperature']),
        relativeHumidity: _int(current['relative_humidity_2m']),
        windSpeed: _double(current['wind_speed_10m']),
        windDirection: _int(current['wind_direction_10m']),
        precipitation: _double(current['precipitation']),
      ),
      hourly: _parseHourly(json['hourly']),
      daily: _parseDaily(json['daily']),
    );
  }

  static List<HourlyForecast> _parseHourly(Object? raw) {
    if (raw is! Map) return const [];
    final times = _list(raw['time']);
    final temps = _list(raw['temperature_2m']);
    final codes = _list(raw['weather_code']);
    final precip = _list(raw['precipitation_probability']);
    final isDay = _list(raw['is_day']);
    final result = <HourlyForecast>[];
    for (var i = 0; i < times.length; i++) {
      final time = parseWallTime(times[i] as String?);
      final temp = _double(_at(temps, i));
      if (time == null || temp == null) continue;
      result.add(
        HourlyForecast(
          time: time,
          temperature: temp,
          condition: WeatherCondition.fromWmoCode(_int(_at(codes, i))),
          precipitationProbability: _int(_at(precip, i)),
          isDay: _int(_at(isDay, i)) != 0,
        ),
      );
    }
    return result;
  }

  static List<DailyForecast> _parseDaily(Object? raw) {
    if (raw is! Map) return const [];
    final times = _list(raw['time']);
    final codes = _list(raw['weather_code']);
    final max = _list(raw['temperature_2m_max']);
    final min = _list(raw['temperature_2m_min']);
    final precip = _list(raw['precipitation_probability_max']);
    final sunrise = _list(raw['sunrise']);
    final sunset = _list(raw['sunset']);
    final uv = _list(raw['uv_index_max']);
    final result = <DailyForecast>[];
    for (var i = 0; i < times.length; i++) {
      final date = parseWallTime(times[i] as String?);
      if (date == null) continue;
      var hi = _double(_at(max, i));
      var lo = _double(_at(min, i));
      // 防御：极少数情况下上游 max/min 颠倒，交换后温度条才不会画反。
      if (hi != null && lo != null && lo > hi) (hi, lo) = (lo, hi);
      result.add(
        DailyForecast(
          date: date,
          condition: WeatherCondition.fromWmoCode(_int(_at(codes, i))),
          temperatureMax: hi,
          temperatureMin: lo,
          precipitationProbabilityMax: _int(_at(precip, i)),
          sunrise: parseWallTime(_at(sunrise, i) as String?),
          sunset: parseWallTime(_at(sunset, i) as String?),
          uvIndexMax: _double(_at(uv, i)),
        ),
      );
    }
    return result;
  }

  static List<Object?> _list(Object? v) => v is List ? v : const [];
  static Object? _at(List<Object?> list, int i) => i < list.length ? list[i] : null;

  static double? _double(Object? v) {
    if (v is! num) return null;
    final d = v.toDouble();
    return d.isFinite ? d : null;
  }

  static int? _int(Object? v) => v is num && v.isFinite ? v.round() : null;
}
