import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:raft_ui/raft_ui.dart'
    show
        RaftForegroundPeriodic,
        RaftbenchDashboard,
        RaftbenchHostedPanel,
        RaftbenchOption,
        RaftbenchRun,
        RaftbenchServiceAgent,
        raftbenchHistoryDays;

/// One HTTP call of the signed-in session (`RaftClient.request`).
typedef RaftbenchRequest = Future<dynamic> Function(
  String method,
  String path, {
  Object? data,
  Map<String, dynamic>? query,
});

/// The conversation-insights panel (Web `HostedAnalysis.tsx`): reads the
/// server-owned dashboard every 5 seconds while the page is open, and writes
/// settings with the dashboard's revision.
///
/// Every result is fenced by [identity] (account, server, role) and by the
/// request order: a response that arrives after the identity changed, after a
/// newer load or while a save is running is dropped. A failure to load or save
/// is one generic state, as on the Web; the page never shows a partial result
/// as if it were current.
class RaftbenchHostedController extends ChangeNotifier
    implements RaftbenchHostedPanel {
  RaftbenchHostedController({
    required this.request,
    required this.identity,
    required this.roleAllowed,
    required this.analysisAllowed,
    required this.onEnabled,
    DateTime Function()? now,
    this.poll = true,
  }) : now = now ?? DateTime.now;

  final RaftbenchRequest request;

  /// Account generation, principal, server and role; a different value means
  /// every pending result belongs to someone else.
  final String Function() identity;
  final bool Function() roleAllowed;

  /// The server flag is confirmed on right now (not merely remembered).
  final bool Function() analysisAllowed;

  /// Whether the analysis is enabled, as the last dashboard said.
  final void Function(bool enabled) onEnabled;
  @override
  final DateTime Function() now;
  final bool poll;

  static const maxSources = 50;

  RaftbenchDashboard? _data;
  @override
  @override
  @override
  bool loading = true, saving = false, failed = false;
  @override
  int page = 1;
  @override
  List<RaftbenchServiceAgent> serviceAgents = const [];
  List<RaftbenchOption> _options = const [];
  List<String>? _selection;
  String? _historyDate;
  @override
  @override
  String? modelAgentId, modelLabel;

  late final String _identity = identity();
  int _loadSeq = 0, _mutationSeq = 0, _modelSeq = 0;
  bool _reading = false, _disposed = false;

  /// A write is in flight (Web `saving` ref): loads wait for it, while
  /// [saving] (the button state) stays on until the follow-up read ends.
  bool _writing = false;
  RaftForegroundPeriodic? _poll, _modelPoll;
  String? _polledAgent;

  @override
  RaftbenchDashboard? get data => analysisAllowed() ? _data : null;
  @override
  List<RaftbenchOption> get options => _options;
  List<String>? get selection => _selection;
  String? get historyDate => _historyDate;

  bool _current() =>
      !_disposed &&
      analysisAllowed() &&
      identity() == _identity &&
      roleAllowed();

  void start() {
    unawaited(load());
    if (poll) {
      _poll ??= RaftForegroundPeriodic(const Duration(seconds: 5), () {
        unawaited(load());
      });
    }
  }

  /// The channels the page offers. An input synced while the page builds, so
  /// it never notifies; the panel reads it in the same build.
  void setOptions(List<RaftbenchOption> next) {
    if (!_sameOptions(next)) _options = next;
  }

  bool _sameOptions(List<RaftbenchOption> next) {
    if (next.length != _options.length) return false;
    for (var i = 0; i < next.length; i++) {
      if (next[i].value != _options[i].value ||
          next[i].label != _options[i].label) {
        return false;
      }
    }
    return true;
  }

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  // Derived state the view shows (HostedAnalysis.tsx locals).

  /// The channels to analyze: the user's choice, else the saved ones, else
  /// the first 50 visible.
  @override
  List<String> get selected {
    final chosen = _selection;
    if (chosen != null) return chosen;
    final saved = data?.channelIds ?? const [];
    return saved.isNotEmpty
        ? saved
        : [for (final o in _options.take(maxSources)) o.value];
  }

  String _day(DateTime value) =>
      value.toUtc().toIso8601String().substring(0, 10);

  /// The analysis start date (UTC `yyyy-MM-dd`) the field shows.
  @override
  String get dateValue =>
      _historyDate ??
      (data?.historyFrom == null
          ? _day(now().subtract(const Duration(days: 7)))
          : data!.historyFrom!.substring(0, 10));

  @override
  bool get invalidHistory {
    final value = _historyDate;
    if (value == null) return false;
    final parsed = DateTime.tryParse('${value}T00:00:00Z');
    return value.isEmpty ||
        parsed == null ||
        !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value) ||
        !parsed.isBefore(now().toUtc());
  }

  /// Settings were edited and not applied yet.
  @override
  bool get changed => _selection != null || _historyDate != null;

  @override
  bool get emptyRange {
    final coverage = data?.coverage;
    return coverage != null &&
        coverage.totalMessages > 0 &&
        coverage.windowMessages == 0;
  }

  @override
  String? get availableHistory => data?.coverage?.latestAt?.substring(0, 10);

  @override
  RaftbenchRun? get run => data?.run;

  @override
  bool get emptyScan {
    final run = this.run;
    return emptyRange &&
        run?.failureReason == null &&
        (run?.report?.patterns.isEmpty ?? true) &&
        (data?.progress?.readMessages ?? 0) == 0 &&
        (run?.fetchedMessages ?? 0) == 0;
  }

  @override
  bool get noMaterial {
    final run = this.run;
    return run?.report != null &&
        run!.fetchedMessages == 0 &&
        (data?.progress?.readMessages ?? 0) == 0 &&
        run.failureReason == null;
  }

  /// The analysis is on and a run is queued, reading or not yet created.
  @override
  bool get busy {
    final data = this.data;
    if (data == null || !data.enabled || data.provisioning?.state == 'failed') {
      return false;
    }
    final run = data.run;
    return run == null || run.status == 'queued' || run.status == 'running';
  }

  /// A service-agent DM or assignment must not be offered while the settings
  /// are being edited on a configured analysis (Web `assignAgent` guard).
  @override
  bool get assignmentBlocked =>
      saving ||
      selected.isEmpty ||
      invalidHistory ||
      ((data?.revision ?? 0) > 0 && changed);

  // Loading.

  Future<void> load() async {
    if (!_current() || _writing || _reading) return;
    final seq = ++_loadSeq;
    _reading = true;
    try {
      final raw = await request('GET', '/raftbench', query: {'page': page});
      if (seq != _loadSeq || !_current()) return;
      final parsed = RaftbenchDashboard.parse(raw);
      _data = parsed;
      loading = false;
      failed = false;
      _changed();
      onEnabled(parsed.enabled);
      _syncModelPoll();
      try {
        final listed = await request('GET', '/raftbench/agents');
        if (seq == _loadSeq && _current()) {
          serviceAgents = RaftbenchServiceAgent.parseList(listed);
          _changed();
        }
      } catch (_) {
        if (seq == _loadSeq && _current()) {
          serviceAgents = const [];
          _changed();
        }
      }
    } catch (_) {
      if (seq == _loadSeq && _current()) {
        _data = null;
        loading = false;
        failed = true;
        _changed();
        onEnabled(false);
      }
    } finally {
      if (seq == _loadSeq) _reading = false;
    }
  }

  void _syncModelPoll() {
    final agent = data?.enabled == true && data?.provisioning?.state == 'active'
        ? data!.agentId
        : null;
    if (agent == _polledAgent) return;
    _polledAgent = agent;
    _modelPoll?.dispose();
    _modelPoll = null;
    _modelSeq++;
    if (agent == null) return;
    unawaited(_readModel(agent));
    if (poll) {
      _modelPoll = RaftForegroundPeriodic(const Duration(seconds: 60), () {
        unawaited(_readModel(agent));
      });
    }
  }

  Future<void> _readModel(String agent) async {
    final seq = _modelSeq;
    String? label;
    try {
      final value = await request('GET', '/agents/$agent/hosted-runtime/model');
      if (value is Map) {
        String? text(String key) {
          final v = value[key];
          return v is String && v.isNotEmpty ? v : null;
        }

        label =
            text('label') ??
            text('model') ??
            text('defaultLabel') ??
            text('default');
      }
    } catch (_) {
      label = null;
    }
    if (seq != _modelSeq || !_current() || _polledAgent != agent) return;
    modelAgentId = agent;
    modelLabel = label;
    _changed();
  }

  // Settings.

  @override
  void toggleChannel(String id) {
    final current = selected;
    _selection = current.contains(id)
        ? [
            for (final value in current)
              if (value != id) value,
          ]
        : [...current, id].take(maxSources).toList();
    _changed();
  }

  @override
  void setHistoryDate(String value) {
    _historyDate = value;
    _changed();
  }

  /// The "Past N days" shortcut: [days] before now, as a UTC date.
  @override
  void chooseHistoryDays(int days) {
    if (!raftbenchHistoryDays.contains(days)) return;
    _historyDate = _day(now().subtract(Duration(days: days)));
    _changed();
  }

  @override
  void setPage(int value) {
    page = value < 1 ? 1 : value;
    _changed();
    unawaited(load());
  }

  String _startIso(String day) =>
      DateTime.tryParse('${day}T00:00:00Z')?.toUtc().toIso8601String() ??
      '${day}T00:00:00.000Z';

  /// Enable or disable (`PUT /raftbench`). Enabling sends the chosen range;
  /// success clears the run and re-reads the dashboard.
  Future<void> save(
    bool enabled, {
    String? startDate,
    bool useDraftDate = true,
  }) async {
    final snapshot = data;
    if (!_current() || snapshot == null) return;
    final date = startDate ?? (useDraftDate ? _historyDate : null);
    saving = true;
    _writing = true;
    failed = false;
    _changed();
    _loadSeq++;
    _reading = false;
    final seq = ++_mutationSeq;
    try {
      await request(
        'PUT',
        '/raftbench',
        data: {
          'enabled': enabled,
          'channelIds': selected,
          'expectedRevision': snapshot.revision,
          if (enabled && date != null && date.isNotEmpty)
            'historyFrom': _startIso(date),
        },
      );
      if (seq == _mutationSeq && _current()) {
        _data = snapshot.copyWith(enabled: enabled, clearRun: true);
        _selection = null;
        _historyDate = null;
        page = 1;
        onEnabled(enabled);
        _syncModelPoll();
        _writing = false;
        _changed();
        await load();
      }
    } catch (_) {
      if (seq == _mutationSeq && _current()) {
        failed = true;
        _changed();
      }
    } finally {
      _writing = false;
      saving = false;
      if (seq == _mutationSeq && _current()) _changed();
    }
  }

  @override
  Future<void> toggleAnalysis() async {
    final snapshot = data;
    if (snapshot != null) await save(!snapshot.enabled);
  }

  /// Apply edited sources / range and restart (enabled stays on).
  @override
  Future<void> applySettings() => save(true);

  /// Restart from the newest source day (the "outside window" shortcut).
  @override
  Future<void> analyzeAvailableHistory() async {
    final day = availableHistory;
    if (day != null) await save(true, startDate: day);
  }

  @override
  Future<void> createServiceAgent() async {
    if (!_current() || saving) return;
    saving = true;
    _writing = true;
    failed = false;
    _changed();
    try {
      await request(
        'POST',
        '/raftbench/agents',
        data: const <String, Object?>{},
      );
    } catch (_) {
      if (_current()) {
        failed = true;
        _changed();
      }
    } finally {
      _writing = false;
      saving = false;
      if (_current()) {
        _changed();
        unawaited(load());
      }
    }
  }

  /// Bind a ready service agent (`PUT /raftbench/assignment`). The first
  /// assignment also carries the sources and the start date.
  @override
  Future<void> assignAgent(String agentId) async {
    final snapshot = data;
    if (!_current() || snapshot == null || assignmentBlocked) return;
    saving = true;
    _writing = true;
    failed = false;
    _changed();
    try {
      await request(
        'PUT',
        '/raftbench/assignment',
        data: {
          'agentId': agentId,
          'expectedRevision': snapshot.revision,
          if (snapshot.revision == 0) ...{
            'channelIds': selected,
            'historyFrom': _startIso(dateValue),
          },
        },
      );
      page = 1;
      onEnabled(true);
    } catch (_) {
      if (_current()) {
        failed = true;
        _changed();
      }
    } finally {
      _writing = false;
      saving = false;
      if (_current()) {
        _changed();
        unawaited(load());
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _loadSeq++;
    _mutationSeq++;
    _modelSeq++;
    _poll?.dispose();
    _modelPoll?.dispose();
    super.dispose();
  }
}
