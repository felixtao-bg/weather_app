import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/app_exception.dart';
import '../../data/location_store.dart';
import '../../domain/location.dart';
import '../../domain/services.dart';

enum SearchStatus {
  /// 输入为空或过短：展示最近搜索 / 提示。
  idle,
  loading,
  results,
  empty,
  error,
}

@immutable
class SearchState {
  const SearchState({
    this.query = '',
    this.status = SearchStatus.idle,
    this.results = const [],
    this.recents = const [],
    this.error,
  });

  /// 已 trim 的查询词。
  final String query;
  final SearchStatus status;

  /// loading 期间保留上一批结果，避免列表在每次按键时闪烁清空。
  final List<Location> results;
  final List<Location> recents;
  final AppException? error;

  SearchState copyWith({
    String? query,
    SearchStatus? status,
    List<Location>? results,
    List<Location>? recents,
    AppException? Function()? error,
  }) => SearchState(
    query: query ?? this.query,
    status: status ?? this.status,
    results: results ?? this.results,
    recents: recents ?? this.recents,
    error: error != null ? error() : this.error,
  );
}

/// 地点搜索：防抖、最短长度、竞态丢弃、重试、最近搜索。
///
/// 生命周期跟随搜索页（页面 dispose 时一并 dispose，取消定时器、丢弃在途响应）。
/// 命名避开 Material 自带的 `SearchController`。
class LocationSearchController extends ChangeNotifier {
  /// Dart 3.11 不支持私有命名的初始化形参（`required this._x` 需 3.12+），因此用初始化列表赋值。
  LocationSearchController({
    required GeocodingService geocoding,
    required LocationStore store,
    this.debounce = const Duration(milliseconds: 350),
    this.minQueryLength = 2,
    this.languageCode = 'zh',
  }) : _geocoding = geocoding,
       _store = store {
    _loadRecents();
  }

  final GeocodingService _geocoding;
  final LocationStore _store;
  final Duration debounce;

  /// Open-Meteo：1 个字符必然无结果，2 个字符只做精确匹配（对“北京”“NY”这类够用）。
  final int minQueryLength;
  final String languageCode;

  SearchState _state = const SearchState();
  SearchState get state => _state;

  Timer? _debounceTimer;
  int _generation = 0;
  bool _disposed = false;

  void onQueryChanged(String raw) {
    final query = raw.trim();
    // 只改了首尾空格等情况不重复请求。
    if (query == _state.query && _state.status != SearchStatus.error) return;

    _debounceTimer?.cancel();
    // 任何输入变化都使在途请求作废。
    final generation = ++_generation;

    if (query.length < minQueryLength) {
      _set(
        _state.copyWith(
          query: query,
          status: SearchStatus.idle,
          results: const [],
          error: () => null,
        ),
      );
      return;
    }

    _set(_state.copyWith(query: query, status: SearchStatus.loading, error: () => null));
    _debounceTimer = Timer(debounce, () => _search(query, generation));
  }

  /// 键盘“搜索”键：跳过防抖立即查询。
  void submit() {
    if (_state.query.length < minQueryLength) return;
    _debounceTimer?.cancel();
    _set(_state.copyWith(status: SearchStatus.loading, error: () => null));
    _search(_state.query, ++_generation);
  }

  void retry() => submit();

  Future<void> clearRecents() async {
    _set(_state.copyWith(recents: const []));
    await _store.clearRecents();
  }

  Future<void> _search(String query, int generation) async {
    try {
      final results = await _geocoding.search(query, languageCode: languageCode);
      if (!_isCurrent(generation)) return;
      _set(
        _state.copyWith(
          results: results,
          status: results.isEmpty ? SearchStatus.empty : SearchStatus.results,
        ),
      );
    } on AppException catch (e) {
      if (!_isCurrent(generation)) return;
      _set(_state.copyWith(status: SearchStatus.error, results: const [], error: () => e));
    } catch (e, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: e, stack: stack, library: 'location_search'),
      );
      if (!_isCurrent(generation)) return;
      _set(
        _state.copyWith(
          status: SearchStatus.error,
          results: const [],
          error: () => UnexpectedException(e.toString()),
        ),
      );
    }
  }

  Future<void> _loadRecents() async {
    final recents = await _store.loadRecents();
    if (_disposed) return;
    _set(_state.copyWith(recents: recents));
  }

  bool _isCurrent(int generation) => !_disposed && generation == _generation;

  void _set(SearchState next) {
    if (_disposed) return;
    _state = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _debounceTimer?.cancel();
    super.dispose();
  }
}
