// Native profile probe with synthetic retained history; no account or disk cache.
// From apps/raft_flutter build macos --profile
//   --target=../../tool/performance/history_memory_scroll.dart
// Give the native build its own PRODUCT_BUNDLE_IDENTIFIER before launching.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:raft_flutter/data/history_body_proofs.dart';
import 'package:raft_flutter/data/history_memory.dart';
import 'package:raft_flutter/data/message_history.dart';
import 'package:raft_flutter/data/workspace_cache_codec.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final versions = <String, List<Map<String, dynamic>>>{
    for (var n = 0; n < 1000; n++)
      '$n': [
        {'id': '$n', 'seq': '$n', 'content': 'Synthetic 中文 $n ' * 600},
      ],
  };
  final saved = {
    for (final entry in versions.entries)
      entry.key: await encodeWorkspaceCache(entry.value.first),
  };
  var inspectedRows = 0, workers = 0, captures = 0;
  final proofs = HistoryBodyProofs(
    inspect: (rows, stored) {
      workers++;
      inspectedRows += rows.length;
      return inspectHistoryBodies(rows, stored);
    },
  );
  final pool = HistoryMemoryPool(
    (_, rows) => proofs(rows, {for (final id in rows.keys) id: saved[id]!}),
    activeLimit: 1000,
  );
  final changes = ValueNotifier(0);
  final controller = ScrollController();
  pool.register(
    changes,
    HistoryMemoryPort(
      changes: changes,
      stamp: () => changes.value,
      capture: () async {
        captures++;
        return [
          HistoryMemoryWindow(
            scope: const MessageHistoryScope(
              origin: 'https://history-memory.invalid',
              principal: 'fixture',
              server: 'fixture',
              channel: 'fixture',
              parentChannel: 'fixture',
              authority: 'fixture',
            ),
            versions: Map.of(versions),
            active: true,
            current: () => true,
            release: (_) =>
                throw StateError('Fixture must stay within its budget'),
          ),
        ];
      },
    ),
  );
  await pool.maintain();
  final initialWorkers = workers;
  final initialRows = inspectedRows;
  controller.addListener(() => pool.samplePosition(controller, () {}));
  runApp(
    MaterialApp(
      home: Scaffold(
        body: ListView.builder(
          controller: controller,
          itemCount: 1000,
          itemExtent: 48,
          itemBuilder: (_, n) => Text('Synthetic history message $n'),
        ),
      ),
    ),
  );
  await Future<void>.delayed(const Duration(seconds: 1));
  final frames = <ui.FrameTiming>[];
  void timing(List<ui.FrameTiming> value) => frames.addAll(value);
  WidgetsBinding.instance.addTimingsCallback(timing);
  final started = Stopwatch()..start();
  for (var n = 0; n < 40; n++) {
    await controller.animateTo(
      n.isEven ? 2400 : 0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.linear,
    );
  }
  await Future<void>.delayed(const Duration(seconds: 1));
  final scrollWorkers = workers - initialWorkers;
  final scrollRows = inspectedRows - initialRows;
  final scrollCaptures = captures - 1;
  final scrollMs = started.elapsedMilliseconds;
  final recheck = Stopwatch()..start();
  for (var n = 0; n < 5; n++) {
    await pool.maintain();
  }
  recheck.stop();
  WidgetsBinding.instance.removeTimingsCallback(timing);
  final build = frames.map((f) => f.buildDuration.inMicroseconds).toList()
    ..sort();
  final raster = frames.map((f) => f.rasterDuration.inMicroseconds).toList()
    ..sort();
  print(
    'RAFT_HISTORY_MEMORY_LAB ${jsonEncode({'rows': versions.length, 'initialWorkers': initialWorkers, 'scrollMs': scrollMs, 'scrollCaptures': scrollCaptures, 'scrollWorkers': scrollWorkers, 'scrollInspectedRows': scrollRows, 'unchangedRecheckMs': recheck.elapsedMilliseconds, 'unchangedRecheckWorkers': workers - initialWorkers - scrollWorkers, 'frames': frames.length, 'buildP99Us': build.isEmpty ? null : build[((build.length - 1) * .99).floor()], 'rasterP99Us': raster.isEmpty ? null : raster[((raster.length - 1) * .99).floor()], 'rssBytes': ProcessInfo.currentRss})}',
  );
  pool.close();
  changes.dispose();
  runApp(const SizedBox());
  await WidgetsBinding.instance.endOfFrame;
  controller.dispose();
  exit(0);
}
