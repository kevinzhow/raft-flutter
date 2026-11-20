// Web v1.24 ChannelSideArea and rowPlan: desktop side columns stand beside
// the conversation. They give way to their content floors, clip to 160, then
// share the rightmost column as tabs. Compact layouts cover the conversation.
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import 'channel_files_media.dart';
import 'channel_details_host.dart';
import 'channel_side_card.dart';
import 'channel_side_cards.dart';
import 'channel_side_column.dart';
import 'channel_side_drag.dart';
import 'channel_side_flags.dart';
import 'channel_side_layout.dart';
import 'channel_side_store.dart';
import 'channel_side_tasks_panel.dart';
import 'channel_side_web_preview.dart';
import 'channel_side_web_preview_panel.dart';
import 'source_channel_files_view.dart';

/// The chat keeps this much beside the columns (Web `MAIN_COLUMN_MIN_WIDTH`).
const channelSideChatMinWidth = 360.0;

/// A column may be shrunk to this (Web's 160 clip) and no further.
const channelSideColumnClip = 160.0;

typedef PlacedChannelSideColumn = ({
  int column,
  List<ChannelSideSection> sections,
  List<List<ChannelSideSection>> tabGroups,
  double width,
});

class ChannelSidePlacement {
  const ChannelSidePlacement(this.mode, this.columns);
  final ChannelSideMode mode;
  final List<PlacedChannelSideColumn> columns;
}

ChannelSidePlacement placeChannelSide(
  List<VisibleChannelSideColumn> visible, {
  required double width,
  required bool compact,
  bool threadFolded = false,
  double? conversationWidth,
  Map<int, double> dockWidths = const {},
}) {
  if (visible.isEmpty) {
    return const ChannelSidePlacement(ChannelSideMode.beside, []);
  }
  if (compact || width < 2 * channelSideColumnClip) {
    return ChannelSidePlacement(ChannelSideMode.overlay, [
      (
        column: visible.first.column,
        sections: [for (final column in visible) ...column.sections],
        tabGroups: const [],
        width: width,
      ),
    ]);
  }
  final sideCount = width ~/ channelSideColumnClip - 1;
  final groups = <List<VisibleChannelSideColumn>>[];
  for (final column in visible) {
    if (groups.length < sideCount) {
      groups.add([column]);
    } else {
      groups.last.add(column);
    }
  }
  final sideSaved = visible.fold(0.0, (sum, column) => sum + column.width);
  final chatFloor = threadFolded
      ? channelSideChatMinWidth * 2
      : channelSideChatMinWidth;
  final saved = [
    conversationWidth ?? math.max(chatFloor, width - sideSaved),
    for (final group in groups)
      dockWidths[group.first.column] ?? group.first.width.toDouble(),
  ];
  final floors = [
    math.min(saved.first, chatFloor),
    for (var i = 0; i < groups.length; i++)
      math.min(saved[i + 1], groups[i].first.minWidth.toDouble()),
  ];
  final widths = _solveChannelSideWidths(
    saved,
    floors,
    width,
    threadFolded: threadFolded,
  );
  return ChannelSidePlacement(ChannelSideMode.beside, [
    for (var i = 0; i < groups.length; i++)
      (
        column: groups[i].first.column,
        sections: [for (final column in groups[i]) ...column.sections],
        tabGroups: groups[i].length == 1
            ? const []
            : [for (final column in groups[i]) column.sections],
        width: widths[i + 1],
      ),
  ]);
}

double _contentFloor(VisibleChannelSideColumn column) =>
    math.min(column.width, column.minWidth).toDouble();

RaftWorkspaceSideRow channelSideRow(WorkspaceController w) {
  final store = ChannelSideStore.of(w);
  final preview = WebPreviewStore.of(w);
  final details = ChannelDetailsStore.of(w);
  return (
    changes: Listenable.merge([
      store,
      preview,
      details,
      ChannelSideFlags.of(w),
    ]),
    widths: () {
      final (open, _) = _openChannelSide(w, preview, details);
      var saved = 0.0;
      var floor = 0.0;
      for (final column in store.layout.visible(open)) {
        saved += column.width;
        floor += _contentFloor(column);
      }
      return (saved: saved, floor: floor);
    },
  );
}

(Set<ChannelSideSection>, WebPreviewPage?) _openChannelSide(
  WorkspaceController w,
  WebPreviewStore preview,
  ChannelDetailsStore details,
) {
  final channel = w.channel;
  final here =
      channel != null && channel.type != 'thread' && w.section == 'chat';
  final page = here ? preview.pageFor(channel.id) : null;
  return (
    {
      if (here)
        for (final card in ChannelSideCards.open(w))
          card == ChannelSideCard.tasks
              ? ChannelSideSection.tasks
              : ChannelSideSection.files,
      if (page != null) ChannelSideSection.artifact,
      if (details.channel != null) ChannelSideSection.details,
    },
    page,
  );
}

List<double> _solveChannelSideWidths(
  List<double> saved,
  List<double> floors,
  double available, {
  required bool threadFolded,
}) {
  final total = saved.fold(0.0, (sum, width) => sum + width);
  if (total <= available) {
    return [for (final width in saved) width * available / total];
  }
  final floorTotal = floors.fold(0.0, (sum, width) => sum + width);
  if (floorTotal <= available) {
    final ratio = (total - available) / (total - floorTotal);
    return [
      for (var i = 0; i < saved.length; i++)
        saved[i] - ratio * (saved[i] - floors[i]),
    ];
  }
  final widths = [...floors];
  var remaining = floorTotal - available;
  if (threadFolded) {
    final drop = math.min(remaining, widths.first - channelSideChatMinWidth);
    widths[0] -= drop;
    remaining -= drop;
  }
  while (remaining > .01) {
    final shrinkable = [
      for (var i = 0; i < widths.length; i++)
        if (widths[i] > channelSideColumnClip) i,
    ];
    if (shrinkable.isEmpty) break;
    final sum = shrinkable.fold(0.0, (sum, i) => sum + widths[i]);
    var taken = 0.0;
    for (final i in shrinkable) {
      final drop = math.min(
        widths[i] - channelSideColumnClip,
        remaining * widths[i] / sum,
      );
      widths[i] -= drop;
      taken += drop;
    }
    remaining -= taken;
  }
  return widths;
}

/// Whether [context] is inside a [ChannelSideArea]: only there do Tasks and
/// Files open as cards, so a conversation panel elsewhere (the Search /
/// Activity detail pane) keeps its Tasks and Files tabs.
bool insideChannelSideArea(BuildContext context) =>
    context.getInheritedWidgetOfExactType<_ChannelSideAreaScope>() != null;

class _ChannelSideAreaScope extends InheritedWidget {
  const _ChannelSideAreaScope({required super.child});
  @override
  bool updateShouldNotify(_ChannelSideAreaScope oldWidget) => false;
}

class ChannelSideArea extends StatefulWidget {
  const ChannelSideArea({
    super.key,
    required this.controller,
    required this.child,
    this.headerExtent = 0,
    this.onOpenTask,
    this.headWrapper,
    @visibleForTesting this.bodyOf,
  });
  final WorkspaceController controller;

  /// The channel column: header and chat. It stays where it is.
  final Widget child;

  /// How much of [child]'s top is the channel header: a floating or covering
  /// column starts under it. 0 where the header stands above this widget.
  final double headerExtent;

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

  @override
  State<ChannelSideArea> createState() => _ChannelSideAreaState();
}

class _ExpandedDockSeam {
  _ExpandedDockSeam(List<PlacedChannelSideColumn> dock, int index)
    : column = dock[index].column,
      initialWidth = dock[index].width.roundToDouble(),
      neighbor = index > 0 ? dock[index - 1].column : null,
      initialWidths = {for (final c in dock) c.column: c.width.roundToDouble()};

  final int column;
  final int? neighbor;
  final double initialWidth;
  final Map<int, double> initialWidths;

  double conversationAt(double width) =>
      channelSideColumnClip + (neighbor == null ? initialWidth - width : 0);

  Map<int, double> atWidth(double width) => {
    ...initialWidths,
    column: width,
    ?neighbor: initialWidths[neighbor]! + initialWidth - width,
  };
}

class _ChannelSideAreaState extends State<ChannelSideArea> {
  WorkspaceController get w => widget.controller;
  late ChannelSideStore store;
  late WebPreviewStore preview;
  late ChannelDetailsStore details;
  late ChannelFilesMedia media;
  final drag = ChannelSideDragController();
  final _chatKey = GlobalKey();
  ChannelSideSection? _expanded;
  ({_ExpandedDockSeam seam, double width})? _resizePreview;
  late Listenable listenable;
  int previewOpenedAt = 0;

  @override
  void initState() {
    super.initState();
    bind();
  }

  void bind() {
    _expanded = null;
    _resizePreview = null;
    store = ChannelSideStore.of(w);
    preview = WebPreviewStore.of(w);
    details = ChannelDetailsStore.of(w);
    media = ChannelFilesMedia(w);
    listenable = Listenable.merge([
      w,
      store,
      ChannelSideFlags.of(w),
      preview,
      details,
    ]);
    previewOpenedAt = preview.openedAt;
  }

  @override
  void didUpdateWidget(ChannelSideArea oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != w) bind();
  }

  /// The page that opened last is the one showing where only one fits.
  void previewChanged() {
    if (preview.page != null && preview.openedAt != previewOpenedAt) {
      store.focus(ChannelSideCards.appCardKey);
    }
    previewOpenedAt = preview.openedAt;
  }

  @override
  void dispose() {
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
  Widget build(BuildContext context) => _ChannelSideAreaScope(
    child: ListenableBuilder(
      listenable: listenable,
      builder: (context, _) {
        previewChanged();
        return LayoutBuilder(builder: _build);
      },
    ),
  );

  void _resizeExpandedDock(_ExpandedDockSeam seam, double width, bool commit) {
    final shown = math.max(channelSideColumnClip, width).roundToDouble();
    final moved = shown != seam.initialWidth;
    if (_resizePreview == null && !moved) return;
    setState(() {
      _expanded = null;
      _resizePreview = commit ? null : (seam: seam, width: shown);
    });
    if (commit && moved) {
      store.resizeExpandedDock(seam.atWidth(shown), seam.conversationAt(shown));
    }
  }

  Widget _build(BuildContext context, BoxConstraints box) {
    final (open, page) = _openChannelSide(w, preview, details);
    final foldedThread = RaftAdaptiveWorkspace.foldedThreadOf(context);
    final compact = RaftAdaptiveWorkspace.compactOf(context);
    final visible = store.layout.visible(open);
    final ownsSeam =
        !compact &&
        foldedThread == null &&
        !RaftInteraction.of(context).touch &&
        box.maxWidth >= (visible.length + 1) * channelSideColumnClip;
    if (_resizePreview case final active?) {
      if (!ownsSeam ||
          visible.length != active.seam.initialWidths.length ||
          visible.any(
            (column) => !active.seam.initialWidths.containsKey(column.column),
          )) {
        _resizePreview = null;
      }
    }
    final resizePreview = _resizePreview;
    final conversationWidth = ownsSeam && visible.isNotEmpty
        ? store.conversationWidth?.toDouble()
        : null;
    final placement = placeChannelSide(
      visible,
      width: box.maxWidth,
      compact: compact,
      threadFolded: foldedThread != null,
      conversationWidth:
          resizePreview?.seam.conversationAt(resizePreview.width) ??
          conversationWidth,
      dockWidths: resizePreview?.seam.atWidth(resizePreview.width) ?? const {},
    );
    final beside = placement.mode == ChannelSideMode.beside;
    final columns = placement.columns;
    final expandedIndex = beside
        ? columns.indexWhere((column) => column.sections.contains(_expanded))
        : -1;
    if (expandedIndex < 0) _expanded = null;
    final docked = [
      for (var i = 0; i < columns.length; i++)
        (
          column: columns[i].column,
          sections: columns[i].sections,
          tabGroups: columns[i].tabGroups,
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
    final ownedExpandedSeam = expandedIndex >= 0 && ownsSeam
        ? _ExpandedDockSeam(docked, expandedIndex)
        : null;
    final seam = resizePreview?.seam ?? ownedExpandedSeam;
    final chatMinimum = conversationWidth != null
        ? channelSideColumnClip
        : channelSideChatMinWidth;
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
                            chatContent(foldedThread),
                          ],
                        ),
                ),
              ),
              if (beside)
                for (final c in docked)
                  SizedBox(
                    width: c.width,
                    child: _column(
                      context,
                      placement.mode,
                      c.column,
                      c.sections,
                      page,
                      compact,
                      tabGroups: c.tabGroups,
                      expanded: c.sections.contains(_expanded)
                          ? _expanded
                          : null,
                      movesOf: _expanded == null && c.tabGroups.isEmpty
                          ? (section) =>
                                _moveItems(context, open, visible, section)
                          : null,
                      resize: _expanded != null && seam?.column != c.column
                          ? null
                          : ChannelSideResize(
                              column: c.column,
                              width: c.width,
                              maxWidth: seam?.column == c.column
                                  ? seam!.initialWidth
                                  : c.width +
                                        math.max(0.0, chatWidth - chatMinimum),
                              fromPointerDown: seam?.column == c.column,
                              onResize: (width, commit) {
                                if (seam?.column == c.column) {
                                  _resizeExpandedDock(seam!, width, commit);
                                } else {
                                  store.resizeColumn(
                                    c.column,
                                    width,
                                    commit,
                                    conversationWidth: conversationWidth == null
                                        ? null
                                        : chatWidth +
                                              c.width -
                                              width.clamp(
                                                channelSideMinSavedWidth,
                                                channelSideMaxSavedWidth,
                                              ),
                                  );
                                }
                              },
                              label: _resizeLabel(context, c.sections, page),
                            ),
                    ),
                  ),
            ],
          ),
        ),
        if (!beside && placement.columns.isNotEmpty)
          Positioned(
            key: const Key('channel-side-overlay'),
            top: widget.headerExtent,
            right: 0,
            left: 0,
            bottom: 0,
            child: _CoverFocus(
              onBack: () => ChannelSideCards.closeCovering(w),
              child: _column(
                context,
                placement.mode,
                placement.columns.first.column,
                placement.columns.first.sections,
                page,
                compact,
              ),
            ),
          ),
        Positioned.fill(child: ChannelSideDragLayer(drag: drag)),
      ],
    );
    return Actions(
      actions: {
        if (_expanded != null)
          DismissIntent: CallbackAction<DismissIntent>(
            onInvoke: (_) => setState(() => _expanded = null),
          ),
      },
      child: row,
    );
  }

  Map<ChannelSideSection, String> _titles(
    BuildContext context,
    WebPreviewPage? page,
  ) => {
    ChannelSideSection.tasks: raftText(context, 'Tasks'),
    ChannelSideSection.files: raftText(context, 'Files'),
    ChannelSideSection.details: raftText(context, 'Details'),
    if (page != null)
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
    List<List<ChannelSideSection>> tabGroups = const [],
    ChannelSideSection? expanded,
    List<RaftMenuEntry> Function(ChannelSideSection)? movesOf,
  }) => ChannelSideColumnView(
    key: Key('channel-side-column-$index'),
    store: store,
    mode: mode,
    sections: sections,
    titles: _titles(context, page),
    resize: resize,
    tabGroups: tabGroups,
    expanded: expanded,
    cardOf: (context, section, fold) => drag.card(
      section,
      _card(context, section, fold, mode, page, compact, movesOf),
    ),
  );

  Widget _card(
    BuildContext context,
    ChannelSideSection section,
    ChannelSideFold fold,
    ChannelSideMode mode,
    WebPreviewPage? page,
    bool compact,
    List<RaftMenuEntry> Function(ChannelSideSection)? movesOf,
  ) {
    final channelId = w.channel?.id ?? '';
    final body = widget.bodyOf?.call(context, section);
    switch (section) {
      case ChannelSideSection.tasks:
        return ChannelSideCardView(
          section: section,
          title: raftText(context, 'Tasks'),
          closeLabel: raftText(context, 'Close Tasks'),
          onClose: () => ChannelSideCards.close(w, ChannelSideCard.tasks),
          mode: mode,
          phone: compact,
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
        return ChannelDetailsHost(
          key: ValueKey('channel-details-host-${details.channel?.id}'),
          controller: w,
          headerWrapper: (context, header) =>
              (widget.headWrapper ?? _wrapHead)(context, section, header),
        );
      case ChannelSideSection.artifact:
        // The page's panel has the head every card has of its own.
        return body ??
            WebPreviewPanel(
              store: preview,
              page: page!,
              covering: mode == ChannelSideMode.overlay,
              headWrapper: widget.headWrapper ?? _wrapHead,
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
class _Inert extends StatelessWidget {
  const _Inert({super.key, required this.inert, required this.child});
  final bool inert;
  final Widget child;

  @override
  Widget build(BuildContext context) => ExcludeFocus(
    excluding: inert,
    child: ExcludeSemantics(
      excluding: inert,
      child: IgnorePointer(ignoring: inert, child: child),
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
      if (mounted) scope.requestFocus();
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
