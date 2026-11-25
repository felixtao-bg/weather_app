import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:weather_app/data/location_store.dart';

import '../support/fakes.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
  });

  test('selected location round-trips', () async {
    final store = SharedPrefsLocationStore();
    expect(await store.loadSelected(), isNull);
    await store.saveSelected(springfieldIl);
    final restored = await SharedPrefsLocationStore().loadSelected();
    expect(restored, springfieldIl);
    expect(restored!.subtitle, 'Illinois, United States');
  });

  test('recents: newest first, deduped, capped', () async {
    final store = SharedPrefsLocationStore(maxRecents: 2);
    await store.addRecent(tokyo);
    await store.addRecent(springfieldMo);
    await store.addRecent(tokyo);
    await store.addRecent(springfieldIl);
    expect(await store.loadRecents(), [springfieldIl, tokyo]);
    await store.clearRecents();
    expect(await store.loadRecents(), isEmpty);
  });

  test('corrupted stored data degrades to empty instead of throwing', () async {
    final prefs = SharedPreferencesAsync();
    await prefs.setString('selected_location_v1', '{not json');
    await prefs.setString('recent_locations_v1', '[{"id": 1}, "x"]');
    final store = SharedPrefsLocationStore(prefs: prefs);
    expect(await store.loadSelected(), isNull);
    expect(await store.loadRecents(), isEmpty);
  });
}
