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
import 'raftbench_hosted_analysis.dart';
import 'raftbench_legacy_rules.dart';
import 'raftbench_manager_overview.dart';
import 'raftbench_parts.dart';

/// The page and its gates: owner / admin only (the server role, never staff
/// access), then the server flag. A page that was confirmed on stays open when
/// a later evaluation cannot be determined, with new reads paused.
class RaftbenchPage extends StatefulWidget {
  const RaftbenchPage({
    super.key,
    required this.controller,
    required this.flag,
  });
  final WorkspaceController controller;
  final RaftbenchFlagController flag;

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
    final t = RaftTokens.of(context), ty = RaftbenchType(t);
    String tr(String s) => raftText(context, s);
    Widget notice(String title, String help) => _Scroll(
      child: RaftbenchCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr(title), style: ty.title()),
            const SizedBox(height: 8),
            Text(tr(help), style: ty.callout(color: t.muted)),
          ],
        ),
      ),
    );
    if (!canUseRaftBench(w.server?.string('role'))) {
      return notice(
        'RaftBench is for server administrators',
        'Only this server’s owner or administrators can open this overview. Existing channel permissions still apply.',
      );
    }
    final flag = widget.flag;
    if (!flag.pageEnabled) {
      // A flag that has not resolved yet shows nothing rather than flashing
      // "not enabled" (the first frame is the final one).
      if (!flag.resolved) {
        return ColoredBox(color: t.canvas, child: const SizedBox.expand());
      }
      return notice(
        'RaftBench is not enabled for this server',
        'This pilot is off by default and only available to explicitly enrolled servers.',
      );
    }
    return _AdminPage(
      key: ValueKey(pageIdentity(w)),
      controller: w,
      analysisAllowed: flag.analysisAllowed,
    );
  }
}

/// The scrolling canvas of the page (`px-5 py-4`, `max-w-7xl`).
class _Scroll extends StatelessWidget {
  const _Scroll({required this.child, this.controller});
  final Widget child;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: RaftTokens.of(context).canvas,
    child: SingleChildScrollView(
      controller: controller,
      primary: false,
      padding: raftScrollPadding(
        context,
        const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: child,
        ),
      ),
    ),
  );
}

class _AdminPage extends StatefulWidget {
  const _AdminPage({
    super.key,
    required this.controller,
    required this.analysisAllowed,
  });
  final WorkspaceController controller;
  final bool analysisAllowed;

  @override
  State<_AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<_AdminPage> {
  final scroll = ScrollController();
  final metricsKey = GlobalKey(), aiKey = GlobalKey();
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
    scroll.dispose();
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

  void _reveal(GlobalKey key) {
    final target = key.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 200),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context), ty = RaftbenchType(t);
    String tr(String s) => raftText(context, s);
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
        channelId: scope == raftbenchWorkspaceScope || scope.isEmpty
            ? null
            : scope,
      );
      if (scope.isNotEmpty) overview!.load();
    }
    final wide = raftBreakpointWidth(context) >= 768;
    final gap = wide ? 20.0 : 16.0;
    final scopeName = scope == raftbenchWorkspaceScope
        ? tr('Workspace overview')
        : choices.where((o) => o.value == scope).firstOrNull?.label ?? '';
    Widget tile({
      required RaftGlyph glyph,
      required String title,
      required String cue,
      required Color color,
      required GlobalKey target,
    }) => GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _reveal(target),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              RaftIcon(glyph, size: 22, color: t.ink),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: ty.callout(weight: FontWeight.w700)),
                    Text(cue, style: ty.caption(weight: FontWeight.w400)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    final tiles = [
      tile(
        glyph: RaftGlyph.barChart3,
        title: tr('Tasks and cost'),
        cue: tr('Database metrics · no AI scan needed'),
        color: t.colors['info-soft']!,
        target: metricsKey,
      ),
      tile(
        glyph: RaftGlyph.sparkles,
        title: tr('Conversation insights'),
        cue: tr('Reads selected channels · no DM replies'),
        color: t.colors['success-soft']!,
        target: aiKey,
      ),
    ];
    return _Scroll(
      controller: scroll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: gap,
        children: [
          if (!widget.analysisAllowed)
            RaftbenchCard(
              color: t.colors['warning-soft'],
              transparentBorder: true,
              child: Semantics(
                liveRegion: true,
                child: Text(
                  tr(
                    'Rollout status could not be refreshed. Your current evidence and review are preserved; new reads are paused until the status is confirmed.',
                  ),
                  style: ty.callout(),
                ),
              ),
            ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  tr('Workspace efficiency and cost'),
                  style: wide ? ty.display() : ty.title(),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                tr(
                  'Two views: task metrics from the database and AI insights from conversations.',
                ),
                style: ty.callout(color: t.muted),
              ),
            ],
          ),
          LayoutBuilder(
            builder: (context, box) {
              final two = raftBreakpointWidth(context) >= 640;
              if (!two) {
                return Column(spacing: 12, children: tiles);
              }
              return Row(
                spacing: 12,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [for (final x in tiles) Expanded(child: x)],
              );
            },
          ),
          RaftbenchCard(
            child: Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: wide ? 240 : 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('Task metrics and phrase-scan scope'),
                      style: ty.footnote(
                        weight: FontWeight.w600,
                        color: t.muted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    RaftSelectField<String>(
                      value: scope.isEmpty ? null : scope,
                      label: tr('Task metrics and phrase-scan scope'),
                      placeholder: 'Select a channel',
                      items: [
                        DropdownMenuItem(
                          value: raftbenchWorkspaceScope,
                          child: Text(tr('Workspace overview')),
                        ),
                        for (final o in choices)
                          DropdownMenuItem(
                            value: o.value,
                            child: Text(o.label),
                          ),
                      ],
                      onChanged: (value) {
                        setState(
                          () => channelId = value ?? raftbenchWorkspaceScope,
                        );
                        rules.resetDrill();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          KeyedSubtree(
            key: metricsKey,
            child: RaftbenchManagerOverview(controller: overview!),
          ),
          KeyedSubtree(
            key: aiKey,
            child: RaftbenchHostedAnalysis(
              controller: hosted,
              allowed: widget.analysisAllowed,
              onOpenAgent: _openAgent,
              onOpenMessage: _openMessage,
            ),
          ),
          RaftbenchLegacyRules(
            controller: rules,
            channelName: scopeName,
            onOpenMessage: _openMessage,
          ),
        ],
      ),
    );
  }
}
