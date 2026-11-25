import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/strings.dart';
import '../../../app/theme.dart';
import '../../../domain/forecast.dart';
import '../../../ui/formatters.dart';

/// 体感、湿度、风、降水、UV、日出日落等细节，窄屏两列、宽屏三列。
class DetailsGrid extends StatelessWidget {
  const DetailsGrid({super.key, required this.current, required this.today});

  final CurrentWeather current;
  final DailyForecast? today;

  @override
  Widget build(BuildContext context) {
    final use24h = MediaQuery.alwaysUse24HourFormatOf(context);
    final windDir = Fmt.compass(current.windDirection);
    final tiles = [
      _Tile(
        icon: Icons.thermostat_rounded,
        label: S.feelsLike,
        value: Fmt.temp(current.apparentTemperature),
      ),
      _Tile(
        icon: Icons.water_drop_outlined,
        label: S.humidity,
        value: Fmt.percent(current.relativeHumidity),
      ),
      _Tile(
        icon: Icons.air_rounded,
        label: S.wind,
        value: Fmt.windSpeed(current.windSpeed),
        caption: windDir.isEmpty ? null : '风向：$windDir',
        trailing: current.windDirection == null
            ? null
            : _WindArrow(fromDegrees: current.windDirection!),
      ),
      _Tile(
        icon: Icons.umbrella_outlined,
        label: S.precipitation,
        value: Fmt.precipitation(current.precipitation),
        caption: today?.precipitationProbabilityMax == null
            ? null
            : '今日降水概率 ${today!.precipitationProbabilityMax}%',
      ),
      _Tile(
        icon: Icons.wb_sunny_outlined,
        label: S.uvIndex,
        value: Fmt.uv(today?.uvIndexMax),
        caption: today?.uvIndexMax == null ? null : '今日最高值',
      ),
      _Tile(
        icon: Icons.wb_twilight_rounded,
        label: '${S.sunrise} / ${S.sunset}',
        value: Fmt.time(today?.sunrise, use24h: use24h),
        caption: '${S.sunset} ${Fmt.time(today?.sunset, use24h: use24h)}',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 520 ? 3 : 2;
        const gap = AppSpacing.md;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [for (final t in tiles) SizedBox(width: width, child: t)],
        );
      },
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.label,
    required this.value,
    this.caption,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? caption;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: [label, value, ?caption].join(', '),
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: 104),
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.cardFill,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: AppColors.textTertiary),
                const SizedBox(width: AppSpacing.xs + 2),
                Expanded(
                  child: Text(
                    label.toUpperCase(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.6,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w500,
                      fontFeatures: tabularFigures,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
            if (caption != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(caption!, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            ],
          ],
        ),
      ),
    );
  }
}

/// 箭头指向风的**去向**（来向 + 180°），与常见天气 App 的直觉一致。
class _WindArrow extends StatelessWidget {
  const _WindArrow({required this.fromDegrees});

  final int fromDegrees;

  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: (fromDegrees + 180) * math.pi / 180,
    child: const Icon(Icons.navigation_rounded, size: 20, color: AppColors.accent),
  );
}
