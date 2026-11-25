import 'package:flutter/widgets.dart';

import 'app/app.dart';
import 'app/dependencies.dart';

/// 启动入口：先组装依赖（含读取上次选择的地点），再挂载根组件。
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final dependencies = await AppDependencies.production();
  runApp(WeatherApp(dependencies: dependencies));
}
