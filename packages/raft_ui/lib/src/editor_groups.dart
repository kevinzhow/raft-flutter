import 'dart:ui' show SemanticsRole;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'icons.dart';
import 'design_primitives.dart';
import 'inline_badge_editor.dart' show RaftTouchTargetExpander;
import 'theme.dart';

/// Source workspaceGridDemoConfig global minWidth260/minHeight180 and
/// WorkspaceGridDemo.css's actual (theme-independent) workspace chrome.
abstract final class RaftEditorGroupMetrics {
  static const minimumWidth = 260.0, minimumHeight = 180.0, headerHeight = 48.0;
  static const tabMinimumWidth = 88.0, tabMaximumWidth = 220.0;
  // Same interim thread pane minimum as adaptive_workspace.dart. Independent
  // Source thread editor tabs remain a separate app integration step.
  static const threadPaneWidth = 360.0;
  static const ink = Color(0xff141111), paper = Color(0xffffffff);
}

class RaftEditorTab {
  const RaftEditorTab({
    required this.id,
    required this.label,
    required this.child,
  });
  final String id, label;
  final Widget child;
}

class RaftEditorGroup {
  const RaftEditorGroup({
    required this.id,
    required this.tabs,
    required this.selected,
  });
  final String id, selected;
  final List<RaftEditorTab> tabs;
}

/// Controlled tabsets. The app owns panel admission, controller lifetime and
/// selected refs. Inactive tabs retain their widgets without focus/pointers.
/// Dragging a tab onto a group moves it; the right edge creates a split group.
class RaftEditorGroups extends StatefulWidget {
  const RaftEditorGroups({
    super.key,
    required this.groups,
    required this.onSelect,
    required this.onClose,
    required this.onMove,
    this.onSplit,
    this.onWeightsChanged,
    this.weights = const [],
  });
  final List<RaftEditorGroup> groups;
  final void Function(String group, String tab) onSelect;
  final ValueChanged<String> onClose;
  final void Function(String tab, String group) onMove;
  final ValueChanged<String>? onSplit;
  final ValueChanged<List<double>>? onWeightsChanged;
  final List<double> weights;
  @override
  State<RaftEditorGroups> createState() => _RaftEditorGroupsState();
}

class _RaftEditorGroupsState extends State<RaftEditorGroups> {
  final nodes = <String, FocusNode>{};
  final panelKeys = <String, GlobalKey>{};
  bool dragging = false;
  void setDragging(bool value) {
    if (mounted) setState(() => dragging = value);
  }

  @override
  void dispose() {
    for (final node in nodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  FocusNode node(String id) =>
      nodes.putIfAbsent(id, () => FocusNode(debugLabel: 'workspace-tab-$id'));

  Widget tab(RaftEditorGroup group, RaftEditorTab item) {
    final selected = item.id == group.selected;
    final focus = node(item.id);
    return Draggable<String>(
      data: item.id,
      onDragStarted: () => setDragging(true),
      onDragEnd: (_) => setDragging(false),
      feedback: Material(
        color: RaftEditorGroupMetrics.paper,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Text(item.label),
        ),
      ),
      child: Focus(
        onKeyEvent: (_, event) {
          if (event is! KeyDownEvent ||
              ![
                LogicalKeyboardKey.arrowRight,
                LogicalKeyboardKey.arrowLeft,
              ].contains(event.logicalKey))
            return KeyEventResult.ignored;
          final step = event.logicalKey == LogicalKeyboardKey.arrowRight
              ? 1
              : -1;
          final index = group.tabs.indexWhere((t) => t.id == item.id);
          final next = group
              .tabs[(index + step + group.tabs.length) % group.tabs.length];
          widget.onSelect(group.id, next.id);
          node(next.id).requestFocus();
          return KeyEventResult.handled;
        },
        child: RaftInteractive(
          focusNode: focus,
          semanticLabel: item.label,
          button: false,
          selected: selected,
          onPressed: () => widget.onSelect(group.id, item.id),
          builder: (context, state) => Semantics(
            role: SemanticsRole.tab,
            child: Container(
              key: ValueKey('editor-tab-${item.id}'),
              constraints: const BoxConstraints(minWidth: 88, maxWidth: 220),
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: selected
                    ? RaftEditorGroupMetrics.paper
                    : state.hovered
                    ? RaftTokens.of(context).colors['brutal-cream']
                    : Colors.transparent,
                border: Border(
                  right: BorderSide(
                    color: RaftEditorGroupMetrics.ink.withValues(alpha: .24),
                  ),
                  bottom: BorderSide(
                    color: selected
                        ? RaftEditorGroupMetrics.paper
                        : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
              foregroundDecoration: state.focusVisible
                  ? BoxDecoration(
                      border: Border.all(color: RaftEditorGroupMetrics.ink),
                    )
                  : null,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: RaftTokens.of(context).headingFont,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: RaftEditorGroupMetrics.ink,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Opacity(
                    opacity: selected || state.hovered ? 1 : 0,
                    child: ExcludeFocus(
                      excluding: !selected && !state.hovered,
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: RaftInteractive(
                          semanticLabel: 'Close ${item.label}',
                          onPressed: () => widget.onClose(item.id),
                          builder: (_, s) => DecoratedBox(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: s.hovered
                                  ? RaftEditorGroupMetrics.ink.withValues(
                                      alpha: .08,
                                    )
                                  : Colors.transparent,
                            ),
                            child: const Center(
                              child: RaftIcon(
                                RaftGlyph.x,
                                size: 16,
                                color: RaftEditorGroupMetrics.ink,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget group(RaftEditorGroup group) => DragTarget<String>(
    onAcceptWithDetails: (details) => widget.onMove(details.data, group.id),
    builder: (context, candidates, rejected) => Column(
      children: [
        SizedBox(
          height: 48,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: candidates.isEmpty
                  ? RaftEditorGroupMetrics.paper
                  : RaftTokens.of(context).colors['primary'],
              border: Border(
                bottom: BorderSide(
                  color: RaftEditorGroupMetrics.ink.withValues(alpha: .25),
                ),
              ),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: group.tabs.map((t) => tab(group, t)).toList(),
              ),
            ),
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              for (final item in group.tabs)
                Positioned.fill(
                  child: Offstage(
                    offstage: item.id != group.selected,
                    child: ExcludeFocus(
                      excluding: item.id != group.selected,
                      child: TickerMode(
                        enabled: item.id == group.selected,
                        child: KeyedSubtree(
                          key: panelKeys.putIfAbsent(
                            item.id,
                            () => GlobalKey(
                              debugLabel: 'editor-panel-${item.id}',
                            ),
                          ),
                          child: item.child,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final ids = {
        for (final g in widget.groups)
          for (final t in g.tabs) t.id,
      };
      for (final id in nodes.keys.where((id) => !ids.contains(id)).toList()) {
        nodes.remove(id)!.dispose();
        panelKeys.remove(id);
      }
      final count = widget.groups.length;
      if (count == 0) return const SizedBox.expand();
      final available = bounds.maxWidth - (count - 1);
      final weights = widget.weights.length == count
          ? widget.weights
          : List.filled(count, 1.0 / count);
      final sum = weights.fold<double>(0, (a, b) => a + b);
      final row = Row(
        children: [
          for (var i = 0; i < count; i++) ...[
            Expanded(
              flex: (weights[i] / sum * 10000).round().clamp(1, 10000),
              child: SizedBox(
                key: ValueKey('editor-group-${widget.groups[i].id}'),
                child: group(widget.groups[i]),
              ),
            ),
            if (i < count - 1)
              MouseRegion(
                cursor: SystemMouseCursors.resizeLeftRight,
                child: RaftTouchTargetExpander(
                  minSize: const Size(8, 0),
                  child: GestureDetector(
                    key: ValueKey(
                      'editor-splitter-${widget.groups[i].id}-${widget.groups[i + 1].id}',
                    ),
                    behavior: HitTestBehavior.opaque,
                    onHorizontalDragUpdate:
                        widget.onWeightsChanged == null ||
                            available < count * 260
                        ? null
                        : (d) {
                            final next = [...weights];
                            final delta = d.delta.dx / available * sum;
                            final min = 260 / available * sum;
                            if (next[i] + delta < min ||
                                next[i + 1] - delta < min) {
                              return;
                            }
                            next[i] += delta;
                            next[i + 1] -= delta;
                            widget.onWeightsChanged!(next);
                          },
                    child: Container(
                      width: 1,
                      color: RaftEditorGroupMetrics.ink.withValues(alpha: .25),
                    ),
                  ),
                ),
              ),
          ],
        ],
      );
      return ColoredBox(
        color: RaftEditorGroupMetrics.paper,
        child: Stack(
          children: [
            Positioned.fill(child: row),
            if (widget.onSplit != null && dragging)
              Positioned(
                right: 0,
                top: 48,
                bottom: 0,
                width: 24,
                child: DragTarget<String>(
                  onAcceptWithDetails: (d) => widget.onSplit!(d.data),
                  builder: (_, candidates, rejected) => ColoredBox(
                    color: candidates.isEmpty
                        ? Colors.transparent
                        : RaftTokens.of(context).colors['primary']!,
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}
