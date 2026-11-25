import '../../domain/location.dart';

/// 空状态的快捷城市。坐标与 id 取自 Open-Meteo Geocoding（GeoNames），
/// 与搜索结果 id 一致，因此“最近搜索”去重和缓存都能正确命中。
const popularPlaces = <Location>[
  Location(
    id: 'geonames:1819729',
    name: '香港',
    latitude: 22.27832,
    longitude: 114.17469,
    country: '香港',
    countryCode: 'HK',
    timezone: 'Asia/Hong_Kong',
  ),
  Location(
    id: 'geonames:1796236',
    name: '上海',
    latitude: 31.22222,
    longitude: 121.45806,
    region: '上海',
    country: '中国',
    countryCode: 'CN',
    timezone: 'Asia/Shanghai',
  ),
  Location(
    id: 'geonames:1880252',
    name: '新加坡',
    latitude: 1.28967,
    longitude: 103.85007,
    country: '新加坡',
    countryCode: 'SG',
    timezone: 'Asia/Singapore',
  ),
  Location(
    id: 'geonames:1850147',
    name: '东京',
    latitude: 35.6895,
    longitude: 139.69171,
    region: '东京',
    country: '日本',
    countryCode: 'JP',
    timezone: 'Asia/Tokyo',
  ),
  Location(
    id: 'geonames:2643743',
    name: '伦敦',
    latitude: 51.50853,
    longitude: -0.12574,
    region: '英格兰',
    country: '英国',
    countryCode: 'GB',
    timezone: 'Europe/London',
  ),
  Location(
    id: 'geonames:5128581',
    name: '纽约',
    latitude: 40.71427,
    longitude: -74.00597,
    region: '纽约',
    country: '美国',
    countryCode: 'US',
    timezone: 'America/New_York',
  ),
];
