part of 'mobile_navigation.dart';

// raft-ui 0.95.3 mobile-nav-server (`MobileNavServerPopover`,
// `MobileNavServerItem`, `MobileNavServerPopoverContent`): the bar's server
// tab and its popover. Every number comes from the `mobileNavServer` recipe;
// what is written here is behaviour (hold, focus, geometry rules) that the
// source keeps in script.

/// How long a hold takes to open the popover (the long press of raft-ui's
/// menus), and how far a pointer may move before the hold is given up.
const _serverHold = Duration(milliseconds: 500);
const _serverHoldSlop = 10.0;

/// Wraps the whole bar so the server popover can anchor to it rather than to
/// its cell (`trigger.closest("[data-slot=mobile-nav-root]")`).
class _MobileNavBarAnchor extends StatefulWidget {
  const _MobileNavBarAnchor({required this.child});
  final Widget child;
  @override
  State<_MobileNavBarAnchor> createState() => _MobileNavBarAnchorState();
}

class _MobileNavBarAnchorState extends State<_MobileNavBarAnchor> {
  final key = GlobalKey(debugLabel: 'mobile nav bar');

  /// The bar in the coordinates of [overlay], once it has been laid out.
  Rect? rectIn(RenderBox overlay) {
    final box = key.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero, ancestor: overlay) & box.size;
  }

  @override
  Widget build(BuildContext context) => _BarAnchorScope(
    anchor: this,
    child: KeyedSubtree(key: key, child: widget.child),
  );
}

class _BarAnchorScope extends InheritedWidget {
  const _BarAnchorScope({required this.anchor, required super.child});
  final _MobileNavBarAnchorState anchor;
  static _MobileNavBarAnchorState? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_BarAnchorScope>()?.anchor;
  @override
  bool updateShouldNotify(_BarAnchorScope old) => false;
}

/// What the docked bar tells its trailing cell: the shared geometry and the
/// cell's width.
class _DockedCellScope extends InheritedWidget {
  const _DockedCellScope({
    required this.geometry,
    required this.width,
    required super.child,
  });
  final _DockedNavGeometry geometry;
  final double width;
  static _DockedCellScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_DockedCellScope>();
  @override
  bool updateShouldNotify(_DockedCellScope old) =>
      geometry != old.geometry || width != old.width;
}

/// Shared between the popover's sizing and its parts.
class _PopoverMetrics {
  /// The list's natural height, written while [budget] is infinite.
  double natural = 0;

  /// The list's one-row minimum.
  double min = 0;
  bool hasList = false;
}

/// The open popover, for the parts inside it.
class _ServerPopoverHandle {
  _ServerPopoverHandle(this.close);
  final VoidCallback close;
  final metrics = _PopoverMetrics();

  /// The row marked `current`: the focus on a keyboard open, the row the list
  /// opens on.
  FocusNode? currentFocus;
  BuildContext? currentRow;
}

class _ServerPopoverScope extends InheritedWidget {
  const _ServerPopoverScope({required this.handle, required super.child});
  final _ServerPopoverHandle handle;
  static _ServerPopoverHandle? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_ServerPopoverScope>()?.handle;
  @override
  bool updateShouldNotify(_ServerPopoverScope old) => handle != old.handle;
}

/// A radius taken from a token, not a literal.
BorderRadius _tokenRadius(double r) => BorderRadius.all(Radius.circular(r));

/// The server tab: the last cell of [RaftMobileNav] (its `trailing`), the
/// current server's avatar where the other tabs have an icon and its name as
/// the label, and the popover it opens above the bar.
///
/// It is never selected: it holds no page. A press opens the popover, and so
/// does holding it for 500ms; lifting the finger after a hold never closes it.
/// The popover is [contentBuilder]'s widget, usually a column of
/// [RaftMobileNavServerPopoverList], [RaftMobileNavServerPopoverGroup] and
/// [RaftMobileNavServerPopoverDestinations] with
/// [RaftMobileNavServerPopoverSeparator]s between.
class RaftMobileNavServerTab extends StatefulWidget {
  const RaftMobileNavServerTab({
    super.key,
    required this.label,
    required this.avatar,
    required this.contentBuilder,
    this.semanticLabel,
    this.attention = false,
    this.attentionKey,
    this.onOpenChanged,
    this.focusNode,
    this.popoverKey,
  });

  /// The server's name, in the bar's label style; truncates.
  final String label;

  /// Replaces [label] for assistive technology.
  final String? semanticLabel;

  /// The server's avatar; the tab sizes it 22px.
  final Widget avatar;

  /// The accent pixel on the avatar's top-right corner.
  final bool attention;

  /// Key of that pixel while [attention] is on.
  final Key? attentionKey;

  /// Builds the popover's content. [close] closes the popover and returns the
  /// focus to the tab.
  final Widget Function(BuildContext context, VoidCallback close)
  contentBuilder;
  final ValueChanged<bool>? onOpenChanged;

  /// The tab's focus, so the app can give it back (for example after a pushed
  /// page).
  final FocusNode? focusNode;

  /// Put on the popover's content root.
  final Key? popoverKey;

  @override
  State<RaftMobileNavServerTab> createState() => _RaftMobileNavServerTabState();
}

class _RaftMobileNavServerTabState extends State<RaftMobileNavServerTab>
    with WidgetsBindingObserver {
  final portal = OverlayPortalController();
  final popoverFocus = FocusNode(
    debugLabel: 'server popover',
    skipTraversal: true,
  );
  FocusNode? ownFocus;
  Timer? hold;
  Offset? holdStart;
  bool held = false, open = false, remeasure = false;
  late final _ServerPopoverHandle handle = _ServerPopoverHandle(close);

  FocusNode get focus =>
      widget.focusNode ?? (ownFocus ??= FocusNode(debugLabel: 'server tab'));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    hold?.cancel();
    popoverFocus.dispose();
    ownFocus?.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    // The bar moves with the window (a keyboard, a rotation): measure it
    // again in the committed layout and place the popover over it.
    if (!open || remeasure) return;
    remeasure = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      remeasure = false;
      if (mounted && open) setState(() {});
    });
  }

  void show() {
    if (open) return;
    setState(() => open = true);
    portal.show();
    widget.onOpenChanged?.call(true);
    // The popover is built next frame; focus goes in once it exists: the
    // current row (Web v1.24 does so for a touch open too, which differs from
    // the raft-ui comment; the app's rows are not text fields, so no keyboard
    // comes up), else the popover itself.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !open) return;
      final row = handle.currentFocus;
      if (row != null && row.canRequestFocus) {
        row.requestFocus();
      } else {
        popoverFocus.requestFocus();
      }
    });
  }

  void close() {
    if (!open) return;
    setState(() => open = false);
    portal.hide();
    handle.currentFocus = null;
    handle.currentRow = null;
    widget.onOpenChanged?.call(false);
    focus.requestFocus();
  }

  void press() {
    // The click that ends a hold is not a press, whether the hold opened the
    // popover or found it open.
    if (held) {
      held = false;
      return;
    }
    open ? close() : show();
  }

  void pointerDown(PointerDownEvent e) {
    hold?.cancel();
    held = false;
    if (e.buttons != kPrimaryButton) return;
    holdStart = e.position;
    hold = Timer(_serverHold, () {
      hold = null;
      held = true;
      if (!open) show();
    });
  }

  void pointerMove(PointerMoveEvent e) {
    final start = holdStart;
    if (start != null && (e.position - start).distance > _serverHoldSlop) {
      cancelHold();
    }
  }

  void cancelHold() {
    hold?.cancel();
    hold = null;
    holdStart = null;
  }

  @override
  Widget build(BuildContext context) {
    final anchor = _BarAnchorScope.maybeOf(context);
    return TapRegion(
      groupId: this,
      onTapOutside: (_) => close(),
      // ds-allow: the server popover hosts its own bar-anchored overlay; no shared host takes an anchor that is not its trigger
      child: OverlayPortal(
        controller: portal,
        overlayChildBuilder: (context) => _popover(context, anchor),
        child: Listener(
          onPointerDown: pointerDown,
          onPointerMove: pointerMove,
          onPointerUp: (_) => cancelHold(),
          onPointerCancel: (_) => cancelHold(),
          child: _cell(context),
        ),
      ),
    );
  }

  Widget _cell(BuildContext context) {
    final scope = _DockedCellScope.maybeOf(context);
    final label = raftText(context, widget.label);
    return RaftLargeContentViewer(
      label: label,
      onActivate: press,
      iconBuilder: (context, size) =>
          SizedBox.square(dimension: size, child: widget.avatar),
      child: RaftInteractive(
        focusNode: focus,
        semanticLabel: widget.semanticLabel ?? label,
        tooltip: scope == null || !scope.geometry.labels ? label : null,
        onPressed: press,
        builder: (context, state) => scope == null
            ? _capsuleCell(context, state)
            : _dockedCell(context, scope, state),
      ),
    );
  }

  Widget _avatar(BuildContext context) {
    final size = RaftMobileNavServerRecipe.resolve(
      tokens: RaftTokens.of(context).recipeTokens,
    ).item.target(':is(& > *)[data-slot="avatar"]');
    final px = size?.width ?? 22;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        SizedBox.square(dimension: px, child: widget.avatar),
        if (widget.attention)
          // Centred on the avatar's top-right corner: (100%, 0).
          Positioned(
            top: -4,
            right: -4,
            child: ExcludeSemantics(
              child: RaftStatus(
                key: widget.attentionKey,
                size: RaftStatusSize.sm,
                variant: RaftStatusVariant.accent,
              ),
            ),
          ),
      ],
    );
  }

  /// The popup-open sticker fill, `data-popup-open:before:bg-fill-medium`.
  Color? _openFill(RaftTokens t) => RaftMobileNavServerRecipe.resolve(
    tokens: t.recipeTokens,
    states: t.recipeStates(extra: const ['data-popup-open']),
  ).item.before?.backgroundColor?.resolve(t.recipeTokens);

  Widget _dockedCell(
    BuildContext context,
    _DockedCellScope scope,
    RaftInteractionState state,
  ) {
    final g = scope.geometry, t = g.t, width = scope.width;
    final fill = open
        ? _openFill(t)
        : state.pressed
        ? t.colors['layer-mobile-nav-pressed']
        : null;
    final sticker = Container(
      key: const ValueKey('mobile-nav-server-sticker'),
      width: g.n('size.mobileNavStickerWidth', 56),
      height: g.n('size.mobileNavStickerHeight', 30),
      decoration: BoxDecoration(
        color: fill ?? Colors.transparent,
        borderRadius: _tokenRadius(g.n('radius.mobileNavSticker', 8)),
      ),
    );
    final style = g.labelStyle(false);
    final text = ExcludeSemantics(
      child: t.option('mobileNav.textLayout', or: 'css') == 'css'
          ? RaftCssText(
              raftText(context, widget.label),
              style: style,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : Text(
              raftText(context, widget.label),
              style: style,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
    );
    return SizedBox(
      width: width,
      height: g.targetHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: g.top - g.targetTop,
            left: 0,
            width: width,
            height: g.height,
            child: CustomPaint(
              foregroundPainter: RaftCssFocusOutline(
                enabled: state.focusVisible,
                color: t.colors['line-strong']!,
                radius: _tokenRadius(g.n('radius.mobileNavSticker', 8)),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.topCenter,
                children: [
                  if (g.iconSticker) g.box(sticker),
                  Padding(
                    padding: EdgeInsets.only(
                      top: g.n('space.mobileNavItemTop', 4),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (g.glyphs) g.box(_avatar(context)),
                        if (g.glyphs && g.labels)
                          SizedBox(height: g.n('space.mobileNavGlyphLabel', 7)),
                        if (g.labels) text,
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The floating capsule keeps its icon-only cells: the avatar, and the
  /// name as the tooltip.
  Widget _capsuleCell(BuildContext context, RaftInteractionState state) {
    final t = RaftTokens.of(context);
    return Container(
      decoration: BoxDecoration(
        color: open
            ? _openFill(t)
            : state.pressed
            ? t.colors['fill-strong']
            : null,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: _avatar(context),
    );
  }

  Widget _popover(BuildContext context, _MobileNavBarAnchorState? anchor) {
    final overlay = Overlay.of(context).context.findRenderObject();
    final rect = overlay is RenderBox ? anchor?.rectIn(overlay) : null;
    if (rect == null) return const SizedBox.shrink();
    final t = RaftTokens.of(context);
    final rt = t.recipeTokens;
    final style = RaftMobileNavServerRecipe.resolve(
      tokens: rt,
      states: t.recipeStates(),
    );
    final popover = RaftPopoverRecipe.resolve(
      tokens: rt,
      states: t.recipeStates(),
    ).content;
    // `min-w-0` replaces the popover's 220px minimum.
    final surface = popover.copyWith(
      properties: {...popover.properties}..remove('min-width'),
    );
    final view = MediaQuery.sizeOf(context);
    final safeTop = MediaQueryData.fromView(View.of(context)).padding.top;
    const gap = 8.0, collision = 8.0;
    // `--available-height`: the room above the bar between the 8px gap and
    // the 8px collision padding, less the top safe area.
    final available = math.max(0.0, rect.top - gap - collision - safeTop);
    // A transparent barrier over everything but the bar: a tap outside closes
    // the popover and is absorbed; the bar stays live (another tab navigates,
    // the server tab closes).
    Widget barrier(Rect r) => Positioned.fromRect(
      rect: r,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => close(),
        onSecondaryTapDown: (_) => close(),
      ),
    );
    final screen = Offset.zero & Size(view.width, view.height);
    return RaftBackDismiss(
      onDismiss: close,
      child: Stack(
        children: [
          barrier(Rect.fromLTRB(0, 0, screen.right, rect.top)),
          barrier(Rect.fromLTRB(0, rect.top, rect.left, rect.bottom)),
          barrier(
            Rect.fromLTRB(rect.right, rect.top, screen.right, rect.bottom),
          ),
          barrier(Rect.fromLTRB(0, rect.bottom, screen.right, screen.bottom)),
          Positioned.fill(
            child: _popoverBody(
              context,
              rect,
              gap,
              surface,
              style,
              view,
              available,
            ),
          ),
        ],
      ),
    );
  }

  Widget _popoverBody(
    BuildContext context,
    Rect rect,
    double gap,
    RaftSlotStyle surface,
    RaftMobileNavServerRecipeStyle style,
    Size view,
    double available,
  ) {
    return CustomSingleChildLayout(
      delegate: _ServerPopoverPlacement(rect, gap),
      child: TapRegion(
        groupId: this,
        child: RaftDismissScope(
          onDismiss: close,
          child: Focus(
            focusNode: popoverFocus,
            child: KeyedSubtree(
              key: widget.popoverKey,
              // The popover is content, not chrome: it follows the system
              // text size even though the bar caps its own.
              child: MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: RaftChrome.contentScalerOf(context)),
                child: RaftPopoverSurface(
                  surfaceStyle: surface,
                  padding: EdgeInsets.zero,
                  child: _ServerPopoverScope(
                    handle: handle,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: available),
                      child: SingleChildScrollView(
                        primary: false,
                        child: _PopoverSizer(
                          metrics: handle.metrics,
                          preferred:
                              view.height *
                              (style.content.maxHeight == null ? .6 : .6),
                          available: available,
                          child: widget.contentBuilder(context, close),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ServerPopoverPlacement extends SingleChildLayoutDelegate {
  const _ServerPopoverPlacement(this.bar, this.gap);
  final Rect bar;
  final double gap;
  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints.tightFor(width: math.max(0, bar.width - 16));
  @override
  Offset getPositionForChild(Size size, Size childSize) =>
      Offset(bar.left + 8, bar.top - gap - childSize.height);
  @override
  bool shouldRelayout(_ServerPopoverPlacement old) =>
      bar != old.bar || gap != old.gap;
}

/// `max-h-[min(max(60dvh, floor), available - safe top)]`, as tall as its
/// content. The floor keeps the list at its one-row minimum: the content is
/// measured with the list at its natural height, then laid out again at the
/// final height, where the list (a `Flexible` of the content's column) takes
/// the room that is left. Where even the floor does not fit
/// the available height, the whole content is taller than its scroll view.
class _PopoverSizer extends SingleChildRenderObjectWidget {
  const _PopoverSizer({
    required this.metrics,
    required this.preferred,
    required this.available,
    required super.child,
  });
  final _PopoverMetrics metrics;
  final double preferred, available;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderPopoverSizer(metrics, preferred, available);
  @override
  void updateRenderObject(BuildContext context, _RenderPopoverSizer ro) => ro
    ..metrics = metrics
    ..preferred = preferred
    ..available = available;
}

class _RenderPopoverSizer extends RenderBox
    with RenderObjectWithChildMixin<RenderBox> {
  _RenderPopoverSizer(this._metrics, this._preferred, this._available);
  _PopoverMetrics _metrics;
  double _preferred, _available;
  set metrics(_PopoverMetrics v) {
    if (v == _metrics) return;
    _metrics = v;
    markNeedsLayout();
  }

  set preferred(double v) {
    if (v == _preferred) return;
    _preferred = v;
    markNeedsLayout();
  }

  set available(double v) {
    if (v == _available) return;
    _available = v;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderObject child) {
    if (child.parentData is! BoxParentData) child.parentData = BoxParentData();
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      Size(constraints.maxWidth, 0);

  @override
  void performLayout() {
    final child = this.child!;
    final w = constraints.maxWidth;
    final m = _metrics..hasList = false;
    child.layout(
      BoxConstraints(minWidth: w, maxWidth: w),
      parentUsesSize: true,
    );
    final natural = child.size.height;
    if (!m.hasList) {
      size = Size(w, natural);
      return;
    }
    final floor = natural - m.natural + m.min;
    final cap = math.min(math.max(_preferred, floor), _available);
    final height = math.min(natural, math.max(cap, floor));
    child.layout(BoxConstraints.tightFor(width: w, height: height));
    size = Size(w, height);
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      context.paintChild(child!, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      child!.hitTest(result, position: position);
}
