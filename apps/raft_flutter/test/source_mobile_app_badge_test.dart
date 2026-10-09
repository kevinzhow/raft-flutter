import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/search_memory.dart';
import 'package:raft_flutter/data/source_mobile_app_badge.dart';

class LocalFlags implements SearchMemoryStorage {
  final flags = <String, String>{};
  final held = <String, Completer<String?>>{};
  bool failRead = false, failWrite = false;
  @override
  Future<String?> read(String key) async {
    if (failRead) throw StateError('optional storage unavailable');
    return held[key]?.future ?? flags[key];
  }

  @override
  Future<void> write(String key, String value) async {
    if (failWrite) throw StateError('optional storage unavailable');
    flags[key] = value;
  }
}

void main() {
  test(
    'Source anonymous/unseen/seen flag is origin and human scoped',
    () async {
      final disk = LocalFlags();
      final owner = SourceMobileAppBadge(storage: disk);
      addTearDown(owner.dispose);
      await owner.bind('origin-a', null);
      expect(owner.hasAttention, false);
      await owner.bind('origin-a', 'alice');
      expect(owner.hasAttention, true);
      final alice = owner.key;
      expect(owner.markSeen(alice), true);
      await owner.writes;
      expect(owner.hasAttention, false);
      await owner.bind('origin-a', 'bob');
      expect(owner.hasAttention, true);
      expect(owner.markSeen(alice), false);
      await owner.bind('origin-a', 'alice');
      expect(owner.hasAttention, false);
      await owner.bind('origin-b', 'alice');
      expect(owner.hasAttention, true);
      expect(disk.flags, {alice!: '1'});
    },
  );
  test(
    'late local read cannot restore old principal or consumed flag',
    () async {
      final disk = LocalFlags();
      final badge = SourceMobileAppBadge(storage: disk);
      addTearDown(badge.dispose);
      final alice = SourceMobileAppBadge.storageKey('a', 'alice');
      disk.held[alice] = Completer<String?>();
      final first = badge.bind('a', 'alice');
      await badge.bind('a', 'bob');
      expect(badge.hasAttention, true);
      disk.held[alice]!.complete('1');
      await first;
      expect(badge.hasAttention, true);
      disk.held[alice] = Completer<String?>();
      final second = badge.bind('a', 'alice');
      expect(badge.markSeen(badge.key), true);
      disk.held[alice]!.complete(null);
      await second;
      expect(badge.hasAttention, false);
    },
  );
  test(
    'storage failure keeps the usable Source unseen/session-seen state',
    () async {
      final disk = LocalFlags()
        ..failRead = true
        ..failWrite = true;
      final badge = SourceMobileAppBadge(storage: disk);
      addTearDown(badge.dispose);
      await badge.bind('a', 'alice');
      expect(badge.hasAttention, true);
      expect(badge.markSeen(badge.key), true);
      await badge.writes;
      expect(badge.hasAttention, false);
    },
  );
}
