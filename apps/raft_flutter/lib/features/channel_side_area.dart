// Where the sections beside a conversation stand. Web v1.24 ChannelSideArea
// and rowPlan are the reference for the wide class only: there, side columns
// stand beside the conversation and give way to their content floors. Web's
// 160px clip and its rightmost-column tabs are gone, because they squeeze the
// chat and the panes below the width at which they can be read (Kevin,
// #raft-flutter:1f51a8b6, 2026-11-25: each screen class gets its own
// presentation; a pane never renders below its own minimum width, the chat
// never below 360). A pane that does not fit beside the chat waits behind the
// top one instead (`ChannelSideStack`). Compact and medium layouts cover the
// conversation.
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import 'channel_artifact_place.dart';
import 'channel_browser_place.dart';
import 'channel_files_media.dart';
import 'channel_details_host.dart';
import 'channel_side_card.dart';
import 'channel_side_cards.dart';
import 'channel_side_column.dart';
import 'channel_side_drag.dart';
import 'channel_side_flags.dart';
import 'channel_side_layout.dart';
import 'channel_side_stack.dart';
import 'channel_side_store.dart';
import 'channel_side_tasks_panel.dart';
import 'channel_side_web_preview.dart';
import 'channel_side_web_preview_panel.dart';
import 'mobile_route_gate.dart';
import 'panel_width_store.dart';
import 'source_channel_files_view.dart';

/// The chat keeps this much beside the columns (Web `MAIN_COLUMN_MIN_WIDTH`).
const channelSideChatMinWidth = 360.0;

/// A column may be shrunk to this (Web's 160 clip) and no further.
const channelSideColumnClip = 160.0;

/// Minimum detail pane width for a side panel to stand beside Activity or
/// Search chat instead of covering the detail pane.
const channelSideDetailBesideMinWidth = 640.0;

typedef PlacedChannelSideColumn = ({
  int column,
  List<ChannelSideSection> sections,
  double width,
});

class ChannelSidePlacement {
  const ChannelSidePlacement(this.mode, this.columns, {this.stackedBelow = 0});
  final ChannelSideMode mode;
  final List<PlacedChannelSideColumn> columns;

  /// Open panes waiting behind the shown one. Non-zero: the top pane's head
  /// draws a back arrow that pops it and reveals the one underneath.
  final int stackedBelow;
}

/// Where the open side columns [visible] stand in [width] px of room.
///
/// Each screen class gets its own presentation (Kevin, 2026-11-25); Web's
/// desktop rule is the reference for the wide class only.
///   - compact: the panes cover the conversation, as one stack.
///   - medium (768-1023, a foldable inner screen or a narrow desktop window):
///     the top pane covers the conversation full width. The rail and the
///     channel sidebar stay. Opening another pane stacks on top of it.
///   - wide: a pane stands beside the chat only if it fits there at its own
///     minimum width beside a [channelSideChatMinWidth] chat. The ones that
///     do not fit wait behind the top one instead of squeezing it; where not
///     even the top pane fits, the area covers.
/// A column is never laid out below its own minimum and the chat never below
/// [channelSideChatMinWidth].
ChannelSidePlacement placeChannelSide(
  List<VisibleChannelSideColumn> visible, {
  required double width,
  required bool compact,
  required RaftLayoutClass layout,
  ChannelSideStack stack = ChannelSideStack.unordered,
  double? conversationWidth,
  Map<int, double> dockWidths = const {},
  bool detailPane = false,
}) {
  if (visible.isEmpty) {
    return const ChannelSidePlacement(ChannelSideMode.beside, []);
  }
  if (compact || width < 2 * channelSideColumnClip) {
    return ChannelSidePlacement(ChannelSideMode.overlay, [
      (
        column: visible.first.column,
        sections: [for (final column in visible) ...column.sections],
        width: width,
      ),
    ]);
  }
  // The chat keeps 360 whether or not a thread is folded into its slot: the
  // folded thread replaces the chat there instead of standing beside it, so
  // reserving two chats' worth asked for room nothing rendered in. That is
  // why this function no longer needs to know about the thread at all.
  const chatFloor = channelSideChatMinWidth;
  final shown =
      layout == RaftLayoutClass.medium ||
          (detailPane && width < channelSideDetailBesideMinWidth)
      ? const <VisibleChannelSideColumn>[]
      : stack.fitting(visible, width: width, chatFloor: chatFloor);
  if (shown.isEmpty) return _coverChannelSide(visible, stack, width);
  final sideSaved = shown.fold(0.0, (sum, column) => sum + column.width);
  final saved = [
    conversationWidth ?? math.max(chatFloor, width - sideSaved),
    for (final column in shown)
      dockWidths[column.column] ?? column.width.toDouble(),
  ];
  final floors = [
    math.min(saved.first, chatFloor),
    for (var i = 0; i < shown.length; i++)
      math.min(saved[i + 1], shown[i].minWidth.toDouble()),
  ];
  final widths = _solveChannelSideWidths(saved, floors, width);
  return ChannelSidePlacement(ChannelSideMode.beside, [
    for (var i = 0; i < shown.length; i++)
      (
        column: shown[i].column,
        sections: shown[i].sections,
        width: widths[i + 1],
      ),
  ], stackedBelow: visible.length - shown.length);
}

/// The top pane over the whole conversation area, the rest waiting behind it.
ChannelSidePlacement _coverChannelSide(
  List<VisibleChannelSideColumn> visible,
  ChannelSideStack stack,
  double width,
) {
  final top = visible[stack.topOf(visible)];
  return ChannelSidePlacement(ChannelSideMode.overlay, [
    (column: top.column, sections: top.sections, width: width),
  ], stackedBelow: visible.length - 1);
}

double _contentFloor(VisibleChannelSideColumn column) =>
    math.min(column.width, column.minWidth).toDouble();

RaftWorkspaceSideRow channelSideRow(
  WorkspaceController w, {
  bool profile = false,
}) {
  final store = ChannelSideStore.of(w);
  final preview = WebPreviewStore.of(w);
  final details = ChannelDetailsStore.of(w);
  return (
    changes: Listenable.merge([
      store,
      preview,
      preview.browserTabs.placement,
      ChannelArtifactPlace.of(w),
      preview.platform.voiceOverState,
      details,
      ChannelSideFlags.of(w),
    ]),
    widths: () {
      final (open, _) = _openChannelSide(w, preview, details, profile: profile);
      var saved = 0.0;
      var floor = 0.0;
      for (final column in _visibleSideColumns(store, open)) {
        saved += column.width;
        floor += _contentFloor(column);
      }
      return (saved: saved, floor: floor);
    },
  );
}

bool _hostsChannelSideSection(
  WorkspaceController w, {
  required bool detailPane,
}) => detailPane
    ? (w.section == 'activity' || w.section == 'search')
    : w.section == 'chat';

(Set<ChannelSideSection>, WebPreviewPage?) _openChannelSide(
  WorkspaceController w,
  WebPreviewStore preview,
  ChannelDetailsStore details, {
  required bool profile,
  bool detailPane = false,
}) {
  final hosts = _hostsChannelSideSection(w, detailPane: detailPane);
  final channel = hosts ? ChannelSideCards.conversation(w) : null;
  final here = channel != null;
  final page = here ? preview.pageFor(channel.id) : null;
  return (
    {
      if (here)
        for (final card in ChannelSideCards.open(w))
          card == ChannelSideCard.tasks
              ? ChannelSideSection.tasks
              : ChannelSideSection.files,
      if (page != null || (here && ChannelSideCards.hasDesktopPlace(w)))
        ChannelSideSection.artifact,
      if (profile) ChannelSideSection.profile,
      if (hosts && details.channel != null) ChannelSideSection.details,
    },
    page,
  );
}

List<VisibleChannelSideColumn> _visibleSideColumns(
  ChannelSideStore store,
  Set<ChannelSideSection> open, {
  double? legacyThreadWidth,
}) {
  final columns = store.layout.visible(open);
  if (legacyThreadWidth != null && store.conversationWidth == null) {
    final index = columns.indexWhere(
      (column) =>
          column.sections.length == 1 &&
          column.sections.single == ChannelSideSection.thread &&
          column.width == channelSideSectionWidth(ChannelSideSection.thread),
    );
    if (index >= 0) {
      final column = columns[index];
      columns[index] = VisibleChannelSideColumn(
        column: column.column,
        sections: column.sections,
        width: legacyThreadWidth.round(),
        minWidth: column.minWidth,
      );
    }
  }
  if (!_profileOnly(open) ||
      columns.single.width !=
          channelSideSectionWidth(ChannelSideSection.profile)) {
    return columns;
  }
  final column = columns.single;
  return [
    VisibleChannelSideColumn(
      column: column.column,
      sections: column.sections,
      width: profilePanelWidth.value.round(),
      minWidth: column.minWidth,
    ),
  ];
}

bool _profileOnly(Set<ChannelSideSection> sections) =>
    sections.length == 1 && sections.contains(ChannelSideSection.profile);

/// The chat and the shown columns at [saved] px each, fitted into [available]:
/// they share the spare room in proportion, and give the deficit back toward
/// their [floors] in proportion to what each has above its own floor.
///
/// Nothing is ever laid out below its floor: only columns that fit at their
/// minimums beside a [channelSideChatMinWidth] chat are shown, so the floors
/// always add up to [available] or less. That is why Web's 160px clip is gone
/// from here (it was what squeezed a column below its own minimum).
List<double> _solveChannelSideWidths(
  List<double> saved,
  List<double> floors,
  double available,
) {
  final total = saved.fold(0.0, (sum, width) => sum + width);
  if (total <= available) {
    return [for (final width in saved) width * available / total];
  }
  final floorTotal = floors.fold(0.0, (sum, width) => sum + width);
  assert(
    floorTotal <= available + .01,
    'floors $floors do not fit in $available',
  );
  final ratio = (total - available) / (total - floorTotal);
  return [
    for (var i = 0; i < saved.length; i++)
      saved[i] - ratio * (saved[i] - floors[i]),
  ];
}

/// Whether [context] is inside a [ChannelSideArea]; when [requireHost] is
/// true, returns true only if that area can place sections for this route.
bool insideChannelSideArea(BuildContext context, {bool requireHost = true}) {
  final scope = context.getInheritedWidgetOfExactType<_ChannelSideAreaScope>();
  return requireHost ? (scope?.hosts ?? false) : scope != null;
}

class _ChannelSideAreaScope extends InheritedWidget {
  const _ChannelSideAreaScope({required this.hosts, required super.child});

  final bool hosts;

  @override
  bool updateShouldNotify(_ChannelSideAreaScope oldWidget) =>
      hosts != oldWidget.hosts;
}

/// The side sections open beside one conversation, the ones of them on
/// screen (a pane waiting behind another is not among them), when each opened
/// ([ChannelSideStack.openedAt]) and whether the panes cover the conversation
/// instead of standing beside it.
typedef OpenChannelSideStack = ({
  Set<ChannelSideSection> open,
  List<ChannelSideSection> shown,
  Map<ChannelSideSection, int> openedAt,
  bool covering,
});

class ChannelSideArea extends StatefulWidget {
  const ChannelSideArea({
    super.key,
    required this.controller,
    required this.child,
    this.detailPane = false,
    this.onOpenTask,
    this.headWrapper,
    this.profile,
    @visibleForTesting this.bodyOf,
  });
  final WorkspaceController controller;
  final bool detailPane;
  final Widget? profile;

  /// The channel column: header and chat. It stays where it is.
  final Widget child;

  /// Opens a task (the workspace's task surface).
  final void Function(
    Map<String, dynamic> task,
    Future<void> Function() reload,
  )?
  onOpenTask;

  /// Wraps each card's head (the drag handle that moves sections; the drag
  /// agent's hook).
  final ChannelSideHeadWrapper? headWrapper;

  /// Replaces a card's body (tests).
  final Widget Function(BuildContext context, ChannelSideSection section)?
  bodyOf;

  static GlobalKey<ChannelSideAreaState> workspaceKey(Object owner) =>
      _WorkspaceChannelSideKey(owner);

  static GlobalKey<ChannelSideAreaState> detailKey(Object owner) =>
      _DetailChannelSideKey(owner);

  static bool restoreForWorkspace(Object owner) =>
      (detailKey(owner).currentState?.restore() ?? false) ||
      (workspaceKey(owner).currentState?.restore() ?? false);

  /// The panes open beside the conversation of the workspace [owner] and which
  /// of them is on top, as of the last frame. Null where none is open or this
  /// area is not mounted. What the shell's own keys act on: a pane hidden
  /// behind another is not theirs to close.
  static OpenChannelSideStack? stackForWorkspace(Object owner) =>
      detailKey(owner).currentState?.openStack ??
      workspaceKey(owner).currentState?.openStack;

  @override
  State<ChannelSideArea> createState() => ChannelSideAreaState();
}

class _WorkspaceChannelSideKey extends GlobalObjectKey<ChannelSideAreaState> {
  const _WorkspaceChannelSideKey(super.value);
}

class _DetailChannelSideKey extends GlobalObjectKey<ChannelSideAreaState> {
  const _DetailChannelSideKey(super.value);
}

class _DockSeam {
  _DockSeam(this.columns, this.index, this.widths);

  final List<int> columns;
  final int index;
  final List<double> widths;

  int get column => columns[index];
  double get initialWidth => widths[index + 1];
  double get maxWidth => math.min(
    channelSideMaxSavedWidth.toDouble(),
    initialWidth + _room(widths.take(index + 1)),
  );
  double get minWidth => initialWidth - _room(widths.skip(index + 1));

  double _room(Iterable<double> donors) => donors.fold(
    0.0,
    (room, width) => room + math.max(0, width - channelSideColumnClip),
  );

  ({double conversation, Map<int, double> columns}) atWidth(double width) {
    final delta = initialWidth - width;
    final next = [...widths];
    final direction = delta >= 0 ? 1 : -1;
    var remaining = delta.abs().roundToDouble();
    for (
      var donor = direction > 0 ? index + 1 : index;
      donor >= 0 && donor < next.length && remaining > 0;
      donor += direction
    ) {
      final taken = math.min(
        remaining,
        math.max(0.0, next[donor] - channelSideColumnClip),
      );
      next[donor] -= taken;
      remaining -= taken;
      next[direction > 0 ? index : index + 1] += taken;
    }
    return (
      conversation: next.first,
      columns: {
        for (var i = 0; i < columns.length; i++) columns[i]: next[i + 1],
      },
    );
  }
}

class ChannelSideAreaState extends State<ChannelSideArea> {
  WorkspaceController get w => widget.controller;
  late ChannelSideStore store;
  late WebPreviewStore preview;
  late ChannelDetailsStore details;
  late ChannelFilesMedia media;
  final drag = ChannelSideDragController();
  final _chatKey = GlobalKey();
  late ChannelBrowserPanes _browserPanes;
  ChannelSideSection? _expanded;

  /// See [ChannelSideArea.stackForWorkspace]. Written once per build, because
  /// which pane is on top is worked out there and nowhere else.
  OpenChannelSideStack? openStack;
  ({_DockSeam seam, double width})? _resizePreview;
  late Listenable listenable;
  late Listenable _previewChanges;
  int previewOpenedAt = 0;
  int desktopPlaceOpenedAt = 0;
  String? _previewConversation;

  bool restore() {
    if (_expanded == null) return false;
    setState(() => _expanded = null);
    return true;
  }

  @override
  void initState() {
    super.initState();
    bind();
  }

  void bind() {
    _expanded = null;
    _resizePreview = null;
    store = ChannelSideStore.of(w);
    store.registerArea(this);
    preview = WebPreviewStore.of(w);
    details = ChannelDetailsStore.of(w);
    media = ChannelFilesMedia(w);
    _previewChanges = Listenable.merge([
      w,
      ChannelSideFlags.of(w),
      preview,
      preview.browserTabs.placement,
      ChannelArtifactPlace.of(w),
      preview.platform.voiceOverState,
    ]);
    listenable = Listenable.merge([_previewChanges, store, details]);
    previewOpenedAt = preview.openedAt;
    _browserPanes = ChannelBrowserPanes.of(w);
    _previewConversation = ChannelSideCards.conversation(w)?.id;
    desktopPlaceOpenedAt = ChannelSideCards.latestDesktopOpen(w);
    _previewChanges.addListener(previewChanged);
  }

  @override
  void didUpdateWidget(ChannelSideArea oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != w) {
      store.unregisterArea(this);
      _previewChanges.removeListener(previewChanged);
      bind();
    }
  }

  /// The page that opened last is the one showing where only one fits.
  void previewChanged() {
    final conversation = ChannelSideCards.conversation(w)?.id;
    final desktopOpened = ChannelSideCards.latestDesktopOpen(w);
    final legacyOpened =
        preview.page != null && preview.openedAt != previewOpenedAt;
    final desktopRaised =
        conversation == _previewConversation &&
        desktopOpened > desktopPlaceOpenedAt;
    previewOpenedAt = preview.openedAt;
    desktopPlaceOpenedAt = desktopOpened;
    _previewConversation = conversation;
    final covered = MobileRouteGate.coveredReader(context)();
    if (legacyOpened && (!covered || !desktopBrowserAvailable(w)) ||
        desktopRaised && !covered) {
      store.focus(ChannelSideCards.appCardKey);
    }
  }

  @override
  void dispose() {
    store.unregisterArea(this);
    _previewChanges.removeListener(previewChanged);
    drag.dispose();
    super.dispose();
  }

  /// Every card's head carries the grip that moves its section.
  Widget _wrapHead(
    BuildContext context,
    ChannelSideSection section,
    Widget head,
  ) => ChannelSideHead(
    drag: drag,
    section: section,
    enabled: drag.enabled,
    child: head,
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: listenable,
    builder: (context, _) => LayoutBuilder(builder: _build),
  );

  void _resizeDock(_DockSeam seam, double width, bool commit, bool profile) {
    final shown = width.clamp(seam.minWidth, seam.maxWidth).roundToDouble();
    final moved = shown != seam.initialWidth;
    if (_resizePreview == null && !moved) return;
    setState(() {
      _expanded = null;
      _resizePreview = commit ? null : (seam: seam, width: shown);
    });
    if (commit && moved) {
      final next = seam.atWidth(shown);
      if (profile) profilePanelWidth.save(next.columns[seam.column]!);
      store.resizeDock(next.columns, next.conversation);
    }
  }

  Widget _build(BuildContext context, BoxConstraints box) {
    final covered = MobileRouteGate.coveredReader(context)();
    final hosts =
        !covered && _hostsChannelSideSection(w, detailPane: widget.detailPane);
    final (open, page) = hosts
        ? _openChannelSide(
            w,
            preview,
            details,
            profile: widget.profile != null,
            detailPane: widget.detailPane,
          )
        : (<ChannelSideSection>{}, null);
    final ownsBrowser = hosts;
    if (page == null && (!ownsBrowser || MobileRouteGate.holds(context, w))) {
      open.remove(ChannelSideSection.artifact);
    }
    final foldedThread = RaftAdaptiveWorkspace.foldedThreadOf(context);
    final dockedThread = RaftAdaptiveWorkspace.dockedThreadOf(context);
    if (dockedThread != null) open.add(ChannelSideSection.thread);
    final compact = RaftAdaptiveWorkspace.compactOf(context);
    final visible = _visibleSideColumns(
      store,
      open,
      legacyThreadWidth: dockedThread?.width,
    );
    // One owner for "which pane is on top": the open set, in the order it
    // grew. Nothing else here tracks opens.
    final stack = ChannelSideStack.of(store, open);
    final ownsSeam =
        !compact &&
        foldedThread == null &&
        !RaftInteraction.of(context).touch &&
        box.maxWidth >= (visible.length + 1) * channelSideColumnClip;
    if (_resizePreview case final active?) {
      if (!ownsSeam ||
          !listEquals([
            for (final column in visible) column.column,
          ], active.seam.columns)) {
        _resizePreview = null;
      }
    }
    final resizePreview = _resizePreview;
    final live = resizePreview?.seam.atWidth(resizePreview.width);
    final conversationWidth = ownsSeam && visible.isNotEmpty
        ? store.conversationWidth?.toDouble()
        : null;
    final placement = placeChannelSide(
      visible,
      width: box.maxWidth,
      compact: compact,
      layout: raftLayoutClassOf(context),
      stack: stack,
      conversationWidth: live?.conversation ?? conversationWidth,
      dockWidths: live?.columns ?? const {},
      detailPane: widget.detailPane,
    );
    final beside = placement.mode == ChannelSideMode.beside;
    final columns = placement.columns;
    final browserEnabled = ownsBrowser && desktopBrowserAvailable(w);
    final activeBrowser =
        browserEnabled &&
            columns.any(
              (column) => column.sections.contains(ChannelSideSection.artifact),
            )
        ? ChannelSideCards.conversation(w)?.id
        : null;
    if (ownsBrowser) {
      _browserPanes.update(
        preview.browserTabs,
        activeBrowser,
        enabled: browserEnabled,
      );
    }
    final expandedIndex = beside
        ? columns.indexWhere((column) => column.sections.contains(_expanded))
        : -1;
    if (expandedIndex < 0) _expanded = null;
    final docked = [
      for (var i = 0; i < columns.length; i++)
        (
          column: columns[i].column,
          sections: columns[i].sections,
          width: expandedIndex < 0
              ? columns[i].width
              : i == expandedIndex
              ? box.maxWidth - columns.length * channelSideColumnClip
              : channelSideColumnClip,
        ),
    ];
    final shown = beside ? docked.fold(0.0, (a, c) => a + c.width) : 0.0;
    final covering =
        placement.mode == ChannelSideMode.overlay &&
        placement.columns.isNotEmpty;
    final chatWidth = box.maxWidth - shown;
    final hasDock = beside && placement.columns.isNotEmpty;
    final dockOrder = [for (final column in docked) column.column];
    final dockWidths = [
      chatWidth.roundToDouble(),
      for (final column in docked) column.width.roundToDouble(),
    ];
    ChannelSideResize? resize(int index) {
      if (expandedIndex >= 0 && expandedIndex != index) return null;
      final column = docked[index];
      final active = resizePreview?.seam;
      final seam = !ownsSeam
          ? null
          : active?.column == column.column
          ? active
          : _DockSeam(dockOrder, index, dockWidths);
      final profile = _profileOnly(open);
      final isThread = column.sections.contains(ChannelSideSection.thread);
      return ChannelSideResize(
        column: column.column,
        key: isThread
            ? const Key('thread-resize-handle')
            : profile
            ? const Key('profile-resize-handle')
            : null,
        width: column.width,
        minWidth: seam?.minWidth ?? channelSideMinSavedWidth.toDouble(),
        maxWidth:
            seam?.maxWidth ??
            column.width + math.max(0, chatWidth - channelSideChatMinWidth),
        fromPointerDown: seam != null,
        onResize: (width, commit) {
          if (seam != null) {
            _resizeDock(seam, width, commit, profile);
          } else {
            if (commit && profile) profilePanelWidth.save(width);
            store.resizeColumn(column.column, width, commit);
          }
        },
        label: _resizeLabel(context, column.sections, page),
      );
    }

    final chatContentFloor = hasDock && chatWidth < channelSideChatMinWidth
        ? channelSideChatMinWidth
        : null;
    Widget chatContent(Widget child) => OverflowBox(
      alignment: Alignment.topLeft,
      minWidth: chatContentFloor,
      maxWidth: chatContentFloor,
      child: child,
    );
    final chat = _Inert(key: _chatKey, inert: covering, child: widget.child);
    // Back always means "close the pane on top". Beside the chat only the top
    // pane draws it, and only while another pane waits behind it; covering the
    // conversation, whichever pane shows draws it (a phone keeps the channel
    // header's Back instead, see ChannelSideCardView.phone).
    final topColumn = visible.isEmpty ? null : visible[stack.topOf(visible)];
    final backSection =
        placement.stackedBelow > 0 && beside && topColumn != null
        ? stack.topSectionOf(topColumn)
        : null;
    VoidCallback? backOf(ChannelSideSection section) =>
        !compact && (covering || section == backSection)
        ? () => closeChannelSideSection(w, section)
        : null;
    // The one answer to "which pane is on top", for the keys the shell owns
    // (Escape, see workspace_panel_dismissal.dart).
    openStack = topColumn == null
        ? null
        : (
            open: open,
            shown: [for (final column in placement.columns) ...column.sections],
            openedAt: stack.openedAt,
            covering: covering,
          );
    // Web suspends section moves while a unit is expanded.
    drag.sync(
      store: store,
      area: context,
      enabled:
          beside &&
          _expanded == null &&
          !RaftInteraction.of(context).touch &&
          placement.columns.fold(0, (n, c) => n + c.sections.length) > 1,
      fits: (moved) =>
          box.maxWidth >=
          channelSideChatMinWidth +
              moved.visible(open).length * channelSideColumnClip,
    );
    final row = Stack(
      clipBehavior: Clip.none,
      children: [
        if (ownsBrowser) ..._browserPanes.parked(w, activeBrowser),
        Positioned.fill(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ClipRect(
                  key: const ValueKey('channel-side-conversation'),
                  clipBehavior: hasDock ? Clip.hardEdge : Clip.none,
                  child: foldedThread == null
                      ? chatContent(chat)
                      : Stack(
                          fit: StackFit.expand,
                          children: [
                            Visibility(
                              visible: false,
                              maintainState: true,
                              child: chatContent(
                                RaftCoveredPane(covered: true, child: chat),
                              ),
                            ),
                            // Folded, the thread stands in the chat's place,
                            // so a covering pane puts it away exactly as it
                            // puts the chat away.
                            chatContent(
                              _Inert(inert: covering, child: foldedThread),
                            ),
                          ],
                        ),
                ),
              ),
              if (beside)
                for (final (index, c) in docked.indexed)
                  SizedBox(
                    width: c.width,
                    child: _column(
                      context,
                      placement.mode,
                      c.column,
                      c.sections,
                      page,
                      compact,
                      backSection: backSection,
                      backOf: backOf,
                      expanded: c.sections.contains(_expanded)
                          ? _expanded
                          : null,
                      movesOf: _expanded == null
                          ? (section) =>
                                _moveItems(context, open, visible, section)
                          : null,
                      resize: resize(index),
                    ),
                  ),
            ],
          ),
        ),
        if (!beside && placement.columns.isNotEmpty)
          // The whole conversation column, the channel header included: the
          // covering pane carries its own head with the Back that pops it, so
          // the header underneath would only be a strip of dead buttons (it is
          // inside `chat`, which is inert while a pane covers).
          Positioned.fill(
            key: const Key('channel-side-overlay'),
            child: _CoverFocus(
              // A phone's Back closes what covers the conversation (Web
              // `headerMobileBack`); wider, it pops the pane on top and the
              // one underneath shows.
              onBack: () {
                if (!compact && topColumn != null) {
                  closeChannelSideSection(w, stack.topSectionOf(topColumn));
                } else if (open.contains(ChannelSideSection.profile)) {
                  w.closeProfile();
                } else {
                  ChannelSideCards.closeCovering(w);
                }
              },
              child: _column(
                context,
                placement.mode,
                placement.columns.first.column,
                placement.columns.first.sections,
                page,
                compact,
                backOf: backOf,
              ),
            ),
          ),
        Positioned.fill(child: ChannelSideDragLayer(drag: drag)),
      ],
    );
    final renderedShown = <ChannelSideSection>{
      for (final column in placement.columns)
        if (_expanded == null &&
            channelSideOneAtATime(
              placement.mode,
              box.maxHeight,
              column.sections.length,
            ))
          channelSideActiveSection(store, column.sections)
        else
          ...column.sections,
    };
    store.setAreaRenderedShown(this, hosts ? renderedShown : const {});
    return _ChannelSideAreaScope(
      hosts: hosts,
      child: Actions(
        actions: {
          if (_expanded != null)
            DismissIntent: CallbackAction<DismissIntent>(
              onInvoke: (_) => restore(),
            ),
        },
        child: row,
      ),
    );
  }

  Map<ChannelSideSection, String> _titles(
    BuildContext context,
    WebPreviewPage? page,
  ) => {
    ChannelSideSection.tasks: raftText(context, 'Tasks'),
    ChannelSideSection.files: raftText(context, 'Files'),
    ChannelSideSection.details: raftText(context, 'Details'),
    ChannelSideSection.profile: raftText(context, 'Profile'),
    ChannelSideSection.thread: raftText(context, 'Thread'),
    if (ChannelSideCards.hasDesktopPlace(w))
      ChannelSideSection.artifact: ChannelSideCards.desktopPlaceTitle(
        context,
        w,
      )
    else if (page != null)
      ChannelSideSection.artifact: webPreviewAddressParts(page.url).host,
  };

  String _resizeLabel(
    BuildContext context,
    List<ChannelSideSection> sections,
    WebPreviewPage? page,
  ) {
    final titles = _titles(context, page);
    final list = channelSideNames(context, [
      for (final s in sections) titles[s] ?? s.name,
    ]);
    return raftFormat(context, 'Resize {sections}', {'sections': list});
  }

  Widget _column(
    BuildContext context,
    ChannelSideMode mode,
    int index,
    List<ChannelSideSection> sections,
    WebPreviewPage? page,
    bool compact, {
    ChannelSideResize? resize,
    ChannelSideSection? expanded,
    ChannelSideSection? backSection,
    VoidCallback? Function(ChannelSideSection)? backOf,
    List<RaftMenuEntry> Function(ChannelSideSection)? movesOf,
  }) => ChannelSideColumnView(
    key: Key('channel-side-column-$index'),
    store: store,
    mode: mode,
    sections: sections,
    titles: _titles(context, page),
    resize: resize,
    expanded: expanded,
    cardOf: (context, section, fold) => drag.card(
      section,
      _card(
        context,
        section,
        fold,
        mode,
        page,
        compact,
        movesOf,
        stacked: section == backSection,
        back: backOf?.call(section),
      ),
    ),
  );

  Widget _card(
    BuildContext context,
    ChannelSideSection section,
    ChannelSideFold fold,
    ChannelSideMode mode,
    WebPreviewPage? page,
    bool compact,
    List<RaftMenuEntry> Function(ChannelSideSection)? movesOf, {
    bool stacked = false,
    VoidCallback? back,
  }) {
    final channelId =
        ChannelSideCards.conversation(w)?.id ?? w.channel?.id ?? '';
    final body = widget.bodyOf?.call(context, section);
    switch (section) {
      case ChannelSideSection.thread:
        final thread = RaftAdaptiveWorkspace.dockedThreadOf(context)!;
        final moves = movesOf?.call(section) ?? const [];
        final tokens = RaftTokens.of(context);
        return SizedBox.expand(
          key: const Key('workspace-thread-panel'),
          child: RaftStatusBarSource(
            color: RaftPrimitiveColors.black.withAlpha(0),
            border: RaftPanelEdge.leftFor(
              tokens,
              RaftPanelPresentation.attached,
            ),
            child: LayoutBuilder(
              builder: (context, box) {
                final width = math.max(box.maxWidth, channelSideChatMinWidth);
                return OverflowBox(
                  alignment: Alignment.topRight,
                  minWidth: width,
                  maxWidth: width,
                  child: RaftPanelHeaderChrome(
                    wrap: (context, head) => (widget.headWrapper ?? _wrapHead)(
                      context,
                      section,
                      head,
                    ),
                    onBack: back,
                    actions: [
                      if (moves.isNotEmpty)
                        RaftOverflowMenuButton(
                          key: const Key('channel-thread-move'),
                          tooltip: raftText(context, 'More actions'),
                          entries: moves,
                        ),
                    ],
                    child: thread.child,
                  ),
                );
              },
            ),
          ),
        );
      case ChannelSideSection.profile:
        final moves = movesOf?.call(section) ?? const [];
        final expand = _expandAction(mode, section);
        final expanded = _expanded == section;
        return RaftPanelHeaderChrome(
          wrap: (context, head) =>
              (widget.headWrapper ?? _wrapHead)(context, section, head),
          moves: moves,
          plannedProfile: true,
          onBack: back,
          actions: [
            if (expand != null)
              raftConversationHeaderToggle(
                key: const Key('channel-profile-expand'),
                glyph: expanded ? RaftGlyph.minimize2 : RaftGlyph.maximize2,
                label: raftText(context, expanded ? 'Restore' : 'Expand'),
                pressed: expanded,
                onPressed: expand,
              ),
          ],
          child: KeyedSubtree(
            key: const Key('workspace-profile-panel'),
            child: widget.profile!,
          ),
        );
      case ChannelSideSection.tasks:
        return ChannelSideCardView(
          section: section,
          title: raftText(context, 'Tasks'),
          closeLabel: raftText(context, 'Close Tasks'),
          onClose: () => ChannelSideCards.close(w, ChannelSideCard.tasks),
          mode: mode,
          phone: compact,
          stacked: stacked,
          collapsed: fold.collapsed,
          stackEnd: fold.stackEnd,
          onCollapsedChanged: fold.onCollapsedChanged,
          expanded: _expanded == section,
          onExpand: _expandAction(mode, section),
          moves: movesOf?.call(section) ?? const [],
          headWrapper: widget.headWrapper ?? _wrapHead,
          onCreateTask: () => openChannelTaskCreate(
            context,
            controller: w,
            channelId: channelId,
            covering: mode == ChannelSideMode.overlay,
          ),
          child:
              body ??
              ChannelSideTasksPanel(
                key: ValueKey('tasks-$channelId'),
                controller: w,
                channelId: channelId,
                filter: store.taskFilter,
                onFilterChanged: store.setTaskFilter,
                onOpenTask: (task) =>
                    widget.onOpenTask?.call(task, () async {}),
                covering: mode == ChannelSideMode.overlay,
              ),
        );
      case ChannelSideSection.files:
        return ChannelSideCardView(
          section: section,
          title: raftText(context, 'Files'),
          closeLabel: raftText(context, 'Close files'),
          onClose: () => ChannelSideCards.close(w, ChannelSideCard.files),
          mode: mode,
          phone: compact,
          stacked: stacked,
          collapsed: fold.collapsed,
          stackEnd: fold.stackEnd,
          onCollapsedChanged: fold.onCollapsedChanged,
          expanded: _expanded == section,
          onExpand: _expandAction(mode, section),
          moves: movesOf?.call(section) ?? const [],
          headWrapper: widget.headWrapper ?? _wrapHead,
          child:
              body ??
              SourceChannelFilesView(
                key: ValueKey('files-$channelId'),
                controller: w,
                channelId: channelId,
                compact: true,
                formatCreatedAt: media.formatter(context).shortDateTime,
                // Web formatCompactDate, the full time in its tooltip.
                formatCompactDate: media.formatter(context).compactDate,
                formatFullDate: media.formatter(context).mediumDateTime,
                acquireImage: media.acquireImage,
                peekImage: media.peekImage,
                // Covering the chat, the message it jumps to would stay hidden.
                beforeOpenSource: mode == ChannelSideMode.overlay
                    ? (_) {
                        for (final card in ChannelSideCards.open(w)) {
                          ChannelSideCards.close(w, card);
                        }
                      }
                    : null,
              ),
        );
      case ChannelSideSection.details:
        // The details head is built deep inside RaftOverflowSheet; the chrome
        // is how this area hands it a Back (it draws one in place of its X).
        return RaftPanelHeaderChrome(
          actions: const [],
          onBack: back,
          child: ChannelDetailsHost(
            key: ValueKey('channel-details-host-${details.channel?.id}'),
            controller: w,
            headerWrapper: (context, header) =>
                (widget.headWrapper ?? _wrapHead)(context, section, header),
          ),
        );
      case ChannelSideSection.artifact:
        // Three heads can stand in this column (the Artifact, the desktop
        // browser, a web page's panel) and each builds its own; the chrome is
        // how this area hands whichever shows a Back, as it does for Details.
        return RaftPanelHeaderChrome(
          actions: const [],
          onBack: back,
          child:
              body == null &&
                  !MobileRouteGate.coveredReader(context)() &&
                  ChannelSideCards.hasDesktopPlace(w)
              ? ChannelBrowserPlace(
                  key: ValueKey('channel-browser-place-$channelId'),
                  workspace: w,
                  conversation: channelId,
                  browserKey: _browserPanes.keyFor(channelId),
                  showing: fold.showing,
                  covering: mode == ChannelSideMode.overlay,
                  collapsed: fold.collapsed,
                  expanded: _expanded == section,
                  onExpand: _expandAction(mode, section),
                  headWrapper: widget.headWrapper ?? _wrapHead,
                )
              // The page's panel has the head every card has of its own.
              : body ??
                    WebPreviewPanel(
                      store: preview,
                      page: page!,
                      covering: mode == ChannelSideMode.overlay,
                      headWrapper: widget.headWrapper ?? _wrapHead,
                    ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  VoidCallback? _expandAction(
    ChannelSideMode mode,
    ChannelSideSection section,
  ) {
    if (mode != ChannelSideMode.beside) return null;
    return () =>
        setState(() => _expanded = _expanded == section ? null : section);
  }

  List<RaftMenuEntry> _moveItems(
    BuildContext context,
    Set<ChannelSideSection> open,
    List<VisibleChannelSideColumn> columns,
    ChannelSideSection section,
  ) {
    final index = columns.indexWhere(
      (column) => column.sections.contains(section),
    );
    if (index < 0) return const [];
    final own = columns[index];
    final shared = own.sections.length > 1;
    final left = shared
        ? own.column
        : index > 0
        ? columns[index - 1].column
        : null;
    final right = shared
        ? own.column + 1
        : index + 1 < columns.length
        ? columns[index + 1].column + 1
        : null;

    RaftMenuEntry? option(int? at, String label, RaftGlyph glyph) {
      if (at == null) return null;
      final drop = ChannelSideDropNewColumn(at);
      final moved = store.layout.move(section, drop).visible(open);
      if (moved.length == columns.length &&
          Iterable<int>.generate(
            moved.length,
          ).every((i) => listEquals(moved[i].sections, columns[i].sections))) {
        return null;
      }
      return RaftMenuEntry(
        label: raftText(context, label),
        glyph: glyph,
        onPressed: () => store.moveSection(section, drop),
      );
    }

    return [
      ?option(left, 'Move left', RaftGlyph.moveLeft),
      ?option(right, 'Move right', RaftGlyph.moveRight),
    ];
  }
}

/// The chat under a cover can't be reached: no focus, no pointer, nothing read
/// out (Web `inert`). The widgets stay in the tree (the chat is not rebuilt).
///
/// Its rows' hover toolbars float in the route's overlay, above the covering
/// pane, so they are told to put themselves away ([RaftCoveredPane]) as they
/// are under the folded profile and the folded thread.
class _Inert extends StatelessWidget {
  const _Inert({super.key, required this.inert, required this.child});
  final bool inert;
  final Widget child;

  @override
  Widget build(BuildContext context) => RaftCoveredPane(
    covered: inert || RaftCoveredPane.of(context),
    child: ExcludeFocus(
      excluding: inert,
      child: ExcludeSemantics(
        excluding: inert,
        child: IgnorePointer(ignoring: inert, child: child),
      ),
    ),
  );
}

/// Covering the chat, focus goes into the card (Web `useCoveringFocus`) and,
/// once it stops covering, back to what had it. The system Back closes what
/// covers before it leaves the channel, as the header's Back does.
class _CoverFocus extends StatefulWidget {
  const _CoverFocus({required this.onBack, required this.child});
  final VoidCallback onBack;
  final Widget child;

  @override
  State<_CoverFocus> createState() => _CoverFocusState();
}

class _CoverFocusState extends State<_CoverFocus> {
  final scope = FocusScopeNode(debugLabel: 'channel side cover');
  FocusNode? opener;

  @override
  void initState() {
    super.initState();

    opener = FocusManager.instance.primaryFocus;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // The cover takes focus from the conversation it covers (the same focus
      // scope it lives in), never from a window above it: a cover can appear
      // because the window reached a width where the pane covers, and an open
      // editor in a dialog keeps what it had.
      final focused = FocusManager.instance.primaryFocus;
      if (focused != null &&
          focused.enclosingScope != scope.enclosingScope &&
          !scope.hasFocus) {
        return;
      }
      scope.requestFocus();
    });
  }

  @override
  void dispose() {
    final back = opener;
    final lost = FocusManager.instance.primaryFocus == null || scope.hasFocus;
    scope.dispose();
    if (lost && back != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (back.context != null) back.requestFocus();
      });
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RaftBackDismiss(
    onDismiss: widget.onBack,
    child: FocusScope(node: scope, child: widget.child),
  );
}
