import 'hover_region.dart';

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

import 'theme.dart';
import 'panel_edge.dart';
import 'design_primitives.dart';
import 'icons.dart';
import 'mouse_double_click.dart';
import 'mounted_avatar_recipe.dart';
import 'recipe_surface.dart';
import 'recipes/app_rail.g.dart';
import 'rail_attention.dart';
import 'status_bar.dart';
import 'tooltip.dart' show RaftTooltip;
import 'viewport_breakpoints.dart';

/// A window-sized workspace layout. Panel sizes follow the Web panel contract.
/// The host owns navigation, persistence, and the mobile application bar.
///
/// Visited desktop sidebars retain state while hidden; their latest data widgets
/// are applied when shown. Change [key] when the content's authority changes.
class RaftAdaptiveWorkspace extends StatefulWidget {
  const RaftAdaptiveWorkspace({
    super.key,
    required this.content,
    required this.sidebar,
    required this.rail,
    this.thread,
    this.profile,
    this.profileWidth = 380,
    this.onPresentationChanged,
    this.sidebarVisible = true,
    this.mobileNavigation,
    this.mobileRail,
    this.mobileNavigationFloating = false,
    this.mobileNavigationClearance = 0,
    this.sidebarWidth = 240,
    this.threadWidth = 400,
    this.onPanelWidthsChanged,
    this.sidebarResizeLabel = 'Resize sidebar',
    this.threadResizeLabel = 'Resize thread',
    this.trailingExtent = 0,
    this.navigationOnRight = false,
    this.focusScope,
  });
  final Widget content, sidebar, rail;

  /// Thread focus mode (Web `uiStore.threadMaximized`): while the thread sits
  /// beside its conversation, the conversation column can be hidden so the
  /// thread takes the whole row. This widget owns the on/off choice; the host
  /// only says where it may apply. A non-null [focusScope] (the conversation
  /// the thread belongs to) offers the choice; the choice is dropped for good
  /// when the scope changes or goes null, the thread closes or a profile opens
  /// (Web `restoreThreadLayout`). Layout only: it takes effect where the window
  /// shows the side thread (a narrower window keeps the choice without
  /// applying it). The hidden conversation stays mounted but is not presented,
  /// so nothing reads it meanwhile.
  final String? focusScope;

  /// The desktop layout puts its navigation column (rail and sidebar, one
  /// unit) on the physical right edge, and the resizable sidebar's handle,
  /// dividers and the docked [trailingExtent] follow. The host decides (touch
  /// devices follow the rail side choice, see
  /// `RaftWindowClass.desktopNavigationOnRight`); computers keep the left.
  final bool navigationOnRight;

  /// The host derives this from the mounted route, not panel width or theme.
  /// Tasks and content masters exclude conversation navigation from layout,
  /// interaction and semantics.
  final bool sidebarVisible;
  final Widget? thread, mobileNavigation;

  /// The phone layout's navigation when [phoneRailOf] holds: the desktop rail
  /// on the leading edge instead of the bottom bar. Null on pages without root
  /// navigation. [mobileNavigation] then only carries what docks at the bottom
  /// of the content (the live activity strip) and never floats.
  final Widget? mobileRail;

  /// Web `ProfilePanel`: the profile side panel, a surface of its own beside
  /// the thread (both stay mounted); it overlays the thread when the
  /// conversation is too narrow for three columns, and the whole workspace
  /// when folded.
  final Widget? profile;
  final double profileWidth;
  final void Function(bool mainVisible, bool threadVisible)?
  onPresentationChanged;

  /// Source MobileBottomBarStack overlays Elegant bars; Brutal stays in flow.
  final bool mobileNavigationFloating;

  /// Space the floating bar covers above the system inset (Web
  /// `.mobile-nav-clearance`, see `raftTabBarClearance`). Reported to the
  /// content as bottom padding so scroll views clear the capsule.
  final double mobileNavigationClearance;
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

  /// The single compact-layout predicate. Route presentation (platform page vs
  /// desktop dialog or docked detail), history projection and dismissal logic
  /// must all use it rather than the platform, so a narrow desktop window gets
  /// the same pages as a phone and never mixes the two models.
  static bool compactOf(BuildContext context) =>
      MediaQuery.sizeOf(context).width < desktopMinWidth;

  /// Navigation placement inside the compact layout: true when the phone's
  /// root navigation is the left rail (wide foldable, landscape phone,
  /// 600-767 dp windows; see [RaftWindowClass]) rather than the bottom bar.
  /// Presentation only: routes and dialogs keep using [compactOf].
  ///
  /// [side] is the rail side to decide with (the hinge rule depends on it);
  /// without it the nearest [RaftRailSideScope] answers.
  static bool phoneRailOf(BuildContext context, {RaftRailSide? side}) {
    if (!compactOf(context)) return false;
    final size = MediaQuery.sizeOf(context);
    // Folds only matter once the window is rail-sized: a portrait phone must
    // not depend on `displayFeatures` at all (see RaftTextScaling).
    if (!RaftWindowClass.isRailSized(size)) return false;
    return RaftWindowClass.phoneNavigationFor(
          size,
          displayFeatures: MediaQuery.displayFeaturesOf(context),
          textDirection: Directionality.of(context),
          railSide: side ?? RaftRailSideScope.of(context),
        ) ==
        RaftNavigationPlacement.rail;
  }

  @override
  State<RaftAdaptiveWorkspace> createState() => _RaftAdaptiveWorkspaceState();
}

/// How the thread slot is presented (read by the thread's own menu): beside
/// the conversation ([split]) and, then, whether the conversation is hidden
/// for focus mode ([focused]). Absent when the thread is a page of its own.
class RaftThreadPlacement extends InheritedWidget {
  const RaftThreadPlacement({
    super.key,
    required this.split,
    required this.focused,
    this.toggleFocus,
    required super.child,
  });
  final bool split, focused;

  /// Switches focus mode; null where it is not offered (the thread is a page,
  /// no conversation to hide, or a profile panel is open).
  final VoidCallback? toggleFocus;

  static RaftThreadPlacement? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<RaftThreadPlacement>();

  @override
  bool updateShouldNotify(RaftThreadPlacement old) =>
      split != old.split || focused != old.focused;
}

class _RaftAdaptiveWorkspaceState extends State<RaftAdaptiveWorkspace> {
  final mainSlot = GlobalKey();
  final threadSlot = GlobalKey();
  final profileSlot = GlobalKey();
  // The navigation column keeps its state when it swaps sides.
  final railSlot = GlobalKey();
  final sidebarSlot = GlobalKey();

  /// Whether the thread and the profile share the right side (both columns)
  /// rather than the profile covering the thread.
  bool columns(double conversationWidth, double threadSize) =>
      widget.thread != null &&
      widget.profile != null &&
      conversationWidth - threadSize - widget.profileWidth >= 320;

  /// Focus mode is in effect: a side thread, no profile panel beside it.
  bool focusedThread(bool split) =>
      split &&
      focusMode &&
      widget.focusScope != null &&
      widget.thread != null &&
      widget.profile == null;

  /// The person's choice (see [RaftAdaptiveWorkspace.focusScope]).
  bool focusMode = false;

  void toggleFocus() => setState(() => focusMode = !focusMode);

  Widget conversation({
    required bool split,
    double threadSize = 0,
    double conversationWidth = 0,
  }) {
    final hasSide = widget.thread != null || widget.profile != null;
    final folded = hasSide && !split;
    final focused = focusedThread(split);
    final both = split && columns(conversationWidth, threadSize);
    final profileOverThread =
        widget.thread != null && widget.profile != null && !both;
    // Visibility keeps the same state owner, excludes hidden focus/semantics,
    // and exposes presentation admission independently of accepted row data.
    // A thread replaces the main conversation when folded; a profile overlay
    // only covers it (Web `absolute inset-0 z-30`), the chat stays mounted
    // and active underneath.
    final hideMain = widget.thread != null && (!split || focused);
    widget.onPresentationChanged?.call(
      !hideMain,
      widget.thread != null && !(widget.profile != null && !both),
    );
    Widget thread() => KeyedSubtree(
      key: threadSlot,
      child: RaftThreadPlacement(
        split: split,
        focused: focused,
        toggleFocus:
            split && widget.focusScope != null && widget.profile == null
            ? toggleFocus
            : null,
        child: widget.thread!,
      ),
    );
    Widget profile() => KeyedSubtree(key: profileSlot, child: widget.profile!);
    Widget panel(Key key, double? width, Widget child) => Builder(
      builder: (context) {
        final t = RaftTokens.of(context);
        // ThreadPanelRoot / ProfilePanel are attached Panels: their own left
        // border is the divider (dropped when folded).
        final border = RaftPanelEdge.leftFor(
          t,
          RaftPanelPresentation.attached,
        )!;
        // The panel's divider continues up under the status bar; its own
        // header (when flush) publishes the colour over the panel body.
        return RaftStatusBarSource(
          color: Colors.transparent,
          border: _opaqueOver(border, t.canvas),
          child: Container(
            key: key,
            width: width,
            decoration: BoxDecoration(border: border),
            child: child,
          ),
        );
      },
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        Row(
          children: [
            if (focused)
              // The conversation stays mounted at its usual width but takes no
              // room: the thread panel fills the row.
              Offstage(
                child: SizedBox(
                  width: math.max(0, conversationWidth - threadSize),
                  child: KeyedSubtree(
                    key: mainSlot,
                    child: Visibility(
                      visible: false,
                      maintainState: true,
                      child: widget.content,
                    ),
                  ),
                ),
              )
            else
              Expanded(
                child: KeyedSubtree(
                  key: mainSlot,
                  child: Visibility(
                    visible: !hideMain,
                    maintainState: true,
                    child: widget.content,
                  ),
                ),
              ),
            if (focused)
              Expanded(
                child: panel(
                  const Key('workspace-thread-panel'),
                  null,
                  thread(),
                ),
              )
            else if (split && both) ...[
              panel(const Key('workspace-thread-panel'), threadSize, thread()),
              panel(
                const Key('workspace-profile-panel'),
                widget.profileWidth,
                profile(),
              ),
            ] else if (split && profileOverThread)
              panel(
                const Key('workspace-thread-panel'),
                threadSize,
                Stack(
                  fit: StackFit.expand,
                  children: [
                    Positioned.fill(child: ExcludeFocus(child: thread())),
                    Positioned.fill(child: profile()),
                  ],
                ),
              )
            else if (split && widget.thread != null)
              panel(const Key('workspace-thread-panel'), threadSize, thread())
            else if (split && widget.profile != null)
              panel(
                const Key('workspace-profile-panel'),
                widget.profileWidth,
                profile(),
              ),
          ],
        ),
        if (folded && widget.thread != null)
          Positioned.fill(
            child: widget.profile == null
                ? thread()
                : ExcludeFocus(child: thread()),
          ),
        if (folded && widget.profile != null) Positioned.fill(child: profile()),
      ],
    );
  }

  Widget? retainedSidebar;
  late double sidebarWidth = widget.sidebarWidth.clamp(180, 320);
  late double threadWidth = widget.threadWidth;

  @override
  void didUpdateWidget(RaftAdaptiveWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (focusMode &&
        (widget.focusScope == null ||
            widget.focusScope != oldWidget.focusScope ||
            widget.thread == null ||
            widget.profile != null)) {
      focusMode = false;
    }
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

  /// The rail slot of the desktop layout. Menus it opens (server switcher,
  /// notification centre) go toward the content, and a Brutal rail faces its
  /// divider that way.
  Widget navigationRail(RaftTokens t, double railWidth, bool onRight) {
    final rail = RaftRailEdgeScope(onRight: onRight, child: widget.rail);
    // Nothing sits between the rail and the content when the sidebar is away,
    // and a Brutal rail draws its own divider; an Elegant rail on the right
    // would have none facing the content (on the left the content panel's
    // own edge is that line).
    final divider = onRight && !t.brutal && !widget.sidebarVisible
        ? Border(left: BorderSide(color: t.colors['line-muted']!))
        : null;
    return SizedBox(
      key: railSlot,
      width: railWidth,
      // The same chain with or without the line, so the rail keeps its state.
      child: RaftStatusBarSource(
        color: Colors.transparent,
        border: divider == null ? null : _opaqueOver(divider, t.canvas),
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(border: divider),
          child: rail,
        ),
      ),
    );
  }

  /// The sidebar slot of the desktop layout: the visited sidebar keeps its
  /// fixed panel width while another route owns the content. Offstage
  /// consumes no width and excludes paint/hit tests/semantics; focus and
  /// tickers are gated separately. Initial hidden routes remain lazy. Hidden
  /// data widgets catch up atomically when shown, without rebuilding the
  /// inactive list on unrelated owner notifications.
  Widget navigationSidebar(RaftTokens t, Color color, Border border) =>
      Offstage(
        key: sidebarSlot,
        offstage: !widget.sidebarVisible,
        child: retainedSidebar == null
            ? const SizedBox.shrink()
            : TickerMode(
                enabled: widget.sidebarVisible,
                child: ExcludeFocus(
                  excluding: !widget.sidebarVisible,
                  child: RaftStatusBarSource(
                    // The sidebar colour and its divider continue up under
                    // the status bar.
                    color: color,
                    border: _opaqueOver(border, t.canvas),
                    child: Container(
                      key: const Key('workspace-sidebar-panel'),
                      width: sidebarWidth,
                      decoration: BoxDecoration(border: border),
                      child: Material(color: color, child: retainedSidebar),
                    ),
                  ),
                ),
              ),
      );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      if (width < RaftAdaptiveWorkspace.desktopMinWidth) {
        retainedSidebar = null;
        // Keep the content's parent chain stable when a detail hides the bar
        // or the theme switches between in-flow and floating navigation.
        final railed = widget.mobileRail != null;
        // Aspects, not `MediaQuery.of`: this builder re-creates the whole
        // conversation, so it must not depend on `viewInsets`, which changes
        // on every frame of the keyboard animation. The side padding equals
        // the side viewPadding (the keyboard only insets the bottom).
        final screenHeight = MediaQuery.sizeOf(context).height;
        final sideInsets = MediaQuery.viewPaddingOf(context);
        final railOnRight = RaftRailSideScope.onRight(
          RaftRailSideScope.of(context),
          Directionality.of(context),
        );
        return _MobileKeyboardLayout(
          floating: widget.mobileNavigationFloating && !railed,
          clearance: widget.mobileNavigationClearance,
          navigation: widget.mobileNavigation,
          rail: railed
              ? RaftRailEdgeScope(
                  onRight: railOnRight,
                  child: widget.mobileRail!,
                )
              : null,
          // The rail paints under its side's system inset (cutout, side
          // navigation bar); its own SafeArea keeps the buttons clear of it.
          railWidth: railed
              ? RaftLayoutMetrics.railWidth(
                      RaftTokens.of(context),
                      screenHeight,
                    ) +
                    (railOnRight ? sideInsets.right : sideInsets.left)
              : 0,
          railOnRight: railOnRight,
          body: conversation(split: false),
        );
      }
      if (widget.sidebarVisible) retainedSidebar = widget.sidebar;
      final t = RaftTokens.of(context);
      final railWidth = RaftLayoutMetrics.railWidth(
        t,
        MediaQuery.sizeOf(context).height,
      );
      final onRight = widget.navigationOnRight;
      final sidebarColor = t.brutal ? t.colors['brutal-cream']! : t.sidebar;
      // The divider always faces the content.
      final sidebarLine = BorderSide(
        color: t.brutal ? Colors.black : t.colors['line-muted']!,
        width: t.brutal ? 2 : 1,
      );
      final sidebarBorder = onRight
          ? Border(left: sidebarLine)
          : Border(right: sidebarLine);
      final hasThread = widget.thread != null || widget.profile != null;
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
            // Physical order: the column sits on the left or the right edge
            // whatever the text direction.
            textDirection: TextDirection.ltr,
            children: [
              if (!onRight) navigationRail(t, railWidth, onRight),
              if (!onRight) navigationSidebar(t, sidebarColor, sidebarBorder),
              Expanded(
                child: RaftNavigationColumnScope(
                  onRight: onRight,
                  child: conversation(
                    split: sideThread,
                    threadSize: actualThread,
                    conversationWidth: conversationWidth,
                  ),
                ),
              ),
              SizedBox(width: widget.trailingExtent),
              if (onRight) navigationSidebar(t, sidebarColor, sidebarBorder),
              if (onRight) navigationRail(t, railWidth, onRight),
            ],
          ),
          if (widget.sidebarVisible)
            Positioned(
              left: onRight ? null : railWidth + sidebarWidth - 4,
              right: onRight ? railWidth + sidebarWidth - 4 : null,
              top: 0,
              bottom: 0,
              width: 8,
              child: RaftPanelResizeHandle(
                key: const Key('sidebar-resize-handle'),
                label: widget.sidebarResizeLabel,
                value: sidebarWidth,
                // A sidebar on the right grows when dragged left.
                reversed: onRight,
                onChanged: resizeSidebar,
              ),
            ),
          if (sideThread && widget.thread != null && !focusedThread(sideThread))
            Positioned(
              right:
                  (columns(conversationWidth, actualThread)
                      ? widget.profileWidth
                      : 0) +
                  actualThread -
                  4 +
                  (onRight
                      ? railWidth + (widget.sidebarVisible ? sidebarWidth : 0)
                      : 0),
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
    this.onChangeStart,
    this.onChangeEnd,
    this.hairline = false,
  });
  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  final bool reversed;

  /// A drag began (Web's `handleResizeStart`).
  final VoidCallback? onChangeStart;

  /// A drag ended, or a keyboard / semantics step landed (Web persists the
  /// width on pointer up).
  final VoidCallback? onChangeEnd;

  /// The public page's PanelResizeHandle: a `w-px bg-foreground/25` rule
  /// (`group-hover:bg-foreground`, Brutal black) centred on the strip, always
  /// painted. The signed-in shell's resizers paint nothing.
  final bool hairline;

  @override
  State<RaftPanelResizeHandle> createState() => _ResizeHandleState();
}

class _ResizeHandleState extends State<RaftPanelResizeHandle> {
  /// `bg-foreground/25 group-hover:bg-foreground`, Brutal `black/25` / black.
  static Color _hairline(RaftTokens t, bool active) {
    final ink = t.brutal ? Colors.black : t.colors['foreground']!;
    return active ? ink : ink.withValues(alpha: .25);
  }

  bool focused = false, hovering = false;
  double? dragValue;
  void change(double delta) {
    widget.onChangeStart?.call();
    widget.onChanged(widget.value + delta);
    widget.onChangeEnd?.call();
  }

  void end() {
    final dragging = dragValue != null;
    setState(() => dragValue = null);
    if (dragging) widget.onChangeEnd?.call();
  }

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
        child: RaftHoverRegion(
          cursor: SystemMouseCursors.resizeColumn,
          onEnter: (_) => setState(() => hovering = true),
          onExit: (_) => setState(() => hovering = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            dragStartBehavior: DragStartBehavior.down,
            onHorizontalDragStart: (_) {
              widget.onChangeStart?.call();
              setState(() => dragValue = widget.value);
            },
            onHorizontalDragUpdate: (details) {
              dragValue =
                  (dragValue ?? widget.value) +
                  details.delta.dx * (widget.reversed ? -1 : 1);
              widget.onChanged(dragValue!);
            },
            onHorizontalDragEnd: (_) => end(),
            onHorizontalDragCancel: end,
            // Web's panel resizers (MainLayout thread/sidebar/search,
            // LegacyTaskPanel, ProfilePanel) paint nothing: hover and drag
            // only change the cursor. Keyboard focus, which Web lacks, keeps
            // a 1px foreground rule so the focused handle is findable.
            child: SizedBox(
              width: 8,
              child: Center(
                child: Container(
                  width: 1,
                  color: widget.hairline
                      ? _hairline(t, hovering || dragValue != null)
                      : focused && !hovering && dragValue == null
                      ? (t.brutal ? Colors.black : t.colors['foreground']!)
                      : Colors.transparent,
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
    this.onDoubleClick,
  }) : assert(icon != null || glyph != null || iconWidget != null);
  final String id, label;
  final IconData? icon;
  final RaftGlyph? glyph;
  final Widget? iconWidget;
  final int unread;

  /// Source binary attention; numeric unread remains a separate library API.
  final bool attention, attentionInactiveOnly;

  /// LeftRail `onDoubleClick` (Activity: jump to the first unread). Mouse and
  /// trackpad only; a tap keeps selecting the destination.
  final VoidCallback? onDoubleClick;
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
    this.phone = false,
    this.itemAreaKey,
  });

  /// Marks the scrolling destination list (hosts measure it, for example to
  /// exclude the rail from system back gestures).
  final GlobalKey? itemAreaKey;
  final List<RaftRailDestination> destinations;

  /// The rail stands in for the phone's bottom bar: touch buttons keep their
  /// full target (Elegant's compact visual density would shave 8 dp off).
  final bool phone;
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
    final footerScrolls = phone && MediaQuery.sizeOf(context).height <= 600;
    // Reserve the regular divider's inset on every route. Painting Activity's
    // thinner divider must not resize the rail or recenter any of its slots.
    final divider = thinDivider
        ? recipe.border.copyWith(width: 1)
        : recipe.border;
    // On the window's right edge (rail on the end side) the divider faces the
    // content, which is now on the left.
    final onRight = RaftRailEdgeScope.onRightOf(context);
    final railBorder = t.brutal
        ? (onRight ? Border(left: divider) : Border(right: divider))
        : null;
    // The rail colour and its divider continue up under the status bar.
    return RaftStatusBarSource(
      color: recipe.background,
      border: railBorder,
      child: Container(
        width: recipe.width,
        padding: t.brutal
            ? EdgeInsets.only(
                left: onRight ? recipe.border.width : 0,
                right: onRight ? 0 : recipe.border.width,
              )
            : EdgeInsets.zero,
        decoration: BoxDecoration(color: recipe.background),
        foregroundDecoration: BoxDecoration(border: railBorder),
        child: SafeArea(
          child: Column(
            children: [
              workspaceHeader ??
                  SizedBox(
                    height: headerHeight,
                    child: RaftTooltip(
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
                key: itemAreaKey,
                child: SingleChildScrollView(
                  // A phone's 48 dp targets need the whole 56 dp column.
                  padding: phone
                      ? nav.padding
                            .resolve(Directionality.of(context))
                            .copyWith(left: 0, right: 0)
                      : nav.padding,
                  child: Column(
                    spacing: nav.rowGap ?? 0,
                    children: [
                      for (final d in destinations)
                        Semantics(
                          selected: selected == d.id,
                          child: Padding(
                            padding: EdgeInsets.zero,
                            child: RaftTooltip(
                              message: d.label,
                              child: RaftMouseDoubleClick(
                                onDoubleClick: d.onDoubleClick,
                                child: IconButton(
                                  key: ValueKey('rail-${d.id}'),
                                  isSelected: selected == d.id,
                                  constraints: BoxConstraints.tightFor(
                                    width: bounds.layoutHeight,
                                    height: bounds.layoutHeight,
                                  ),
                                  style: IconButton.styleFrom(
                                    visualDensity: phone
                                        ? VisualDensity.standard
                                        : null,
                                    minimumSize: Size.square(
                                      bounds.layoutHeight,
                                    ),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    padding: EdgeInsets.zero,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: recipe.radius,
                                    ),
                                    foregroundColor: t.brutal
                                        ? t.strong
                                        : t.muted,
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
                                  onPressed: () {
                                    if (d.onDoubleClick != null &&
                                        RaftMouseDoubleClick.secondClick) {
                                      return;
                                    }
                                    onSelected(d.id);
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                      // Short phone windows (landscape): the footer scrolls
                      // with the list, so the list is never cut off above a
                      // pinned footer with its tail unreachable-looking.
                      if (footerScrolls && footer != null) footer!,
                    ],
                  ),
                ),
              ),
              if (!footerScrolls && footer != null) footer!,
              const SizedBox(height: 8),
            ],
          ),
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

/// Phone layout: the conversation sits above the keyboard, the tab bar never
/// follows it. The host Scaffold must not resize for the keyboard
/// (`resizeToAvoidBottomInset: false`); this layout shrinks only the content
/// region. The bar stays at the bottom edge and the keyboard simply covers it.
///
/// Floating (elegant) bars overlay the content; in-flow (brutal) bars reserve
/// their own height, so the content only shrinks by the part of the keyboard
/// that rises above the bar.
///
/// With a [rail] (wide foldable, landscape phone) the rail takes the leading
/// edge at full height and the content region is what remains; [navigation]
/// then docks in flow at the bottom of that region. The content keeps its
/// `LayoutId` slot in both placements, so switching never remounts the pages.
class _MobileKeyboardLayout extends StatelessWidget {
  const _MobileKeyboardLayout({
    required this.floating,
    required this.clearance,
    required this.navigation,
    required this.rail,
    required this.railWidth,
    required this.railOnRight,
    required this.body,
  });

  final bool floating;
  final double clearance;
  final Widget? navigation, rail;
  final double railWidth;
  final bool railOnRight;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final keyboard = media.viewInsets.bottom;
    final inFlowBar = navigation != null && !floating;
    // The rail consumed its side's system inset.
    EdgeInsets withoutRailInset(EdgeInsets insets) => rail == null
        ? insets
        : railOnRight
        ? insets.copyWith(right: 0)
        : insets.copyWith(left: 0);
    // The content region ends above the keyboard (and above an in-flow bar), so
    // it no longer overlaps the system bar: padding keeps the engine value
    // (nav height at rest, 0 once the keyboard covers it), viewInsets are spent.
    // A floating bar overlays the content instead: report the space it covers
    // as padding, shrinking as the keyboard (which covers the bar) rises.
    final padding = inFlowBar
        ? 0.0
        : navigation != null
        ? math.max(0.0, clearance + media.viewPadding.bottom - keyboard)
        : media.padding.bottom;
    final content = MediaQuery(
      data: media.copyWith(
        viewInsets: media.viewInsets.copyWith(bottom: 0),
        padding: withoutRailInset(media.padding).copyWith(bottom: padding),
        // Stable system bar height at rest; spent once the keyboard covers it.
        viewPadding: withoutRailInset(media.viewPadding).copyWith(
          bottom: inFlowBar
              ? 0
              : keyboard > 0
              ? media.padding.bottom
              : media.viewPadding.bottom,
        ),
      ),
      child: body,
    );
    return CustomMultiChildLayout(
      delegate: _MobileKeyboardLayoutDelegate(
        floating: floating,
        keyboard: keyboard,
        railWidth: rail == null ? 0 : railWidth,
        railOnRight: railOnRight,
      ),
      children: [
        LayoutId(id: _MobileSlot.content, child: content),
        if (navigation != null)
          LayoutId(id: _MobileSlot.navigation, child: navigation!),
        if (rail != null) LayoutId(id: _MobileSlot.rail, child: rail!),
      ],
    );
  }
}

enum _MobileSlot { content, navigation, rail }

class _MobileKeyboardLayoutDelegate extends MultiChildLayoutDelegate {
  _MobileKeyboardLayoutDelegate({
    required this.floating,
    required this.keyboard,
    required this.railWidth,
    required this.railOnRight,
  });

  final bool floating;
  final double keyboard;
  final double railWidth;
  final bool railOnRight;

  @override
  void performLayout(Size size) {
    var regionLeft = 0.0, regionWidth = size.width;
    if (hasChild(_MobileSlot.rail)) {
      final width = railWidth.clamp(0.0, size.width);
      layoutChild(
        _MobileSlot.rail,
        BoxConstraints.tightFor(width: width, height: size.height),
      );
      positionChild(
        _MobileSlot.rail,
        Offset(railOnRight ? size.width - width : 0, 0),
      );
      regionWidth = size.width - width;
      if (!railOnRight) regionLeft = width;
    }
    var reserved = 0.0;
    if (hasChild(_MobileSlot.navigation)) {
      final bar = layoutChild(
        _MobileSlot.navigation,
        floating
            ? BoxConstraints.tightFor(width: regionWidth)
            : BoxConstraints(maxWidth: regionWidth),
      );
      positionChild(
        _MobileSlot.navigation,
        Offset(
          regionLeft + (regionWidth - bar.width) / 2,
          size.height - bar.height,
        ),
      );
      if (!floating) reserved = bar.height;
    }
    final bottom = keyboard > reserved ? keyboard : reserved;
    layoutChild(
      _MobileSlot.content,
      BoxConstraints.tight(
        Size(regionWidth, (size.height - bottom).clamp(0.0, size.height)),
      ),
    );
    positionChild(_MobileSlot.content, Offset(regionLeft, 0));
  }

  @override
  bool shouldRelayout(_MobileKeyboardLayoutDelegate old) =>
      old.floating != floating ||
      old.keyboard != keyboard ||
      old.railWidth != railWidth ||
      old.railOnRight != railOnRight;
}

/// [border] with its sides composited over [backdrop]: a divider drawn outside
/// a column's own background sits on the page behind it, not on the column.
Border _opaqueOver(Border border, Color backdrop) => Border(
  left: border.left.copyWith(
    color: Color.alphaBlend(border.left.color, backdrop),
  ),
  right: border.right.copyWith(
    color: Color.alphaBlend(border.right.color, backdrop),
  ),
);
