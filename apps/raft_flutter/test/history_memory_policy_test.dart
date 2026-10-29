import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/history_memory.dart';
import 'package:raft_flutter/platform/workspace_cache.dart';

import 'history_capacity_test.dart' as fixture;

void main() {
  test('shared byte budget counts duplicate owners and keeps an unsaved latest edit', () async {
    final cache = DriftWorkspaceCache(
      NativeDatabase.memory(),
      automaticHistoryMaintenance: false,
    );
    addTearDown(cache.close);
    final scope = fixture.scope('chat');
    final data = fixture.rows('chat', 1, 20, bytes: 2048);
    await cache.messageHistory.acceptEvents(scope, data);
    final versions = <String, List<Map<String, dynamic>>>{
      for (final row in data) row['id'] as String: [row, Map.of(row)],
    };
    versions['chat-1'] = [
      {...data.first, 'content': 'Unsaved newer text'},
    ];
    final changes = ChangeNotifier();
    final pool = HistoryMemoryPool(
      cache.messageHistory.memory.prove,
      byteLimit: 12 << 10,
    );
    addTearDown(() {
      pool.close();
      changes.dispose();
    });
    pool.register(
      changes,
      HistoryMemoryPort(
        changes: changes,
        stamp: () => versions.length,
        capture: () async => [
          HistoryMemoryWindow(
            scope: scope,
            versions: Map.of(versions),
            active: true,
            current: () => true,
            release: (ids) {
              for (final id in ids) {
                versions.remove(id);
              }
              return ids;
            },
          ),
        ],
      ),
    );
    await pool.maintain();
    expect(versions.keys, containsAll(['chat-1', 'chat-20']));
    expect(versions.length, lessThan(20));
    expect(versions['chat-1']!.single['content'], 'Unsaved newer text');
    final actual = versions.values
        .expand((copies) => copies)
        .fold<int>(0, (sum, row) => sum + utf8.encode(jsonEncode(row)).length);
    expect(pool.retainedBytes, actual);
    expect(actual, lessThanOrEqualTo(12 << 10));
    expect(
      HistoryMemoryPool(cache.messageHistory.memory.prove).byteLimit,
      32 << 20,
    );
  });

  test('only twenty idle windows retain fifty bodies and their database copies remain', () async {
    final cache = DriftWorkspaceCache(
      NativeDatabase.memory(),
      automaticHistoryMaintenance: false,
    );
    addTearDown(cache.close);
    final windows = <String, Map<String, List<Map<String, dynamic>>>>{};
    for (var n = 0; n < 22; n++) {
      final channel = 'idle$n', rows = fixture.rows('idle$n', 1, 60, bytes: 32);
      await cache.messageHistory.acceptEvents(fixture.scope(channel), rows);
      windows[channel] = {
        for (final row in rows) row['id'] as String: [row],
      };
    }
    final changes = ChangeNotifier(), pool = cache.messageHistory.memory;
    String? selected;
    var visit = 0;
    addTearDown(() {
      pool.unregister(changes);
      changes.dispose();
    });
    pool.register(
      changes,
      HistoryMemoryPort(
        changes: changes,
        stamp: () => visit,
        selected: () => selected == null ? const [] : [selected],
        capture: () async => [
          for (final entry in windows.entries)
            HistoryMemoryWindow(
              scope: fixture.scope(entry.key),
              versions: Map.of(entry.value),
              active: false,
              current: () => true,
              release: (ids) {
                for (final id in ids) {
                  entry.value.remove(id);
                }
                return ids;
              },
            ),
        ],
      ),
    );
    for (final channel in windows.keys) {
      selected = channel;
      visit++;
      changes.notifyListeners();
    }
    selected = null;
    visit++;
    changes.notifyListeners();
    await pool.maintain();
    expect(windows.values.where((rows) => rows.isNotEmpty), hasLength(20));
    expect(windows.values.expand((rows) => rows.keys), hasLength(1000));
    expect(windows['idle0'], isEmpty);
    expect(windows['idle1'], isEmpty);
    expect(windows['idle21'], hasLength(50));
    expect(
      (await cache
              .customSelect('SELECT count(*) AS n FROM raft_history_rows')
              .getSingle())
          .read<int>('n'),
      1320,
    );
  });

  test(
    'a receiver retired while durable proof waits cannot release any body',
    () async {
      final changes = ChangeNotifier(),
          ready = Completer<void>(),
          reached = Completer<void>();
      var current = true, releases = 0;
      final pool = HistoryMemoryPool((scope, versions) async {
        if (!reached.isCompleted) reached.complete();
        await ready.future;
        return [
          for (final id in versions.keys) (id: id, bytes: 1024, durable: true),
        ];
      }, activeLimit: 1);
      addTearDown(() {
        pool.close();
        changes.dispose();
      });
      pool.register(
        changes,
        HistoryMemoryPort(
          changes: changes,
          stamp: () => 1,
          capture: () async => [
            HistoryMemoryWindow(
              scope: fixture.scope('chat'),
              versions: {
                for (final row in fixture.rows('chat', 1, 3, bytes: 32))
                  row['id'] as String: [row],
              },
              active: true,
              current: () => current,
              release: (ids) {
                releases++;
                return ids;
              },
            ),
          ],
        ),
      );
      final job = pool.maintain();
      await reached.future;
      current = false;
      ready.complete();
      await job;
      expect(releases, 0);
    },
  );
}
