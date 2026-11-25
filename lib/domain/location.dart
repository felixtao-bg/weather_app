import 'package:flutter/foundation.dart';

/// 一个可查询天气的地点（来自地理编码结果或内置推荐城市）。
@immutable
class Location {
  const Location({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.region,
    this.subregion,
    this.country,
    this.countryCode,
    this.timezone,
  });

  /// 地理编码服务的稳定 ID（GeoNames id），用作相等性与缓存键。
  final String id;
  final String name;
  final double latitude;
  final double longitude;

  /// 一级行政区（省/州），例如 "Missouri"。
  final String? region;

  /// 二级行政区（市/县），仅在同名地点需要进一步区分时展示。
  final String? subregion;
  final String? country;

  /// ISO-3166 alpha-2，例如 "US"，用于生成国旗 emoji。
  final String? countryCode;

  /// IANA 时区名，例如 "Asia/Shanghai"。天气接口也会返回时区，这里仅作展示补充。
  final String? timezone;

  /// "Missouri, United States" 这样的副标题；缺失字段会被跳过。
  String get subtitle => _joinNonEmpty([region, country]);

  /// 国旗 emoji：把两位国家码映射到 Regional Indicator Symbol。
  String? get flagEmoji {
    final code = countryCode?.toUpperCase();
    if (code == null || code.length != 2) return null;
    final units = code.codeUnits;
    if (units.any((u) => u < 0x41 || u > 0x5A)) return null;
    return String.fromCharCodes(units.map((u) => 0x1F1E6 + (u - 0x41)));
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'latitude': latitude,
    'longitude': longitude,
    'region': region,
    'subregion': subregion,
    'country': country,
    'countryCode': countryCode,
    'timezone': timezone,
  };

  /// 从本地持久化恢复。数据损坏时返回 null，而不是让启动流程崩溃。
  static Location? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final name = json['name'];
    final lat = json['latitude'];
    final lon = json['longitude'];
    if (id is! String || name is! String || lat is! num || lon is! num) {
      return null;
    }
    return Location(
      id: id,
      name: name,
      latitude: lat.toDouble(),
      longitude: lon.toDouble(),
      region: json['region'] as String?,
      subregion: json['subregion'] as String?,
      country: json['country'] as String?,
      countryCode: json['countryCode'] as String?,
      timezone: json['timezone'] as String?,
    );
  }

  @override
  bool operator ==(Object other) => other is Location && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Location($id, $name, $subtitle)';
}

/// 为搜索结果生成可区分的副标题。
///
/// 默认是“省/州, 国家”；若多条结果的名称+副标题完全相同（如美国多个同州同名小镇），
/// 再补上二级行政区，仍相同则补坐标，保证用户能区分并选对地点。
List<String> disambiguatedSubtitles(List<Location> locations) {
  String keyOf(Location l, String subtitle) => '${l.name}|$subtitle';

  final base = [for (final l in locations) l.subtitle];
  final baseCounts = <String, int>{};
  for (var i = 0; i < locations.length; i++) {
    final k = keyOf(locations[i], base[i]);
    baseCounts[k] = (baseCounts[k] ?? 0) + 1;
  }

  final withSub = [
    for (var i = 0; i < locations.length; i++)
      baseCounts[keyOf(locations[i], base[i])]! > 1
          ? _joinNonEmpty([locations[i].subregion, locations[i].region, locations[i].country])
          : base[i],
  ];
  final subCounts = <String, int>{};
  for (var i = 0; i < locations.length; i++) {
    final k = keyOf(locations[i], withSub[i]);
    subCounts[k] = (subCounts[k] ?? 0) + 1;
  }

  return [
    for (var i = 0; i < locations.length; i++)
      subCounts[keyOf(locations[i], withSub[i])]! > 1
          ? _joinNonEmpty([withSub[i], _formatCoordinates(locations[i])])
          : withSub[i],
  ];
}

String _formatCoordinates(Location l) {
  final lat = '${l.latitude.abs().toStringAsFixed(2)}°${l.latitude >= 0 ? 'N' : 'S'}';
  final lon = '${l.longitude.abs().toStringAsFixed(2)}°${l.longitude >= 0 ? 'E' : 'W'}';
  return '$lat $lon';
}

String _joinNonEmpty(List<String?> parts) {
  final seen = <String>{};
  return parts
      .whereType<String>()
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty && seen.add(s))
      .join(', ');
}
