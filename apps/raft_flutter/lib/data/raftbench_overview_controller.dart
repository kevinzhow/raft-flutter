import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:raft_client/raft_client.dart' show RaftApiException;

import 'raftbench_hosted_controller.dart' show RaftbenchRequest;
import 'raftbench_metrics.dart';

enum RaftbenchLoadKind { idle, loading, error, unavailable, ready }

/// One metric's load state (Web `Load<T>`).
class RaftbenchLoad<T> {
  const RaftbenchLoad(this.kind, [this.value]);
  const RaftbenchLoad.ready(T this.value) : kind = RaftbenchLoadKind.ready;
  final RaftbenchLoadKind kind;
  final T? value;
  bool get loading => kind == RaftbenchLoadKind.loading;
}

/// "Tasks and cost" (Web `ManagerOverview.tsx`): task snapshot, the period
/// comparison and the server-wide cloud-agent spend, three independent reads
/// of existing database and billing aggregates (no AI, no message scan).
///
/// One controller serves one scope (a channel, or the whole workspace when
/// [channelId] is null). A result is dropped once the identity changed or a
/// newer [load] started.
class RaftbenchOverviewController extends ChangeNotifier {
  RaftbenchOverviewController({
    required this.request,
    required this.identity,
    required this.roleAllowed,
    required this.channelId,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;

  final RaftbenchRequest request;
  final String Function() identity;
  final bool Function() roleAllowed;
  final String? channelId;
  final DateTime Function() now;

  RaftbenchLoad<RaftbenchTaskPeriods> tasks = const RaftbenchLoad(
    RaftbenchLoadKind.idle,
  );
  RaftbenchLoad<RaftbenchTaskSnapshot> snapshot = const RaftbenchLoad(
    RaftbenchLoadKind.idle,
  );
  RaftbenchLoad<RaftbenchCostComparison> costs = const RaftbenchLoad(
    RaftbenchLoadKind.idle,
  );

  late final String _identity = identity();
  int _seq = 0;
  bool _disposed = false;

  bool get anyLoading => snapshot.loading || tasks.loading || costs.loading;

  bool _current(int seq) =>
      !_disposed && seq == _seq && identity() == _identity && roleAllowed();

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() async {
    if (_disposed || identity() != _identity || !roleAllowed()) return;
    final seq = ++_seq;
    final window = RaftbenchWindow.at(now());
    tasks = const RaftbenchLoad(RaftbenchLoadKind.loading);
    snapshot = const RaftbenchLoad(RaftbenchLoadKind.loading);
    costs = const RaftbenchLoad(RaftbenchLoadKind.loading);
    _changed();
    final scope = channelId == null
        ? <String, dynamic>{}
        : {'channelId': channelId};
    await Future.wait([
      () async {
        try {
          final raw = await request(
            'GET',
            '/tasks/server/snapshot-metrics',
            query: scope,
          );
          final value = RaftbenchTaskSnapshot.parse(raw);
          if (_current(seq)) snapshot = RaftbenchLoad.ready(value);
        } catch (_) {
          if (_current(seq)) {
            snapshot = const RaftbenchLoad(RaftbenchLoadKind.error);
          }
        }
        if (_current(seq)) _changed();
      }(),
      () async {
        try {
          final raw = await request(
            'GET',
            '/tasks/server/period-metrics',
            query: {
              'from': RaftbenchWindow.iso(window.previousStart),
              'midpoint': RaftbenchWindow.iso(window.start),
              'to': RaftbenchWindow.iso(window.end),
              ...scope,
            },
          );
          final value = RaftbenchTaskPeriods.parse(raw, window);
          if (_current(seq)) tasks = RaftbenchLoad.ready(value);
        } catch (_) {
          if (_current(seq)) {
            tasks = const RaftbenchLoad(RaftbenchLoadKind.error);
          }
        }
        if (_current(seq)) _changed();
      }(),
      () async {
        try {
          final raw = await request(
            'GET',
            '/billing/hosted-runtime-usage',
            query: {
              'from': RaftbenchWindow.iso(window.previousStart),
              'to': RaftbenchWindow.iso(window.end),
              'bucket': 'day',
            },
          );
          final value = RaftbenchCostComparison.parse(raw, window);
          if (_current(seq)) costs = RaftbenchLoad.ready(value);
        } catch (e) {
          if (_current(seq)) {
            costs = RaftbenchLoad(
              e is RaftApiException && e.status == 404
                  ? RaftbenchLoadKind.unavailable
                  : RaftbenchLoadKind.error,
            );
          }
        }
        if (_current(seq)) _changed();
      }(),
    ]);
  }

  @override
  void dispose() {
    _disposed = true;
    _seq++;
    super.dispose();
  }
}
