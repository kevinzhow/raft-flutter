// Web v1.24 components/agent/subagentGroups.ts and stopSubagent.ts: the
// Activity tab's Subagents view, folded from the activity the page already
// holds. A row belongs to a subagent only by its explicit lineage marker
// (never by its text). Pure: no widgets, no network.
library;

/// `SubagentState`: `running` or a `SubagentOutcome`, or `ended` when the
/// activity says only that it ended.
enum SubagentState { running, done, failed, ceiling, stopped, ended }

/// How a lineage row reads as a presence light (`subagentRowPresence`).
enum SubagentPresence { busy, error, online }

/// One run of a subagent: the call that started it and its own id.
class SubagentGroup {
  SubagentGroup({
    required this.key,
    required this.startedAt,
    required this.lastAt,
  }) : state = SubagentState.ended;

  /// The run: the call that started it and its `taskId` when known.
  final String key;

  /// The call that started it: its title, and the raw log's link to it.
  String? parentToolUseId;

  /// What it was asked: the spawn row's summary, without Codex's operation
  /// prefix.
  String? title;
  String? subagentType;

  /// Its own id (`SubagentLineage.taskId`), which a stop names.
  String? taskId;
  SubagentState state;
  num startedAt;

  /// When it finished; null while it runs.
  num? endedAt;

  /// Its latest row.
  num lastAt;

  /// Its tool calls.
  int steps = 0;

  /// The tool it called last.
  String? lastToolName;

  /// Its own rows, oldest first, without the lineage marker.
  final List<Map<String, dynamic>> items = [];
}

Map<String, dynamic>? _entryOf(Map row) {
  final entry = row['entry'];
  return entry is Map ? Map<String, dynamic>.from(entry) : null;
}

/// The row's `subagent` lineage marker, or null.
Map<String, dynamic>? subagentLineageOf(Map row) {
  final entry = row['entry'];
  final lineage = entry is Map ? entry['subagent'] : null;
  return lineage is Map ? Map<String, dynamic>.from(lineage) : null;
}

String? _string(Object? value) =>
    value is String && value.isNotEmpty ? value : null;

Map<String, dynamic> _withoutLineage(Map row) {
  final entry = Map<String, dynamic>.from(row['entry'] as Map)
    ..remove('subagent');
  return {...Map<String, dynamic>.from(row), 'entry': entry};
}

/// A Codex collab summary leads with its operation (`spawnAgent: ...`); the
/// title is the task.
String? subagentTitleFromSpawnSummary(String toolInput) {
  final text = toolInput
      .replaceFirst(RegExp(r'^spawnAgent(?::\s*|$)'), '')
      .trim();
  return text.isEmpty ? null : text;
}

/// Whether a row opens or closes its subagent. Only lifecycle rows count: the
/// daemon's `subagent_activity` status rows and a hosted agent's system rows.
/// Other rows that carry a phase (a hosted agent's tool end says `active`) are
/// its steps, not its lifecycle.
bool? _lifecycleOf(Map<String, dynamic> entry, Map<String, dynamic> lineage) {
  final lifecycleRow =
      (entry['kind'] == 'status' &&
          entry['detailKind'] == 'subagent_activity') ||
      entry['kind'] == 'system';
  if (!lifecycleRow) return null;
  return switch (lineage['phase']) {
    'started' || 'progress' => true,
    'notification' || 'ended' => false,
    _ => null,
  };
}

/// The group key a row's lineage belongs to ([SubagentGroup.key]), as
/// [groupSubagents] keys them, so a row can open exactly its own run.
String? Function(Map<String, dynamic> lineage) subagentKeyResolver(
  List<Map<String, dynamic>> log,
) {
  // One call can start several subagents (a Kimi AgentSwarm, a Codex spawn
  // naming several threads). Claude's inner rows carry only the call; they
  // belong to that call's one task.
  final tasksByCall = <String, Set<String>>{};
  for (final row in log) {
    final lineage = subagentLineageOf(row);
    final call = _string(lineage?['parentToolUseId']);
    final task = _string(lineage?['taskId']);
    if (call != null && task != null) {
      (tasksByCall[call] ??= <String>{}).add(task);
    }
  }
  // A run is one call and one task: a swarm's subagents share the call, a
  // Kimi resume reuses the task under a new call, a Codex follow-up turn
  // keeps both.
  return (lineage) {
    final call = _string(lineage['parentToolUseId']);
    final taskOwn = _string(lineage['taskId']);
    if (call == null) return taskOwn;
    final tasks = tasksByCall[call];
    final task =
        taskOwn ?? (tasks != null && tasks.length == 1 ? tasks.first : null);
    return task != null ? '$call\u0000$task' : call;
  };
}

/// `groupSubagents`: the log's subagent runs, running first and then the most
/// recent.
List<SubagentGroup> groupSubagents(List<Map<String, dynamic>> log) {
  final groups = <String, SubagentGroup>{};
  final spawnSummaries = <String, ({String text, num at})>{};
  final keyOf = subagentKeyResolver(log);
  for (final row in log) {
    final entry = _entryOf(row);
    if (entry == null) continue;
    final at = row['timestamp'] as num;
    final callId = _string(entry['callId']);
    final toolInput = _string(entry['toolInput']);
    if (entry['kind'] == 'tool_start' && callId != null && toolInput != null) {
      spawnSummaries[callId] = (text: toolInput, at: at);
    }
    final lineage = subagentLineageOf(row);
    if (lineage == null) continue;
    final key = keyOf(lineage);
    if (key == null) continue;
    final group = groups.putIfAbsent(
      key,
      () => SubagentGroup(key: key, startedAt: at, lastAt: at),
    );
    group.parentToolUseId ??= _string(lineage['parentToolUseId']);
    group.subagentType ??= _string(lineage['subagentType']);
    group.taskId ??= _string(lineage['taskId']);
    group.lastAt = at;
    final opens = _lifecycleOf(entry, lineage);
    if (opens == true) {
      // A start (again, for a follow-up turn) opens it.
      group.state = SubagentState.running;
      group.endedAt = null;
      continue;
    }
    if (opens == false) {
      // Without an outcome (an older daemon, or a notification that is only
      // an update) it reads as ended; a later start reopens it.
      group.state = switch (lineage['outcome']) {
        'done' => SubagentState.done,
        'failed' => SubagentState.failed,
        'ceiling' => SubagentState.ceiling,
        'stopped' => SubagentState.stopped,
        _ => SubagentState.ended,
      };
      group.endedAt = at;
      continue;
    }
    if (entry['kind'] == 'status' &&
        entry['detailKind'] == 'subagent_activity') {
      continue;
    }
    if (entry['kind'] == 'tool_start') {
      group.steps += 1;
      group.lastToolName = _string(entry['toolName']);
    }
    group.items.add(_withoutLineage(row));
  }
  for (final group in groups.values) {
    // Its start may have scrolled out of the loaded activity: what is left
    // reads as ended at its last row, never as still running time.
    if (group.state != SubagentState.running && group.endedAt == null) {
      group.endedAt = group.lastAt;
    }
    final call = group.parentToolUseId;
    final spawn = call == null ? null : spawnSummaries[call];
    if (spawn != null) {
      group.title = subagentTitleFromSpawnSummary(spawn.text);
      if (spawn.at < group.startedAt) group.startedAt = spawn.at;
    }
  }
  final out = groups.values.toList();
  // Running first, then the most recent (a stable sort, like JS).
  final indexed = out.indexed.toList()
    ..sort((a, b) {
      final running =
          (b.$2.state == SubagentState.running ? 1 : 0) -
          (a.$2.state == SubagentState.running ? 1 : 0);
      if (running != 0) return running;
      final recent = b.$2.startedAt.compareTo(a.$2.startedAt);
      return recent != 0 ? recent : a.$1.compareTo(b.$1);
    });
  return [for (final g in indexed) g.$2];
}

/// `subagentRowPresence`: a system row that is a subagent's lifecycle reads as
/// that subagent's state, not as an error.
SubagentPresence? subagentRowPresence(Map<String, dynamic>? lineage) =>
    switch (lineage?['phase']) {
      'started' || 'progress' => SubagentPresence.busy,
      'notification' || 'ended' =>
        lineage!['outcome'] == 'failed'
            ? SubagentPresence.error
            : SubagentPresence.online,
      _ => null,
    };
