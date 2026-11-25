import 'package:flutter/material.dart';

import '../../../app/strings.dart';
import '../../../app/theme.dart';
import '../../../domain/forecast.dart';
import '../../../domain/location.dart';
import '../../../ui/formatters.dart';
import '../../../ui/weather_glyph.dart';

/// 首屏“英雄区”：地点、当地时间、大号温度、天气描述、今日高低温。
class CurrentConditions extends StatelessWidget {
  const CurrentConditions({
    super.key,
    required this.location,
    required this.forecast,
    required this.now,
  });

  final Location location;
  final Forecast forecast;

  /// 设备时刻（由注入时钟提供），在组件内换算为地点时间。
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final use24h = MediaQuery.alwaysUse24HourFormatOf(context);
    final current = forecast.current;
    final today = forecast.today(now);
    final localTime = Fmt.time(forecast.localNow(now), use24h: use24h);
    final subtitle = location.subtitle;

    final semantics = [
      location.name,
      '${Fmt.temp(current.temperature)}, ${current.condition.label}',
      if (current.apparentTemperature != null)
        '${S.feelsLike} ${Fmt.temp(current.apparentTemperature)}',
      if (today != null)
        '最高温度 ${Fmt.temp(today.temperatureMax)}，最低温度 ${Fmt.temp(today.temperatureMin)}',
      S.localTime(localTime, forecast.timezoneAbbreviation),
    ].join('. ');

    return Semantics(
      container: true,
      label: semantics,
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.sm,
            AppSpacing.xl,
            AppSpacing.xl,
          ),
          child: Column(
            children: [
              Text(
                location.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.4,
                ),
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15, color: AppColors.textSecondary),
                ),
              ],
              const SizedBox(height: AppSpacing.xs),
              Text(
                S.localTime(localTime, forecast.timezoneAbbreviation),
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textTertiary,
                  fontFeatures: tabularFigures,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    WeatherGlyph(condition: current.condition, isDay: current.isDay, size: 84),
                    const SizedBox(width: AppSpacing.md),
                    Text(
                      Fmt.temp(current.temperature),
                      // 大号温度不随系统字号继续放大，否则会撑破首屏；其余文字正常缩放。
                      textScaler: TextScaler.noScaling,
                      style: const TextStyle(
                        fontFamily: 'InterDisplay',
                        fontSize: 104,
                        fontWeight: FontWeight.w300,
                        height: 1.0,
                        letterSpacing: -4,
                        fontFeatures: tabularFigures,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                current.condition.label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: AppSpacing.xs),
              // Wrap 而非拼接字符串：大字体换行时两组信息各自成行，不会留下孤立的分隔符。
              DefaultTextStyle.merge(
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                  fontFeatures: tabularFigures,
                ),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: AppSpacing.xl,
                  children: [
                    if (current.apparentTemperature != null)
                      Text(S.feelsLikeValue(Fmt.temp(current.apparentTemperature))),
                    if (today != null)
                      Text(
                        S.highLow(Fmt.temp(today.temperatureMax), Fmt.temp(today.temperatureMin)),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
