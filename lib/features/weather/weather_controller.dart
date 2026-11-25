import 'package:flutter/foundation.dart';

import '../../core/app_exception.dart';
import '../../data/location_store.dart';
import '../../data/weather_repository.dart';
import '../../domain/location.dart';

/// 首页的不可变状态。
///
/// 没有用“Loading / Data / Error 三选一”的 sealed union，因为真实场景里它们会叠加：
/// 刷新中仍要显示旧数据（data + loading），刷新失败也要保留旧数据（data + error）。
@immutable
class WeatherState {
  const WeatherState({this.location, this.snapshot, this.isLoading = false, this.error});

  /// 当前选中的地点；null 表示首次启动、尚未选择。
  final Location? location;

  /// 最近一次成功的数据；切换地点时会先清空（或用缓存填充）。
  final ForecastSnapshot? snapshot;
  final bool isLoading;

  /// 最近一次请求的错误；有 [snapshot] 时 UI 以横幅形式提示，没有时整页错误。
  final AppException? error;

  bool get hasData => snapshot != null;

  WeatherState copyWith({
    Location? location,
    ForecastSnapshot? Function()? snapshot,
    bool? isLoading,
    AppException? Function()? error,
  }) => WeatherState(
    location: location ?? this.location,
    snapshot: snapshot != null ? snapshot() : this.snapshot,
    isLoading: isLoading ?? this.isLoading,
    error: error != null ? error() : this.error,
  );
}

/// 首页业务逻辑：选择地点、加载/刷新天气、回到前台时按需刷新。
///
/// 相当于 iOS 里的 ObservableObject / ViewModel；View 通过 [ListenableBuilder] 订阅。
class WeatherController extends ChangeNotifier {
  WeatherController({
    required WeatherRepository repository,
    required LocationStore store,
    Location? initialLocation,
  }) : _repository = repository,
       _store = store,
       _state = WeatherState(location: initialLocation);

  final WeatherRepository _repository;
  final LocationStore _store;

  WeatherState _state;
  WeatherState get state => _state;

  /// 每发起一次请求自增。响应返回时若编号已变，说明用户已切换地点，直接丢弃，
  /// 避免“慢请求覆盖快请求”的竞态（先选 A 再选 B，A 晚到却显示了 A）。
  int _generation = 0;
  bool _disposed = false;

  /// 启动后调用：若有上次选择的地点则立即加载。
  Future<void> start() async {
    if (_state.location != null) await _load();
  }

  Future<void> selectLocation(Location location) async {
    final isSame = location == _state.location;
    // 切到别的地点时，先用缓存（若有）填充，避免闪白；没有则显示骨架屏。
    final cached = isSame ? _state.snapshot : _repository.peek(location);
    _set(_state.copyWith(location: location, snapshot: () => cached, error: () => null));
    // 持久化失败不影响主流程（store 内部已吞掉异常）。
    _store.saveSelected(location).ignore();
    _store.addRecent(location).ignore();
    await _load();
  }

  /// 下拉刷新 / 重试：跳过缓存。返回的 Future 供 RefreshIndicator 控制转圈时长。
  Future<void> refresh() => _load(forceRefresh: true);

  /// App 回到前台：数据过期才刷新，避免每次切后台都打接口。
  Future<void> onAppResumed() async {
    final snapshot = _state.snapshot;
    if (_state.location == null || _state.isLoading) return;
    if (snapshot != null && _repository.isFresh(snapshot)) return;
    await _load(forceRefresh: true);
  }

  Future<void> _load({bool forceRefresh = false}) async {
    final location = _state.location;
    if (location == null) return;
    final generation = ++_generation;
    _set(_state.copyWith(isLoading: true, error: () => null));

    try {
      final snapshot = await _repository.getForecast(location, forceRefresh: forceRefresh);
      if (!_isCurrent(generation)) return;
      _set(WeatherState(location: location, snapshot: snapshot));
    } on AppException catch (e) {
      if (!_isCurrent(generation)) return;
      _set(_state.copyWith(isLoading: false, error: () => e));
    } catch (e, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: e, stack: stack, library: 'weather_controller'),
      );
      if (!_isCurrent(generation)) return;
      _set(_state.copyWith(isLoading: false, error: () => UnexpectedException(e.toString())));
    }
  }

  bool _isCurrent(int generation) => !_disposed && generation == _generation;

  void _set(WeatherState next) {
    if (_disposed) return;
    _state = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
