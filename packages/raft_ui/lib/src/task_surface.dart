import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'interaction.dart';
import 'system_inset.dart';
import 'auth_page.dart';
import 'agent_profile.dart' show RaftPanelSection, raftPanelRuleColor;
import 'indicators.dart' show RaftSkeleton;
import 'panel_layout.dart' show RaftCssText;
import 'recipes/button_variants.g.dart';
import 'recipes/card.g.dart';
import 'recipes/recipe_utilities.g.dart';
import 'components.dart' show RaftAvatar, RaftAvatarKind;
import 'list_items.dart';
import 'mounted_avatar_recipe.dart';
import 'recipes/recipe_runtime.dart' show RaftSlotStyle;
import 'panel_edge.dart';
import 'design_primitives.dart';
import 'dialog_card.dart';
import 'icons.dart';
import 'inline_badge_editor.dart';
import 'localization.dart';
import 'css_recipe_decoration.dart';
import 'recipe_surface.dart';
import 'mounted_task_chip.dart' show RaftMessageTaskStatus;
import 'task.dart';
import 'task_status_badge.dart';
import 'task_timeline.dart';
import 'theme.dart';
import 'tooltip.dart' show RaftTooltip;
import 'thread_composition.dart';
import 'thread_resolution_body.dart';
import 'tokens/shadows.g.dart';
import 'status_bar.dart';

/// LegacyTaskPanel's container is selected by MainLayout, independently of
/// the modern task modal and of the task's accepted metadata.
enum RaftLegacyTaskPresentation { side, modal, mobileModal }

/// Mounted Source TaskModalBar/TaskModalHead/TaskProperties and the separate
/// LegacyTaskPanel. API and discussion ownership belong to the scoped model.
class RaftTaskSurface extends StatefulWidget {
  const RaftTaskSurface({
    super.key,
    required this.task,
    required this.history,
    required this.assignees,
    required this.legacy,
    required this.loading,
    required this.historyLoading,
    required this.busy,
    required this.canStatus,
    required this.canAssign,
    required this.canCleanupDelete,
    required this.statusOptions,
    required this.onClose,
    required this.onRetry,
    required this.onLoadAssignees,
    required this.onUpdate,
    required this.formatTime,
    this.error,
    this.historyError,
    this.discussionBuilder,
    this.onCleanupDelete,
    this.onBack,
    this.unresolvedBody,
    this.legacyPresentation = RaftLegacyTaskPresentation.modal,
    this.page = false,
    this.displayNameFor,
  });

  /// Display name of a known person (`type` is `user` or `agent`), as Web
  /// resolves it from the channel members; null falls back to `@handle`.
  final String? Function(String type, String id)? displayNameFor;
  final Map<String, dynamic> task;
  final List<Map<String, dynamic>> history, assignees;
  final bool legacy, loading, historyLoading, busy;
  final bool canStatus, canAssign, canCleanupDelete;
  final List<String> statusOptions;
  final Object? error, historyError;
  final VoidCallback onClose;
  final VoidCallback? onBack;
  final Widget? unresolvedBody;
  final RaftLegacyTaskPresentation legacyPresentation;
  final bool page;
  final Future<void> Function() onRetry, onLoadAssignees;
  final Future<void> Function(String, dynamic) onUpdate;
  final String Function(dynamic) formatTime;
  final Widget Function(Widget parentSlot)? discussionBuilder;
  final VoidCallback? onCleanupDelete;
  @override
  State<RaftTaskSurface> createState() => _RaftTaskSurfaceState();
}

class _RaftTaskSurfaceState extends State<RaftTaskSurface> {
  bool historyOpen = false, descriptionExpanded = false;
  final popover = MenuController();
  final assigneeSearch = TextEditingController();
  String needle = '';
  @override
  void didUpdateWidget(RaftTaskSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.task['id'] != widget.task['id'] ||
        oldWidget.task['description'] != widget.task['description']) {
      descriptionExpanded = false;
    }
  }

  @override
  void dispose() {
    assigneeSearch.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context), size = MediaQuery.sizeOf(context);
    final mobile = size.width < 768;
    final legacy = widget.legacy;
    final side =
        legacy && widget.legacyPresentation == RaftLegacyTaskPresentation.side;
    final fullscreen =
        widget.page ||
        legacy &&
            widget.legacyPresentation == RaftLegacyTaskPresentation.mobileModal;
    final overlay = side || fullscreen;
    final body =
        widget.unresolvedBody ??
        (legacy ? legacyBody(context) : modernBody(context));
    // Web: modern modal `rounded-lg border border-line-muted bg-layer-popover
    // shadow-raft-xl` (theme-brutal: square, `border-2 border-black bg-white
    // shadow-brutal`); legacy modal is square with `shadow-raft-md`. CSS
    // borders take space and outer shadows never paint over the box, so the
    // frame is a bordered container whose shadow is painted underneath.
    final bordered = !(overlay || mobile);
    final borderWidth = bordered ? (t.brutal ? 2.0 : 1.0) : 0.0;
    final radius = BorderRadius.circular(t.brutal || legacy ? 0 : 8);
    final frameKey = ValueKey(
      legacy ? 'legacy-task-panel' : 'task-thread-modal',
    );
    final panel = Material(
      key: bordered ? null : frameKey,
      color: legacy ? t.canvas : t.panel,
      child: SizedBox(
        width: overlay
            ? double.infinity
            : mobile
            ? size.width
            : math.min(legacy ? 760 : 960, size.width - 32) - 2 * borderWidth,
        height: overlay
            ? double.infinity
            : mobile
            ? size.height
            : math.min(legacy ? 720 : 900, size.height * (legacy ? .78 : .86)) -
                  2 * borderWidth,
        child: Column(
          children: [
            header(context, mobile),
            Expanded(
              // The modern ThreadPanel is a raft-ui `Panel edge="attached"`
              // (`border-l-2 border-black`, elegant `border-l border-line-muted`):
              // its column starts 2px / 1px inside the modal frame, in the
              // modal. The shared rule (RaftPanelEdge) leaves the full-width
              // phone page without it. LegacyTaskPanel keeps its own
              // side-presentation border (`framed` below).
              child: legacy
                  ? body
                  : Container(
                      decoration: BoxDecoration(
                        border: RaftPanelEdge.left(context),
                      ),
                      child: body,
                    ),
            ),
          ],
        ),
      ),
    );
    final edge = side && size.width >= 1024
        ? Border(
            left: BorderSide(
              color: t.brutal ? t.ink : t.colors['line-hairline']!,
              width: t.brutal ? 2 : 1,
            ),
          )
        : null;
    final framed = overlay || mobile
        // A full-height panel is a column under the status bar: its surface
        // and edge continue up through the band.
        ? RaftStatusBarSource(
            color: legacy ? t.canvas : t.panel,
            border: edge,
            child: DecoratedBox(
              position: DecorationPosition.foreground,
              decoration: BoxDecoration(border: edge),
              child: panel,
            ),
          )
        : RaftModalBackdrop(
            child: GestureDetector(
              onTap: () {},
              child: CustomPaint(
                painter: RaftOuterShadowPainter(
                  t.brutal
                      ? RaftProductShadows.shadowBrutal.paintOrder
                      : (legacy ? t.themeShadows.md : t.themeShadows.xl)
                            .paintOrder,
                  radius,
                ),
                child: Container(
                  key: frameKey,
                  decoration: RaftRecipeDecoration(
                    color: t.brutal
                        ? Colors.white
                        : legacy
                        ? t.canvas
                        : t.popover,
                    border: Border.all(
                      color: t.brutal ? Colors.black : t.colors['line-muted']!,
                      width: borderWidth,
                    ),
                    borderRadius: radius,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: panel,
                ),
              ),
            ),
          );
    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
      },
      child: Actions(
        actions: {
          DismissIntent: CallbackAction<DismissIntent>(
            onInvoke: (_) {
              widget.onClose();
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: overlay || mobile
              ? framed
              : GestureDetector(
                  onTap: widget.onClose,
                  behavior: HitTestBehavior.opaque,
                  child: framed,
                ),
        ),
      ),
    );
  }

  Widget header(BuildContext context, bool mobile) {
    final t = RaftTokens.of(context);
    final task = widget.task;
    final side =
        widget.legacy &&
        widget.legacyPresentation == RaftLegacyTaskPresentation.side;
    final showBack = side
        ? MediaQuery.sizeOf(context).width < 1024
        : mobile || widget.page;
    final showClose = widget.legacy
        ? widget.legacyPresentation == RaftLegacyTaskPresentation.modal &&
                  !mobile ||
              side && MediaQuery.sizeOf(context).width >= 1024
        : !mobile;
    if (widget.unresolvedBody != null) {
      return RaftThreadHeader(
        presentation: mobile
            ? RaftThreadPresentation.mobileModal
            : RaftThreadPresentation.modal,
        threadLabel: raftText(context, 'Thread'),
        backLabel: raftText(context, 'Close task'),
        closeLabel: raftText(context, 'Close task'),
        jumpLabel: raftText(context, 'Jump to beginning'),
        onBack: widget.onBack ?? widget.onClose,
        onClose: widget.onClose,
      );
    }
    return Container(
      key: const ValueKey('task-modal-bar'),
      // TaskModalBar px-4 py-2 with 16+20 line boxes and a 1/2px border.
      // LegacyTaskPanel uses the separate h-panel-header recipe.
      // The height is a minimum: larger text grows the bar, whose two-line
      // title would otherwise spill out of it.
      constraints: BoxConstraints(
        minHeight: widget.legacy
            ? (t.brutal
                  ? RaftMetrics.brutalPanelHeader
                  : RaftMetrics.panelHeader)
            : (t.brutal ? 54 : 53),
      ),
      padding: EdgeInsets.symmetric(horizontal: widget.legacy ? 20 : 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: t.brutal
                ? t.ink
                : t.colors[widget.legacy ? 'line-hairline' : 'line-muted']!,
            width: t.brutal ? 2 : 1,
          ),
        ),
      ),
      child: Row(
        spacing: 12,
        children: [
          if (showBack)
            // Web: `Button size="icon-sm" variant="outline" className="size-7"`
            // (legacy panel: the default variant).
            // Web's 28px square; the touch area is extended around it (outside
            // the tooltip, whose own box would otherwise clip the hit test).
            RaftTouchTargetExpander(
              minSize: Size.square(
                RaftInteraction.of(context).touch || mobile || widget.page
                    ? RaftMetrics.touchTarget
                    : 0,
              ),
              child: RaftTooltip(
                message: raftText(context, 'Close task'),
                excludeFromSemantics: true,
                child: RaftRecipeButton(
                  key: const ValueKey('task-back'),
                  variant: widget.legacy
                      ? RaftButtonRecipeVariant.default_
                      : RaftButtonRecipeVariant.outline,
                  size: RaftButtonRecipeSize.iconSm,
                  glyph: RaftGlyph.arrowLeft,
                  glyphSize: 14,
                  tooltip: 'Close task',
                  onPressed: widget.legacy
                      ? widget.onClose
                      : widget.onBack ?? widget.onClose,
                ),
              ),
            ),
          if (widget.legacy) const RaftIcon(RaftGlyph.fileText, size: 18),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '#${task['channelName'] ?? raftText(context, 'unknown')}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: RaftTypography.heading(
                    t,
                    size: widget.legacy ? 16 : 12,
                    line: widget.legacy ? 24 : 16,
                  ).copyWith(color: t.muted),
                ),
                Text(
                  raftFormat(
                    context,
                    widget.legacy
                        ? 'Task #{taskNumber} · LEGACY'
                        : 'Task #{taskNumber}',
                    {'taskNumber': task['taskNumber'] ?? ''},
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: RaftTypography.heading(
                    t,
                    size: widget.legacy ? 12 : 14,
                    line: widget.legacy ? 16 : 20,
                  ),
                ),
              ],
            ),
          ),
          if (showClose)
            // Web `CloseButton` (brutal: bordered, white, shadow-brutal-sm);
            // icon-only, so it carries its name as a tooltip.
            RaftTooltip(
              message: raftText(context, 'Close task'),
              excludeFromSemantics: true,
              child: RaftCloseButton(
                key: const ValueKey('task-close'),
                tooltip: 'Close task',
                onPressed: widget.onClose,
              ),
            ),
        ],
      ),
    );
  }

  Widget modernBody(BuildContext context) {
    final head = properties(context);
    if (widget.error != null && widget.loading == false)
      // ThreadPanel `resolveFailed`: title, body and an outline Retry; the
      // exception itself is never shown.
      return SingleChildScrollView(
        child: RaftThreadResolutionBody(
          loadingLabel: raftText(context, 'Loading...'),
          errorTitle: raftText(context, "Couldn't load this thread"),
          errorBody: raftText(
            context,
            "The thread couldn't be opened. If this channel just became public, retrying usually fixes it.",
          ),
          retryLabel: raftText(context, 'Retry'),
          onRetry: () => unawaited(widget.onRetry()),
        ),
      );
    final buildDiscussion = widget.discussionBuilder;
    if (buildDiscussion == null) {
      return SingleChildScrollView(
        child: Column(
          children: [head, if (widget.loading) const RaftSkeleton(height: 16)],
        ),
      );
    }
    return buildDiscussion(head);
  }

  /// Web `TaskModalHead`: PanelSection (`border-t-0 bg-layer-panel`) holding
  /// the title (`mb-2 line-clamp-3 text-lg font-bold leading-snug`), the
  /// optional description (`mb-3 text-sm text-foreground-muted`, collapsed to
  /// three lines) and `TaskProperties`: the History toggle block
  /// (`mb-4 border-b pb-3`) and the wrapping facts row.
  Widget properties(BuildContext context) {
    final t = RaftTokens.of(context), task = widget.task;
    final description = '${task['description'] ?? ''}'.trim();
    final section = RaftPanelSection(
      topBorder: false,
      gap: 0,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            '${task['title'] ?? ''}',
            key: const ValueKey('task-modal-title'),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: RaftTypography.heading(t, size: 18, line: 24.75),
          ),
        ),
        if (description.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final style = RaftTypography.heading(
                  t,
                  size: 14,
                  line: 20,
                  weight: FontWeight.w400,
                ).copyWith(color: t.muted);
                final measure = TextPainter(
                  text: TextSpan(text: description, style: style),
                  textDirection: Directionality.of(context),
                  textScaler: MediaQuery.textScalerOf(context),
                )..layout(maxWidth: constraints.maxWidth);
                final long = measure.height > 61;
                measure.dispose();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      description,
                      key: const ValueKey('task-modal-description'),
                      maxLines: long && !descriptionExpanded ? 3 : null,
                      overflow: long && !descriptionExpanded
                          ? TextOverflow.ellipsis
                          : TextOverflow.clip,
                      style: style,
                    ),
                    if (long)
                      RaftTextButton(
                        label: descriptionExpanded ? 'Collapse' : 'Show more',
                        onPressed: () => setState(
                          () => descriptionExpanded = !descriptionExpanded,
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        historyBlock(context),
        Wrap(
          key: const ValueKey('task-properties'),
          spacing: 24,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            property(context, 'Status', status(context)),
            property(context, 'Assignee', assignee(context)),
            property(
              context,
              'Created by',
              Text(createdBy(context), style: detailsStyle(t)),
            ),
          ],
        ),
        if (task['readOnlyReason'] != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              raftText(
                context,
                'This task predates the channel conversion. Only the source workspace can change it.',
              ),
              style: RaftTypography.body(
                t,
                size: 12,
                line: 16,
                color: Colors.black.withValues(alpha: .6),
              ),
            ),
          ),
        if (widget.canCleanupDelete && widget.onCleanupDelete != null)
          RaftTextButton(label: 'Delete', onPressed: widget.onCleanupDelete),
      ],
    );
    // `PanelSection bg-layer-panel theme-brutal:bg-white` then `<Separator />`
    // (elegant 1px line-hairline, brutal 2px line-strong).
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ColoredBox(color: t.brutal ? Colors.white : t.panel, child: section),
        ColoredBox(
          color: t.colors[t.brutal ? 'line-strong' : 'line-hairline']!,
          child: SizedBox(height: t.border),
        ),
      ],
    );
  }

  /// `mb-4 border-b border-line-muted theme-brutal:border-black/10 pb-3`
  /// around the History toggle (`mb-1 flex w-full items-center gap-1
  /// text-left text-xs font-bold` + 14px chevron) and, open, `mt-3` content.
  Widget historyBlock(BuildContext context) {
    final t = RaftTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: raftPanelRuleColor(t))),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RaftInteractive(
              key: const ValueKey('task-properties-history'),
              semanticLabel: raftText(context, 'History'),
              onPressed: () => setState(() => historyOpen = !historyOpen),
              builder: (context, state) => Semantics(
                expanded: historyOpen,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    spacing: 4,
                    children: [
                      RaftCssText(
                        raftText(context, 'History'),
                        style: RaftTypography.body(
                          t,
                          size: 12,
                          line: 16,
                          weight: FontWeight.w700,
                          color: t.brutal ? Colors.black : t.strong,
                        ),
                      ),
                      RaftIcon(
                        historyOpen
                            ? RaftGlyph.chevronDown
                            : RaftGlyph.chevronRight,
                        size: 14,
                        color: t.brutal ? Colors.black : t.strong,
                      ),
                      const Spacer(),
                    ],
                  ),
                ),
              ),
            ),
            if (historyOpen)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: history(context),
              ),
          ],
        ),
      ),
    );
  }

  /// raft-ui `DescriptionDetails`: elegant `text-sm leading-5
  /// text-foreground-muted`, brutal `text-sm text-foreground`.
  TextStyle detailsStyle(RaftTokens t) => RaftTypography.body(
    t,
    size: 14,
    line: 20,
    color: t.brutal ? t.ink : t.muted,
  );

  /// raft-ui `DescriptionTerm`: elegant `text-[11px] font-medium leading-none
  /// text-foreground-placeholder`, brutal `text-xs text-foreground-strong/50`.
  TextStyle termStyle(RaftTokens t) => t.brutal
      ? RaftTypography.body(
          t,
          size: 12,
          line: 16,
          color: t.strong.withValues(alpha: .5),
        )
      : RaftTypography.body(
          t,
          size: 11,
          line: 11,
          weight: FontWeight.w500,
          color: t.colors['foreground-placeholder'],
        );

  String createdBy(BuildContext context) {
    final task = widget.task;
    final named = widget.displayNameFor?.call(
      '${task['createdByType']}',
      '${task['createdById']}',
    );
    return named ??
        '@${task['createdByName'] ?? raftTextZh(context, 'Unknown', '未知')}';
  }

  /// `PropertyRow`: `flex min-w-0 items-center gap-2` of `DescriptionTerm`
  /// (`mb-0 shrink-0`) and `DescriptionDetails` (`min-w-0`).
  Widget property(BuildContext context, String label, Widget value) {
    final t = RaftTokens.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 8,
      children: [
        RaftCssText(raftText(context, label), style: termStyle(t)),
        Flexible(child: value),
      ],
    );
  }

  Widget status(BuildContext context) {
    final value = '${widget.task['status']}';
    if (!raftTaskStatuses.contains(value)) return Text(value);
    final label = raftText(context, raftTaskStatusLabel(value));
    // Web: editor when the viewer may edit (or the row is read-only with a
    // reason, shown disabled); otherwise the plain StatusBadge.
    if (!widget.canStatus && widget.task['readOnlyReason'] == null) {
      return RaftTaskStatus(
        key: const ValueKey('task-properties-status-readonly'),
        status: value,
      );
    }
    return RaftInlineBadgeEditor(
      key: const ValueKey('task-properties-status'),
      // Web `badgeStatus`: the trigger is the TaskStatusBadge, so `uppercase`
      // does not apply.
      label: label,
      selectedId: value,
      options: [
        for (final next in widget.statusOptions)
          RaftInlineBadgeOption(
            id: next,
            label: raftText(
              context,
              value == 'closed' && next == 'todo'
                  ? 'Reopen to Todo'
                  : raftTaskStatusLabel(next),
            ),
          ),
      ],
      enabled: widget.canStatus && !widget.busy,
      tooltip: widget.task['readOnlyReason'] == null
          ? null
          : raftText(
              context,
              'This task predates the channel conversion. Only the source workspace can change it.',
            ),
      onSelect: (next) => unawaited(widget.onUpdate('status', next)),
      taskStatus: raftTaskStatusOf(value),
    );
  }

  /// Web assignee `InlineBadgeEditor`: a badge (`bg-layer-panel
  /// text-foreground-strong`, theme-brutal white/black) that opens the search
  /// page's SelectionPopover (`w-[240px]`, titled "Assignee").
  Widget assignee(BuildContext context) {
    final t = RaftTokens.of(context), task = widget.task;
    final assigned =
        task['claimedById'] != null && task['claimedByType'] != null;
    final unassigned = raftTextZh(context, 'Unassigned', '未指派');
    final label = assigned
        ? widget.displayNameFor?.call(
                '${task['claimedByType']}',
                '${task['claimedById']}',
              ) ??
              '@${task['claimedByName'] ?? raftTextZh(context, 'Unknown', '未知')}'
        : unassigned;
    final done = task['status'] == 'done';
    final enabled = widget.canAssign && !done && !widget.busy;
    return RaftInlineBadgeEditor(
      key: const ValueKey('task-properties-assignee'),
      label: label,
      selectedId: assigned
          ? '${task['claimedByType']}:${task['claimedById']}'
          : 'unassign',
      options: const [],
      enabled: enabled,
      tooltip: task['readOnlyReason'] != null
          ? raftText(
              context,
              'This task predates the channel conversion. Only the source workspace can change it.',
            )
          : done
          ? raftText(
              context,
              'Completed tasks cannot change assignees. Reopen the task first.',
            )
          : null,
      background: t.brutal ? Colors.white : t.panel,
      foreground: t.brutal ? Colors.black : t.strong,
      onSelect: (_) {},
      onOpenChanged: (open) {
        if (!open) return;
        assigneeSearch.clear();
        needle = '';
        // The member list is read on first open (Web reads it with the
        // surface); the panel rebuilds when it lands.
        unawaited(widget.onLoadAssignees().catchError((_) {}));
      },
      panelBuilder: (context, close) => AnimatedBuilder(
        animation: assigneeSearch,
        builder: (context, _) => assigneePanel(context, close),
      ),
    );
  }

  Widget assigneePanel(BuildContext context, VoidCallback close) {
    final t = RaftTokens.of(context), task = widget.task;
    final selected =
        task['claimedById'] != null && task['claimedByType'] != null
        ? '${task['claimedByType']}:${task['claimedById']}'
        : 'unassign';
    final query = assigneeSearch.text.trim().toLowerCase();
    Widget avatar(Map<String, dynamic> person) {
      final agent = person['actorType'] == 'agent';
      return RaftAvatar(
        name: '${person['displayName'] ?? person['name']}',
        size: 20,
        kind: agent ? RaftAvatarKind.agent : RaftAvatarKind.human,
        mountedContext: RaftMountedAvatarContext.compactList,
        content: RaftMountedAvatarFallback(
          avatarContext: RaftMountedAvatarContext.compactList,
          identity: agent
              ? RaftMountedAvatarIdentity.agent
              : RaftMountedAvatarIdentity.human,
        ),
      );
    }

    final people = [
      for (final person in widget.assignees)
        if (query.isEmpty ||
            '${person['displayName'] ?? person['name']}'.toLowerCase().contains(
              query,
            ))
          person,
    ];
    final hasPeople = widget.assignees.isNotEmpty;
    return RaftSelectionPopover(
      title: raftText(context, 'Assignee'),
      width: 240,
      brutalProductShadow: true,
      surfaceStyle: assigneeSurface(t),
      searchController: assigneeSearch,
      searchPlaceholder: raftText(context, 'Search people and agents'),
      onSearchChanged: (_) {},
      options: [
        RaftSelectionOption(
          label: raftTextZh(context, 'Unassigned', '未指派'),
          checked: selected == 'unassign',
          reserveLeadingSlot: hasPeople,
          onTap: () {
            if (!widget.canAssign || widget.busy) return;
            close();
            if (selected != 'unassign') {
              unawaited(widget.onUpdate('assignee', null));
            }
          },
        ),
        for (final person in people)
          RaftSelectionOption(
            label: '${person['displayName'] ?? person['name']}',
            checked:
                selected ==
                '${person['actorType']}:${person['userId'] ?? person['id']}',
            leading: avatar(person),
            reserveLeadingSlot: true,
            onTap: () {
              if (!widget.canAssign || widget.busy) return;
              close();
              final id = '${person['userId'] ?? person['id']}';
              if (selected != '${person['actorType']}:$id') {
                unawaited(
                  widget.onUpdate('assignee', {
                    'type': person['actorType'],
                    'id': id,
                  }),
                );
              }
            },
          ),
      ],
    );
  }

  /// `w-[240px] border border-line-muted bg-layer-popover text-foreground-strong
  /// shadow-raft-md` (theme-brutal: `border-2 border-black bg-white text-black
  /// shadow-brutal`) over the Card recipe.
  RaftSlotStyle assigneeSurface(RaftTokens t) {
    final card = RaftCardRecipe.resolve(
      theme: t.recipeTheme,
      states: t.recipeStates(),
      tokens: t.recipeTokens,
    ).root;
    final classes = [
      ...card.classes.where(
        (name) => !const {
          'min-w-0',
          'border-2',
          'border-[0.5px]',
          'border-line-muted',
          'border-line-strong',
          'border-black',
          'bg-white',
          'bg-layer-panel',
          'shadow-raft-md',
          'shadow-raft-xs',
          'shadow-raft-sm',
        }.contains(name),
      ),
      t.brutal ? 'border-2' : 'border',
      t.brutal ? 'border-black' : 'border-line-muted',
      t.brutal ? 'bg-white' : 'bg-layer-popover',
      t.brutal ? 'text-black' : 'text-foreground-strong',
      if (!t.brutal) 'shadow-raft-md',
    ];
    return raftRecipeEngine.resolveSlot(
      [
        for (final name in classes)
          raftRecipeUtilities.indexWhere((utility) => utility.name == name),
      ],
      t.recipeStates(),
      t.recipeTokens,
    );
  }

  /// Web `TaskProperties` history: `Timeline size="sm"` of the visible events
  /// (resource receipts are CLI-only), an error line or the empty line.
  Widget history(BuildContext context) {
    final t = RaftTokens.of(context);
    if (widget.historyLoading) {
      return const Padding(
        padding: EdgeInsets.only(top: 12),
        child: RaftSkeleton(height: 16),
      );
    }
    if (widget.historyError != null) {
      return Text(
        raftText(context, 'Unable to load history.'),
        key: const ValueKey('task-history-error'),
        style: RaftTypography.body(
          t,
          size: 12,
          line: 16,
          color: t.colors['warning-strong'],
        ),
      );
    }
    final events = [
      for (final e in widget.history)
        if (e['eventType'] != 'resource_receipt_recorded') e,
    ];
    if (events.isEmpty) {
      return Text(
        raftText(context, 'No history yet.'),
        style: RaftTypography.body(
          t,
          size: 12,
          line: 16,
          color: t.brutal ? Colors.black.withValues(alpha: .5) : t.muted,
        ),
      );
    }
    final detail = RaftTypography.body(
      t,
      size: 12,
      line: 16,
      color: t.brutal ? Colors.black.withValues(alpha: .6) : t.muted,
    );
    String label(dynamic status) =>
        raftText(context, raftTaskStatusLabel('$status'));
    return RaftTimelineSm(
      entries: [
        for (final event in events)
          RaftTimelineEntry(
            status: historyStatus(event),
            title: raftText(context, switch (event['eventType']) {
              'created' => 'Created task',
              'amended' => 'Updated task',
              'status_changed' => 'Changed status',
              'assignee_changed' => 'Changed assignee',
              'closed' => 'Closed task',
              'reopened' => 'Reopened task',
              _ => '${event['eventType']}',
            }),
            meta:
                '${event['actorName'] ?? event['actorType']} · ${widget.formatTime(event['createdAt'])}',
            detail: _historyDetail(context, event, detail, label),
          ),
      ],
    );
  }

  /// Web `HistoryTimeline.historyStatus`: the status the event is about, so
  /// the marker paints from that status's own token. A closed event is
  /// `closed` and a reopened one `in_progress` when the payload names none.
  RaftMessageTaskStatus? historyStatus(Map<String, dynamic> event) {
    final payload = event['payload'] is Map
        ? event['payload'] as Map
        : const {};
    final status =
        [payload['to'], payload['status'], payload['from']].firstWhere(
          (v) => v is String && raftTaskStatuses.contains(v),
          orElse: () => null,
        ) ??
        switch (event['eventType']) {
          'closed' => 'closed',
          'reopened' => 'in_progress',
          _ => null,
        };
    return status == null ? null : raftTaskStatusOf('$status');
  }

  Widget? _historyDetail(
    BuildContext context,
    Map<String, dynamic> event,
    TextStyle style,
    String Function(dynamic) label,
  ) {
    final type = '${event['eventType']}';
    final p = event['payload'] is Map ? event['payload'] as Map : const {};
    if (const ['status_changed', 'closed', 'reopened'].contains(type) &&
        p['from'] != null &&
        p['to'] != null) {
      Widget badge(dynamic status) => RaftTaskStatusBadge(
        status: raftTaskStatusOf('$status'),
        label: label(status),
      );

      return Row(
        spacing: 4,
        children: [
          badge(p['from']),
          Text('→', style: style),
          badge(p['to']),
        ],
      );
    }
    String? text;
    if (type == 'created') {
      text = raftFormat(context, 'Task #{taskNumber} · Status: {status}', {
        'taskNumber': p['taskNumber'] ?? '—',
        'status': label(p['status'] ?? 'todo'),
      });
    } else if (type == 'amended' && p['changes'] is Map) {
      text = [
        for (final entry in (p['changes'] as Map).entries)
          () {
            final field = switch ('${entry.key}') {
              'title' => raftText(context, 'Title'),
              'description' => raftText(context, 'Description'),
              final other => other,
            };
            final v = entry.value;
            final from =
                v is Map && v.containsKey('from') && v.containsKey('to')
                ? '${v['from'] ?? '—'}'
                : '—';
            final to = v is Map && v.containsKey('from') && v.containsKey('to')
                ? '${v['to'] ?? '—'}'
                : v is String
                ? v
                : '$v';
            return raftFormat(context, '{field}: {from} → {to}', {
              'field': field,
              'from': from,
              'to': to,
            });
          }(),
      ].join(' · ');
    } else if (type == 'assignee_changed') {
      if (p['assigneeId'] == null) {
        text = raftText(context, 'Unassigned');
      } else {
        final kind = p['assigneeType'] == 'agent' ? 'agent' : 'user';
        text = raftFormat(context, 'Assigned to {name}', {
          'name':
              widget.displayNameFor?.call(kind, '${p['assigneeId']}') ?? kind,
        });
      }
    } else {
      text = [
        for (final entry in p.entries)
          if (entry.value != false && entry.value != null)
            '${entry.key}: ${entry.value is String ? entry.value : entry.value}',
      ].join(' · ');
    }
    if (text.isEmpty) return null;
    return RaftTimelineText(text, style: style);
  }

  Widget legacyBody(BuildContext context) {
    final t = RaftTokens.of(context), task = widget.task;
    String tr(String value) => raftText(context, value);
    return SingleChildScrollView(
      padding: raftScrollPadding(
        context,
        const EdgeInsets.fromLTRB(20, 16, 20, 32),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 16,
        children: [
          RaftTaskStatus(status: '${task['status']}'),
          RaftRecipeCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 12,
              children: [
                Text(
                  tr('Title'),
                  style: RaftTypography.mono(t, size: 12, line: 16),
                ),
                Text(
                  '${task['title'] ?? ''}',
                  style: RaftTypography.heading(t, size: 18, line: 28),
                ),
                Text(
                  tr('Description'),
                  style: RaftTypography.mono(t, size: 12, line: 16),
                ),
                Text(
                  '${task['description'] ?? ''}'.trim().isEmpty
                      ? tr('No description')
                      : '${task['description']}',
                  style: RaftTypography.heading(
                    t,
                    size: 14,
                    line: 20,
                    weight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          RaftRecipeCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              spacing: 8,
              children: [
                for (final entry in <String, String>{
                  'Created by': '@${task['createdByName'] ?? tr('Unknown')}',
                  'Created at': taskTime(task['createdAt']),
                  'Assignee': task['claimedByName'] == null
                      ? tr('Unassigned')
                      : '@${task['claimedByName']}',
                  'Completed': task['completedAt'] == null
                      ? tr('Not done')
                      : taskTime(task['completedAt']),
                }.entries)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 12,
                    children: [
                      Expanded(
                        child: Text(
                          entry.key == 'Created by'
                              ? raftTextZh(context, 'Created by', '创建者')
                              : tr(entry.key),
                          style: RaftTypography.mono(
                            t,
                            size: 14,
                            line: 20,
                          ).copyWith(color: t.muted),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          entry.value,
                          textAlign: TextAlign.right,
                          style: RaftTypography.heading(
                            t,
                            size: 14,
                            line: 20,
                            weight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          RaftAuthBanner(
            info: true,
            text:
                '${tr('Read-only panel')}\n${tr('Legacy tasks do not map to a message thread. This panel shows task metadata only, and posting is disabled.')}',
          ),
        ],
      ),
    );
  }

  String taskTime(dynamic value) => widget.formatTime(value);
}
