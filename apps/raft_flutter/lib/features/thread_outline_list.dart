import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderAbstractViewport;
import 'package:flutter/services.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/source_time_formatter.dart';
import '../data/thread_outline.dart';

class ThreadOutlineAnchor extends StatefulWidget {
  const ThreadOutlineAnchor({
    super.key,
    required this.outline,
    required this.onJump,
    required this.builder,
  });

  final ThreadOutline? outline;
  final ValueChanged<String> onJump;
  final Widget Function(BuildContext, VoidCallback) builder;

  @override
  State<ThreadOutlineAnchor> createState() => _ThreadOutlineAnchorState();
}

class _ThreadOutlineAnchorState extends State<ThreadOutlineAnchor> {
  final anchor = GlobalKey();
  final popup = MenuController();
  Route<void>? sheet;

  @override
  void didUpdateWidget(covariant ThreadOutlineAnchor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.outline != oldWidget.outline) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.outline != oldWidget.outline) dismiss();
      });
    }
  }

  void dismiss() {
    popup.close();
    final route = sheet;
    if (route != null && route.isActive) route.navigator?.removeRoute(route);
    sheet = null;
  }

  @override
  void dispose() {
    final route = sheet;
    if (route != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (route.isActive) route.navigator?.removeRoute(route);
      });
    }
    super.dispose();
  }

  void open() {
    final outline = widget.outline;
    if (outline == null || !outline.current) return;
    if (!RaftInteraction.of(context).touch) {
      popup.open();
      return;
    }
    if (sheet != null) return;
    final navigator = Navigator.of(context, rootNavigator: true);
    final route = raftPresentedRoute<void>(
      context,
      policy: const RaftPresentationPolicy(
        compact: RaftSurfaceForm.sheet,
        medium: RaftSurfaceForm.sheet,
        wide: RaftSurfaceForm.sheet,
      ),
      routeSettings: const RouteSettings(name: 'thread-timeline-sheet'),
      sheetInitialSize: .5,
      drawerMaxSize: .82,
      label: raftText(context, 'Timeline'),
      content: (context, _) => RaftSheet.fixed(
        key: const Key('thread-timeline-sheet'),
        child: ThreadOutlineList(
          outline: outline,
          onClose: () => navigator.pop(),
          onJump: (id) {
            navigator.pop();
            if (mounted && outline.current) widget.onJump(id);
          },
        ),
      ),
    );
    sheet = route;
    unawaited(
      navigator.push(route).whenComplete(() {
        if (identical(sheet, route)) sheet = null;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final trigger = KeyedSubtree(
      key: anchor,
      child: widget.builder(context, open),
    );
    final outline = widget.outline;
    if (outline == null || RaftInteraction.of(context).touch) return trigger;
    final size = MediaQuery.sizeOf(context);
    return RaftPopoverAnchor(
      controller: popup,
      anchorKey: anchor,
      alignRight: true,
      gap: 6,
      collisionPadding: 8,
      builder: (_, _, child) => child!,
      popup: RaftDismissScope(
        onDismiss: popup.close,
        takeFocus: true,
        child: RaftPopoverSurface(
          key: const Key('thread-timeline-popover'),
          child: SizedBox(
            width: RaftThreadOutlineMetrics.popoverWidth(size.width),
            height: RaftThreadOutlineMetrics.popoverHeight(size.height),
            child: ThreadOutlineList(
              outline: outline,
              onJump: (id) {
                popup.close();
                if (outline.current) widget.onJump(id);
              },
            ),
          ),
        ),
      ),
      child: trigger,
    );
  }
}

class ThreadOutlineList extends StatefulWidget {
  const ThreadOutlineList({
    super.key,
    required this.outline,
    required this.onJump,
    this.onClose,
    this.compact = false,
    this.focusCurrent = false,
  });

  final ThreadOutline outline;
  final ValueChanged<String> onJump;
  final VoidCallback? onClose;
  final bool compact, focusCurrent;

  @override
  State<ThreadOutlineList> createState() => _ThreadOutlineListState();
}

class _ThreadOutlineListState extends State<ThreadOutlineList> {
  final scroll = ScrollController();
  final openingRow = GlobalKey();
  final rowFocus = <String, FocusNode>{};
  ThreadOutline get outline => widget.outline;
  bool get compact => widget.compact;
  late final openingId = outline.currentId ?? outline.items.lastOrNull?.id;
  late final openingIndex = outline.items.indexWhere(
    (item) => item.id == openingId,
  );
  late final firstId = outline.items
      .elementAtOrNull((openingIndex - 1).clamp(0, outline.items.length))
      ?.id;
  bool loadingOlder = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (compact) {
        final id = openingId;
        if (id != null) _showCompactRow(id, focus: widget.focusCurrent);
      } else if (openingRow.currentContext case final row?) {
        unawaited(Scrollable.ensureVisible(row));
      }
    });
  }

  @override
  void didUpdateWidget(ThreadOutlineList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusCurrent && !oldWidget.focusCurrent) _queueCurrentFocus();
  }

  void _queueCurrentFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.focusCurrent) return;
      final id = outline.currentId ?? outline.items.lastOrNull?.id;
      if (id != null) _showCompactRow(id, focus: true);
    });
  }

  double get compactExtent =>
      RaftScaled.extent(context, RaftThreadOutlineMetrics.compactRow);

  void _showCompactRow(String id, {required bool focus}) {
    final node = rowFocus[id];
    final row = node?.context;
    if (row != null) {
      if (focus) node!.requestFocus();
      unawaited(Scrollable.ensureVisible(row, alignment: .5));
      return;
    }
    final items = outline.items;
    final index = items.indexWhere((item) => item.id == id);
    if (!scroll.hasClients || index < 0) return;
    final position = scroll.position;
    final offset =
        (items.length - index - .5) * compactExtent -
        position.viewportDimension / 2;
    scroll.jumpTo(offset.clamp(0.0, position.maxScrollExtent));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && focus) rowFocus[id]?.requestFocus();
    });
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final direction = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowUp => -1,
      LogicalKeyboardKey.arrowDown => 1,
      _ => 0,
    };
    if (direction == 0) return KeyEventResult.ignored;
    final items = outline.items;
    final focused = FocusManager.instance.primaryFocus;
    final next =
        items.indexWhere((item) => rowFocus[item.id] == focused) + direction;
    if (next >= 0 && next < items.length) {
      _showCompactRow(items[next].id, focus: true);
    }
    return KeyEventResult.handled;
  }

  @override
  void dispose() {
    scroll.dispose();
    for (final node in rowFocus.values) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final formatter = SourceTimeFormatter(
      locale: Localizations.localeOf(context).toLanguageTag(),
      preferredTimezone: outline.preferredTimezone,
      preferredTimeFormat: sourceTimeFormatPreference(
        outline.preferredTimeFormat,
      ),
      systemTimeFormat: MediaQuery.alwaysUse24HourFormatOf(context)
          ? SourceTimeFormat.twentyFourHour
          : null,
      yesterdayLabel: raftText(context, 'Yesterday'),
    );
    return ListenableBuilder(
      listenable: outline,
      builder: (context, _) {
        final items = outline.items;
        final currentId = outline.currentId;
        final inDrawer = widget.onClose != null;
        Widget row(ThreadOutlineItem item) => _OutlineRow(
          key: ValueKey('thread-outline-row-${item.id}'),
          item: item,
          time: formatter.messageTime(item.createdAt),
          own: item.senderId == outline.userId,
          current: item.id == currentId,
          compact: compact,
          inDrawer: inDrawer,
          focusNode: compact
              ? rowFocus.putIfAbsent(
                  item.id,
                  () => FocusNode(skipTraversal: true),
                )
              : null,
          onTap: () => widget.onJump(item.id),
        );
        return Column(
          children: [
            if (!compact)
              Container(
                padding: RaftThreadOutlineMetrics.titlePadding,
                constraints: const BoxConstraints(
                  minHeight: RaftThreadOutlineMetrics.headerHeight,
                ),
                decoration: inDrawer
                    ? null
                    : BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: t.ui.lineSeam),
                        ),
                      ),
                child: Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          raftText(context, 'Timeline'),
                          style: inDrawer
                              ? t.scale(
                                  t.typeSlot('headline'),
                                  weight: FontWeight.w700,
                                )
                              : RaftTypography.inherited(
                                  t,
                                  size: 16,
                                  weight: FontWeight.w600,
                                  color: t.ink,
                                ),
                        ),
                      ),
                    ),
                    if (widget.onClose != null)
                      RaftSheetClose(onPressed: widget.onClose),
                  ],
                ),
              ),
            Expanded(
              child: NotificationListener<ScrollNotification>(
                onNotification: (event) {
                  if (event is ScrollUpdateNotification && !loadingOlder) {
                    if (compact && event.metrics.extentAfter < 150) {
                      unawaited(outline.loadOlder());
                    } else if (!compact && event.metrics.extentBefore < 150) {
                      unawaited(
                        _prepend(
                          items,
                          RaftSheetScope.maybeOf(context)?.scrollController ??
                              scroll,
                        ),
                      );
                    }
                  }
                  return false;
                },
                child: Focus(
                  canRequestFocus: false,
                  onKeyEvent: compact ? _onKey : null,
                  child: compact
                      ? ListView.builder(
                          controller: scroll,
                          reverse: true,
                          itemExtent: compactExtent,
                          padding: RaftThreadOutlineMetrics.listPadding,
                          itemCount: items.length,
                          itemBuilder: (context, index) =>
                              row(items[items.length - index - 1]),
                        )
                      : SingleChildScrollView(
                          controller:
                              RaftSheetScope.maybeOf(context)
                                  ?.scrollController ??
                              scroll,
                          padding: RaftThreadOutlineMetrics.listPadding,
                          child: Column(
                            children: [
                              for (final item in items)
                                KeyedSubtree(
                                  key: item.id == firstId
                                      ? openingRow
                                      : ValueKey(item.id),
                                  child: row(item),
                                ),
                            ],
                          ),
                        ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _prepend(
    List<ThreadOutlineItem> before,
    ScrollController controller,
  ) async {
    if (before.isEmpty || !controller.hasClients) return;
    final row = openingRow.currentContext?.findRenderObject();
    final viewport = row == null ? null : RenderAbstractViewport.maybeOf(row);
    if (row == null || viewport == null) return;
    final lead = viewport.getOffsetToReveal(row, 0).offset;
    loadingOlder = true;
    final position = controller.position;
    await outline.loadOlder();
    if (!mounted || before.first.id == outline.items.firstOrNull?.id) {
      loadingOlder = false;
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      loadingOlder = false;
      if (mounted &&
          row.attached &&
          controller.hasClients &&
          identical(position, controller.position)) {
        final delta = viewport.getOffsetToReveal(row, 0).offset - lead;
        final target = position.pixels + delta;
        position.jumpTo(target.clamp(0, position.maxScrollExtent).toDouble());
      }
    });
  }
}

class _OutlineRow extends StatelessWidget {
  const _OutlineRow({
    super.key,
    required this.item,
    required this.time,
    required this.own,
    required this.current,
    required this.compact,
    required this.inDrawer,
    this.focusNode,
    required this.onTap,
  });

  final ThreadOutlineItem item;
  final String time;
  final bool own, current, compact, inDrawer;
  final FocusNode? focusNode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final label = outlineItemText(context, item);
    final row = RaftInteractive(
      onPressed: onTap,
      focusNode: focusNode,
      selected: current,
      semanticLabel: raftFormat(context, '{sender}, {time}, {text}', {
        'sender': item.senderName,
        'time': time,
        'text': label,
      }),
      builder: (context, state) => Container(
        constraints: BoxConstraints(
          minHeight: compact
              ? RaftThreadOutlineMetrics.compactRow
              : RaftThreadOutlineMetrics.mediumRow,
        ),
        padding: RaftThreadOutlineMetrics.rowPadding(compact),
        decoration: BoxDecoration(
          color:
              (current && !inDrawer) ||
                  state.hovered ||
                  state.focusVisible ||
                  state.pressed
              ? t.colors['brand-soft']
              : null,
          borderRadius: RaftThreadOutlineMetrics.rowCorners(t),
        ),
        child: Row(
          spacing: RaftSpace.x3,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    maxLines: compact ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: t.scale(
                      t.typeSlot('callout'),
                      weight: current ? FontWeight.w600 : null,
                      color: current ? t.ink : t.muted,
                    ),
                  ),
                  if (!compact)
                    Padding(
                      padding: RaftThreadOutlineMetrics.metadataPadding,
                      child: Row(
                        spacing: RaftThreadOutlineMetrics.metadataGap,
                        children: [
                          Flexible(
                            child: Text(
                              item.senderName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: t.scale(
                                t.typeSlot('footnote'),
                                color: t.ui.foregroundHint,
                              ),
                            ),
                          ),
                          Flexible(
                            child: Text(
                              time,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: t.scale(
                                t.typeSlot('mono-meta'),
                                mono: true,
                                color: t.ui.foregroundHint,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            ThreadOutlineTick(own: own, current: current),
          ],
        ),
      ),
    );
    return compact ? RaftTooltip(message: label, child: row) : row;
  }
}

String outlineItemText(BuildContext context, ThreadOutlineItem item) {
  if (item.preview.isNotEmpty) return item.preview;
  if (item.attachmentCount == 0) return raftText(context, 'No text');
  return raftFormat(
    context,
    item.attachmentCount == 1 ? '{count} attachment' : '{count} attachments',
    {'count': item.attachmentCount},
  );
}

class ThreadOutlineTick extends StatelessWidget {
  const ThreadOutlineTick({super.key, required this.own, this.current = false});

  final bool own, current;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final size = current
        ? RaftThreadOutlineMetrics.currentTick
        : RaftThreadOutlineMetrics.tick;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: current
            ? t.ink
            : own
            ? t.muted
            : t.ui.lineSeam,
        borderRadius: RaftThreadOutlineMetrics.tickCorners,
      ),
      child: SizedBox.fromSize(size: size),
    );
  }
}
