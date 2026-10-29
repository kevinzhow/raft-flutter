import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/history_capacity.dart';
import 'package:raft_flutter/features/message_history_settings.dart';
import 'package:raft_ui/raft_ui.dart';

import 'close_support.dart';
import 'close_surface.dart';

const _account = HistoryAccount('https://history.invalid', 'close-test');

class _Capacity implements HistoryCapacity {
  @override
  Future<void> opened(
    HistoryAccount account,
    String server,
    String channel,
  ) async {}
  int mutations = 0;
  @override
  Future<HistoryDiskUsage> usage(HistoryAccount account) async =>
      const HistoryDiskUsage(
        budget: 2 << 30,
        accountBytes: 1 << 20,
        databaseBytes: 2 << 20,
        walBytes: 0,
        indexBytes: 0,
        freeBytes: 0,
        rows: 10,
        pendingCompaction: true,
      );
  @override
  Future<void> setBudget(HistoryAccount account, int bytes) async =>
      mutations++;
  @override
  Future<bool> isKept(
    HistoryAccount account,
    String server,
    String channel,
  ) async => false;
  @override
  Future<void> keep(
    HistoryAccount account,
    String server,
    String channel,
    bool value,
  ) async => mutations++;
  @override
  void protect(
    Object owner,
    Iterable<HistoryProtectedRows> Function() current,
  ) {}
  @override
  void release(Object owner) {}
  @override
  Future<HistoryCompactionPlan> compactionPlan(HistoryAccount account) async =>
      const HistoryCompactionPlan(
        fullVacuum: true,
        requiredBytes: 4 << 20,
        availableBytes: 1 << 30,
      );
  @override
  Future<HistoryDiskUsage> maintain(
    HistoryAccount account, {
    bool compact = false,
    bool allowFullVacuum = false,
  }) async {
    mutations++;
    return usage(account);
  }
}

/// Opens each real settings action, rather than a duplicate confirm widget.
Future<SurfaceProbe> historySettingsConfirmation(
  WidgetTester t,
  Size size,
) async {
  await t.pumpWidget(const SizedBox.shrink());
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final capacity = _Capacity();
  await t.pumpWidget(
    MaterialApp(
      theme: raftTheme(),
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(RaftSpace.x4),
          child: MessageHistorySettings(capacity: capacity, account: _account),
        ),
      ),
    ),
  );
  await frames(t, 10);
  final action = find.byKey(const Key('history-budget'));
  await t.ensureVisible(action);
  await frames(t, 5);
  await t.tap(action);
  await frames(t, 10);
  await t.tap(find.text('512 MiB').last);
  await frames(t, 10);
  final surface = find.byKey(const ValueKey('history-lower-dialog'));
  return SurfaceProbe(
    isOpen: () {
      expect(
        capacity.mutations,
        0,
        reason: 'Dismissal must not lower the quota',
      );
      return surface.evaluate().isNotEmpty;
    },
    x: find.descendant(
      of: surface,
      matching: find.byWidgetPredicate(
        (w) =>
            w is RaftDialogClose || w.key == const Key('confirm-dialog-close'),
      ),
    ),
    scrim: const Offset(6, 6),
  );
}
