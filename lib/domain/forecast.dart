import 'package:flutter/foundation.dart';

import 'weather_condition.dart';

/// 某地点的完整天气数据（当前 + 逐小时 + 逐日）。
///
/// ## 时间约定（重要）
/// 所有 `DateTime` 字段都是**地点当地的“墙上时间”**，以 `isUtc: true` 的形式保存，
/// 仅借用 UTC 容器来避免被设备时区二次换算。例如东京 09:00 就存成
/// `DateTime.utc(…, 9, 0)`，格式化时直接取 hour/minute 即可。
/// 需要“地点此刻时间”时用 [localNow]，不要直接用 `DateTime.now()`。
@immutable
class Forecast {
  const Forecast({
    required this.timezone,
    required this.timezoneAbbreviation,
    required this.utcOffset,
    required this.current,
    required this.hourly,
    required this.daily,
  });

  /// IANA 时区，例如 "Asia/Shanghai"。
  final String timezone;

  /// 例如 "GMT+8"、"CET"。
  final String timezoneAbbreviation;

  /// 接口返回的当前 UTC 偏移（含夏令时）。
  final Duration utcOffset;
  final CurrentWeather current;
  final List<HourlyForecast> hourly;
  final List<DailyForecast> daily;

  /// 把设备的真实时刻换算为地点的墙上时间。
  DateTime localNow(DateTime deviceNow) => deviceNow.toUtc().add(utcOffset);

  /// 从地点“当前整点”开始的 [count] 个小时。
  List<HourlyForecast> upcomingHours(DateTime deviceNow, {int count = 24}) {
    final now = localNow(deviceNow);
    final currentHour = DateTime.utc(now.year, now.month, now.day, now.hour);
    return hourly.where((h) => !h.time.isBefore(currentHour)).take(count).toList(growable: false);
  }

  /// 地点当地“今天”的逐日数据；跨日或数据缺失时返回 null。
  DailyForecast? today(DateTime deviceNow) {
    final now = localNow(deviceNow);
    for (final d in daily) {
      if (d.date.year == now.year && d.date.month == now.month && d.date.day == now.day) {
        return d;
      }
    }
    return null;
  }

  /// 从地点当地“今天”起的逐日数据（过滤掉已经过去的日期）。
  List<DailyForecast> upcomingDays(DateTime deviceNow) {
    final now = localNow(deviceNow);
    final today = DateTime.utc(now.year, now.month, now.day);
    return daily.where((d) => !d.date.isBefore(today)).toList(growable: false);
  }
}

/// 当前实况。除 [time] / [condition] 外的字段都可能缺失（接口偶发 null）。
@immutable
class CurrentWeather {
  const CurrentWeather({
    required this.time,
    required this.condition,
    required this.isDay,
    this.temperature,
    this.apparentTemperature,
    this.relativeHumidity,
    this.windSpeed,
    this.windDirection,
    this.precipitation,
  });

  /// 观测/模型时间（地点墙上时间）。
  final DateTime time;
  final WeatherCondition condition;
  final bool isDay;

  /// 摄氏度。
  final double? temperature;
  final double? apparentTemperature;

  /// 百分比 0–100。
  final int? relativeHumidity;

  /// km/h。
  final double? windSpeed;

  /// 风的来向，0–360°，0 = 北风。
  final int? windDirection;

  /// 过去 15 分钟降水量，mm。
  final double? precipitation;
}

@immutable
class HourlyForecast {
  const HourlyForecast({
    required this.time,
    required this.temperature,
    required this.condition,
    required this.isDay,
    this.precipitationProbability,
  });

  final DateTime time;

  /// 逐小时温度缺失的点会在解析时被丢弃，所以这里非空。
  final double temperature;
  final WeatherCondition condition;
  final bool isDay;
  final int? precipitationProbability;
}

@immutable
class DailyForecast {
  const DailyForecast({
    required this.date,
    required this.condition,
    this.temperatureMax,
    this.temperatureMin,
    this.precipitationProbabilityMax,
    this.sunrise,
    this.sunset,
    this.uvIndexMax,
  });

  /// 当地日期（时分为 0）。
  final DateTime date;
  final WeatherCondition condition;
  final double? temperatureMax;
  final double? temperatureMin;
  final int? precipitationProbabilityMax;
  final DateTime? sunrise;
  final DateTime? sunset;
  final double? uvIndexMax;
}

/// 解析 Open-Meteo 的本地时间字符串（"2026-11-24T20:00" 或 "2026-11-24"）为墙上时间。
///
/// 故意不用 `DateTime.parse(s)`：无时区后缀时它会按**设备**时区解释，
/// 设备处于夏令时切换日时某些时刻不存在，会被悄悄平移一小时。
DateTime? parseWallTime(String? value) {
  if (value == null) return null;
  final normalized = value.length == 10 ? '${value}T00:00Z' : '${value}Z';
  final parsed = DateTime.tryParse(normalized);
  return parsed?.isUtc == true ? parsed : null;
}
