import 'package:flutter/material.dart';
import 'package:raft_ui/previews.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/history_capacity.dart';
import 'message_history_settings.dart';

@RaftPreviews('Message storage', size: Size(640, 1100))
@RaftPreviews('Message storage phone', size: Size(360, 1300))
Widget messageStoragePreview() => _preview(_Capacity());

@RaftPreviews('Message storage protected full', size: Size(360, 1300))
Widget protectedMessageStoragePreview() => _preview(_Capacity(full: true));

@RaftPreviews('Message storage retry', size: Size(360, 1300))
Widget unavailableMessageStoragePreview() => _preview(_Capacity(failed: true));

Widget _preview(_Capacity capacity) => SingleChildScrollView(
  padding: const EdgeInsets.all(RaftSpace.x4),
  child: MessageHistorySettings(
    capacity: capacity,
    account: const HistoryAccount('https://preview.invalid', 'preview'),
  ),
);

/// Synthetic state only; the preview never opens a database or a connection.
class _Capacity implements HistoryCapacity {
  @override
  Future<void> opened(
    HistoryAccount account,
    String server,
    String channel,
  ) async {}
  _Capacity({this.full = false, this.failed = false});
  bool full, failed, kept = false;
  int budget = 1 << 30;
  @override
  Future<HistoryDiskUsage> usage(HistoryAccount account) async {
    if (failed) throw StateError('Synthetic measurement failure');
    return HistoryDiskUsage(
      budget: budget,
      accountBytes: (full ? 1200 : 120) << 20,
      databaseBytes: 1300 << 20,
      walBytes: 0,
      indexBytes: 10 << 20,
      freeBytes: 16 << 20,
      rows: 100000,
      pendingCompaction: true,
      protectedFull: full,
    );
  }

  @override
  Future<void> setBudget(HistoryAccount account, int bytes) async {
    budget = bytes;
  }

  @override
  Future<bool> isKept(
    HistoryAccount account,
    String server,
    String channel,
  ) async => kept;
  @override
  Future<void> keep(
    HistoryAccount account,
    String server,
    String channel,
    bool value,
  ) async {
    kept = value;
  }

  @override
  Future<HistoryDiskUsage> maintain(
    HistoryAccount account, {
    bool compact = false,
    bool allowFullVacuum = false,
  }) => usage(account);
  @override
  Future<HistoryCompactionPlan> compactionPlan(HistoryAccount account) async =>
      const HistoryCompactionPlan(fullVacuum: false);

  @override
  void protect(
    Object owner,
    Iterable<HistoryProtectedRows> Function() current,
  ) {}
  @override
  void release(Object owner) {}
}
