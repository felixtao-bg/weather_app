/// 纯格式化函数，UI 与测试共用。缺失值统一显示 em dash，而不是 0 或 "null"。
abstract final class Fmt {
  static const missing = '—';

  /// 7.4 → "7°"；-0.4 → "0°"（int 没有负零）；负数用排版减号 U+2212 而非连字符。
  static String temp(double? celsius) {
    if (celsius == null) return missing;
    final v = celsius.round();
    return v < 0 ? '\u2212${-v}°' : '$v°';
  }

  /// “更新于”用相对时间：避免与“地点当地时间”并列时让人分不清是哪个时区。
  static String ago(DateTime then, DateTime now) {
    final minutes = now.difference(then).inMinutes;
    if (minutes < 1) return '刚刚';
    if (minutes < 60) return '$minutes分钟前';
    final hours = minutes ~/ 60;
    return '$hours小时前';
  }

  static String percent(int? value) => value == null ? missing : '$value%';

  static String windSpeed(double? kmh) => kmh == null ? missing : '${kmh.round()} 公里/小时';

  static String precipitation(double? mm) {
    if (mm == null) return missing;
    return '${mm == 0 ? '0' : mm.toStringAsFixed(1)} 毫米';
  }

  static String uv(double? index) {
    if (index == null) return missing;
    final v = index.round();
    final level = switch (v) {
      <= 2 => '低',
      <= 5 => '中等',
      <= 7 => '高',
      <= 10 => '很高',
      _ => '极高',
    };
    return '$v · $level';
  }

  /// 风向：气象上表示“从哪来”，0° = 北风。
  static String compass(int? degrees) {
    if (degrees == null) return '';
    const points = ['北', '东北', '东', '东南', '南', '西南', '西', '西北'];
    return points[((degrees % 360) / 45).round() % 8];
  }

  /// 中文墙上时间：不做设备时区转换，也不依赖全局 intl locale 或系统语言。
  static String time(DateTime? wallTime, {required bool use24h}) {
    if (wallTime == null) return missing;
    final minute = wallTime.minute.toString().padLeft(2, '0');
    if (use24h) return '${wallTime.hour.toString().padLeft(2, '0')}:$minute';
    final period = wallTime.hour < 12 ? '上午' : '下午';
    final hour = wallTime.hour % 12 == 0 ? 12 : wallTime.hour % 12;
    return '$period$hour:$minute';
  }

  static String hour(DateTime wallTime, {required bool use24h}) {
    if (use24h) return '${wallTime.hour}时';
    final period = wallTime.hour < 12 ? '上午' : '下午';
    final hour = wallTime.hour % 12 == 0 ? 12 : wallTime.hour % 12;
    return '$period$hour时';
  }

  static const _weekdays = ['一', '二', '三', '四', '五', '六', '日'];
  static String weekday(DateTime wallDate) => '周${_weekdays[wallDate.weekday - 1]}';
  static String fullWeekday(DateTime wallDate) => '星期${_weekdays[wallDate.weekday - 1]}';
}
