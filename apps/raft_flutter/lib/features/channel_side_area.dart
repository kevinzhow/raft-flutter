// Web v1.24 ChannelSideArea and rowPlan: desktop side columns stand beside
// the conversation. They give way to their content floors, clip to 160, then
// share the rightmost column as tabs. Compact layouts cover the conversation.
import 'dart:math' as math;

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
    math.max(chatFloor, width - sideSaved),
    for (final group in groups) group.first.width.toDouble(),
  ];
  final floors = [
    chatFloor,
    for (final group in groups) _contentFloor(group.first),
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

class _ChannelSideAreaState extends State<ChannelSideArea> {
  WorkspaceController get w => widget.controller;
  late ChannelSideStore store;
  late WebPreviewStore preview;
  late ChannelDetailsStore details;
  late ChannelFilesMedia media;
  final drag = ChannelSideDragController();
  late Listenable listenable;
  int previewOpenedAt = 0;

  @override
  void initState() {
    super.initState();
    bind();
  }

  void bind() {
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

  Widget _build(BuildContext context, BoxConstraints box) {
    final (open, page) = _openChannelSide(w, preview, details);
    final foldedThread = RaftAdaptiveWorkspace.foldedThreadOf(context);
    final compact = RaftAdaptiveWorkspace.compactOf(context);
    final placement = placeChannelSide(
      store.layout.visible(open),
      width: box.maxWidth,
      compact: compact,
      threadFolded: foldedThread != null,
    );
    final beside = placement.mode == ChannelSideMode.beside;
    final shown = beside
        ? placement.columns.fold(0.0, (a, c) => a + c.width)
        : 0.0;
    final covering =
        placement.mode == ChannelSideMode.overlay &&
        placement.columns.isNotEmpty;
    final chatWidth = box.maxWidth - shown;
    final hasDock = beside && placement.columns.isNotEmpty;
    final chatContentFloor = hasDock && chatWidth < channelSideChatMinWidth
        ? channelSideChatMinWidth
        : null;
    Widget chatContent(Widget child) => OverflowBox(
      alignment: Alignment.topLeft,
      minWidth: chatContentFloor,
      maxWidth: chatContentFloor,
      child: child,
    );
    // Sections move only beside the chat, by a pointer, with more than one
    // open (Web `sideSectionDrag` enabled).
    drag.sync(
      store: store,
      area: context,
      enabled:
          beside &&
          !RaftInteraction.of(context).touch &&
          placement.columns.fold(0, (n, c) => n + c.sections.length) > 1,
      fits: (moved) =>
          box.maxWidth >=
          channelSideChatMinWidth +
              moved.visible(open).length * channelSideColumnClip,
    );
    return Stack(
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
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Visibility(
                        visible: foldedThread == null,
                        maintainState: true,
                        child: chatContent(
                          RaftCoveredPane(
                            covered:
                                foldedThread != null ||
                                RaftCoveredPane.of(context),
                            child: _Inert(inert: covering, child: widget.child),
                          ),
                        ),
                      ),
                      if (foldedThread != null) chatContent(foldedThread),
                    ],
                  ),
                ),
              ),
              if (beside)
                for (final c in placement.columns)
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
                      resize: ChannelSideResize(
                        column: c.column,
                        width: c.width,
                        maxWidth:
                            c.width +
                            math.max(0.0, chatWidth - channelSideChatMinWidth),
                        onResize: (width, commit) =>
                            store.resizeColumn(c.column, width, commit),
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
  }) => ChannelSideColumnView(
    key: Key('channel-side-column-$index'),
    store: store,
    mode: mode,
    sections: sections,
    titles: _titles(context, page),
    resize: resize,
    tabGroups: tabGroups,
    cardOf: (context, section, fold) =>
        drag.card(section, _card(context, section, fold, mode, page, compact)),
  );

  Widget _card(
    BuildContext context,
    ChannelSideSection section,
    ChannelSideFold fold,
    ChannelSideMode mode,
    WebPreviewPage? page,
    bool compact,
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
          onCollapsedChanged: fold.onCollapsedChanged,
          headWrapper: widget.headWrapper ?? _wrapHead,
          actions: [
            RaftPanelAction(
              key: const Key('channel-tasks-panel-new'),
              glyph: RaftGlyph.plus,
              tooltip: raftText(context, 'New task'),
              minHitExtent: RaftMetrics.touchTarget,
              onPressed: () => openChannelTaskCreate(
                context,
                controller: w,
                channelId: channelId,
                covering: mode == ChannelSideMode.overlay,
              ),
            ),
          ],
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
          onCollapsedChanged: fold.onCollapsedChanged,
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
}

/// The chat under a cover can't be reached: no focus, no pointer, nothing read
/// out (Web `inert`). The widgets stay in the tree (the chat is not rebuilt).
class _Inert extends StatelessWidget {
  const _Inert({required this.inert, required this.child});
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
