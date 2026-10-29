// What the RaftBench views read and call. The app's controllers (network,
// identity fencing, polling) implement these; the views are pure presentation
// and know nothing about the API.
import 'package:flutter/foundation.dart';

import 'raftbench_metrics.dart';
import 'raftbench_models.dart';
import 'raftbench_rules.dart';

/// The `all` scope of the page's channel picker.
const raftbenchWorkspaceScope = 'workspace';

/// Web `OVERVIEW_CHANNEL_LIMIT`: a workspace scan reads this many channels.
const raftbenchOverviewChannelLimit = 20;

/// The "Past N days" shortcuts of the start-date field.
const raftbenchHistoryDays = [7, 30, 90];

/// A channel the analysis can read: id and display name (`#general`-style
/// names are matched against evidence targets). [activityAt] (last message
/// time) orders the legacy workspace scan; [unjoinedPublic] marks a public
/// channel the viewer has not joined.
class RaftbenchOption {
  const RaftbenchOption(
    this.value,
    this.label, {
    this.activityAt,
    this.unjoinedPublic = false,
  });
  final String value, label;
  final String? activityAt;
  final bool unjoinedPublic;
}

enum RaftbenchLoadKind { idle, loading, error, unavailable, ready }

/// One metric's load state (Web `Load<T>`).
class RaftbenchLoad<T> {
  const RaftbenchLoad(this.kind, [this.value]);
  const RaftbenchLoad.ready(T this.value) : kind = RaftbenchLoadKind.ready;
  final RaftbenchLoadKind kind;
  final T? value;
  bool get loading => kind == RaftbenchLoadKind.loading;
}

/// A reviewer's label and note for one cue; kept only until the scope changes
/// or the scan is refreshed (nothing is sent anywhere).
class RaftbenchCueReview {
  const RaftbenchCueReview(this.status, this.note);
  final RaftbenchReview status;
  final String note;
  static const unreviewed = RaftbenchCueReview(RaftbenchReview.needsReview, '');
  RaftbenchCueReview copyWith({RaftbenchReview? status, String? note}) =>
      RaftbenchCueReview(status ?? this.status, note ?? this.note);
}

class RaftbenchChannelSummary {
  const RaftbenchChannelSummary(this.channelId, this.messages);
  final String channelId;
  final int messages;
}

/// The messages the legacy scan read, with what it could not read.
class RaftbenchOverviewSnapshot {
  const RaftbenchOverviewSnapshot({
    required this.messages,
    required this.fetchedAt,
    required this.historyLimited,
    required this.mayHaveOlder,
    required this.channels,
    required this.unavailableChannelIds,
    required this.requestedChannels,
  });
  final List<RaftbenchEvidenceMessage> messages;
  final DateTime fetchedAt;
  final bool historyLimited, mayHaveOlder;
  final List<RaftbenchChannelSummary> channels;
  final List<String> unavailableChannelIds;
  final int requestedChannels;
}

/// "Tasks and cost".
abstract interface class RaftbenchOverviewPanel implements Listenable {
  RaftbenchLoad<RaftbenchTaskPeriods> get tasks;
  RaftbenchLoad<RaftbenchTaskSnapshot> get snapshot;
  RaftbenchLoad<RaftbenchCostComparison> get costs;
  bool get anyLoading;
  Future<void> load();
}

/// "Conversation insights".
abstract interface class RaftbenchHostedPanel implements Listenable {
  RaftbenchDashboard? get data;
  bool get loading;
  bool get saving;
  bool get failed;
  int get page;
  List<RaftbenchServiceAgent> get serviceAgents;
  List<RaftbenchOption> get options;
  String? get modelAgentId;
  String? get modelLabel;
  List<String> get selected;
  String get dateValue;
  bool get invalidHistory;
  bool get changed;
  bool get emptyRange;
  bool get emptyScan;
  bool get noMaterial;
  bool get busy;
  bool get assignmentBlocked;
  String? get availableHistory;
  RaftbenchRun? get run;

  /// The clock (the default start date, the latest pickable day).
  DateTime Function() get now;
  void toggleChannel(String id);
  void setHistoryDate(String value);
  void chooseHistoryDays(int days);
  void setPage(int value);
  Future<void> toggleAnalysis();
  Future<void> applySettings();
  Future<void> analyzeAvailableHistory();
  Future<void> createServiceAgent();
  Future<void> assignAgent(String agentId);
}

/// The collapsed legacy phrase rules.
abstract interface class RaftbenchRulesPanel implements Listenable {
  String get channelId;
  List<RaftbenchOption> get options;
  int get minimum;
  RaftbenchSignal? get filter;
  String get drillChannelId;
  Map<String, RaftbenchCueReview> get reviews;
  bool get loading;
  bool get failed;
  bool get canScan;
  RaftbenchOverviewSnapshot? get snapshot;
  RaftbenchEvaluation get evaluation;
  List<RaftbenchFinding> get findings;
  RaftbenchFinding? get finding;
  RaftbenchCueReview? get review;
  int get pendingCount;
  Set<String> get evidenceIds;
  List<RaftbenchEvidenceMessage> get evidence;
  Future<void> analyze();
  void setFilter(RaftbenchSignal? kind);
  void changeMinimum(String text);
  void drillTo(String channel);
  void clearDrill();
  void chooseFinding(String id);
  void setNote(String note);
  void confirm();
  void dismiss();
  void reopen();
}
