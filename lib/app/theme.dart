import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

import '../domain/weather_condition.dart';

/// 设计令牌：间距、圆角、颜色层级集中定义，组件里不写魔法数。
abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;

  /// 内容最大宽度：平板/横屏时居中，避免一行拉得过长。
  static const maxContentWidth = 640.0;

  /// 最小触摸目标（Material 48dp；iOS HIG 44pt，取较大者）。
  static const minTouchTarget = 48.0;
}

abstract final class AppRadius {
  static const card = 22.0;
  static const chip = 14.0;
}

/// 深色基调上的文字层级（白色不同透明度），在所有天空渐变上都保证可读。
abstract final class AppColors {
  static const background = Color(0xFF0C1322);
  static const surface = Color(0xFF151E31);
  static const textPrimary = Colors.white;
  static const textSecondary = Color(0xC7FFFFFF); // 78%
  static const textTertiary = Color(0x99FFFFFF); // 60%
  static const divider = Color(0x1FFFFFFF);

  /// 叠在渐变上的卡片：用“压暗”而不是“提亮”，保证白字对比度 ≥ 4.5:1。
  static const cardFill = Color(0x29000000);
  static const cardBorder = Color(0x1AFFFFFF);
  static const accent = Color(0xFF9CCBFF);
  static const sun = Color(0xFFFFCF5C);
  static const moon = Color(0xFFE4E8F7);
  static const cloud = Color(0xFFE3E9F2);
  static const rain = Color(0xFF8CC8FF);
  static const snow = Color(0xFFF2F7FF);
  static const storm = Color(0xFFFFD36B);
  static const error = Color(0xFFFFB4A9);
}

/// 根据天气与昼夜决定背景渐变（上 → 下）。
List<Color> skyGradient(WeatherKind kind, {required bool isDay}) {
  return switch ((kind, isDay)) {
    (WeatherKind.clear, true) => const [Color(0xFF1A4C8F), Color(0xFF3D7FCC)],
    (WeatherKind.clear, false) => const [Color(0xFF070B1F), Color(0xFF1C2754)],
    (WeatherKind.partlyCloudy, true) => const [Color(0xFF285487), Color(0xFF5784B4)],
    (WeatherKind.partlyCloudy, false) => const [Color(0xFF0D1329), Color(0xFF283456)],
    (WeatherKind.cloudy, true) => const [Color(0xFF3A4A60), Color(0xFF64768E)],
    (WeatherKind.cloudy, false) => const [Color(0xFF131A26), Color(0xFF2B3546)],
    (WeatherKind.fog, true) => const [Color(0xFF414A57), Color(0xFF6C7683)],
    (WeatherKind.fog, false) => const [Color(0xFF161B23), Color(0xFF353D49)],
    (WeatherKind.rain, true) => const [Color(0xFF223147), Color(0xFF48607F)],
    (WeatherKind.rain, false) => const [Color(0xFF0D1522), Color(0xFF233146)],
    (WeatherKind.snow, true) => const [Color(0xFF395676), Color(0xFF6787A8)],
    (WeatherKind.snow, false) => const [Color(0xFF141E30), Color(0xFF34465F)],
    (WeatherKind.storm, _) => const [Color(0xFF17112B), Color(0xFF3A2C5C)],
    (WeatherKind.unknown, _) => const [Color(0xFF151E31), Color(0xFF2A3854)],
  };
}

/// 没有天气数据时（空状态/加载/错误）使用的中性背景。
const neutralSky = [Color(0xFF101A30), Color(0xFF233355)];

ThemeData buildAppTheme() {
  const scheme = ColorScheme.dark(
    primary: AppColors.accent,
    onPrimary: Color(0xFF0A1A30),
    surface: AppColors.surface,
    onSurface: AppColors.textPrimary,
    onSurfaceVariant: AppColors.textSecondary,
    error: AppColors.error,
    outline: AppColors.divider,
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    fontFamily: 'Inter',
    scaffoldBackgroundColor: AppColors.background,
    splashFactory: InkSparkle.splashFactory,
  );

  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    ),
    // 视觉统一、行为保持平台原生：iOS 侧滑返回；Android 预测性返回动画。
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
      },
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.light,
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Color(0xFF26324A),
      contentTextStyle: TextStyle(fontFamily: 'Inter', color: Colors.white),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.accent,
      linearTrackColor: Colors.transparent,
    ),
  );
}

extension BoxScaling on TextScaler {
  /// 按“框内文字字号”的实际放大倍数缩放一个盒子尺寸。
  ///
  /// Android 14+ 的系统字号是**非线性**的：2x 设置下 13sp 文字约放大 2 倍，
  /// 但 `scale(58)` 只放大约 1.3 倍。若直接 `scale(盒宽)`，盒子会比文字涨得慢，导致挤压截断。
  double scaleBox(double base, {required double fontSize}) => base * scale(fontSize) / fontSize;
}

/// 大号温度等展示性数字：等宽数字防止刷新时数字宽度跳动。
const tabularFigures = [FontFeature.tabularFigures()];
