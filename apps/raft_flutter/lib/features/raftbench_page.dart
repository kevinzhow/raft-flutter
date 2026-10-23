// RaftBench (Web raftbench/RaftBenchPage.tsx): the owner / admin page behind
// the `raftbench_overview_v0` rollout. Tasks and cost, AI conversation
// insights per channel, and the collapsed legacy phrase rules.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/raft_location.dart' show RaftProfileKind;
import '../data/raftbench_access.dart';
import '../data/raftbench_flag_controller.dart';
import '../data/raftbench_hosted_controller.dart';
import '../data/raftbench_overview_controller.dart';
import '../data/raftbench_rules_controller.dart';
import '../data/workspace_controller.dart';
import 'management_support.dart' show pageIdentity;

/// The page and its gates: owner / admin only (the server role, never staff
/// access), then the server flag. A page that was confirmed on stays open when
/// a later evaluation cannot be determined, with new reads paused.
class RaftbenchPage extends StatefulWidget {
  const RaftbenchPage({
    super.key,
    required this.controller,
    required this.flag,
    this.now,
  });
  final WorkspaceController controller;
  final RaftbenchFlagController flag;

  /// The clock the page reads (windows, the default start date); tests and
  /// the parity harness freeze it.
  final DateTime Function()? now;

  @override
  State<RaftbenchPage> createState() => _RaftbenchPageState();
}

class _RaftbenchPageState extends State<RaftbenchPage> {
  RaftForegroundPeriodic? _refresh;

  WorkspaceController get w => widget.controller;

  @override
  void initState() {
    super.initState();
    widget.flag.addListener(_changed);
    w.addListener(_changed);
    // Web refreshes the rollout every 30 s, on focus and on visibility.
    _refresh = RaftForegroundPeriodic(const Duration(seconds: 30), () {
      if (canUseRaftBench(w.server?.string('role'))) {
        widget.flag.refresh(force: false);
      }
    });
    widget.flag.refresh(force: false);
  }

  @override
  void dispose() {
    _refresh?.dispose();
    widget.flag.removeListener(_changed);
    w.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!canUseRaftBench(w.server?.string('role'))) {
      return const RaftbenchNotice(
        title: 'RaftBench is for server administrators',
        help: 'Only this server’s owner or administrators can open this overview. Existing channel permissions still apply.',
      );
    }
    final flag = widget.flag;
    if (!flag.pageEnabled) {
      // A flag that has not resolved yet shows nothing rather than flashing
      // "not enabled" (the first frame is the final one).
      if (!flag.resolved) {
        return const RaftbenchBlankPage();
      }
      return const RaftbenchNotice(
        title: 'RaftBench is not enabled for this server',
        help: 'This pilot is off by default and only available to explicitly enrolled servers.',
      );
    }
    return _AdminPage(
      key: ValueKey(pageIdentity(w)),
      controller: w,
      analysisAllowed: flag.analysisAllowed,
      now: widget.now,
    );
  }
}

class _AdminPage extends StatefulWidget {
  const _AdminPage({
    super.key,
    required this.controller,
    required this.analysisAllowed,
    this.now,
  });
  final WorkspaceController controller;
  final bool analysisAllowed;
  final DateTime Function()? now;

  @override
  State<_AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<_AdminPage> {
  String channelId = raftbenchWorkspaceScope;
  bool consented = false;
  late final RaftbenchHostedController hosted;
  late final RaftbenchRulesController rules;
  RaftbenchOverviewController? overview;
  String? overviewScope;

  WorkspaceController get w => widget.controller;

  Future<dynamic> _request(
    String method,
    String path, {
    Object? data,
    Map<String, dynamic>? query,
  }) => w.client.request(method, path, data: data, query: query);

  @override
  void initState() {
    super.initState();
    bool role() => canUseRaftBench(w.server?.string('role'));
    hosted = RaftbenchHostedController(
      request: _request,
      identity: () => pageIdentity(w),
      roleAllowed: role,
      analysisAllowed: () => widget.analysisAllowed,
      now: widget.now,
      onEnabled: (enabled) {
        if (consented != enabled && mounted) {
          setState(() => consented = enabled);
        }
      },
    )..start();
    rules = RaftbenchRulesController(
      request: _request,
      identity: () => pageIdentity(w),
      roleAllowed: role,
      now: widget.now,
    );
    w.addListener(_changed);
    unawaited(w.refreshChannels());
  }

  @override
  void dispose() {
    w.removeListener(_changed);
    hosted.dispose();
    rules.dispose();
    overview?.dispose();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  List<RaftbenchOption> get options => [
    for (final c in w.channels)
      if (isRaftBenchChannel(c))
        RaftbenchOption(
          c.id,
          c.name,
          activityAt: c.json['lastMessageAt'] is String
              ? c.json['lastMessageAt'] as String
              : null,
          unjoinedPublic: c.type == 'channel' && c.json['joined'] == false,
        ),
  ];

  void _openAgent(String id) => w.openProfile(RaftProfileKind.agent, id);

  void _openMessage(String channel, String message) {
    unawaited(w.jumpToMessage(channel, message));
  }

  @override
  Widget build(BuildContext context) {
    final choices = options;
    final ids = {for (final o in choices) o.value};
    // A chosen channel that is no longer a candidate leaves the scope empty.
    final scope = channelId == raftbenchWorkspaceScope
        ? raftbenchWorkspaceScope
        : ids.contains(channelId)
        ? channelId
        : '';
    hosted.setOptions(choices);
    rules.configure(
      channelId: scope,
      options: choices,
      consented: consented,
      analysisAllowed: widget.analysisAllowed,
    );
    final membership = ([...ids]..sort()).join(',');
    final managerScope = '${pageIdentity(w)}|$scope|$membership';
    if (overviewScope != managerScope) {
      overview?.dispose();
      overviewScope = managerScope;
      overview = RaftbenchOverviewController(
        request: _request,
        identity: () => pageIdentity(w),
        roleAllowed: () => canUseRaftBench(w.server?.string('role')),
        now: widget.now,
        channelId: scope == raftbenchWorkspaceScope || scope.isEmpty
            ? null
            : scope,
      );
      if (scope.isNotEmpty) overview!.load();
    }
    return RaftbenchAdminView(
      overview: overview!,
      hosted: hosted,
      rules: rules,
      options: choices,
      scope: scope,
      onScope: (value) {
        setState(() => channelId = value);
        rules.resetDrill();
      },
      analysisAllowed: widget.analysisAllowed,
      onOpenAgent: _openAgent,
      onOpenMessage: _openMessage,
    );
  }
}
