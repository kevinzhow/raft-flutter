// The explicit memory budgets: the per-class framework ImageCache limits are
// applied (and restored) by RaftMemoryRelease, the table lists every tier, and
// the small remembered maps of PlayerSessions stay bounded.
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/platform/attachment_player_sessions.dart';
import 'package:raft_flutter/platform/bounded_lru.dart';
import 'package:raft_flutter/platform/memory_budgets.dart';
import 'package:raft_flutter/platform/memory_release.dart';

import 'support/repo_root.dart';

const _mib = 1024 * 1024;

void main() {
  group('RaftMemoryBudgets', () {
    test('every platform maps to a class; phones are tighter than desktops', () {
      for (final p in [TargetPlatform.android, TargetPlatform.iOS]) {
        expect(RaftMemoryBudgets.forPlatform(p), same(RaftMemoryBudgets.phone));
      }
      for (final p in [
        TargetPlatform.linux,
        TargetPlatform.macOS,
        TargetPlatform.windows,
        TargetPlatform.fuchsia,
      ]) {
        expect(RaftMemoryBudgets.forPlatform(p), same(RaftMemoryBudgets.desktop));
      }
      const phone = RaftMemoryBudgets.phone, desktop = RaftMemoryBudgets.desktop;
      expect(phone.imageCacheBytes, 64 * _mib);
      expect(phone.imageCacheEntries, 200);
      expect(desktop.imageCacheBytes, 128 * _mib);
      expect(desktop.imageCacheEntries, 500);
      expect(phone.imageCacheBytes, lessThan(desktop.imageCacheBytes));
    });

    test('the attachment repository never decodes more than the ImageCache can hold', () {
      // The repository's bitmaps are shared with ImageCache entries; a larger
      // repository than cache would pin images the cache already forgot.
      for (final b in [RaftMemoryBudgets.phone, RaftMemoryBudgets.desktop]) {
        expect(b.attachmentImageDecodedBytes, lessThanOrEqualTo(b.imageCacheBytes));
      }
    });

    test('applyImageCache sets the limits and restores the previous ones', () {
      final cache = ImageCache();
      expect(cache.maximumSize, 1000);
      expect(cache.maximumSizeBytes, 100 * _mib);
      final restore = RaftMemoryBudgets.phone.applyImageCache(cache);
      expect(cache.maximumSize, 200);
      expect(cache.maximumSizeBytes, 64 * _mib);
      restore();
      expect(cache.maximumSize, 1000);
      expect(cache.maximumSizeBytes, 100 * _mib);
    });

    testWidgets('RaftMemoryRelease.install applies the budget of the platform class', (tester) async {
      final cache = ImageCache();
      final release = RaftMemoryRelease(
        imageCache: () => cache,
        budgets: () => RaftMemoryBudgets.desktop,
      );
      release.install();
      expect(cache.maximumSize, 500);
      expect(cache.maximumSizeBytes, 128 * _mib);
      expect(release.snapshot(), contains('imageCache 0/500 images 0/134217728 B'));
      release.install(); // idempotent: the restore point stays the original
      release.uninstall();
      expect(cache.maximumSize, 1000);
      expect(cache.maximumSizeBytes, 100 * _mib);
    });

    testWidgets('the default budget follows defaultTargetPlatform', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(RaftMemoryBudgets.current, same(RaftMemoryBudgets.phone));
      final cache = ImageCache();
      final release = RaftMemoryRelease(imageCache: () => cache)..install();
      expect(cache.maximumSizeBytes, 64 * _mib);
      release.uninstall();
      debugDefaultTargetPlatformOverride = null;
    });

    test('the table in docs/architecture.md lists every tier of describe()', () {
      final root = repoRoot();
      final doc = File('${root.path}/docs/architecture.md').readAsStringSync();
      expect(doc, contains('RaftMemoryBudgets'));
      for (final tier in [
        'ImageCache',
        'AttachmentImageRepository',
        'RaftHotImages',
        'RaftImageBytes',
        'PlayerSessions',
        'AttachmentUrlCache',
      ]) {
        expect(doc, contains(tier), reason: tier);
      }
      for (final line in RaftMemoryBudgets.phone.describe()) {
        expect(line, isNotEmpty);
      }
    });
  });

  group('BoundedLru', () {
    test('map: past the bound the least recently used key goes; reads refresh', () {
      final map = BoundedLruMap<String, int>(3);
      map['a'] = 1;
      map['b'] = 2;
      map['c'] = 3;
      expect(map['a'], 1); // a is now the most recent
      map['d'] = 4; // evicts b
      expect(map.keys, ['c', 'a', 'd']);
      expect(map['b'], isNull);
      map['c'] = 30; // rewriting refreshes too
      map['e'] = 5; // evicts a
      expect(map.keys, ['d', 'c', 'e']);
      expect(map.length, 3);
      expect(map.containsKey('a'), isFalse);
    });

    test('set: add refreshes, the oldest goes past the bound', () {
      final set = BoundedLruSet<String>(2);
      expect(set.add('a'), isTrue);
      expect(set.add('b'), isTrue);
      expect(set.add('a'), isFalse);
      expect(set.add('c'), isTrue); // evicts b
      expect(set.contains('b'), isFalse);
      expect(set.toSet(), {'a', 'c'});
    });

    test('a bound below one is rejected', () {
      expect(() => BoundedLruMap<String, int>(0), throwsArgumentError);
      expect(() => BoundedLruSet<String>(0), throwsArgumentError);
    });

    test('PlayerSessions remembered maps stop at the budget', () {
      final sessions = PlayerSessions();
      addTearDown(sessions.dispose);
      const n = RaftMemoryBudgets.playerRememberedEntries;
      for (var i = 0; i < n * 3; i++) {
        sessions.hdrVerdicts['k$i'] = i.isEven;
        sessions.prepared.add('k$i');
        sessions.resumeAt['k$i'] = Duration(seconds: i);
      }
      expect(sessions.hdrVerdicts.length, n);
      expect(sessions.prepared.length, n);
      expect(sessions.resumeAt.length, n);
      expect(sessions.prepared.contains('k0'), isFalse);
      expect(sessions.prepared.contains('k${n * 3 - 1}'), isTrue);
      expect(sessions.resumeAt['k${n * 3 - 1}'], Duration(seconds: n * 3 - 1));
      sessions.clear();
      expect(sessions.resumeAt, isEmpty);
    });
  });
}
