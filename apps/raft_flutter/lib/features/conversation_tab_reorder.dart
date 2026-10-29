// Web ChatPanel `SortableTabsList`: the Chat / Tasks / Files tabs can be
// dragged into another order; the whole new order is saved as
// `sidebarOrder.channelPanelTabOrder`. A pointer drags at once; a finger needs
// a long press so the strip still scrolls and swipes between tabs.
import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

/// The whole order after [moving] is dropped onto [onto] (`arrayMove`): it
/// takes the place of [onto]; an unchanged or unknown pair leaves [order] as is.
List<RaftConversationTabId> movedConversationTab(
  List<RaftConversationTabId> order,
  RaftConversationTabId moving,
  RaftConversationTabId onto,
) {
  final from = order.indexOf(moving), to = order.indexOf(onto);
  if (from < 0 || to < 0 || from == to) return order;
  final next = [...order];
  next.insert(to, next.removeAt(from));
  return next;
}

/// The `RaftConversationTabs.reorderWrapper` for [order].
Widget Function(Widget child, RaftConversationTab tab, int index)
conversationTabReorder({
  required List<RaftConversationTabId> order,
  required ValueChanged<List<RaftConversationTabId>> onReorder,
  required bool touch,
}) =>
    (child, tab, index) => _TabSlot(
      key: ValueKey('conversation-tab-slot-${tab.id.name}'),
      tab: tab,
      order: order,
      touch: touch,
      onReorder: onReorder,
      child: child,
    );

class _TabSlot extends StatefulWidget {
  const _TabSlot({
    super.key,
    required this.tab,
    required this.order,
    required this.touch,
    required this.onReorder,
    required this.child,
  });
  final RaftConversationTab tab;
  final List<RaftConversationTabId> order;
  final bool touch;
  final ValueChanged<List<RaftConversationTabId>> onReorder;
  final Widget child;
  @override
  State<_TabSlot> createState() => _TabSlotState();
}

class _TabSlotState extends State<_TabSlot> {
  bool marked = false;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final id = widget.tab.id;
    // The lifted tab: its label on a raised chip (the tab itself stays put).
    // It floats in the overlay, so its text carries its own style.
    final feedback = Container(
      // ds-allow: the floating drag chip has no raft_ui recipe; it mirrors the tab's own padding
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: t.colors['layer-panel'],
        border: Border.all(color: t.colors['line-strong']!),
        boxShadow: t.shadows,
      ),
      child: Text(
        widget.tab.label,
        style: RaftTypography.heading(
          t,
          size: 13,
          line: 19.5,
          weight: FontWeight.w500,
          color: t.strong,
        ).copyWith(decoration: TextDecoration.none),
      ),
    );
    final source = widget.touch
        ? LongPressDraggable<RaftConversationTabId>(
            data: id,
            feedback: feedback,
            child: widget.child,
          )
        : Draggable<RaftConversationTabId>(
            data: id,
            feedback: feedback,
            child: widget.child,
          );
    return DragTarget<RaftConversationTabId>(
      onWillAcceptWithDetails: (details) => details.data != id,
      onMove: (_) {
        if (!marked) setState(() => marked = true);
      },
      onLeave: (_) {
        if (marked) setState(() => marked = false);
      },
      onAcceptWithDetails: (details) {
        setState(() => marked = false);
        final next = movedConversationTab(widget.order, details.data, id);
        if (next != widget.order) widget.onReorder(next);
      },
      builder: (context, candidates, _) => DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          border: marked && candidates.isNotEmpty
              // ds-allow: the 2px drop marker mirrors the tab strip's own drop indicator
              ? Border(left: BorderSide(color: t.strong, width: 2))
              : null,
        ),
        child: source,
      ),
    );
  }
}
