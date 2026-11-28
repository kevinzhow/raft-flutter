import 'card.dart' show RaftCard;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'interaction.dart';
import 'system_inset.dart';
import 'tap_slop.dart';
import 'auth_page.dart';
import 'agent_profile.dart' show RaftPanelSection, raftPanelRuleColor;
import 'indicators.dart' show RaftSkeleton;
import 'panel_layout.dart' show RaftCssLineBox, RaftCssText;
import 'recipes/button_variants.g.dart';
import 'recipes/card.g.dart';

import 'recipes/recipe_router.dart'
    show raftPopoverSurfaceClasses, resolveRecipeClasses;
import 'components.dart' show RaftAvatar, RaftAvatarKind;
import 'collapsible.dart' show RaftShowMoreToggle;
import 'list_items.dart';
import 'mounted_avatar_recipe.dart';
import 'recipes/recipe_runtime.dart' show RaftSlotStyle;
import 'panel_edge.dart';
import 'side_panel_frame.dart';
import 'space.dart';
import 'design_primitives.dart';
import 'dialog_card.dart';
import 'dismiss_scope.dart';
import 'icons.dart';
import 'inline_badge_editor.dart';
import 'localization.dart';
import 'css_recipe_decoration.dart';
import 'recipe_surface.dart';
import 'mounted_task_chip.dart' show RaftMessageTaskStatus;
import 'raft/button.dart';
import 'task.dart';
import 'task_conversation_parts.dart';
import 'task_head_editor.dart';
import 'task_status_badge.dart';
import 'raft/ui_tokens.dart';
import 'task_head_pull_down.dart';
import 'task_reason_popover.dart';
import 'task_timeline.dart';
import 'tokens/tokens.dart' show RaftTypeScale;
import 'page_tokens.dart';
import 'theme.dart';
import 'tooltip.dart' show RaftTooltip;
import 'thread_composition.dart';
import 'thread_resolution_body.dart';
import 'status_bar.dart';

/// LegacyTaskPanel's container is selected by MainLayout, independently of
/// the modern task modal and of the task's accepted metadata.
/// Web v1.21.23 TaskProperties look (the Raft pack) or the a57b9dab one.
bool _webHead(RaftTokens t) =>
    t.option('taskModal.head', or: 'web23') == 'web23';

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
    this.panelBuilder,
    this.onCleanupDelete,
    this.onBack,
    this.unresolvedBody,
    this.legacyPresentation = RaftLegacyTaskPresentation.modal,
    this.page = false,
    this.inPlace = false,
    this.tasksPage = false,
    this.focusMode,
    this.displayNameFor,
    this.onViewInThread,
    this.conversation,
    this.onUpdateWithReason,
    this.viewerId,
  });

  /// Task v2: the task's own conversation (Web TaskConversationDialog). The
  /// bar names the task by its ref with the More menu, the head is editable
  /// and the properties add Source, Created at and Earlier discussion.
  final RaftTaskConversation? conversation;

  /// Leaves the task for the ordinary thread of its message (Web TaskModalBar
  /// "View in thread"); null when the task has no thread to show (legacy tasks,
  /// or a task whose message is itself a thread reply).
  final VoidCallback? onViewInThread;

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

  /// Beside a list (Web TaskContentSlot, `TaskConversationPage
  /// presentation="modal" page`): the dialog's frameless page filling its
  /// column, with the desktop head and its ×.
  final bool inPlace, tasksPage;
  final ({bool focused, VoidCallback toggle})? focusMode;
  final Future<void> Function() onRetry, onLoadAssignees;
  final Future<void> Function(String, dynamic) onUpdate;

  /// Task v2 reasons (Web TaskBacklogReasonPopover / TaskHandoffReasonPanel):
  /// moving into Backlog asks what would bring the task back in a popover
  /// under the status chip; choosing someone other than [viewerId] in the
  /// assignee picker asks what the task waits on them for inside the picker.
  /// Resolves false when the write failed. Null: no reason step.
  final Future<bool> Function(String field, dynamic value, String reason)?
  onUpdateWithReason;
  final String? viewerId;
  final String Function(dynamic) formatTime;
  final Widget Function(Widget parentSlot)? discussionBuilder;

  /// Composes an auxiliary panel within the task frame.
  final Widget Function(Widget conversation)? panelBuilder;
  final VoidCallback? onCleanupDelete;
  @override
  State<RaftTaskSurface> createState() => _RaftTaskSurfaceState();
}

enum _TaskDetailsPlacement { drawer, pinned }

_TaskDetailsPlacement? _detailsPlacement(RaftTaskSurface surface) {
  if (surface.tasksPage ||
      surface.legacy ||
      surface.conversation == null ||
      surface.unresolvedBody != null ||
      surface.error != null && !surface.loading) {
    return null;
  }
  if (surface.inPlace) return _TaskDetailsPlacement.pinned;
  if (surface.page) return _TaskDetailsPlacement.drawer;
  return null;
}

class _RaftTaskSurfaceState extends State<RaftTaskSurface> {
  bool historyOpen = false, descriptionExpanded = false;

  /// The head field being edited (task v2), keyed by task.
  ({Object? taskId, RaftTaskHeadField field})? editing;
  bool _preparingAmend = false;
  RaftTaskHeadField? get editingField =>
      editing != null && editing!.taskId == widget.task['id']
      ? editing!.field
      : null;

  Future<void> _startAmend(RaftTaskHeadField field) async {
    if (_preparingAmend) return;
    final id = widget.task['id'];
    final prepare = widget.conversation?.onPrepareAmend;
    if (prepare != null) {
      _preparingAmend = true;
      try {
        if (!await prepare()) return;
      } finally {
        _preparingAmend = false;
      }
    }
    if (mounted && widget.task['id'] == id) {
      setState(() => editing = (taskId: id, field: field));
    }
  }

  final popover = MenuController();
  final statusKey = GlobalKey(),
      pullDownStatusKey = GlobalKey(),
      reasonPanelKey = GlobalKey<RaftTaskReasonPanelState>();
  GlobalKey? backlogAnchor;

  /// Task v2 on a phone: whether the head (a row of the conversation) is on
  /// screen, and the head pulled down from the bar once it is not.
  final headInView = RaftTaskHeadVisibility();
  final barLink = LayerLink();
  final barFocus = FocusNode(debugLabel: 'task bar summary');
  bool headPanelOpen = false;

  final detailsFocus = FocusNode(debugLabel: 'task details toggle');
  bool detailsOpen = false;

  _TaskDetailsPlacement? get detailsPlacement => _detailsPlacement(widget);
  bool get drawerOpen =>
      detailsPlacement == _TaskDetailsPlacement.drawer && detailsOpen;

  /// Someone other than the viewer chosen in the picker: the reason step
  /// shows in the picker before the write.
  ({Map<String, String> value, String name})? handoff;
  final assigneeSearch = TextEditingController();
  String needle = '';
  @override
  void didUpdateWidget(RaftTaskSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.task['id'] != widget.task['id'] ||
        _detailsPlacement(oldWidget) != detailsPlacement) {
      detailsOpen = false;
    }
    if (oldWidget.task['id'] != widget.task['id'] ||
        oldWidget.task['description'] != widget.task['description']) {
      descriptionExpanded = false;
    }
  }

  @override
  void dispose() {
    headInView.dispose();
    barFocus.dispose();
    detailsFocus.dispose();
    assigneeSearch.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.tasksPage && widget.inPlace
      ? LayoutBuilder(
          builder: (context, constraints) =>
              buildSurface(context, taskColumnHeight: constraints.maxHeight),
        )
      : buildSurface(context);

  Widget buildSurface(BuildContext context, {double? taskColumnHeight}) {
    final t = RaftTokens.of(context), size = MediaQuery.sizeOf(context);
    final mobile = size.width < 768;
    final legacy = widget.legacy;
    final side =
        legacy && widget.legacyPresentation == RaftLegacyTaskPresentation.side;
    final fullscreen =
        widget.page ||
        widget.inPlace ||
        legacy &&
            widget.legacyPresentation == RaftLegacyTaskPresentation.mobileModal;
    final overlay = side || fullscreen;
    final body =
        widget.unresolvedBody ??
        (legacy
            ? legacyBody(context)
            : modernBody(context, taskColumnHeight: taskColumnHeight));
    // Web: modern modal `rounded-lg border border-line-muted bg-layer-popover
    // shadow-raft-xl` (theme-brutal: square, `border-2 border-black bg-white
    // shadow-brutal`); legacy modal is square with `shadow-raft-md`. CSS
    // borders take space and outer shadows never paint over the box, so the
    // frame is a bordered container whose shadow is painted underneath.
    final bordered = !(overlay || mobile);
    final borderWidth = bordered ? (1.0) : 0.0;
    final radius = BorderRadius.circular(legacy ? 0 : 8);
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
        child: pullDown(context, mobile, (dismissable) {
          final conversation = Column(
            children: [
              CompositedTransformTarget(
                link: barLink,
                child: header(context, mobile),
              ),
              Expanded(
                // The modern ThreadPanel is a raft-ui `Panel edge="attached"`
                // (`border-l-2 border-black`, elegant `border-l border-line-muted`):
                // its column starts 2px / 1px inside the modal frame, in the
                // modal. The shared rule (RaftPanelEdge) leaves the full-width
                // phone page without it. LegacyTaskPanel keeps its own
                // side-presentation border (`framed` below). Beside a list
                // (TaskContentSlot) the column draws the seam: Web's page
                // has no edge of its own there.
                child: legacy
                    ? body
                    : Container(
                        decoration: BoxDecoration(
                          border: widget.inPlace
                              ? null
                              : RaftPanelEdge.left(context),
                        ),
                        child: detailsPlacement == _TaskDetailsPlacement.drawer
                            ? raftTaskPullDownHost(
                                link: barLink,
                                open: drawerOpen,
                                onClose: closeDetailsDrawer,
                                pageDrawer: true,
                                panel: drawerOpen
                                    ? RaftBackDismiss(
                                        onDismiss: closeDetailsDrawer,
                                        child: properties(context),
                                      )
                                    : const SizedBox.shrink(),
                                child: body,
                              )
                            : dismissable(body),
                      ),
              ),
            ],
          );
          return widget.panelBuilder?.call(conversation) ?? conversation;
        }),
      ),
    );
    final edge = side && size.width >= 1024
        ? Border(left: BorderSide(color: t.colors['line-hairline']!, width: 1))
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
                  (legacy ? t.themeShadows.md : t.themeShadows.xl).paintOrder,
                  radius,
                ),
                child: Container(
                  key: frameKey,
                  decoration: RaftRecipeDecoration(
                    color: legacy ? t.canvas : t.popover,
                    border: Border.all(
                      color: t.colors['line-muted']!,
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
      // Beside a list the slot owns Escape (a field's Escape stays the
      // field's, Web TaskContentSlot `isOthersEscape`).
      shortcuts: widget.inPlace
          ? const <ShortcutActivator, Intent>{}
          : const {SingleActivator(LogicalKeyboardKey.escape): DismissIntent()},
      child: Actions(
        actions: {
          DismissIntent: CallbackAction<DismissIntent>(
            onInvoke: (_) {
              if (drawerOpen) {
                closeDetailsDrawer();
              } else if (headPanelOpen && !headInView.value) {
                closeHeadPanel(restoreFocus: true);
              } else {
                widget.onClose();
              }
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
    final conversation = widget.conversation;
    if (conversation != null && !widget.legacy) {
      final phone = mobile || widget.page;
      return RaftTaskConversationBar(
        conversation: conversation,
        taskNumber: task['taskNumber'],
        mobile: phone,
        onClose: phone ? widget.onBack ?? widget.onClose : widget.onClose,
        bottomBorder: widget.inPlace || widget.tasksPage
            ? RaftSidePanelFrame.headerRule(t)
            : null,
        detailsToggle: detailsPlacement == null ? null : detailsToggle(context),
        focusMode: widget.focusMode,
        compactPage: widget.tasksPage && phone,
        desktopBar: t.desktop && !phone && RaftInteraction.of(context).pointer,
        pageStatus: detailsPlacement == _TaskDetailsPlacement.drawer
            ? RaftTaskStatus(status: '${task['status']}')
            : null,
        summary: !summarizes(mobile)
            ? null
            : (label) => ValueListenableBuilder<bool>(
                valueListenable: headInView,
                builder: (context, inView, _) => inView
                    ? Text(
                        label,
                        key: const ValueKey('task-modal-bar-label'),
                        style: t.scale(
                          RaftTypeScale.subhead,
                          weight: FontWeight.w700,
                        ),
                      )
                    : RaftTaskBarSummary(
                        label: label,
                        status: '${task['status']}',
                        assignee: task['claimedById'] == null
                            ? null
                            : widget.displayNameFor?.call(
                                '${task['claimedByType']}',
                                '${task['claimedById']}',
                              ),
                        assigneeIsAgent: task['claimedByType'] == 'agent',
                        open: headPanelOpen,
                        focusNode: barFocus,
                        onToggle: () => headPanelOpen
                            ? closeHeadPanel(restoreFocus: true)
                            : setState(() => headPanelOpen = true),
                      ),
              ),
      );
    }
    if (widget.unresolvedBody != null) {
      return RaftThreadHeader(
        presentation: mobile
            ? RaftThreadPresentation.mobileModal
            : RaftThreadPresentation.modal,
        threadLabel: raftText(context, 'Thread'),
        backLabel: raftText(context, 'Close Task'),
        closeLabel: raftText(context, 'Close Task'),
        jumpLabel: raftText(context, 'Jump to Beginning'),
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
        minHeight: widget.legacy ? RaftMetrics.panelHeader : (53),
      ),
      padding: EdgeInsets.symmetric(horizontal: widget.legacy ? 20 : 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: t.colors[widget.legacy ? 'line-hairline' : 'line-muted']!,
            width: 1,
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
                message: raftText(context, 'Close Task'),
                excludeFromSemantics: true,
                child: RaftRecipeButton(
                  key: const ValueKey('task-back'),
                  variant: widget.legacy
                      ? RaftButtonRecipeVariant.default_
                      : RaftButtonRecipeVariant.outline,
                  size: RaftButtonRecipeSize.iconSm,
                  glyph: RaftGlyph.arrowLeft,
                  glyphSize: 14,
                  tooltip: 'Close Task',
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
                        ? 'Task #{taskNumber} · Legacy'
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
          if (widget.onViewInThread != null && !widget.legacy)
            RaftTooltip(
              message: raftText(context, 'View in thread'),
              excludeFromSemantics: true,
              child: RaftThreadViewButton(
                key: const ValueKey('task-modal-view-in-thread'),
                tooltip: 'View in thread',
                onPressed: widget.onViewInThread,
              ),
            ),
          if (showClose)
            // Web `CloseButton` (brutal: bordered, white, shadow-brutal-sm);
            // icon-only, so it carries its name as a tooltip.
            RaftTooltip(
              message: raftText(context, 'Close Task'),
              excludeFromSemantics: true,
              child: RaftCloseButton(
                key: const ValueKey('task-close'),
                tooltip: 'Close Task',
                onPressed: widget.onClose,
              ),
            ),
        ],
      ),
    );
  }

  Widget detailsToggle(BuildContext context) {
    final expanded = detailsOpen;
    final label = raftText(
      context,
      expanded ? 'Hide task details' : 'Show task details',
    );
    return RaftButton(
      key: const ValueKey('task-details-toggle'),
      glyph: expanded ? RaftGlyph.chevronUp : RaftGlyph.chevronDown,
      uiVariant: RaftButtonVariant.ghost,
      uiSize: RaftButtonSize.iconSm,
      minimumTargetSize: RaftInteraction.of(context).touch
          ? RaftMetrics.touchTarget
          : null,
      expandTouchTarget: false,
      tooltip: label,
      semanticLabel: label,
      semanticContainer: false,
      surfaceBuilder: (context, surface) =>
          Semantics(expanded: expanded, child: surface),
      focusNode: detailsFocus,
      onPressed: () {
        if (drawerOpen) {
          closeDetailsDrawer();
        } else {
          setState(() => detailsOpen = !detailsOpen);
        }
      },
    );
  }

  void closeDetailsDrawer() {
    if (!drawerOpen) return;
    setState(() => detailsOpen = false);
    detailsFocus.requestFocus();
  }

  Widget modernBody(BuildContext context, {double? taskColumnHeight}) {
    if (widget.error != null && widget.loading == false) {
      // ThreadPanel `resolveFailed`: title, body and an outline Retry; the
      // exception itself is never shown.
      return SingleChildScrollView(
        child: RaftThreadResolutionBody(
          loadingLabel: raftText(context, 'Loading thread…'),
          errorTitle: raftText(context, "Couldn't load this thread"),
          errorBody: raftText(
            context,
            "The thread couldn't be opened. If this channel recently became public, try again.",
          ),
          retryLabel: raftText(context, 'Retry'),
          onRetry: () => unawaited(widget.onRetry()),
        ),
      );
    }
    final buildDiscussion = widget.discussionBuilder;
    final placement = detailsPlacement;
    if (placement != null) {
      final discussion =
          buildDiscussion?.call(const SizedBox.shrink()) ??
          (widget.loading
              ? const Align(
                  alignment: Alignment.topCenter,
                  child: RaftSkeleton(height: 16),
                )
              : const SizedBox.expand());
      return placement == _TaskDetailsPlacement.drawer
          ? discussion
          : raftTaskPinnedHead(
              head: detailsOpen ? properties(context) : null,
              child: discussion,
            );
    }
    final inline = summarizes(MediaQuery.sizeOf(context).width < 768);
    final head = properties(context);
    if (buildDiscussion == null) {
      return SingleChildScrollView(
        child: Column(
          children: [head, if (widget.loading) const RaftSkeleton(height: 16)],
        ),
      );
    }
    if (widget.conversation == null) return buildDiscussion(head);
    // Task v2: pinned above the conversation, but on a phone its first row.
    return inline
        ? buildDiscussion(
            RaftTaskHeadInView(visibility: headInView, child: head),
          )
        : raftTaskPinnedHead(
            head: head,
            frameHeight: taskColumnHeight,
            child: buildDiscussion(const SizedBox.shrink()),
          );
  }

  /// On compact Tasks pages and phone modals the head scrolls with the
  /// conversation and the bar summarises the task once it is out of view.
  bool summarizes(bool mobile) =>
      widget.conversation != null &&
      !widget.legacy &&
      !widget.inPlace &&
      (widget.page ? widget.tasksPage : mobile);

  /// Closes the pulled-down head; focus goes back to the bar unless a press
  /// outside closed it (Web `TaskHeadPullDown`).
  void closeHeadPanel({required bool restoreFocus}) {
    if (!headPanelOpen) return;
    setState(() {
      headPanelOpen = false;
      if (backlogAnchor == pullDownStatusKey) backlogAnchor = null;
    });
    if (restoreFocus) barFocus.requestFocus();
  }

  /// The head pulled down from the bar, over the messages; [body] is what a
  /// press or a scroll start closes it from (never the bar itself).
  Widget pullDown(
    BuildContext context,
    bool mobile,
    Widget Function(Widget Function(Widget body) dismissable) build,
  ) {
    if (!summarizes(mobile)) return build((body) => body);
    return ValueListenableBuilder<bool>(
      valueListenable: headInView,
      builder: (context, inView, _) {
        final open = headPanelOpen && !inView;
        void close() => closeHeadPanel(restoreFocus: true);
        return raftTaskPullDownHost(
          link: barLink,
          open: open,
          onClose: close,
          panel: open
              ? RaftBackDismiss(
                  onDismiss: close,
                  child: properties(
                    context,
                    divider: !widget.tasksPage,
                    inPullDown: true,
                  ),
                )
              : const SizedBox.shrink(),
          child: build(
            (body) => raftTaskPullDownDismiss(
              open: open,
              onClose: () => closeHeadPanel(restoreFocus: false),
              onScrollClose: close,
              child: body,
            ),
          ),
        );
      },
    );
  }

  /// Web `TaskModalHead`: PanelSection (`border-t-0 bg-layer-panel`) holding
  /// the title (`mb-2 line-clamp-3 text-lg font-bold leading-snug`), the
  /// optional description (`mb-3 text-sm text-foreground-muted`, collapsed to
  /// three lines) and `TaskProperties`: the History toggle block
  /// (`mb-4 border-b pb-3`) and the wrapping facts row.
  Widget properties(
    BuildContext context, {
    bool divider = true,
    bool inPullDown = false,
  }) {
    final t = RaftTokens.of(context), task = widget.task;
    final hasStatus = raftTaskStatusVocabulary.contains('${task['status']}');
    final touchSlop = widget.tasksPage && RaftInteraction.of(context).touch;
    final inlineBadgePair =
        widget.tasksPage &&
        hasStatus &&
        (widget.canStatus || task['readOnlyReason'] != null) &&
        (task['claimedById'] == null || task['claimedByType'] == null);
    final description = '${task['description'] ?? ''}'.trim();
    // v1.21.23 PanelHeading is a bare flex slot: the title inherits the
    // body text (16/24 regular); a57b9dab drew it 18px bold.
    // Task v2 (Web TASK_HEAD_TITLE_CLASS): `text-headline
    // font-semibold text-foreground`.
    final titleStyle = widget.conversation != null
        ? t
              .scale(RaftTypeScale.headline, weight: FontWeight.w600)
              .copyWith(color: t.colors['foreground'])
        : _webHead(t)
        ? RaftTypography.body(
            t,
            size: 16,
            line: 24,
            color: t.colors['foreground'],
          ).copyWith(fontFamily: t.headingFont)
        : RaftTypography.heading(t, size: 18, line: 24.75);
    final displayTitle = Text(
      '${task['title'] ?? ''}',
      key: const ValueKey('task-modal-title'),
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
      style: titleStyle,
    );
    final section = RaftPanelSection(
      topBorder: false,
      horizontal: widget.tasksPage && widget.inPlace ? 16 : 20,
      gap: 0,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: headText(
            RaftTaskHeadField.title,
            '${task['title'] ?? ''}',
            widget.tasksPage &&
                    widget.inPlace &&
                    t.desktop &&
                    widget.conversation != null
                ? RaftCssLineBox(
                    style: DefaultTextStyle.of(context).style.merge(titleStyle),
                    textScaler: MediaQuery.textScalerOf(context),
                    child: displayTitle,
                  )
                : displayTitle,
          ),
        ),
        if (editingField == RaftTaskHeadField.description)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: headText(RaftTaskHeadField.description, description, null),
          )
        else if (description.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: headText(
              RaftTaskHeadField.description,
              description,
              LayoutBuilder(
                builder: (context, constraints) {
                  final style = widget.conversation == null
                      ? RaftTypography.heading(
                          t,
                          size: 14,
                          line: 20,
                          weight: FontWeight.w400,
                        ).copyWith(color: t.muted)
                      : t.scale(RaftTypeScale.subhead, color: t.muted);
                  final measure = TextPainter(
                    maxLines: 3,
                    text: TextSpan(text: description, style: style),
                    textDirection: Directionality.of(context),
                    textScaler: MediaQuery.textScalerOf(context),
                  )..layout(maxWidth: constraints.maxWidth);
                  final long = measure.didExceedMaxLines;
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
                        Padding(
                          padding: EdgeInsets.only(
                            top: RaftSpace.x1,
                            // The desktop body line extends below the inline
                            // TextLink's own footnote line.
                            bottom: t.desktop && widget.conversation != null
                                ? RaftSpace.half
                                : 0,
                          ),
                          child: RaftShowMoreToggle(
                            label: raftText(
                              context,
                              descriptionExpanded ? 'Collapse' : 'Show more',
                            ),
                            expanded: descriptionExpanded,
                            onPressed: () => setState(
                              () => descriptionExpanded = !descriptionExpanded,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          )
        else if (widget.conversation?.onAmend != null &&
            (task.containsKey('description') ||
                task['hasDescription'] == false))
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: RaftButton(
                key: const ValueKey('task-modal-add-description'),
                uiVariant: RaftButtonVariant.ghost,
                uiSize: RaftButtonSize.sm,
                label: 'Add a description',
                padding: widget.tasksPage
                    ? const EdgeInsets.only(right: 12)
                    : null,
                onPressed: () => _startAmend(RaftTaskHeadField.description),
              ),
            ),
          ),
        // v1.21.23 TaskProperties: the facts row first, History folds under it
        // (`pt-4` section eyebrow); a57b9dab put the History block above.
        if (!_webHead(t)) historyBlock(context),
        Wrap(
          key: const ValueKey('task-properties'),
          spacing: 24,
          runSpacing: RaftSpace.x2,
          crossAxisAlignment: inlineBadgePair
              ? WrapCrossAlignment.start
              : WrapCrossAlignment.center,
          children: [
            Padding(
              // The assignee chip's 2px top margin raises its row baseline by
              // half the margin. CSS baseline alignment moves Status down 1px.
              // ignore: raft_lints/off_grid_spacing -- inline badge baseline compensation
              padding: EdgeInsets.only(top: inlineBadgePair ? 1 : 0),
              child: property(
                context,
                'Status',
                status(context, inPullDown: inPullDown),
                // DescriptionList hangs a leading task-status-badge by 7 px.
                hang: hasStatus ? 7 : 0,
              ),
            ),
            property(
              context,
              'Assignee',
              assignee(context, touchSlop: touchSlop),
              hang: widget.conversation?.assigneeAvatar == null
                  ? RaftSpace.x1_5
                  : 0,
            ),
            if (widget.conversation?.source case final source?)
              property(context, 'Source', source),
            property(
              context,
              'Created by',
              Text(createdBy(context), style: detailsStyle(t)),
            ),
            if (widget.conversation?.createdAt case final createdAt?)
              property(
                context,
                'Created at',
                RaftCssText(
                  createdAt,
                  key: const ValueKey('task-modal-created-at'),
                  style: widget.tasksPage
                      ? t.scale(RaftTypeScale.monoMeta, mono: true)
                      : detailsStyle(t),
                ),
              ),
            if (widget.conversation?.earlierDiscussion case final earlier?)
              property(
                context,
                'Earlier discussion',
                RaftTaskPropertyLink(
                  key: const ValueKey('task-modal-earlier-discussion-open'),
                  semanticLabel:
                      "Open the earlier discussion in its message's thread",
                  onPressed: earlier.onOpen,
                  children: [Text(earlier.label, style: detailsStyle(t))],
                ),
              ),
          ],
        ),
        if (_webHead(t)) historyBlock(context),
        if (task['readOnlyReason'] != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              raftText(
                context,
                'This task predates the channel conversion. Only the source server can change it.',
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
          RaftTextButton(
            label: 'Delete task',
            onPressed: widget.onCleanupDelete,
          ),
      ],
    );
    // `PanelSection bg-layer-panel theme-brutal:bg-white` then `<Separator />`
    // (elegant 1px line-hairline, brutal 2px line-strong).
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ColoredBox(
          color: t.panel,
          child: touchSlop ? RaftTapSlopHost(child: section) : section,
        ),
        if (divider)
          ColoredBox(
            color: widget.tasksPage && t.panel.a == 1
                ? raftChromeBlend(t.ui.lineHairline, t.panel)
                : t.ui.lineHairline,
            child: SizedBox(height: t.border),
          ),
      ],
    );
  }

  /// A head field with its pencil (task v2), or its editor while edited.
  Widget headText(RaftTaskHeadField field, String value, Widget? display) {
    final amend = widget.conversation?.onAmend;
    return RaftTaskHeadText(
      field: field,
      value: value,
      display: display ?? const SizedBox.shrink(),
      revealOnHover: widget.tasksPage,
      editing: editingField == field,
      onEdit: () => _startAmend(field),
      onClose: () => setState(() => editing = null),
      onSave: amend == null ? null : (text) => amend(field, text),
    );
  }

  /// `mb-4 border-b border-line-muted theme-brutal:border-black/10 pb-3`
  /// around the History toggle (`mb-1 flex w-full items-center gap-1
  /// text-left text-xs font-bold` + 14px chevron) and, open, `mt-3` content.
  Widget historyBlock(BuildContext context) {
    final t = RaftTokens.of(context);
    final web = _webHead(t);
    return Padding(
      padding: web
          ? const EdgeInsets.only(top: 16)
          : const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: web ? EdgeInsets.zero : const EdgeInsets.only(bottom: 12),
        decoration: web
            ? null
            : BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: raftPanelRuleColor(t)),
                ),
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
                  padding: EdgeInsets.only(bottom: web ? 0 : 4),
                  child: Row(
                    spacing: 4,
                    children: [
                      RaftCssText(
                        raftText(context, 'History'),
                        // SectionEyebrow: 13/18 bold hint (v1.21.23).
                        style: web
                            ? t.sectionEyebrow()
                            : RaftTypography.body(
                                t,
                                size: 12,
                                line: 16,
                                weight: FontWeight.w700,
                                color: t.strong,
                              ),
                      ),
                      RaftIcon(
                        historyOpen
                            ? RaftGlyph.chevronDown
                            : RaftGlyph.chevronRight,
                        size: 14,
                        color: web ? t.colors['foreground-eyebrow'] : t.strong,
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
  TextStyle detailsStyle(RaftTokens t) => widget.tasksPage
      ? t.scale(RaftTypeScale.callout, color: t.colors['foreground'])
      : RaftTypography.body(
          t,
          size: 14,
          line: 20,
          color: _webHead(t) ? t.colors['foreground'] : t.muted,
        );

  TextStyle termStyle(RaftTokens t) => widget.tasksPage
      ? t.scale(
          RaftTypeScale.footnote,
          weight: FontWeight.w500,
          color: t.colors['foreground-hint'],
        )
      : _webHead(t)
      ? RaftTypography.body(
          t,
          size: 13,
          line: 18,
          weight: FontWeight.w500,
          color: t.colors['foreground-hint'],
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
  Widget property(
    BuildContext context,
    String label,
    Widget value, {
    double hang = 0,
  }) {
    final t = RaftTokens.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: widget.tasksPage ? RaftSpace.x3 - hang : RaftSpace.x2,
      crossAxisAlignment: widget.tasksPage
          ? CrossAxisAlignment.baseline
          : CrossAxisAlignment.center,
      textBaseline: widget.tasksPage ? TextBaseline.alphabetic : null,
      children: [
        RaftCssText(raftText(context, label), style: termStyle(t)),
        Flexible(
          child: widget.tasksPage
              ? ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 28),
                  child: Align(
                    widthFactor: 1,
                    heightFactor: 1,
                    alignment: AlignmentDirectional.centerStart,
                    child: value,
                  ),
                )
              : value,
        ),
      ],
    );
  }

  Widget status(BuildContext context, {bool inPullDown = false}) {
    final anchor = inPullDown ? pullDownStatusKey : statusKey;
    final value = '${widget.task['status']}';
    if (!raftTaskStatusVocabulary.contains(value)) return Text(value);
    final label = raftText(context, raftTaskStatusLabel(value));
    // Web: editor when the viewer may edit (or the row is read-only with a
    // reason, shown disabled); otherwise the plain StatusBadge.
    if (!widget.canStatus && widget.task['readOnlyReason'] == null) {
      return RaftTaskStatus(
        key: const ValueKey('task-properties-status-readonly'),
        status: value,
      );
    }
    final editor = RaftInlineBadgeEditor(
      key: const ValueKey('task-properties-status'),
      inlineProperty: widget.tasksPage,
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
              'This task predates the channel conversion. Only the source server can change it.',
            ),
      onSelect: (next) {
        if (next == 'backlog' &&
            value != 'backlog' &&
            widget.onUpdateWithReason != null) {
          setState(() => backlogAnchor = anchor);
        } else {
          unawaited(widget.onUpdate('status', next));
        }
      },
      taskStatus: raftTaskStatusOf(value),
    );
    if (widget.onUpdateWithReason == null) return editor;
    return RaftTaskReasonPopover(
      // Someone else may park the task meanwhile: nothing left to ask.
      open: backlogAnchor == anchor && value != 'backlog',
      anchorKey: anchor,
      panelKey: reasonPanelKey,
      onSubmit: (reason) async {
        final ok = await widget.onUpdateWithReason!(
          'status',
          'backlog',
          reason,
        );
        if (ok && mounted) setState(() => backlogAnchor = null);
        return ok;
      },
      onDismiss: () => setState(() => backlogAnchor = null),
      child: KeyedSubtree(key: anchor, child: editor),
    );
  }

  /// Web assignee `InlineBadgeEditor`: a badge (`bg-layer-panel
  /// text-foreground-strong`, theme-brutal white/black) that opens the search
  /// page's SelectionPopover (`w-[240px]`, titled "Assignee").
  Widget assignee(BuildContext context, {required bool touchSlop}) {
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
    // A hand-off's write keeps its picker open (the reason step shows a failure).
    final enabled =
        widget.canAssign && !done && (!widget.busy || handoff != null);
    final editor = RaftInlineBadgeEditor(
      key: const ValueKey('task-properties-assignee'),
      inlineProperty: widget.tasksPage && !assigned,
      personProperty: widget.tasksPage && assigned,
      label: label,
      selectedId: assigned
          ? '${task['claimedByType']}:${task['claimedById']}'
          : 'unassign',
      options: const [],
      enabled: enabled,
      tooltip: task['readOnlyReason'] != null
          ? raftText(
              context,
              'This task predates the channel conversion. Only the source server can change it.',
            )
          : done
          ? raftText(
              context,
              'Completed tasks cannot change assignees. Reopen the task first.',
            )
          : null,
      background: widget.tasksPage ? Colors.transparent : t.panel,
      foreground: widget.tasksPage && assigned ? t.ui.foreground : t.strong,
      indicator: widget.tasksPage ? RaftGlyph.chevronDown : RaftGlyph.pencil,
      onSelect: (_) {},
      onOpenChanged: (open) {
        if (!open) {
          handoff = null;
          return;
        }
        assigneeSearch.clear();
        needle = '';
        // The member list is read on first open (Web reads it with the
        // surface); the panel rebuilds when it lands.
        unawaited(widget.onLoadAssignees().catchError((_) {}));
      },
      panelBuilder: (context, close) => handoff != null
          ? RaftTaskReasonSurface(
              child: RaftTaskReasonPanel(
                key: ValueKey('handoff-${handoff!.value['id']}'),
                kind: RaftTaskReasonKind.handoff,
                name: handoff!.name,
                onCancel: () => setState(() => handoff = null),
                onSubmit: (reason) async {
                  final ok = await widget.onUpdateWithReason!(
                    'assignee',
                    handoff!.value,
                    reason,
                  );
                  if (ok && mounted) close();
                  return ok;
                },
              ),
            )
          : AnimatedBuilder(
              animation: assigneeSearch,
              builder: (context, _) => assigneePanel(context, close),
            ),
    );
    final trigger = touchSlop
        ? RaftTapSlopAnchor(
            minSize: assigned && enabled
                ? const Size.square(RaftMetrics.touchTarget)
                : Size.zero,
            child: editor,
          )
        : editor;
    final avatar = widget.conversation?.assigneeAvatar;
    return avatar == null
        ? trigger
        : Row(
            mainAxisSize: MainAxisSize.min,
            spacing: RaftSpace.x1_5,
            children: [
              avatar,
              Flexible(child: trigger),
            ],
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
      surfaceStyle: taskAssigneeSurface(t),
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
              final id = '${person['userId'] ?? person['id']}';
              if (selected == '${person['actorType']}:$id') return close();
              final value = {'type': '${person['actorType']}', 'id': id};
              if (widget.onUpdateWithReason != null &&
                  !(value['type'] == 'user' && id == widget.viewerId)) {
                return setState(
                  () => handoff = (
                    value: value,
                    name: '${person['displayName'] ?? person['name']}',
                  ),
                );
              }
              close();
              unawaited(widget.onUpdate('assignee', value));
            },
          ),
      ],
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
        raftText(context, 'No history yet'),
        style: RaftTypography.body(t, size: 12, line: 16, color: t.muted),
      );
    }
    final detail = RaftTypography.body(t, size: 12, line: 16, color: t.muted);
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
          (v) => v is String && raftTaskStatusVocabulary.contains(v),
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

      final transition = Row(
        spacing: 4,
        children: [
          badge(p['from']),
          Text('→', style: style),
          badge(p['to']),
        ],
      );
      // What would bring it back: only on a move into Backlog.
      final reason = p['reason'];
      if (p['to'] != 'backlog' || reason is! String || reason.isEmpty) {
        return transition;
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          transition,
          RaftTimelineText(reason, style: style),
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
    // A hand-off: what the task waits on the new assignee for.
    final handoff = p['reason'];
    if (type == 'assignee_changed' &&
        p['assigneeId'] != null &&
        handoff is String &&
        handoff.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RaftTimelineText(text, style: style),
          RaftTimelineText(handoff, style: style),
        ],
      );
    }
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
          RaftCard(
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
          RaftCard(
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

/// `w-[240px] border border-line-muted bg-layer-popover text-foreground-strong
/// shadow-raft-md` over the Card recipe.
RaftSlotStyle taskAssigneeSurface(RaftTokens t) {
  final card = RaftCardRecipe.resolve(
    states: t.recipeStates(),
    tokens: t.recipeTokens,
  ).root;
  // The Card classes of the current set with the Popover content treatment.
  final classes = raftPopoverSurfaceClasses(card.classes);
  return resolveRecipeClasses(classes, t.recipeStates(), t.recipeTokens);
}
