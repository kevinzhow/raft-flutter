import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

import 'theme.dart';
import 'design_primitives.dart';
import 'icons.dart';
import 'mounted_avatar_recipe.dart';
import 'recipe_surface.dart';
import 'recipes/app_rail.g.dart';
import 'rail_attention.dart';

/// A window-sized workspace layout. Panel sizes follow the Web panel contract.
/// The host owns navigation, persistence, and the mobile application bar.
class RaftAdaptiveWorkspace extends StatefulWidget {
  const RaftAdaptiveWorkspace({
    super.key,
    required this.content,
    required this.sidebar,
    required this.rail,
    this.thread,
    this.onPresentationChanged,
    this.sidebarVisible = true,
    this.mobileNavigation,
    this.mobileNavigationFloating = false,
    this.sidebarWidth = 240,
    this.threadWidth = 400,
    this.onPanelWidthsChanged,
    this.sidebarResizeLabel = 'Resize sidebar',
    this.threadResizeLabel = 'Resize thread',
    this.trailingExtent = 0,
  });
  final Widget content, sidebar, rail;

  /// The host derives this from the mounted route, not panel width or theme.
  /// Tasks and content masters must not retain hidden conversation navigation.
  final bool sidebarVisible;
  final Widget? thread, mobileNavigation;
  final void Function(bool mainVisible, bool threadVisible)?
  onPresentationChanged;

  /// Source MobileBottomBarStack overlays Elegant bars; Brutal stays in flow.
  final bool mobileNavigationFloating;
  final double sidebarWidth, threadWidth;
  final void Function(double sidebarWidth, double threadWidth)?
  onPanelWidthsChanged;
  final String sidebarResizeLabel, threadResizeLabel;

  /// A separately owned docked panel reserves content width without changing
  /// the viewport breakpoint or remounting the rail, sidebar and editor.
  final double trailingExtent;

  // MainLayout and the overlay ThreadPanel use the pinned Web md/lg cuts.
  static const desktopMinWidth = RaftLayoutMetrics.desktopBreakpoint;
  static const threadMinWidth = RaftLayoutMetrics.threadOverlayBreakpoint;

  @override
  State<RaftAdaptiveWorkspace> createState() => _RaftAdaptiveWorkspaceState();
}

class _RaftAdaptiveWorkspaceState extends State<RaftAdaptiveWorkspace> {
  final mainSlot = GlobalKey();
  final threadSlot = GlobalKey();

  Widget conversation({required bool split, double threadSize = 0}) {
    final folded = widget.thread != null && !split;
    // Visibility keeps the same state owner, excludes hidden focus/semantics,
    // and exposes presentation admission independently of accepted row data.
    widget.onPresentationChanged?.call(!folded, widget.thread != null);
    Widget thread() => KeyedSubtree(key: threadSlot, child: widget.thread!);
    return Stack(
      fit: StackFit.expand,
      children: [
        Row(
          children: [
            Expanded(
              child: KeyedSubtree(
                key: mainSlot,
                child: Visibility(
                  visible: !folded,
                  maintainState: true,
                  child: widget.content,
                ),
              ),
            ),
            if (split && widget.thread != null)
              SizedBox(
                key: const Key('workspace-thread-panel'),
                width: threadSize,
                child: thread(),
              ),
          ],
        ),
        if (folded) Positioned.fill(child: thread()),
      ],
    );
  }

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
        // Keep the content's parent chain stable when a detail hides the bar
        // or the theme switches between in-flow and floating navigation.
        return Column(
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  conversation(split: false),
                  if (widget.mobileNavigationFloating &&
                      widget.mobileNavigation != null)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: widget.mobileNavigation!,
                    ),
                ],
              ),
            ),
            if (!widget.mobileNavigationFloating &&
                widget.mobileNavigation != null)
              widget.mobileNavigation!,
          ],
        );
      }
      final t = RaftTokens.of(context);
      final railWidth = RaftLayoutMetrics.railWidth(
        t,
        MediaQuery.sizeOf(context).height,
      );
      final hasThread = widget.thread != null;
      final conversationWidth =
          width -
          railWidth -
          (widget.sidebarVisible ? sidebarWidth : 0) -
          widget.trailingExtent;
      // index.css thread-layout: real container680 + landscape or viewport xl.
      final sideThread =
          hasThread &&
          conversationWidth >= RaftLayoutMetrics.threadSplitContainerWidth &&
          (width >= RaftLayoutMetrics.threadPortraitSplitViewport ||
              width > MediaQuery.sizeOf(context).height);
      // Keep the main conversation usable while resizing a narrow window.
      final threadMax =
          (width - railWidth - (widget.sidebarVisible ? sidebarWidth : 0) - 320)
              .clamp(360.0, width * .6);
      final actualThread = threadWidth.clamp(360.0, threadMax);
      // Web resizers overlay panel boundaries; their hit area never consumes
      // conversation width (MainLayout's absolute w-2/-right-1 handles).
      return Stack(
        fit: StackFit.expand,
        children: [
          Row(
            children: [
              SizedBox(width: railWidth, child: widget.rail),
              if (widget.sidebarVisible)
                Container(
                  key: const Key('workspace-sidebar-panel'),
                  width: sidebarWidth,
                  decoration: BoxDecoration(
                    border: Border(
                      right: BorderSide(
                        color: t.brutal
                            ? Colors.black
                            : t.colors['line-muted']!,
                        width: t.brutal ? 2 : 1,
                      ),
                    ),
                  ),
                  child: Material(
                    color: t.brutal ? t.colors['brutal-cream'] : t.sidebar,
                    child: widget.sidebar,
                  ),
                ),
              Expanded(
                child: conversation(
                  split: sideThread,
                  threadSize: actualThread,
                ),
              ),
              SizedBox(width: widget.trailingExtent),
            ],
          ),
          if (widget.sidebarVisible)
            Positioned(
              left: railWidth + sidebarWidth - 4,
              top: 0,
              bottom: 0,
              width: 8,
              child: RaftPanelResizeHandle(
                key: const Key('sidebar-resize-handle'),
                label: widget.sidebarResizeLabel,
                value: sidebarWidth,
                onChanged: resizeSidebar,
              ),
            ),
          if (sideThread)
            Positioned(
              right: actualThread - 4,
              top: 0,
              bottom: 0,
              width: 8,
              child: RaftPanelResizeHandle(
                key: const Key('thread-resize-handle'),
                label: widget.threadResizeLabel,
                value: actualThread,
                reversed: true,
                onChanged: (value) => resizeThread(value, threadMax),
              ),
            ),
        ],
      );
    },
  );
}

class RaftPanelResizeHandle extends StatefulWidget {
  /// MainLayout's overlaid w-2 hit strip consumes no panel layout width.
  static const double hitExtent = 8;
  const RaftPanelResizeHandle({
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
  State<RaftPanelResizeHandle> createState() => _ResizeHandleState();
}

class _ResizeHandleState extends State<RaftPanelResizeHandle> {
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
                  : Colors.transparent,
              child: Center(
                child: Container(
                  width: focused || hovering ? 3 : 1,
                  color: focused || hovering ? t.accent : Colors.transparent,
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
    this.icon,
    this.glyph,
    this.iconWidget,
    this.unread = 0,
    this.attention = false,
    this.attentionInactiveOnly = true,
  }) : assert(icon != null || glyph != null || iconWidget != null);
  final String id, label;
  final IconData? icon;
  final RaftGlyph? glyph;
  final Widget? iconWidget;
  final int unread;

  /// Source binary attention; numeric unread remains a separate library API.
  final bool attention, attentionInactiveOnly;
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
    this.workspaceHeader,
    this.footer,
    this.thinDivider = false,
  });
  final List<RaftRailDestination> destinations;
  final String selected, workspaceName, workspaceTooltip;
  final ValueChanged<String> onSelected;
  final VoidCallback onWorkspace;

  /// Mounted Source server-switcher owns the complete header anchor.
  final Widget? workspaceHeader;
  final Widget? footer;

  /// LeftRail's Activity caller uses a one-pixel Brutal border-right override.
  final bool thinDivider;

  Widget railGlyph(RaftRailDestination destination, double size) =>
      destination.iconWidget ??
      (destination.glyph != null
          ? RaftIcon(destination.glyph!, size: size)
          : Icon(destination.icon, size: size));

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
    final nav = RaftAppRailRecipe.resolve(
      theme: t.recipeTheme,
      tokens: t.recipeTokens,
      states: t.recipeStates(),
    ).nav;
    final headerHeight = RaftLayoutMetrics.shellHeaderHeight(
      t,
      MediaQuery.sizeOf(context).height,
    );
    final visualSize = recipe.itemSize;
    // AppRailRoot is a CSS border box: Container reserves its border width
    // before centering children. Explicit zero padding keeps the same padding
    // wrapper in Elegant, preserving child state when the theme changes.
    return Container(
      padding: EdgeInsets.zero,
      decoration: BoxDecoration(
        color: recipe.background,
        border: t.brutal
            ? Border(
                right: thinDivider
                    ? recipe.border.copyWith(width: 1)
                    : recipe.border,
              )
            : null,
      ),
      child: SafeArea(
        child: Column(
          children: [
            workspaceHeader ??
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
                      icon: _RailAvatar(
                        name: workspaceName,
                        size: visualSize - 4,
                      ),
                    ),
                  ),
                ),
            Expanded(
              child: SingleChildScrollView(
                padding: nav.padding,
                child: Column(
                  spacing: nav.rowGap ?? 0,
                  children: [
                    for (final d in destinations)
                      Semantics(
                        selected: selected == d.id,
                        child: Padding(
                          padding: EdgeInsets.zero,
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
                              child: Stack(
                                alignment: Alignment.center,
                                fit: StackFit.expand,
                                clipBehavior: Clip.none,
                                children: [
                                  Center(
                                    child: SizedBox.square(
                                      dimension: recipe.glyphSize,
                                      child: Stack(
                                        clipBehavior: Clip.none,
                                        fit: StackFit.expand,
                                        children: [
                                          railGlyph(d, recipe.glyphSize),
                                          if (d.attention &&
                                              (!d.attentionInactiveOnly ||
                                                  selected != d.id))
                                            RaftRailAttention(
                                              child: railGlyph(
                                                d,
                                                recipe.glyphSize,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  if (d.unread > 0)
                                    Positioned(
                                      right: -4,
                                      top: -4,
                                      child: RaftRailUnreadCount(
                                        count: d.unread,
                                      ),
                                    ),
                                ],
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
    return RaftMountedAvatarFrame(
      name: name,
      identity: RaftMountedAvatarIdentity.server,
      extent: MediaQuery.sizeOf(context).height <= 600 ? 32 : size,
    );
  }
}

/// Numeric AppRailItemBadge slot. Product attention indicators are separate;
/// this component represents only an explicitly supplied positive count.
class RaftRailUnreadCount extends StatelessWidget {
  const RaftRailUnreadCount({super.key, required this.count});
  final int count;
  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    final tokens = RaftTokens.of(context);
    final recipe = RaftAppRailRecipe.resolve(
      theme: tokens.recipeTheme,
      states: tokens.recipeStates(),
      tokens: tokens.recipeTokens,
    );
    return RaftRecipeBox(
      style: recipe.itemBadge,
      tokens: tokens.recipeTokens,
      child: Text(count > 99 ? '99+' : '$count'),
    );
  }
}
