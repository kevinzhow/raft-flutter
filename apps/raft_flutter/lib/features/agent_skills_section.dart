import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';

/// How fresh the Computer's skill list is (Web `AgentSkills` `SkillsData.state`).
enum AgentSkillsState {
  /// The Computer answered in time (older servers send no state).
  ok,

  /// The Computer did not answer in time: its last list, possibly out of date.
  stale,

  /// No list in time: the server sent empty lists.
  unavailable,
}

/// `GET /agents/:id/skills` body: `{global, workspace, state}` (Web
/// `parseSkillsData`: lists that are not lists are empty, an unknown state is ok).
class AgentSkillsAnswer {
  const AgentSkillsAnswer({
    this.global = const [],
    this.workspace = const [],
    this.state = AgentSkillsState.ok,
  });

  factory AgentSkillsAnswer.parse(Object? body) {
    final data = body is Map ? body : const {};
    List<Map<String, dynamic>> rows(Object? v) => [
      for (final r in (v is List ? v : const []))
        if (r is Map) Map<String, dynamic>.from(r),
    ];
    return AgentSkillsAnswer(
      global: rows(data['global']),
      workspace: rows(data['workspace']),
      state: switch (data['state']) {
        'stale' => AgentSkillsState.stale,
        'unavailable' => AgentSkillsState.unavailable,
        _ => AgentSkillsState.ok,
      },
    );
  }

  final List<Map<String, dynamic>> global, workspace;
  final AgentSkillsState state;
}

/// Last accepted answer of one agent's skills, kept in the controller's
/// server-bound cache: a revisit shows it at its first frame and the read
/// refreshes it in place.
class _SkillsSnapshot {
  AgentSkillsAnswer? answer;

  /// A read the member asked for again failed (never the server's text).
  bool failed = false;
}

/// Web AgentSkills `embedded`: the "Skills" section of the profile. The list
/// can be fresh, stale (the Computer's last list with a Retry link) or
/// unavailable (an error with Retry); a failed read says so in catalog text,
/// never in the server's.
class AgentSkillsSection extends StatefulWidget {
  const AgentSkillsSection({
    super.key,
    required this.controller,
    required this.agentId,
  });
  final WorkspaceController controller;
  final String agentId;
  @override
  State<AgentSkillsSection> createState() => _AgentSkillsSectionState();
}

class _AgentSkillsSectionState extends State<AgentSkillsSection> {
  WorkspaceController get w => widget.controller;
  late _SkillsSnapshot snapshot = _snapshot();
  _SkillsSnapshot _snapshot() => w.agentTabCache.putIfAbsent(
    'skills/${widget.agentId}',
    _SkillsSnapshot.new,
  ) as _SkillsSnapshot;
  int _ticket = 0;
  bool _reading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_read(explicit: false));
  }

  @override
  void didUpdateWidget(AgentSkillsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.agentId != widget.agentId) {
      snapshot = _snapshot();
      unawaited(_read(explicit: false));
    }
  }

  /// A refresh in the background keeps a list already shown; the member's own
  /// Retry takes whatever the read says (Web `fetchSkills`).
  Future<void> _read({required bool explicit}) async {
    final ticket = ++_ticket;
    final held = snapshot;
    setState(() {
      _reading = true;
      if (explicit) held.failed = false;
    });
    AgentSkillsAnswer? answer;
    var failed = false;
    try {
      answer = AgentSkillsAnswer.parse(
        await w.query('/agents/${widget.agentId}/skills'),
      );
    } catch (_) {
      failed = true;
    }
    if (!mounted || ticket != _ticket || !identical(held, snapshot)) {
      // Left the page: a good answer still warms the cache for the revisit.
      if (answer != null && answer.state != AgentSkillsState.unavailable) {
        held.answer = answer;
      }
      return;
    }
    setState(() {
      _reading = false;
      final shown = held.answer;
      final keepShown =
          !explicit &&
          shown != null &&
          (failed || answer?.state == AgentSkillsState.unavailable);
      if (keepShown) return;
      held.failed = failed;
      if (answer != null) held.answer = answer;
    });
  }

  List<RaftSkillItem> _items(List<Map<String, dynamic>> rows) => [
    for (final s in rows)
      RaftSkillItem(
        name: '${s['name'] ?? ''}',
        displayName: '${s['displayName'] ?? s['name'] ?? ''}',
        description: '${s['description'] ?? ''}',
        sourcePath: '${s['sourcePath'] ?? ''}',
        userInvocable: s['userInvocable'] == true,
      ),
  ];

  @override
  Widget build(BuildContext context) {
    final answer = snapshot.answer;
    final unavailable = answer?.state == AgentSkillsState.unavailable;
    return RaftSkillsSection(
      global: _items(answer?.global ?? const []),
      workspace: _items(answer?.workspace ?? const []),
      // Only a first read waits; a refresh never blanks the list.
      loading: answer == null && !snapshot.failed && _reading,
      error: snapshot.failed
          ? raftText(context, 'Failed to load skills')
          : unavailable
          ? raftText(
              context,
              'Could not load skills from this Computer in time. Try again later.',
            )
          : null,
      stale: answer?.state == AgentSkillsState.stale && !snapshot.failed,
      onRetry: () => unawaited(_read(explicit: true)),
    );
  }
}
