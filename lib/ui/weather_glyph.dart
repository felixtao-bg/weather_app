import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../domain/weather_condition.dart';

/// 天气图标：用 Material Icons 组合出“太阳+云”“云+雨滴”等复合图形。
///
/// 不引入图片/Lottie 资源：矢量字体在任意尺寸清晰、双端一致、零额外体积。
/// 纯装饰，语义信息由外层的 Semantics 提供。
class WeatherGlyph extends StatelessWidget {
  const WeatherGlyph({super.key, required this.condition, required this.isDay, this.size = 28});

  final WeatherCondition condition;
  final bool isDay;
  final double size;

  @override
  Widget build(BuildContext context) {
    final celestial = isDay
        ? const _Part(Icons.wb_sunny_rounded, AppColors.sun)
        : const _Part(Icons.nightlight_round, AppColors.moon);

    final parts = switch (condition.kind) {
      WeatherKind.clear => [_Placed(celestial, 0.92, Alignment.center)],
      WeatherKind.partlyCloudy => [
        _Placed(celestial, 0.62, const Alignment(0.75, -0.8)),
        const _Placed(_Part(Icons.cloud, AppColors.cloud), 0.82, Alignment(-0.3, 0.5)),
      ],
      WeatherKind.cloudy => const [
        _Placed(_Part(Icons.cloud, Color(0x99E3E9F2)), 0.62, Alignment(0.8, -0.7)),
        _Placed(_Part(Icons.cloud, AppColors.cloud), 0.86, Alignment(-0.2, 0.4)),
      ],
      WeatherKind.fog => const [
        _Placed(_Part(Icons.foggy, AppColors.cloud), 0.9, Alignment.center),
      ],
      WeatherKind.rain => const [
        _Placed(_Part(Icons.cloud, AppColors.cloud), 0.8, Alignment(0, -0.6)),
        _Placed(_Part(Icons.water_drop, AppColors.rain), 0.3, Alignment(-0.45, 0.85)),
        _Placed(_Part(Icons.water_drop, AppColors.rain), 0.3, Alignment(0.35, 0.95)),
      ],
      WeatherKind.snow => const [
        _Placed(_Part(Icons.ac_unit, AppColors.snow), 0.84, Alignment.center),
      ],
      WeatherKind.storm => const [
        _Placed(_Part(Icons.thunderstorm, AppColors.storm), 0.92, Alignment.center),
      ],
      WeatherKind.unknown => const [
        _Placed(_Part(Icons.cloud_queue, AppColors.textTertiary), 0.84, Alignment.center),
      ],
    };

    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          children: [
            for (final p in parts)
              Align(
                alignment: p.alignment,
                child: Icon(p.part.icon, size: size * p.scale, color: p.part.color),
              ),
          ],
        ),
      ),
    );
  }
}

class _Part {
  const _Part(this.icon, this.color);
  final IconData icon;
  final Color color;
}

class _Placed {
  const _Placed(this.part, this.scale, this.alignment);
  final _Part part;
  final double scale;
  final Alignment alignment;
}
