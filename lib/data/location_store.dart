import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/location.dart';

/// 本地持久化：上次选择的地点 + 最近搜索。抽象出来便于测试替换为内存实现。
abstract interface class LocationStore {
  Future<Location?> loadSelected();
  Future<void> saveSelected(Location location);
  Future<List<Location>> loadRecents();

  /// 把 [location] 放到最近列表最前面（去重、限长），返回新的列表。
  Future<List<Location>> addRecent(Location location);
  Future<void> clearRecents();
}

/// 基于 shared_preferences（iOS: NSUserDefaults / Android: DataStore）的实现。
///
/// 所有读写都吞掉异常并降级：本地存储坏了不应该阻止用户查看天气。
class SharedPrefsLocationStore implements LocationStore {
  SharedPrefsLocationStore({SharedPreferencesAsync? prefs, this.maxRecents = 6})
    : _prefs = prefs ?? SharedPreferencesAsync();

  static const _selectedKey = 'selected_location_v1';
  static const _recentsKey = 'recent_locations_v1';

  final SharedPreferencesAsync _prefs;
  final int maxRecents;

  @override
  Future<Location?> loadSelected() async {
    try {
      final raw = await _prefs.getString(_selectedKey);
      return raw == null ? null : Location.tryFromJson(jsonDecode(raw));
    } catch (e) {
      debugPrint('LocationStore.loadSelected failed: $e');
      return null;
    }
  }

  @override
  Future<void> saveSelected(Location location) async {
    try {
      await _prefs.setString(_selectedKey, jsonEncode(location.toJson()));
    } catch (e) {
      debugPrint('LocationStore.saveSelected failed: $e');
    }
  }

  @override
  Future<List<Location>> loadRecents() async {
    try {
      final raw = await _prefs.getString(_recentsKey);
      if (raw == null) return const [];
      final list = jsonDecode(raw);
      if (list is! List) return const [];
      return list.map(Location.tryFromJson).whereType<Location>().toList();
    } catch (e) {
      debugPrint('LocationStore.loadRecents failed: $e');
      return const [];
    }
  }

  @override
  Future<List<Location>> addRecent(Location location) async {
    final updated = mergeRecent(await loadRecents(), location, maxRecents);
    try {
      await _prefs.setString(_recentsKey, jsonEncode([for (final l in updated) l.toJson()]));
    } catch (e) {
      debugPrint('LocationStore.addRecent failed: $e');
    }
    return updated;
  }

  @override
  Future<void> clearRecents() async {
    try {
      await _prefs.remove(_recentsKey);
    } catch (e) {
      debugPrint('LocationStore.clearRecents failed: $e');
    }
  }
}

/// 纯函数：新地点置顶、按 id 去重、截断到 [max]。
List<Location> mergeRecent(List<Location> current, Location added, int max) =>
    [added, ...current.where((l) => l != added)].take(max).toList(growable: false);
