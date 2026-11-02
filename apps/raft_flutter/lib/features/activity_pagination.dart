import 'dart:async';

import 'package:flutter/widgets.dart';

/// Web ThreadsInbox's 240px near-end read, also checked after layout so a
/// first page shorter than the viewport does not need an impossible scroll.
/// Each accepted offset is attempted automatically once. Errors/empty pages
/// leave the existing manual action available rather than retrying on layout.
class ActivityPagination extends StatefulWidget {
  const ActivityPagination({
    super.key,
    required this.controller,
    required this.scope,
    required this.offset,
    required this.ready,
    required this.onMore,
    required this.child,
  });

  final ScrollController controller;
  final Object scope;
  final int offset;

  /// Read at dispatch time: a quiet background request can become active
  /// without rebuilding the retained list.
  final bool Function() ready;
  final Future<void> Function() onMore;
  final Widget child;

  @override
  State<ActivityPagination> createState() => _ActivityPaginationState();
}

class _ActivityPaginationState extends State<ActivityPagination> {
  Object? attempted;
  bool scheduled = false, active = true;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(schedule);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    active = TickerMode.valuesOf(context).enabled;
  }

  @override
  void didUpdateWidget(covariant ActivityPagination oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scope != widget.scope) attempted = null;
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(schedule);
      widget.controller.addListener(schedule);
    }
  }

  void schedule() {
    if (scheduled) return;
    scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      scheduled = false;
      if (!mounted || !active || !widget.ready()) return;
      final controller = widget.controller,
          page = (widget.scope, widget.offset);
      if (attempted == page || controller.positions.length != 1) return;
      final position = controller.position;
      if (!position.hasContentDimensions || position.extentAfter >= 240) return;
      attempted = page;
      unawaited(widget.onMore());
    });
  }

  @override
  Widget build(BuildContext context) {
    schedule();
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (notification) {
        if (notification.depth == 0) schedule();
        return false;
      },
      child: widget.child,
    );
  }

  @override
  void dispose() {
    widget.controller.removeListener(schedule);
    super.dispose();
  }
}
