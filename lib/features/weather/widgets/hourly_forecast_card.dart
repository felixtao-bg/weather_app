import 'package:flutter/material.dart';

import '../../../app/strings.dart';
import '../../../app/theme.dart';
import '../../../domain/forecast.dart';
import '../../../ui/common_widgets.dart';
import '../../../ui/formatters.dart';
import '../../../ui/weather_glyph.dart';

/// 未来 24 小时横向列表。降水概率 ≥ 20% 才显示，避免满屏 “0%” 噪音。
class HourlyForecastCard extends StatelessWidget {
  const HourlyForecastCard({super.key, required this.hours});

  final List<HourlyForecast> hours;

  static const _itemWidth = 58.0;

  @override
  Widget build(BuildContext context) {
    final use24h = MediaQuery.alwaysUse24HourFormatOf(context);
    // 列宽随系统字号等比放大，"10 AM" 这类标签在 2x 字号下也不会挤在一起。
    final itemWidth = MediaQuery.textScalerOf(context).scaleBox(_itemWidth, fontSize: 13);

    return GlassCard(
      title: S.next24Hours,
      icon: Icons.schedule_rounded,
      padding: const EdgeInsets.fromLTRB(0, AppSpacing.lg, 0, AppSpacing.lg),
      // 卡片左右内边距为 0 是为了让小时列可贴边滚动；标题单独补回与其他卡片相同的左边距。
      titlePadding: const EdgeInsets.only(left: AppSpacing.lg),
      child: hours.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Text(S.noForecastData, style: TextStyle(color: AppColors.textSecondary)),
            )
          // 只有 24 项，用 Row 而非 ListView.builder：高度由内容决定，
          // 任意系统字号下都不会被固定高度裁切；24 个轻量 widget 的构建成本可忽略。
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < hours.length; i++)
                    SizedBox(
                      width: itemWidth,
                      child: _HourItem(hour: hours[i], isNow: i == 0, use24h: use24h),
                    ),
                ],
              ),
            ),
    );
  }
}

class _HourItem extends StatelessWidget {
  const _HourItem({required this.hour, required this.isNow, required this.use24h});

  final HourlyForecast hour;
  final bool isNow;
  final bool use24h;

  @override
  Widget build(BuildContext context) {
    final pop = hour.precipitationProbability;
    final showPop = pop != null && pop >= 20;
    return Semantics(
      label: [
        isNow ? S.now : Fmt.time(hour.time, use24h: use24h),
        Fmt.temp(hour.temperature),
        hour.condition.label,
        if (showPop) '降水概率 $pop%',
      ].join(', '),
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isNow ? S.now : Fmt.hour(hour.time, use24h: use24h),
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.fade,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isNow ? FontWeight.w600 : FontWeight.w500,
              color: isNow ? AppColors.textPrimary : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          WeatherGlyph(condition: hour.condition, isDay: hour.isDay, size: 28),
          const SizedBox(height: 2),
          // 无降水概率时也占位，保证各列温度对齐。
          Text(
            showPop ? '$pop%' : ' ',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.rain,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            Fmt.temp(hour.temperature),
            maxLines: 1,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w500,
              fontFeatures: tabularFigures,
            ),
          ),
        ],
      ),
    );
  }
}
