import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:raft_ui/raft_ui.dart'
    show
        RaftbenchCueReview,
        RaftbenchEvaluation,
        RaftbenchEvidenceMessage,
        RaftbenchFinding,
        RaftbenchOption,
        RaftbenchOverviewSnapshot,
        RaftbenchReview,
        RaftbenchRulesPanel,
        RaftbenchSignal,
        evaluateRaftbenchMessages,
        raftbenchOverviewChannelLimit,
        raftbenchWorkspaceScope;

import 'raftbench_hosted_controller.dart' show RaftbenchRequest;
import 'raftbench_live_messages.dart';

class _Snapshot {
  const _Snapshot(this.scopeKey, this.value);
  final String scopeKey;
  final RaftbenchOverviewSnapshot value;
}

/// The legacy phrase and repetition scan (Web `RaftBenchPage` rule section):
/// reads the latest 200 top-level messages of the chosen scope on request and
/// evaluates them locally. Changing the scope, the identity or the consent
/// drops the snapshot, the reviews and the selection.
class RaftbenchRulesController extends ChangeNotifier
    implements RaftbenchRulesPanel {
  RaftbenchRulesController({
    required this.request,
    required this.identity,
    required this.roleAllowed,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;

  final RaftbenchRequest request;
  final String Function() identity;
  final bool Function() roleAllowed;
  final DateTime Function() now;

  /// What the last [configure] call fixed.
  @override
  String channelId = raftbenchWorkspaceScope;
  @override
  List<RaftbenchOption> options = const [];
  bool consented = false, analysisAllowed = false;

  @override
  int minimum = 3;
  @override
  RaftbenchSignal? filter;
  @override
  String drillChannelId = '';
  String selectedId = '';
  @override
  Map<String, RaftbenchCueReview> reviews = const {};
  @override
  @override
  bool loading = false, failed = false;

  _Snapshot? _snapshot;
  String _scopeKey = '';
  int _generation = 0;
  bool _disposed = false;
  RaftbenchEvaluation? _evaluation;
  Object? _evaluated;
  int _evaluatedMinimum = 0;

  /// Sync the inputs the page owns. A different scope drops everything
  /// derived from the old one. Safe to call while building: it never notifies.
  void configure({
    required String channelId,
    required List<RaftbenchOption> options,
    required bool consented,
    required bool analysisAllowed,
  }) {
    this.options = options;
    this.analysisAllowed = analysisAllowed;
    final membership = jsonEncode([for (final o in options) o.value]..sort());
    final key = jsonEncode([identity(), channelId, membership, consented]);
    this.channelId = channelId;
    this.consented = consented;
    if (key == _scopeKey) return;
    _scopeKey = key;
    _generation++;
    _snapshot = null;
    reviews = const {};
    selectedId = '';
    failed = false;
    loading = false;
    _evaluation = null;
  }

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  @override
  RaftbenchOverviewSnapshot? get snapshot =>
      _snapshot?.scopeKey == _scopeKey ? _snapshot!.value : null;

  @override
  RaftbenchEvaluation get evaluation {
    final value = snapshot;
    if (value == null) return RaftbenchEvaluation.empty;
    if (!identical(_evaluated, value) || _evaluatedMinimum != minimum) {
      _evaluation = evaluateRaftbenchMessages(value.messages, minimum: minimum);
      _evaluated = value;
      _evaluatedMinimum = minimum;
    }
    return _evaluation!;
  }

  @override
  List<RaftbenchFinding> get findings => [
    for (final f in evaluation.findings)
      if ((filter == null || f.kind == filter) &&
          (drillChannelId.isEmpty ||
              f.evidence.first.channelId == drillChannelId))
        f,
  ];

  @override
  RaftbenchFinding? get finding {
    final all = findings;
    for (final f in all) {
      if (f.id == selectedId) return f;
    }
    return all.isEmpty ? null : all.first;
  }

  @override
  RaftbenchCueReview? get review {
    final f = finding;
    return f == null ? null : reviews[f.id] ?? RaftbenchCueReview.unreviewed;
  }

  @override
  int get pendingCount => [
    for (final f in evaluation.findings)
      if ((reviews[f.id]?.status ?? RaftbenchReview.needsReview) ==
          RaftbenchReview.needsReview)
        f,
  ].length;

  @override
  Set<String> get evidenceIds => {
    for (final m in finding?.evidence ?? const []) m.id,
  };

  /// The matched messages plus up to four nearby ones (same channel, within
  /// two minutes of the matched span), oldest first.
  @override
  List<RaftbenchEvidenceMessage> get evidence {
    final f = finding;
    if (f == null) return const [];
    final ids = evidenceIds;
    final start = f.evidence.first.time, end = f.evidence.last.time;
    final nearby = [
      for (final m in snapshot?.messages ?? const <RaftbenchEvidenceMessage>[])
        if (m.channelId == f.evidence.first.channelId &&
            !ids.contains(m.id) &&
            m.time >= start - 120000 &&
            m.time <= end + 120000)
          m,
    ].take(4);
    return [...f.evidence, ...nearby]..sort((a, b) => a.time.compareTo(b.time));
  }

  @override
  bool get canScan =>
      consented &&
      analysisAllowed &&
      channelId.isNotEmpty &&
      options.isNotEmpty &&
      !loading;

  @override
  Future<void> analyze() async {
    if (!consented || !analysisAllowed || channelId.isEmpty || !roleAllowed()) {
      return;
    }
    final generation = ++_generation;
    final scopeKey = _scopeKey;
    final principal = identity();
    bool current() =>
        !_disposed &&
        generation == _generation &&
        identity() == principal &&
        roleAllowed();
    loading = true;
    failed = false;
    _snapshot = null;
    reviews = const {};
    selectedId = '';
    _changed();
    try {
      final targets = channelId == raftbenchWorkspaceScope
          ? ([...options]..sort((a, b) {
                  final byActivity = (b.activityAt ?? '').compareTo(
                    a.activityAt ?? '',
                  );
                  return byActivity != 0
                      ? byActivity
                      : a.value.compareTo(b.value);
                }))
                .take(raftbenchOverviewChannelLimit)
                .map((o) => o.value)
                .toList()
          : [channelId];
      final result = await loadRaftbenchChannelSnapshots(
        request,
        targets,
        isCurrent: current,
        now: now,
      );
      if (!current()) return;
      _snapshot = _Snapshot(scopeKey, result);
    } catch (_) {
      if (current()) failed = true;
    } finally {
      if (!_disposed && generation == _generation) {
        loading = false;
        _changed();
      }
    }
  }

  @override
  void setFilter(RaftbenchSignal? kind) {
    filter = kind;
    _changed();
  }

  @override
  void changeMinimum(String text) {
    final n = int.tryParse(text);
    if (n != null && n >= 2 && n <= 20) {
      minimum = n;
      reviews = const {};
      _changed();
    }
  }

  @override
  void drillTo(String channel) {
    drillChannelId = channel;
    _changed();
  }

  @override
  void clearDrill() => drillTo('');

  @override
  void chooseFinding(String id) {
    selectedId = id;
    _changed();
  }

  void _review(RaftbenchCueReview Function(RaftbenchCueReview) change) {
    final f = finding, r = review;
    if (f == null || r == null) return;
    reviews = {...reviews, f.id: change(r)};
    _changed();
  }

  @override
  void setNote(String note) => _review((r) => r.copyWith(note: note));
  @override
  void confirm() =>
      _review((r) => r.copyWith(status: RaftbenchReview.confirmed));
  @override
  void dismiss() =>
      _review((r) => r.copyWith(status: RaftbenchReview.dismissed));
  @override
  void reopen() =>
      _review((r) => r.copyWith(status: RaftbenchReview.needsReview));

  /// A scope picker change clears the channel drill (Web `chooseChannel`).
  void resetDrill() {
    if (drillChannelId.isEmpty) return;
    drillChannelId = '';
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
