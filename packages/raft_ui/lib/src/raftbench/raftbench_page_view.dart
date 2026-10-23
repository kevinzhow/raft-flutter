// The RaftBench page body (Web raftbench/RaftBenchPage.tsx): the notices of
// the gates, and the admin page with its link tiles, scope picker and the
// three sections. Pure presentation: the app owns the controllers.
import 'package:flutter/material.dart';

import '../../raft_ui.dart';
import 'raftbench_parts.dart';

/// The scrolling canvas (`px-5 py-4`, `max-w-7xl`).
class _Scroll extends StatelessWidget {
  const _Scroll({required this.child, this.controller});
  final Widget child;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: RaftTokens.of(context).canvas,
    child: SingleChildScrollView(
      key: const ValueKey('raftbench-scroll'),
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

/// "RaftBench is for server administrators" / "...is not enabled": a card
/// with a title and its help.
class RaftbenchNotice extends StatelessWidget {
  const RaftbenchNotice({super.key, required this.title, required this.help});
  final String title, help;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context), ty = RaftbenchType(t);
    return _Scroll(
      child: RaftbenchCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(raftText(context, title), style: ty.title()),
            const SizedBox(height: 8),
            Text(raftText(context, help), style: ty.callout(color: t.muted)),
          ],
        ),
      ),
    );
  }
}

/// The page while the rollout flag has not resolved: the canvas, nothing else.
class RaftbenchBlankPage extends StatelessWidget {
  const RaftbenchBlankPage({super.key});

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: RaftTokens.of(context).canvas,
    child: const SizedBox.expand(),
  );
}

/// The footer of a DM with the RaftBench service agent (Web ChatPanel
/// `raftbench-service-dm-notice`): the agent is read-only analysis, it never
/// replies, so the composer is replaced by an info banner.
class RaftbenchServiceDmNotice extends StatelessWidget {
  const RaftbenchServiceDmNotice({super.key});

  @override
  Widget build(BuildContext context) => ColoredBox(
    key: const ValueKey('raftbench-service-dm-notice'),
    color: RaftTokens.of(context).canvas,
    child: const Padding(
      padding: EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: RaftBanner(
        status: RaftBannerRecipeStatus.info,
        textAlign: TextAlign.center,
        description: 'This read-only analysis agent does not reply to DMs. Results appear on the RaftBench page.',
      ),
    ),
  );
}

class RaftbenchAdminView extends StatefulWidget {
  const RaftbenchAdminView({
    super.key,
    required this.overview,
    required this.hosted,
    required this.rules,
    required this.options,
    required this.scope,
    required this.onScope,
    required this.analysisAllowed,
    required this.onOpenAgent,
    required this.onOpenMessage,
  });
  final RaftbenchOverviewPanel overview;
  final RaftbenchHostedPanel hosted;
  final RaftbenchRulesPanel rules;
  final List<RaftbenchOption> options;

  /// [raftbenchWorkspaceScope], a channel id, or '' (the chosen channel is no
  /// longer a candidate).
  final String scope;
  final ValueChanged<String> onScope;
  final bool analysisAllowed;
  final void Function(String agentId) onOpenAgent;
  final void Function(String channelId, String messageId) onOpenMessage;

  @override
  State<RaftbenchAdminView> createState() => _RaftbenchAdminViewState();
}

class _RaftbenchAdminViewState extends State<RaftbenchAdminView> {
  final scroll = ScrollController();
  final metricsKey = GlobalKey(), aiKey = GlobalKey();

  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
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
    final scope = widget.scope;
    final wide = raftBreakpointWidth(context) >= 768;
    final gap = wide ? 20.0 : 16.0;
    final scopeName = scope == raftbenchWorkspaceScope
        ? tr('Workspace overview')
        : widget.options.where((o) => o.value == scope).firstOrNull?.label ??
              '';
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
                    // The cue is an inline span: its line box takes the 24px of
                    // the parent's line height, not the caption's 16.
                    Text(
                      cue,
                      style: ty
                          .caption(weight: FontWeight.w400)
                          .copyWith(height: 24 / 12),
                    ),
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
              if (raftBreakpointWidth(context) < 640) {
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
                      height: 40,
                      placeholder: 'Select a channel',
                      items: [
                        DropdownMenuItem(
                          value: raftbenchWorkspaceScope,
                          child: Text(tr('Workspace overview')),
                        ),
                        for (final o in widget.options)
                          DropdownMenuItem(
                            value: o.value,
                            child: Text(o.label),
                          ),
                      ],
                      onChanged: (value) =>
                          widget.onScope(value ?? raftbenchWorkspaceScope),
                    ),
                  ],
                ),
              ),
            ),
          ),
          KeyedSubtree(
            key: metricsKey,
            child: RaftbenchManagerOverview(controller: widget.overview),
          ),
          KeyedSubtree(
            key: aiKey,
            child: RaftbenchHostedAnalysis(
              controller: widget.hosted,
              allowed: widget.analysisAllowed,
              onOpenAgent: widget.onOpenAgent,
              onOpenMessage: widget.onOpenMessage,
            ),
          ),
          RaftbenchLegacyRules(
            controller: widget.rules,
            channelName: scopeName,
            onOpenMessage: widget.onOpenMessage,
          ),
        ],
      ),
    );
  }
}
