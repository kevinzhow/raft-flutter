// The side area of a conversation (Web v1.24 `ChannelSideArea.tsx`, simplified:
// no row plan, no thread folding, no columns as tabs): the open sections as
// cards beside the chat, floating over its messages, or covering it.
//
//   - A desktop (not compact): the open sections' columns of the person's layout
//     stand right of the whole channel column, header included, each with its
//     own head level with the channel header. A column is as wide as saved,
//     shrunk so the chat keeps 360px, never under 160.
//   - Compact (a phone, a narrow window): one card at a time covers the chat
//     under the header (a Tasks | Files switch with both open), or, with 520px
//     or more, one column floats over the right of the messages above the
//     composer. The chat and the composer are inert under a cover; focus moves
//     into the card.
//
// The chat is `child`: it keeps its element whatever opens or closes, and its
// rows are not rebuilt (this widget rebuilds, `child` is the same widget).
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/source_channel_files_store.dart';
import '../data/workspace_controller.dart';
import 'channel_files_media.dart';
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

/// A compact panel this wide floats one column; narrower, the cards cover it.
const channelSideFloatMinPanel = 520.0;
const _floatGap = 12.0;

class ChannelSidePlacement {
  const ChannelSidePlacement(this.mode, this.columns);
  final ChannelSideMode mode;

  /// Beside: one per visible column, with its shown width. Float and overlay:
  /// one holding every open section.
  final List<({int column, List<ChannelSideSection> sections, double width})>
  columns;
}

/// Where the open [visible] columns stand in a panel [width] wide.
ChannelSidePlacement placeChannelSide(
  List<VisibleChannelSideColumn> visible, {
  required double width,
  required bool compact,
}) {
  if (visible.isEmpty) {
    return const ChannelSidePlacement(ChannelSideMode.beside, []);
  }
  if (!compact) {
    final available = width - channelSideChatMinWidth;
    final saved = [for (final c in visible) c.width.toDouble()];
    final total = saved.fold(0.0, (a, b) => a + b);
    if (total <= available) {
      return ChannelSidePlacement(ChannelSideMode.beside, [
        for (var i = 0; i < visible.length; i++)
          (
            column: visible[i].column,
            sections: visible[i].sections,
            width: saved[i],
          ),
      ]);
    }
    if (available >= visible.length * channelSideColumnClip) {
      // Each gives way in proportion to what it has above the clip.
      final spare = total - visible.length * channelSideColumnClip;
      final excess = total - available;
      return ChannelSidePlacement(ChannelSideMode.beside, [
        for (var i = 0; i < visible.length; i++)
          (
            column: visible[i].column,
            sections: visible[i].sections,
            width:
                saved[i] - excess * (saved[i] - channelSideColumnClip) / spare,
          ),
      ]);
    }
  }
  // No room beside the chat: one column floats over the messages, or covers
  // the panel where it is too narrow for that.
  final mode = width >= channelSideFloatMinPanel
      ? ChannelSideMode.float
      : ChannelSideMode.overlay;
  return ChannelSidePlacement(mode, [
    (
      column: visible.first.column,
      sections: [for (final c in visible) ...c.sections],
      width: mode == ChannelSideMode.float
          ? math.min(math.min(360.0, math.max(280.0, width * .58)), width - 24)
          : width,
    ),
  ]);
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
  late ChannelFilesMedia media;
  final drag = ChannelSideDragController();
  late Listenable listenable;
  int previewOpenedAt = 0;
  double composerBelow = 0;
  Element? composer;

  @override
  void initState() {
    super.initState();
    bind();
  }

  void bind() {
    store = ChannelSideStore.of(w);
    preview = WebPreviewStore.of(w);
    media = ChannelFilesMedia(w);
    listenable = Listenable.merge([w, store, ChannelSideFlags.of(w), preview]);
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
    final channel = w.channel;
    final here =
        channel != null && channel.type != 'thread' && w.section == 'chat';
    final page = here ? preview.pageFor(channel.id) : null;
    final open = <ChannelSideSection>{
      if (here)
        for (final card in ChannelSideCards.open(w))
          card == ChannelSideCard.tasks
              ? ChannelSideSection.tasks
              : ChannelSideSection.files,
      if (page != null) ChannelSideSection.artifact,
    };
    final compact = RaftAdaptiveWorkspace.compactOf(context);
    final placement = placeChannelSide(
      store.layout.visible(open),
      width: box.maxWidth,
      compact: compact,
    );
    final beside = placement.mode == ChannelSideMode.beside;
    final shown = beside
        ? placement.columns.fold(0.0, (a, c) => a + c.width)
        : 0.0;
    final covering =
        placement.mode == ChannelSideMode.overlay &&
        placement.columns.isNotEmpty;
    if (placement.mode == ChannelSideMode.float) _measureComposer();
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
          placeChannelSide(
            moved.visible(open),
            width: box.maxWidth,
            compact: false,
          ).mode ==
          ChannelSideMode.beside,
    );
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _Inert(inert: covering, child: widget.child),
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
                      resize: ChannelSideResize(
                        column: c.column,
                        width: c.width,
                        maxWidth:
                            c.width +
                            box.maxWidth -
                            shown -
                            channelSideChatMinWidth,
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
            key: Key('channel-side-${placement.mode.name}'),
            top: widget.headerExtent,
            right: 0,
            left: covering ? 0 : null,
            width: covering ? null : placement.columns.first.width,
            bottom: covering ? 0 : composerBelow + _floatGap,
            child: _CoverFocus(
              active: covering,
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
  }) => ChannelSideColumnView(
    key: Key('channel-side-column-$index'),
    store: store,
    mode: mode,
    sections: sections,
    titles: _titles(context, page),
    resize: resize,
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
                acquireImage: media.acquireImage,
                peekImage: media.peekImage,
                // Covering the chat, the message it jumps to would stay hidden.
                onOpenSource: mode == ChannelSideMode.overlay
                    ? (SourceChannelFileEntry file) async {
                        for (final card in ChannelSideCards.open(w)) {
                          ChannelSideCards.close(w, card);
                        }
                        await w.jumpToMessage(channelId, file.messageId);
                      }
                    : null,
              ),
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

  /// The floating column stops 12px above the composer: what stands under the
  /// messages is measured from the composer in the chat (after layout, only
  /// while floating).
  void _measureComposer() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final area = context.findRenderObject();
      if (area is! RenderBox || !area.hasSize) return;
      if (composer == null || !composer!.mounted) {
        composer = null;
        void visit(Element e) {
          if (composer != null) return;
          if (e.widget is RaftComposer) {
            composer = e;
            return;
          }
          e.visitChildren(visit);
        }

        (context as Element).visitChildren(visit);
      }
      final box = composer?.renderObject;
      final below = box is RenderBox && box.attached && box.hasSize
          ? area.size.height - box.localToGlobal(Offset.zero, ancestor: area).dy
          : 0.0;
      if ((below - composerBelow).abs() > .5) {
        setState(() => composerBelow = below);
      }
    });
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
  const _CoverFocus({
    required this.active,
    required this.onBack,
    required this.child,
  });
  final bool active;
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
    if (widget.active) _take();
  }

  void _take() {
    opener = FocusManager.instance.primaryFocus;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) scope.requestFocus();
    });
  }

  @override
  void didUpdateWidget(_CoverFocus oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) _take();
  }

  @override
  void dispose() {
    final back = opener;
    final lost = FocusManager.instance.primaryFocus == null || scope.hasFocus;
    scope.dispose();
    if (widget.active && lost && back != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (back.context != null) back.requestFocus();
      });
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scoped = FocusScope(node: scope, child: widget.child);
    return widget.active
        ? RaftBackDismiss(onDismiss: widget.onBack, child: scoped)
        : scoped;
  }
}
