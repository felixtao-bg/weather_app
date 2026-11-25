import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_app/core/app_exception.dart';
import 'package:weather_app/domain/location.dart';
import 'package:weather_app/features/search/location_search_controller.dart';

import '../support/fakes.dart';

void main() {
  late FakeGeocodingService geocoding;
  late InMemoryLocationStore store;

  LocationSearchController build() => LocationSearchController(
    geocoding: geocoding,
    store: store,
    debounce: const Duration(milliseconds: 300),
  );

  setUp(() {
    geocoding = FakeGeocodingService((q) async => [springfieldMo, springfieldIl]);
    store = InMemoryLocationStore(recents: [tokyo]);
  });

  test('loads recents on creation', () {
    fakeAsync((async) {
      final c = build();
      async.flushMicrotasks();
      expect(c.state.recents, [tokyo]);
      expect(c.state.status, SearchStatus.idle);
      c.dispose();
    });
  });

  test('debounces typing into a single request with the final query', () {
    fakeAsync((async) {
      final c = build();
      for (final q in ['S', 'Sp', 'Spr', 'Spri', 'Spring']) {
        c.onQueryChanged(q);
        async.elapse(const Duration(milliseconds: 100));
      }
      expect(geocoding.queries, isEmpty);
      expect(c.state.status, SearchStatus.loading);
      async.elapse(const Duration(milliseconds: 300));
      expect(geocoding.queries, ['Spring']);
      expect(c.state.status, SearchStatus.results);
      expect(c.state.results, hasLength(2));
      c.dispose();
    });
  });

  test('short or whitespace-only input returns to idle without requests', () {
    fakeAsync((async) {
      final c = build();
      c.onQueryChanged('  a ');
      async.elapse(const Duration(seconds: 1));
      expect(c.state.status, SearchStatus.idle);
      expect(c.state.query, 'a');
      expect(geocoding.queries, isEmpty);
      c.dispose();
    });
  });

  test('race: a slow response for an old query is discarded', () {
    fakeAsync((async) {
      final slow = Completer<List<Location>>();
      geocoding.handler = (q) => q == 'Spr' ? slow.future : Future.value([tokyo]);
      final c = build();

      c.onQueryChanged('Spr');
      async.elapse(const Duration(milliseconds: 300)); // 'Spr' request in flight
      c.onQueryChanged('东京');
      async.elapse(const Duration(milliseconds: 300));
      expect(c.state.results, [tokyo]);

      slow.complete([springfieldMo]);
      async.flushMicrotasks();
      expect(c.state.results, [tokyo], reason: 'stale response ignored');
      expect(c.state.query, '东京');
      c.dispose();
    });
  });

  test('submit bypasses debounce', () {
    fakeAsync((async) {
      final c = build();
      c.onQueryChanged('Springfield');
      c.submit();
      async.flushMicrotasks();
      expect(geocoding.queries, ['Springfield']);
      async.elapse(const Duration(seconds: 1));
      expect(geocoding.queries, ['Springfield'], reason: 'timer was cancelled');
      c.dispose();
    });
  });

  test('empty and error states, then retry', () {
    fakeAsync((async) {
      geocoding.handler = (_) async => const [];
      final c = build();
      c.onQueryChanged('zzzz');
      async.elapse(const Duration(milliseconds: 300));
      expect(c.state.status, SearchStatus.empty);

      geocoding.handler = (_) async => throw const NetworkException('offline');
      c.onQueryChanged('Paris');
      async.elapse(const Duration(milliseconds: 300));
      expect(c.state.status, SearchStatus.error);
      expect(c.state.error, isA<NetworkException>());

      geocoding.handler = (_) async => [tokyo];
      c.retry();
      async.flushMicrotasks();
      expect(c.state.status, SearchStatus.results);
      expect(geocoding.queries, ['zzzz', 'Paris', 'Paris']);
      c.dispose();
    });
  });

  test('dispose cancels pending debounce and ignores late responses', () {
    fakeAsync((async) {
      final c = build();
      c.onQueryChanged('Spring');
      c.dispose();
      async.elapse(const Duration(seconds: 1));
      expect(geocoding.queries, isEmpty);
    });
  });

  test('clearRecents empties state and store', () {
    fakeAsync((async) {
      final c = build();
      async.flushMicrotasks();
      c.clearRecents();
      async.flushMicrotasks();
      expect(c.state.recents, isEmpty);
      expect(store.recents, isEmpty);
      c.dispose();
    });
  });
}
