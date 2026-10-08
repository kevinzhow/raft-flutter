import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

import 'theme.dart';
import 'design_primitives.dart';

/// A window-sized workspace layout. Panel sizes follow the Web panel contract.
/// The host owns navigation, persistence, and the mobile application bar.
class RaftAdaptiveWorkspace extends StatefulWidget {
  const RaftAdaptiveWorkspace({
    super.key,
    required this.content,
    required this.sidebar,
    required this.rail,
    this.thread,
    this.mobileNavigation,
    this.sidebarWidth = 240,
    this.threadWidth = 400,
    this.onPanelWidthsChanged,
    this.sidebarResizeLabel = 'Resize sidebar',
    this.threadResizeLabel = 'Resize thread',
  });
  final Widget content, sidebar, rail;
  final Widget? thread, mobileNavigation;
  final double sidebarWidth, threadWidth;
  final void Function(double sidebarWidth, double threadWidth)?
  onPanelWidthsChanged;
  final String sidebarResizeLabel, threadResizeLabel;

  // MainLayout and the overlay ThreadPanel use the pinned Web md/lg cuts.
  static const desktopMinWidth = RaftLayoutMetrics.desktopBreakpoint;
  static const threadMinWidth = RaftLayoutMetrics.threadOverlayBreakpoint;

  @override
  State<RaftAdaptiveWorkspace> createState() => _RaftAdaptiveWorkspaceState();
}

class _RaftAdaptiveWorkspaceState extends State<RaftAdaptiveWorkspace> {
  late double sidebarWidth = widget.sidebarWidth.clamp(180, 320);
  late double threadWidth = widget.threadWidth;

  @override
  void didUpdateWidget(RaftAdaptiveWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sidebarWidth != widget.sidebarWidth) {
      sidebarWidth = widget.sidebarWidth.clamp(180, 320);
    }
    if (oldWidget.threadWidth != widget.threadWidth) {
      threadWidth = widget.threadWidth;
    }
  }

  void resizeSidebar(double value) {
    setState(() => sidebarWidth = value.clamp(180, 320));
    widget.onPanelWidthsChanged?.call(sidebarWidth, threadWidth);
  }

  void resizeThread(double value, double maximum) {
    setState(() => threadWidth = value.clamp(360, maximum));
    widget.onPanelWidthsChanged?.call(sidebarWidth, threadWidth);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      if (width < RaftAdaptiveWorkspace.desktopMinWidth) {
        return Column(
          children: [
            Expanded(child: widget.thread ?? widget.content),
            if (widget.mobileNavigation != null) widget.mobileNavigation!,
          ],
        );
      }
      final t = RaftTokens.of(context);
      final railWidth = RaftLayoutMetrics.railWidth(
        t,
        MediaQuery.sizeOf(context).height,
      );
      final hasThread = widget.thread != null;
      final sideThread =
          hasThread && width >= RaftAdaptiveWorkspace.threadMinWidth;
      // Keep the main conversation usable while resizing a narrow window.
      final threadMax = (width - railWidth - sidebarWidth - 16 - 320).clamp(
        360.0,
        width * .6,
      );
      final actualThread = threadWidth.clamp(360.0, threadMax);
      return Row(
        children: [
          SizedBox(width: railWidth, child: widget.rail),
          Container(
            key: const Key('workspace-sidebar-panel'),
            width: sidebarWidth,
            child: Material(
              color: t.brutal ? t.colors['brutal-cream'] : t.sidebar,
              child: widget.sidebar,
            ),
          ),
          _ResizeHandle(
            key: const Key('sidebar-resize-handle'),
            label: widget.sidebarResizeLabel,
            value: sidebarWidth,
            onChanged: resizeSidebar,
          ),
          Expanded(
            child: hasThread && !sideThread ? widget.thread! : widget.content,
          ),
          if (sideThread) ...[
            _ResizeHandle(
              key: const Key('thread-resize-handle'),
              label: widget.threadResizeLabel,
              value: actualThread,
              reversed: true,
              onChanged: (value) => resizeThread(value, threadMax),
            ),
            SizedBox(
              key: const Key('workspace-thread-panel'),
              width: actualThread,
              child: Material(color: t.canvas, child: widget.thread),
            ),
          ],
        ],
      );
    },
  );
}

class _ResizeHandle extends StatefulWidget {
  const _ResizeHandle({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.reversed = false,
  });
  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  final bool reversed;
  @override
  State<_ResizeHandle> createState() => _ResizeHandleState();
}

class _ResizeHandleState extends State<_ResizeHandle> {
  bool focused = false, hovering = false;
  double? dragValue;
  void change(double delta) => widget.onChanged(widget.value + delta);
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return Semantics(
      label: widget.label,
      value: '${widget.value.round()} px',
      increasedValue: '${widget.value.round() + 16} px',
      decreasedValue: '${widget.value.round() - 16} px',
      onIncrease: () => change(16),
      onDecrease: () => change(-16),
      child: Focus(
        onFocusChange: (value) => setState(() => focused = value),
        onKeyEvent: (_, event) {
          if (event is KeyDownEvent || event is KeyRepeatEvent) {
            if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
              change(widget.reversed ? 16 : -16);
              return KeyEventResult.handled;
            }
            if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
              change(widget.reversed ? -16 : 16);
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: MouseRegion(
          cursor: SystemMouseCursors.resizeColumn,
          onEnter: (_) => setState(() => hovering = true),
          onExit: (_) => setState(() => hovering = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            dragStartBehavior: DragStartBehavior.down,
            onHorizontalDragStart: (_) => dragValue = widget.value,
            onHorizontalDragUpdate: (details) {
              dragValue =
                  (dragValue ?? widget.value) +
                  details.delta.dx * (widget.reversed ? -1 : 1);
              widget.onChanged(dragValue!);
            },
            onHorizontalDragEnd: (_) => dragValue = null,
            onHorizontalDragCancel: () => dragValue = null,
            child: Container(
              width: 8,
              color: focused || hovering
                  ? t.accent.withValues(alpha: .2)
                  : t.brutal
                  ? t.colors['brutal-cream']
                  : t.sidebar,
              child: Center(
                child: Container(
                  width: focused || hovering ? 3 : 1,
                  color: focused || hovering ? t.accent : t.line,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One destination in the app rail. User-generated names remain untranslated.
class RaftRailDestination {
  const RaftRailDestination({
    required this.id,
    required this.label,
    required this.icon,
    this.iconWidget,
    this.unread = 0,
  });
  final String id, label;
  final IconData icon;
  final Widget? iconWidget;
  final int unread;
}

class RaftWorkspaceRail extends StatelessWidget {
  const RaftWorkspaceRail({
    super.key,
    required this.destinations,
    required this.selected,
    required this.onSelected,
    required this.workspaceName,
    required this.onWorkspace,
    this.workspaceTooltip = 'Switch workspace',
    this.footer,
  });
  final List<RaftRailDestination> destinations;
  final String selected, workspaceName, workspaceTooltip;
  final ValueChanged<String> onSelected;
  final VoidCallback onWorkspace;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final recipe = RaftRailRecipe(
      t,
      viewportHeight: MediaQuery.sizeOf(context).height,
    );
    final bounds = RaftControlBounds(
      visualHeight: recipe.itemSize,
      density: RaftDensityScope.of(context),
    );
    final headerHeight = RaftLayoutMetrics.shellHeaderHeight(
      t,
      MediaQuery.sizeOf(context).height,
    );
    final visualSize = recipe.itemSize;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: recipe.background,
        border: t.brutal ? Border(right: recipe.border) : null,
      ),
      child: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: headerHeight,
              child: Tooltip(
                message: workspaceTooltip,
                child: IconButton(
                  key: const Key('rail-workspace'),
                  constraints: BoxConstraints.tightFor(
                    width: bounds.layoutHeight,
                    height: bounds.layoutHeight,
                  ),
                  style: IconButton.styleFrom(
                    minimumSize: Size.square(bounds.layoutHeight),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: const RoundedRectangleBorder(),
                  ),
                  onPressed: onWorkspace,
                  icon: _RailAvatar(name: workspaceName, size: visualSize - 4),
                ),
              ),
            ),
            SizedBox(height: t.brutal ? 8 : 16),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (final d in destinations)
                      Semantics(
                        selected: selected == d.id,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: IconButton(
                            key: ValueKey('rail-${d.id}'),
                            tooltip: d.label,
                            isSelected: selected == d.id,
                            constraints: BoxConstraints.tightFor(
                              width: bounds.layoutHeight,
                              height: bounds.layoutHeight,
                            ),
                            style: IconButton.styleFrom(
                              minimumSize: Size.square(bounds.layoutHeight),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: recipe.radius,
                              ),
                              foregroundColor: t.brutal ? t.strong : t.muted,
                              backgroundColor: Colors.transparent,
                            ),
                            icon: Container(
                              width: visualSize,
                              height: visualSize,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: selected == d.id
                                    ? recipe.selectedBackground
                                    : Colors.transparent,
                                borderRadius: recipe.radius,
                                border: Border.all(
                                  color: selected == d.id && t.brutal
                                      ? t.strong
                                      : Colors.transparent,
                                  width: t.brutal ? 2 : 1,
                                ),
                                boxShadow: selected == d.id && t.brutal
                                    ? [
                                        BoxShadow(
                                          color: t.strong,
                                          offset: const Offset(2, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Badge(
                                isLabelVisible: d.unread > 0,
                                label: Text(
                                  d.unread > 99 ? '99+' : '${d.unread}',
                                ),
                                child:
                                    d.iconWidget ??
                                    Icon(d.icon, size: RaftMetrics.railGlyph),
                              ),
                            ),
                            onPressed: () => onSelected(d.id),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (footer != null) footer!,
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// The workspace marker is an identity avatar, not a Material tonal circle.
class _RailAvatar extends StatelessWidget {
  const _RailAvatar({required this.name, required this.size});
  final String name;
  final double size;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final recipe = RaftRailRecipe(
      t,
      viewportHeight: MediaQuery.sizeOf(context).height,
    );
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: recipe.identityBackground,
        border: Border.fromBorderSide(recipe.border),
        borderRadius: recipe.avatarRadius,
      ),
      child: Text(
        name.isEmpty
            ? 'R'
            : String.fromCharCodes(name.runes.take(1)).toUpperCase(),
        style: TextStyle(
          color: t.ink,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
