import '../core/app_exception.dart';

/// UI 文案集中于此：当前本地版本默认简体中文；文案集中维护，不新增语言设置页。
abstract final class S {
  static const appTitle = '天气';
  static const searchHint = '搜索城市或地点';
  static const searchTooltip = '搜索地点';
  static const emptyTitle = '发现你的天气';
  static const emptyBody = '搜索任意城市，查看实时天气、未来24小时及7天天气预报。';
  static const emptyCta = '搜索地点';
  static const clearSearch = '清除搜索内容';
  static const searching = '正在搜索';
  static const loadingWeather = '正在加载天气';
  static const popular = '热门城市';
  static const recent = '最近搜索';
  static const clear = '清除';
  static const retry = '重试';
  static const chooseAnother = '选择其他地点';
  static const next24Hours = '未来24小时';
  static const sevenDay = '7天天气预报';
  static const now = '现在';
  static const today = '今天';
  static const feelsLike = '体感温度';
  static const humidity = '湿度';
  static const wind = '风速';
  static const precipitation = '降水量';
  static const uvIndex = '紫外线指数';
  static const sunrise = '日出';
  static const sunset = '日落';
  static const attribution = '天气数据来自 Open-Meteo.com · CC BY 4.0';
  static const searchIdleHint = '请输入至少2个字符，可输入中文或英文地名；同名地点会显示地区信息以便区分。';
  static const noForecastData = '该地点的预报数据暂不可用。';

  static String noResults(String q) => '未找到与“$q”匹配的地点';
  static const noResultsHint = '请检查输入，或尝试附近较大的城市。';
  static String updatedAgo(String ago) => '更新于$ago';
  static String staleBanner(String ago) => '刷新失败，当前显示$ago的数据。';
  static String localTime(String time, String tz) => '当地时间 $time · $tz';
  // 不换行空格让 "H 6°  L −5°" 作为整体换行，不会拆成 "L" / "−5°"。
  static String highLow(String hi, String lo) => '最高\u00A0$hi\u00A0\u00A0最低\u00A0$lo';
  static String feelsLikeValue(String v) => '体感\u00A0$v';

  static String errorTitle(AppException e) => switch (e) {
    NetworkException() => '网络连接不可用',
    ServerException(isRateLimited: true) => '请求过于频繁',
    ServerException() => '天气服务暂不可用',
    DataFormatException() => '天气数据异常',
    UnexpectedException() => '暂时出了点问题',
  };

  static String errorMessage(AppException e) => switch (e) {
    NetworkException() => '请检查网络连接后重试。',
    ServerException(isRateLimited: true) => '免费天气服务繁忙，请稍后重试。',
    ServerException(:final statusCode) => '天气服务返回错误（$statusCode），请稍后重试。',
    DataFormatException() => '暂时无法读取天气数据，请稍后重试。',
    UnexpectedException() => '请重试。',
  };
}
