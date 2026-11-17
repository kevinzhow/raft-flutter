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
        help:
            'Only this server’s owner or administrators can open this overview. Existing channel permissions still apply.',
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
        help:
            'This pilot is off by default and only available to explicitly enrolled servers.',
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
  RaftbenchHostedController? hosted;
  String? hostedScope;
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
    hosted?.dispose();
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

  /// Web `EvidenceChip.open`: a cited top-level message opens its thread; a
  /// `#channel:shortId` reply resolves its parent through the message context
  /// and opens focused on the reply. False when the thread no longer resolves.
  Future<bool> _openEvidence(
    String channelId,
    String target,
    String messageId,
  ) async {
    final shortId = raftbenchParseEvidenceTarget(target).threadShortId;
    if (shortId == null) {
      await w.openThreadIdentity(
        parentChannelId: channelId,
        parentMessageId: messageId,
      );
      return true;
    }
    final Object? context;
    try {
      context = await _request(
        'GET',
        '/messages/context/$shortId',
        query: {'channelId': channelId},
      );
    } catch (_) {
      // Web lets the failure surface unhandled: the chip stays a link.
      return true;
    }
    final map = context is Map ? context : const {};
    final canonical = map['canonicalTarget'];
    final targetId = map['targetMessageId'];
    String? parent, threadChannel, parentChannel = channelId;
    if (canonical is Map &&
        canonical['kind'] == 'thread' &&
        canonical['threadParentMessageId'] is String) {
      parent = canonical['threadParentMessageId'] as String;
      if (canonical['channelId'] is String) {
        parentChannel = canonical['channelId'] as String;
      }
      if (canonical['threadChannelId'] is String) {
        threadChannel = canonical['threadChannelId'] as String;
      }
    } else if (targetId is String && targetId.isNotEmpty) {
      parent = targetId;
    }
    if (parent == null) return false;
    await w.openThreadIdentity(
      parentChannelId: parentChannel,
      parentMessageId: parent,
      focusedMessageId: messageId,
      initialThreadChannelId: threadChannel,
    );
    return true;
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
    rules.configure(
      channelId: scope,
      options: choices,
      consented: consented,
      analysisAllowed: widget.analysisAllowed,
    );
    final membership = ([...ids]..sort()).join(',');
    final managerScope = '${pageIdentity(w)}|$scope|$membership';
    // Web keys HostedAnalysis by the same scope: a new scope starts afresh.
    if (hostedScope != managerScope) {
      hosted?.dispose();
      hostedScope = managerScope;
      hosted = RaftbenchHostedController(
        request: _request,
        identity: () => pageIdentity(w),
        roleAllowed: () => canUseRaftBench(w.server?.string('role')),
        analysisAllowed: () => widget.analysisAllowed,
        now: widget.now,
        channelId: scope == raftbenchWorkspaceScope || scope.isEmpty
            ? null
            : scope,
        onEnabled: (enabled) {
          if (consented != enabled && mounted) {
            setState(() => consented = enabled);
          }
        },
      )..start();
    }
    hosted!.setOptions(choices);
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
      hosted: hosted!,
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
      onOpenEvidence: _openEvidence,
    );
  }
}
