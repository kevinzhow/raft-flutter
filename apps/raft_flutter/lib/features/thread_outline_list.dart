import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:raft_ui/raft_ui.dart';

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
  final rowFocus = <String, FocusNode>{};
  ThreadOutline get outline => widget.outline;
  bool get compact => widget.compact;

  @override
  void initState() {
    super.initState();
    if (widget.focusCurrent) _queueCurrentFocus();
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
      if (id != null) _focusRow(id);
    });
  }

  double get compactExtent =>
      RaftScaled.extent(context, RaftThreadOutlineMetrics.compactRow);

  void _focusRow(String id) {
    final node = rowFocus[id];
    final row = node?.context;
    if (row != null) {
      node!.requestFocus();
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
      if (mounted) rowFocus[id]?.requestFocus();
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
    if (next >= 0 && next < items.length) _focusRow(items[next].id);
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
    return ListenableBuilder(
      listenable: outline,
      builder: (context, _) {
        final items = outline.items;
        return Column(
          children: [
            if (!compact)
              Container(
                padding: RaftThreadOutlineMetrics.titlePadding,
                constraints: const BoxConstraints(
                  minHeight: RaftThreadOutlineMetrics.headerHeight,
                ),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: t.ui.lineSeam)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          raftText(context, 'Timeline'),
                          style: RaftTypography.inherited(
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
                  if (event.metrics.extentAfter < 150) {
                    unawaited(outline.loadOlder());
                  }
                  return false;
                },
                child: Focus(
                  canRequestFocus: false,
                  onKeyEvent: compact ? _onKey : null,
                  child: ListView.builder(
                    controller: compact
                        ? scroll
                        : RaftSheetScope.maybeOf(context)?.scrollController,
                    reverse: true,
                    itemExtent: compact ? compactExtent : null,
                    padding: RaftThreadOutlineMetrics.listPadding,
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[items.length - index - 1];
                      return _OutlineRow(
                        key: ValueKey('thread-outline-row-${item.id}'),
                        item: item,
                        own: item.senderId == outline.userId,
                        current: item.id == outline.currentId,
                        compact: compact,
                        focusNode: compact
                            ? rowFocus.putIfAbsent(
                                item.id,
                                () => FocusNode(skipTraversal: true),
                              )
                            : null,
                        onTap: () => widget.onJump(item.id),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _OutlineRow extends StatelessWidget {
  const _OutlineRow({
    super.key,
    required this.item,
    required this.own,
    required this.current,
    required this.compact,
    this.focusNode,
    required this.onTap,
  });

  final ThreadOutlineItem item;
  final bool own, current, compact;
  final FocusNode? focusNode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final label = outlineItemText(context, item);
    final date = item.createdAt?.toLocal();
    final time = date == null
        ? ''
        : MaterialLocalizations.of(context)
              .formatTimeOfDay(TimeOfDay.fromDateTime(date));
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
          color: state.hovered || state.focusVisible
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
                children: [
                  Text(
                    label,
                    maxLines: compact ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: RaftTypography.inherited(
                      t,
                      size: 14,
                      color: t.muted,
                    ),
                  ),
                  if (!compact)
                    Text(
                      '${item.senderName}  $time',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: RaftTypography.inherited(
                        t,
                        size: 12,
                        color: t.muted,
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
