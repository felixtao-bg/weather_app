import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/strings.dart';
import '../../../app/theme.dart';
import '../../../domain/forecast.dart';
import '../../../ui/common_widgets.dart';
import '../../../ui/formatters.dart';
import '../../../ui/weather_glyph.dart';

/// 7 日预报。温度条按“整周最低~最高”归一化，一眼看出哪天冷/热。
class DailyForecastCard extends StatelessWidget {
  const DailyForecastCard({
    super.key,
    required this.days,
    required this.localToday,
    this.currentTemperature,
  });

  final List<DailyForecast> days;

  /// 地点当地今天的日期，用于标注 “Today”。
  final DateTime localToday;

  /// 在“今天”的温度条上标出当前温度的位置。
  final double? currentTemperature;

  @override
  Widget build(BuildContext context) {
    final temps = [
      for (final d in days) ...[?d.temperatureMin, ?d.temperatureMax],
    ];
    final weekMin = temps.isEmpty ? 0.0 : temps.reduce(math.min);
    final weekMax = temps.isEmpty ? 0.0 : temps.reduce(math.max);

    return GlassCard(
      title: S.sevenDay,
      icon: Icons.calendar_today_rounded,
      child: days.isEmpty
          ? const Text(S.noForecastData, style: TextStyle(color: AppColors.textSecondary))
          : Column(
              children: [
                for (var i = 0; i < days.length; i++) ...[
                  if (i > 0) const Divider(height: 1, color: AppColors.divider),
                  _DayRow(
                    day: days[i],
                    isToday: _sameDay(days[i].date, localToday),
                    weekMin: weekMin,
                    weekMax: weekMax,
                    currentTemperature: _sameDay(days[i].date, localToday)
                        ? currentTemperature
                        : null,
                  ),
                ],
              ],
            ),
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.day,
    required this.isToday,
    required this.weekMin,
    required this.weekMax,
    this.currentTemperature,
  });

  final DailyForecast day;
  final bool isToday;
  final double weekMin;
  final double weekMax;
  final double? currentTemperature;

  @override
  Widget build(BuildContext context) {
    final label = isToday ? S.today : Fmt.weekday(day.date);
    final pop = day.precipitationProbabilityMax;
    final showPop = pop != null && pop >= 20;
    const tempStyle = TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      fontFeatures: tabularFigures,
    );
    final scaler = MediaQuery.textScalerOf(context);
    // 系统大字体（>1.3x）时单行放不下“星期+图标+两端温度+温度条”，改为两行布局，
    // 而不是让数值在固定宽度里折行成 "−5 / °"。
    final stacked = scaler.scale(16) > 16 * 1.3;
    final tempWidth = scaler.scaleBox(40, fontSize: 16);

    final dayLabel = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: 16, fontWeight: isToday ? FontWeight.w600 : FontWeight.w500),
    );
    final popLabel = Text(
      showPop ? '$pop%' : '',
      maxLines: 1,
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.rain),
    );
    final glyph = WeatherGlyph(condition: day.condition, isDay: true, size: 26);
    final minText = SizedBox(
      width: tempWidth,
      child: Text(
        Fmt.temp(day.temperatureMin),
        maxLines: 1,
        textAlign: TextAlign.right,
        style: tempStyle.copyWith(color: AppColors.textTertiary),
      ),
    );
    final maxText = SizedBox(
      width: tempWidth,
      child: Text(
        Fmt.temp(day.temperatureMax),
        maxLines: 1,
        textAlign: TextAlign.right,
        style: tempStyle,
      ),
    );
    final bar = Expanded(
      child: TemperatureRangeBar(
        min: day.temperatureMin,
        max: day.temperatureMax,
        scaleMin: weekMin,
        scaleMax: weekMax,
        marker: currentTemperature,
      ),
    );

    final Widget content = stacked
        ? Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: dayLabel),
                    if (showPop) ...[popLabel, const SizedBox(width: AppSpacing.sm)],
                    glyph,
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    minText,
                    const SizedBox(width: AppSpacing.md),
                    bar,
                    const SizedBox(width: AppSpacing.md),
                    maxText,
                  ],
                ),
              ],
            ),
          )
        : Row(
            children: [
              SizedBox(width: scaler.scaleBox(64, fontSize: 16), child: dayLabel),
              SizedBox(
                width: 44,
                child: Column(mainAxisSize: MainAxisSize.min, children: [glyph, popLabel]),
              ),
              const SizedBox(width: AppSpacing.sm),
              minText,
              const SizedBox(width: AppSpacing.md),
              bar,
              const SizedBox(width: AppSpacing.md),
              maxText,
            ],
          );

    return Semantics(
      label: [
        isToday ? S.today : Fmt.fullWeekday(day.date),
        day.condition.label,
        '最高温度 ${Fmt.temp(day.temperatureMax)}',
        '最低温度 ${Fmt.temp(day.temperatureMin)}',
        if (showPop) '降水概率 $pop%',
      ].join(', '),
      excludeSemantics: true,
      child: ConstrainedBox(constraints: const BoxConstraints(minHeight: 52), child: content),
    );
  }
}

/// 温度区间条：灰色轨道 + 按温度着色的区间段 + 可选的“当前温度”圆点。
class TemperatureRangeBar extends StatelessWidget {
  const TemperatureRangeBar({
    super.key,
    required this.min,
    required this.max,
    required this.scaleMin,
    required this.scaleMax,
    this.marker,
  });

  final double? min;
  final double? max;
  final double scaleMin;
  final double scaleMax;
  final double? marker;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        height: 8,
        child: CustomPaint(
          painter: _RangePainter(
            min: min,
            max: max,
            scaleMin: scaleMin,
            scaleMax: scaleMax,
            marker: marker,
          ),
        ),
      ),
    );
  }
}

class _RangePainter extends CustomPainter {
  _RangePainter({
    required this.min,
    required this.max,
    required this.scaleMin,
    required this.scaleMax,
    required this.marker,
  });

  final double? min;
  final double? max;
  final double scaleMin;
  final double scaleMax;
  final double? marker;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = Radius.circular(size.height / 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, radius),
      Paint()..color = const Color(0x26FFFFFF),
    );
    final lo = min;
    final hi = max;
    if (lo == null || hi == null) return;

    final span = math.max(scaleMax - scaleMin, 1.0);
    double x(double t) => ((t - scaleMin) / span).clamp(0.0, 1.0) * size.width;

    // 最短保证一个圆点宽度，min==max 时也看得见。
    var left = x(lo);
    var right = math.max(x(hi), left + size.height);
    if (right > size.width) {
      left = math.max(0, size.width - (right - left));
      right = size.width;
    }
    final rect = Rect.fromLTRB(left, 0, right, size.height);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, radius),
      Paint()..shader = LinearGradient(colors: [_colorFor(lo), _colorFor(hi)]).createShader(rect),
    );

    final m = marker;
    if (m != null) {
      final cx = x(m).clamp(size.height / 2, size.width - size.height / 2);
      final center = Offset(cx, size.height / 2);
      canvas.drawCircle(center, size.height / 2 + 1.5, Paint()..color = const Color(0x66000000));
      canvas.drawCircle(center, size.height / 2 - 0.5, Paint()..color = Colors.white);
    }
  }

  /// 冷 → 热：蓝 → 青 → 黄 → 橙 → 红。
  static Color _colorFor(double celsius) {
    const stops = <(double, Color)>[
      (-10, Color(0xFF7AA7FF)),
      (5, Color(0xFF6FD3E8)),
      (15, Color(0xFFB6E27A)),
      (24, Color(0xFFFFD15C)),
      (32, Color(0xFFFF9248)),
      (40, Color(0xFFFF5A4E)),
    ];
    if (celsius <= stops.first.$1) return stops.first.$2;
    for (var i = 1; i < stops.length; i++) {
      final (t1, c1) = stops[i];
      if (celsius <= t1) {
        final (t0, c0) = stops[i - 1];
        return Color.lerp(c0, c1, (celsius - t0) / (t1 - t0))!;
      }
    }
    return stops.last.$2;
  }

  @override
  bool shouldRepaint(_RangePainter old) =>
      old.min != min ||
      old.max != max ||
      old.scaleMin != scaleMin ||
      old.scaleMax != scaleMax ||
      old.marker != marker;
}
