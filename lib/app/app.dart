import 'package:flutter/material.dart';

import '../features/weather/weather_controller.dart';
import '../features/weather/weather_screen.dart';
import 'dependencies.dart';
import 'chinese_localizations.dart';
import 'strings.dart';
import 'theme.dart';

/// 根组件：持有全局唯一的 [WeatherController]（与 App 同生命周期）。
class WeatherApp extends StatefulWidget {
  const WeatherApp({super.key, required this.dependencies});

  final AppDependencies dependencies;

  @override
  State<WeatherApp> createState() => _WeatherAppState();
}

class _WeatherAppState extends State<WeatherApp> {
  late final WeatherController _weather = WeatherController(
    repository: widget.dependencies.weatherRepository,
    store: widget.dependencies.locationStore,
    initialLocation: widget.dependencies.initialLocation,
  )..start();

  @override
  void dispose() {
    _weather.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      dependencies: widget.dependencies,
      child: MaterialApp(
        title: S.appTitle,
        locale: const Locale('zh', 'CN'),
        supportedLocales: const [Locale('zh', 'CN')],
        localizationsDelegates: chineseDelegates,
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        // 支持系统大字体，但上限 2.0，避免极端字号让固定高度的横向列表失去意义。
        builder: (context, child) =>
            MediaQuery.withClampedTextScaling(maxScaleFactor: 2.0, child: child!),
        home: WeatherScreen(controller: _weather),
      ),
    );
  }
}
