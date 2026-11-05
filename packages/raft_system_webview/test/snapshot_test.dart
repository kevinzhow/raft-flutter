import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_system_webview/src/snapshot.dart';

final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC',
);
SystemWebViewSnapshot frame() => SystemWebViewSnapshot(_png, 1, 1, 3);

void main() {
  test(
    'native snapshot is bounded and tied to its exact viewport sequence',
    () {
      final packet = <String, Object>{
        'png': _png,
        'width': 1,
        'height': 1,
        'sequence': 3,
      };
      expect(SystemWebViewSnapshot.parse(packet, 3)?.width, 1);
      expect(SystemWebViewSnapshot.parse(packet, 4), isNull);
      for (final change in <Map<String, Object>>[
        {'png': Uint8List(24)},
        {'width': 2},
        {'height': -1},
        {'width': 8193},
        {'png': Uint8List(SystemWebViewSnapshot.maximumBytes + 1)},
      ]) {
        expect(SystemWebViewSnapshot.parse({...packet, ...change}, 3), isNull);
      }
    },
  );

  testWidgets(
    'snapshot survives an occlusion refresh failure and is privately released',
    (tester) async {
      var fail = false, notifications = 0;
      final cache = SystemWebViewSnapshotCache(
        capture: () async {
          if (fail) throw StateError('Native frame no longer visible');
          return frame();
        },
        changed: () => notifications++,
      );
      try {
        await tester.runAsync(cache.refresh);
        expect(cache.image?.width, 1);
        final previous = cache.image;
        expect(notifications, 1);
        fail = true;
        await tester.runAsync(cache.refresh);
        expect(identical(cache.image, previous), isTrue);
        expect(notifications, 1);
      } finally {
        cache.dispose();
      }
      expect(cache.image, isNull);
    },
  );

  testWidgets('a resized viewport cannot reuse the previous image', (
    tester,
  ) async {
    final cache = SystemWebViewSnapshotCache(
      capture: () async => frame(),
      changed: () {},
    );
    try {
      await tester.runAsync(cache.refresh);
      expect(cache.image, isNotNull);
      cache.invalidate(clearImage: true);
      expect(cache.image, isNull);
      await tester.pump();
    } finally {
      cache.dispose();
    }
  });

  testWidgets(
    'resize and disposal reject a late native snapshot without decoding it',
    (tester) async {
      var notifications = 0;
      var pending = Completer<SystemWebViewSnapshot?>();
      final cache = SystemWebViewSnapshotCache(
        capture: () => pending.future,
        changed: () => notifications++,
      );
      final old = cache.refresh();
      cache.invalidate();
      pending.complete(frame());
      await old;
      expect(cache.image, isNull);
      pending = Completer<SystemWebViewSnapshot?>();
      final closing = cache.refresh();
      cache.dispose();
      pending.complete(frame());
      await closing;
      expect(cache.image, isNull);
      expect(notifications, 0);
    },
  );
}
