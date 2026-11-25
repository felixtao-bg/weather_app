/// 视觉分组：决定背景渐变与图标风格。比 WMO 代码粗，避免 UI 层关心 30 种代码。
enum WeatherKind { clear, partlyCloudy, cloudy, fog, rain, snow, storm, unknown }

/// WMO 天气代码（Open-Meteo `weather_code`）到语义状况的映射。
///
/// 参考：https://open-meteo.com/en/docs 中 “WMO Weather interpretation codes”。
/// 未知代码映射为 [unknown]，UI 显示“Unknown”而不是崩溃或误报晴天。
enum WeatherCondition {
  clear('晴', WeatherKind.clear),
  mainlyClear('晴间少云', WeatherKind.clear),
  partlyCloudy('多云', WeatherKind.partlyCloudy),
  overcast('阴', WeatherKind.cloudy),
  fog('雾', WeatherKind.fog),
  rimeFog('雾凇', WeatherKind.fog),
  lightDrizzle('毛毛雨', WeatherKind.rain),
  drizzle('细雨', WeatherKind.rain),
  heavyDrizzle('强毛毛雨', WeatherKind.rain),
  freezingDrizzle('冻毛毛雨', WeatherKind.rain),
  lightRain('小雨', WeatherKind.rain),
  rain('中雨', WeatherKind.rain),
  heavyRain('大雨', WeatherKind.rain),
  freezingRain('冻雨', WeatherKind.rain),
  lightSnow('小雪', WeatherKind.snow),
  snow('中雪', WeatherKind.snow),
  heavySnow('大雪', WeatherKind.snow),
  snowGrains('米雪', WeatherKind.snow),
  rainShowers('阵雨', WeatherKind.rain),
  heavyRainShowers('强阵雨', WeatherKind.rain),
  snowShowers('阵雪', WeatherKind.snow),
  thunderstorm('雷暴', WeatherKind.storm),
  thunderstormHail('雷暴伴冰雹', WeatherKind.storm),
  unknown('天气未知', WeatherKind.unknown);

  const WeatherCondition(this.label, this.kind);

  final String label;
  final WeatherKind kind;

  static WeatherCondition fromWmoCode(int? code) => switch (code) {
    0 => clear,
    1 => mainlyClear,
    2 => partlyCloudy,
    3 => overcast,
    45 => fog,
    48 => rimeFog,
    51 => lightDrizzle,
    53 => drizzle,
    55 => heavyDrizzle,
    56 || 57 => freezingDrizzle,
    61 => lightRain,
    63 => rain,
    65 => heavyRain,
    66 || 67 => freezingRain,
    71 => lightSnow,
    73 => snow,
    75 => heavySnow,
    77 => snowGrains,
    80 || 81 => rainShowers,
    82 => heavyRainShowers,
    85 || 86 => snowShowers,
    95 => thunderstorm,
    96 || 99 => thunderstormHail,
    _ => unknown,
  };
}
