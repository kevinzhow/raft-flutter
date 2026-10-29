// Web MessageInput pending attachments use dnd-kit's `SortableContext` with a
// `PointerSensor` (`activationConstraint: { distance: 5 }`) and
// `horizontalListSortingStrategy`: the chip body is the drag handle, the other
// chips shift while one is dragged, and the order commits on drop (`arrayMove`
// of the dragged chip to the position of the chip under it). This is that
// interaction over a [Wrap]: a mouse or pen drags at once past the slop, a
// finger long-presses first so scrolling and the chip's own taps stay free.
import 'package:flutter/material.dart';

import 'design_primitives.dart';

class RaftReorderableWrap<T> extends StatefulWidget {
  const RaftReorderableWrap({
    super.key,
    required this.items,
    required this.idOf,
    required this.itemBuilder,
    required this.spacing,
    required this.runSpacing,
    this.onReorder,
  });
  final List<T> items;
  final String Function(T item) idOf;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final double spacing, runSpacing;

  /// The new order of every id, called once when a drag ends with a change.
  /// Null makes the chips plain (no drag).
  final ValueChanged<List<String>>? onReorder;
  @override
  State<RaftReorderableWrap<T>> createState() => _RaftReorderableWrapState<T>();
}

class _RaftReorderableWrapState<T> extends State<RaftReorderableWrap<T>> {
  // The order while a drag is under way (and until the owner applies it).
  List<String>? live;
  String? dragging;

  List<String> get ids => [for (final item in widget.items) widget.idOf(item)];

  @override
  void didUpdateWidget(covariant RaftReorderableWrap<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The owner applied the order (or the set of chips changed): stop
    // overriding it.
    final shown = live;
    if (shown != null && dragging == null) {
      final current = ids;
      if (_same(shown, current) || !_sameSet(shown, current)) live = null;
    }
  }

  static bool _same(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static bool _sameSet(List<String> a, List<String> b) =>
      a.length == b.length && a.toSet().containsAll(b);

  List<T> get ordered {
    final order = live;
    if (order == null) return widget.items;
    final byId = {for (final item in widget.items) widget.idOf(item): item};
    if (!_sameSet(order, ids)) return widget.items;
    return [for (final id in order) byId[id] as T];
  }

  /// dnd-kit `arrayMove(order, from, to)`.
  void moveOver(String moved, String over) {
    final order = [...(live ?? ids)];
    final from = order.indexOf(moved), to = order.indexOf(over);
    if (from < 0 || to < 0 || from == to) return;
    order.insert(to, order.removeAt(from));
    setState(() => live = order);
  }

  void finish() {
    final order = live;
    setState(() => dragging = null);
    if (order != null && !_same(order, ids)) {
      widget.onReorder?.call(order);
    } else if (mounted) {
      setState(() => live = null);
    }
  }

  Widget slot(BuildContext context, T item, bool touch) {
    final id = widget.idOf(item);
    final child = widget.itemBuilder(context, item);
    if (widget.onReorder == null)
      return KeyedSubtree(key: ValueKey(id), child: child);
    final density = RaftDensityScope.of(context);
    Widget feedback() => RaftDensityScope(
      density: density,
      child: Material(
        type: MaterialType.transparency,
        child: Opacity(opacity: .5, child: widget.itemBuilder(context, item)),
      ),
    );
    final ghost = Opacity(opacity: .5, child: child);
    return DragTarget<String>(
      key: ValueKey(id),
      onWillAcceptWithDetails: (details) {
        if (details.data != id) moveOver(details.data, id);
        return false;
      },
      builder: (context, _, _) {
        void started() => setState(() => dragging = id);
        void ended(Object? _) => finish();
        return touch
            ? LongPressDraggable<String>(
                data: id,
                feedback: feedback(),
                childWhenDragging: ghost,
                maxSimultaneousDrags: 1,
                onDragStarted: started,
                onDragEnd: ended,
                child: child,
              )
            : Draggable<String>(
                data: id,
                feedback: feedback(),
                childWhenDragging: ghost,
                maxSimultaneousDrags: 1,
                onDragStarted: started,
                onDragEnd: ended,
                child: child,
              );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final touch = RaftDensityScope.of(context) == RaftDensity.touch;
    return Wrap(
      spacing: widget.spacing,
      runSpacing: widget.runSpacing,
      children: [for (final item in ordered) slot(context, item, touch)],
    );
  }
}
