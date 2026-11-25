import '../../domain/location.dart';
import '../../domain/services.dart';
import 'open_meteo_http.dart';

/// Open-Meteo Geocoding API（数据源 GeoNames，CC BY 4.0），无需 API Key。
///
/// 文档：https://open-meteo.com/en/docs/geocoding-api
class OpenMeteoGeocodingApi implements GeocodingService {
  OpenMeteoGeocodingApi(this._http, {Uri? baseUri, this.resultCount = 10})
    : _baseUri = baseUri ?? Uri.parse('https://geocoding-api.open-meteo.com/v1/search');

  final OpenMeteoHttp _http;
  final Uri _baseUri;
  final int resultCount;

  @override
  Future<List<Location>> search(String query, {String languageCode = 'zh'}) async {
    final uri = _baseUri.replace(
      queryParameters: {
        'name': query,
        'count': '$resultCount',
        'language': languageCode,
        'format': 'json',
      },
    );
    final json = await _http.getJson(uri);

    // 无匹配时接口直接省略 `results` 字段，而不是返回空数组。
    final results = json['results'];
    if (results is! List) return const [];

    // 单条脏数据（缺坐标等）直接跳过，不让整次搜索失败。
    return results.map(_parseLocation).whereType<Location>().toList(growable: false);
  }

  static Location? _parseLocation(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final name = raw['name'];
    final lat = raw['latitude'];
    final lon = raw['longitude'];
    if (id is! num || name is! String || name.trim().isEmpty) return null;
    if (lat is! num || lon is! num) return null;
    if (lat.abs() > 90 || lon.abs() > 180) return null;
    return Location(
      id: 'geonames:${id.toInt()}',
      name: name.trim(),
      latitude: lat.toDouble(),
      longitude: lon.toDouble(),
      region: _string(raw['admin1']),
      subregion: _string(raw['admin2']),
      country: _string(raw['country']),
      countryCode: _string(raw['country_code']),
      timezone: _string(raw['timezone']),
    );
  }

  static String? _string(Object? v) => v is String && v.trim().isNotEmpty ? v.trim() : null;
}
