import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'design_primitives.dart';
import 'dismiss_scope.dart';
import 'overlays/dialog.dart' show RaftDialogBarrier;
import 'sheet.dart';
import 'settings_layout.dart' show RaftSpace;
import 'text_scaling.dart';
import 'theme.dart';
import 'tokens/raft_tokens.g.dart' show RaftEase;

// One place decides which form a floating window takes. A window states what
// it is for (a [RaftPresentationPolicy]); the window's width gives the layout
// class; the policy maps the class to a form. Nothing else may decide: not the
// platform, not whether the window is open or expanded. A window that is open
// follows the live width, so crossing a breakpoint switches its form in place
// and its content (a text field, a scroll position) keeps its state.

/// How much room the window has, by width. The cuts are the app's own:
/// [RaftLayoutMetrics.desktopBreakpoint] (the one compact predicate, see
/// `RaftAdaptiveWorkspace.compactOf`) and
/// [RaftLayoutMetrics.threadOverlayBreakpoint].
enum RaftLayoutClass {
  /// Phones and narrow desktop windows: below 768.
  compact,

  /// Tablets and foldable inner screens: 768 up to 1024.
  medium,

  /// Desktop windows: 1024 and wider.
  wide,
}

RaftLayoutClass raftLayoutClassForWidth(double width) =>
    width < RaftLayoutMetrics.desktopBreakpoint
    ? RaftLayoutClass.compact
    : width < RaftLayoutMetrics.threadOverlayBreakpoint
    ? RaftLayoutClass.medium
    : RaftLayoutClass.wide;

/// The layout class of the window [context] is in (the raw window width, not a
/// breakpoint band: the cut must be exact).
RaftLayoutClass raftLayoutClassOf(BuildContext context) =>
    raftLayoutClassForWidth(MediaQuery.sizeOf(context).width);

/// What a floating window looks like.
enum RaftSurfaceForm {
  /// Rises from the bottom edge, with a drag handle.
  sheet,

  /// Centered over a scrim.
  dialog,

  /// Docked to the trailing edge.
  side,

  /// Fills the window.
  page,

  /// Anchored to its trigger (menus, selects, hover cards). Drawn by the
  /// anchored overlay widgets, not by [RaftPresentedRoute]; a route asked for
  /// one shows a dialog.
  popover,
}

/// Which form a kind of window takes in each layout class.
@immutable
class RaftPresentationPolicy {
  const RaftPresentationPolicy({
    required this.compact,
    required this.medium,
    required this.wide,
  });

  final RaftSurfaceForm compact, medium, wide;

  RaftSurfaceForm formFor(RaftLayoutClass layout) => switch (layout) {
    RaftLayoutClass.compact => compact,
    RaftLayoutClass.medium => medium,
    RaftLayoutClass.wide => wide,
  };

  /// A short question that needs an answer.
  static const confirm = RaftPresentationPolicy(
    compact: RaftSurfaceForm.dialog,
    medium: RaftSurfaceForm.dialog,
    wide: RaftSurfaceForm.dialog,
  );

  /// Create and edit forms with inputs.
  static const form = RaftPresentationPolicy(
    compact: RaftSurfaceForm.sheet,
    medium: RaftSurfaceForm.dialog,
    wide: RaftSurfaceForm.dialog,
  );

  /// Long text editing with a keyboard (the expanded composer).
  static const editor = RaftPresentationPolicy(
    compact: RaftSurfaceForm.sheet,
    medium: RaftSurfaceForm.dialog,
    wide: RaftSurfaceForm.dialog,
  );

  /// Read-only details: profiles, settings panels.
  static const detail = RaftPresentationPolicy(
    compact: RaftSurfaceForm.page,
    medium: RaftSurfaceForm.side,
    wide: RaftSurfaceForm.side,
  );

  /// Choosing from a list: selects, emoji pickers.
  static const picker = RaftPresentationPolicy(
    compact: RaftSurfaceForm.sheet,
    medium: RaftSurfaceForm.popover,
    wide: RaftSurfaceForm.popover,
  );

  /// Context, overflow and dropdown menus.
  static const menu = RaftPresentationPolicy(
    compact: RaftSurfaceForm.popover,
    medium: RaftSurfaceForm.popover,
    wide: RaftSurfaceForm.popover,
  );

  /// Image, file and document previews.
  static const viewer = RaftPresentationPolicy(
    compact: RaftSurfaceForm.page,
    medium: RaftSurfaceForm.dialog,
    wide: RaftSurfaceForm.dialog,
  );
}

/// The route of a floating window whose form follows the window width.
///
/// One route for every form: the form is read from the live width each build,
/// so a resize switches it without closing the window. [content] is built in
/// whichever frame the form needs and keeps its state across the switch.
///
/// The sheet form is the framework's modal bottom sheet route (scrim, Back,
/// drag-to-dismiss and the sheet's animation come from it) with the
/// design-system look of [RaftSheet]; the dialog, side and page forms are
/// frames of the same route.
// ignore: raft_lints/avoid_raw_bottom_sheet -- the one place a framework sheet route is built on: raft_ui's presentation primitive
class RaftPresentedRoute<T> extends ModalBottomSheetRoute<T> {
  RaftPresentedRoute({
    required RaftPresentationPolicy policy,
    required Widget Function(BuildContext context, RaftSurfaceForm form)
    content,
    required CapturedThemes capturedThemes,
    required RaftSurfaceForm initialForm,
    String? label,
    RouteSettings? settings,
    bool dismissible = true,
    bool dragDismissible = true,
    double dialogMaxWidth = 560,
    double? dialogMaxHeight,
    bool dialogFillsHeight = false,
    bool scrollDialogSurface = false,
    bool dialogScrollbar = true,
    bool sheetFillsHeight = false,
    double Function(BuildContext)? sheetFixedHeight,
    double sheetInitialSize = RaftSheetMetrics.largeDetent,
    double? drawerMaxSize,
    double sideWidth = 420,
    bool reduceMotion = false,
  }) : this._(
         _SheetBuilder(),
         policy: policy,
         content: content,
         capturedThemes: capturedThemes,
         initialForm: initialForm,
         label: label,
         settings: settings,
         dismissible: dismissible,
         dragDismissible: dragDismissible,
         dialogMaxWidth: dialogMaxWidth,
         dialogMaxHeight: dialogMaxHeight,
         dialogFillsHeight: dialogFillsHeight,
         scrollDialogSurface: scrollDialogSurface,
         dialogScrollbar: dialogScrollbar,
         sheetFillsHeight: sheetFillsHeight,
         sheetFixedHeight: sheetFixedHeight,
         sheetInitialSize: sheetInitialSize,
         drawerMaxSize: drawerMaxSize,
         sideWidth: sideWidth,
         reduceMotion: reduceMotion,
       );

  RaftPresentedRoute._(
    this._sheetBuilder, {
    required this.policy,
    required this.content,
    required CapturedThemes capturedThemes,
    required RaftSurfaceForm initialForm,
    String? label,
    super.settings,
    required bool dismissible,
    required this.dragDismissible,
    required this.dialogMaxWidth,
    required this.dialogMaxHeight,
    required this.dialogFillsHeight,
    required this.scrollDialogSurface,
    required this.dialogScrollbar,
    required this.sheetFillsHeight,
    required this.sheetFixedHeight,
    required this.sheetInitialSize,
    required this.drawerMaxSize,
    required this.sideWidth,
    required bool reduceMotion,
  }) : assert(drawerMaxSize == null || drawerMaxSize > sheetInitialSize),
       super(
         builder: _sheetBuilder.call,
         capturedThemes: capturedThemes,
         barrierLabel: label ?? 'Dismiss',
         isDismissible: dismissible,
         isScrollControlled: true,
         useSafeArea: true,
         // A fixed sheet (an editor) is dragged as a whole by the framework's
         // sheet; a scrolling sheet is dragged by its draggable detents, which
         // also decide when a pull at the top of the content closes it.
         enableDrag: sheetFillsHeight && dragDismissible,
         showDragHandle: false,
         // The sheet draws its own surface (ring and float shadow do not
         // survive the route's clipping material): the route paints none.
         backgroundColor: Colors.transparent,
         shape: null,
         elevation: 0,
         clipBehavior: Clip.none,
         constraints: const BoxConstraints(maxWidth: RaftSheetMetrics.maxWidth),
         sheetAnimationStyle: _animationStyle(
           initialForm,
           reduceMotion: reduceMotion,
         ),
       ) {
    _sheetBuilder.target = _buildSheet;
  }

  // The sheet is the raft-ui Drawer (own surface, 240/180ms `ease-slide`) and
  // a dialog has no motion, as the Web Dialog has none.

  // Drawer popup `transition-duration: 240ms` on `--ease-slide`; the exit is
  // `180ms` (drawer_motion recipe; dialog-sheet-context.mjs:42-54).
  // No motion, but not a zero-length animation: a route popped while the tree
  // builds (the composer collapsing on a real disable) must not notify its
  // listeners synchronously. One millisecond is one frame without movement.
  static const _instant = AnimationStyle(
    duration: Duration(milliseconds: 1),
    reverseDuration: Duration(milliseconds: 1),
  );

  static AnimationStyle? _animationStyle(
    RaftSurfaceForm initialForm, {
    required bool reduceMotion,
  }) {
    final centered =
        initialForm == RaftSurfaceForm.dialog ||
        initialForm == RaftSurfaceForm.popover;
    if (reduceMotion || centered) return _instant;
    if (initialForm == RaftSurfaceForm.sheet) {
      return const AnimationStyle(
        duration: Duration(milliseconds: 240),
        reverseDuration: Duration(milliseconds: 180),
        curve: RaftEase.slide,
        reverseCurve: RaftEase.slide,
      );
    }
    return null;
  }

  final _SheetBuilder _sheetBuilder;
  final RaftPresentationPolicy policy;

  /// Builds the window's content for [form]. Called again when the form
  /// changes; the widgets it returns keep their state when they keep their
  /// types and keys.
  final Widget Function(BuildContext context, RaftSurfaceForm form) content;
  final double dialogMaxWidth, sideWidth;
  final double? dialogMaxHeight;

  /// A drag down closes the sheet. Independent of the scrim ([isDismissible]):
  /// a form sheet adds the drag where Web has no backdrop close (an approved
  /// phone difference, docs/close-affordances.md). False for a window no
  /// pointer may close (Web `disablePointerDismissal` on content shown once,
  /// such as new backup codes): the sheet then only moves between its detents.
  final bool dragDismissible;

  /// The dialog takes all the height there is (up to [dialogMaxHeight]).
  final bool dialogFillsHeight;

  /// A form's ordinary dialog scrolls its entire padded surface as Web Modal
  /// does, instead of clipping an inner scrollport at the window inset.
  final bool scrollDialogSurface;

  /// Whether that scrolling backdrop draws a scrollbar ([RaftDialogFrame]).
  final bool dialogScrollbar;

  /// Content manages its own scrolling in a sheet of [sheetFixedHeight],
  /// or [RaftSheetMetrics.largeDetent] of the window by default. Otherwise
  /// the sheet opens at [sheetInitialSize] and can expand to the large detent.
  final bool sheetFillsHeight;
  final double Function(BuildContext)? sheetFixedHeight;
  final double sheetInitialSize;

  /// Opts a scrolling sheet into the Drawer snap-point recipe. The extent is
  /// measured against the available screen, including after a resize.
  final double? drawerMaxSize;
  late final _drawerExtent = ValueNotifier(sheetInitialSize);

  final contentKey = GlobalKey(debugLabel: 'presented content');

  /// The form the live width gives; a popover has no frame here.
  RaftSurfaceForm formOf(BuildContext context) {
    final form = policy.formFor(raftLayoutClassOf(context));
    return form == RaftSurfaceForm.popover ? RaftSurfaceForm.dialog : form;
  }

  Widget _buildSheet(BuildContext context) {
    final media = MediaQuery.of(context);
    final keyboard = media.viewInsets.bottom;
    final body = KeyedSubtree(
      key: contentKey,
      child: Builder(
        builder: (context) => content(context, RaftSurfaceForm.sheet),
      ),
    );
    Widget surface(Widget child) => RaftSheetPanel(child: child);
    // The sheet rides above the keyboard: its room shrinks by the inset.
    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: sheetFillsHeight
          ? LayoutBuilder(
              builder: (context, box) => SizedBox(
                height: math.min(
                  sheetFixedHeight?.call(context) ??
                      media.size.height * RaftSheetMetrics.largeDetent,
                  box.maxHeight,
                ),
                child: surface(
                  RaftSheetScope(scrollController: null, child: body),
                ),
              ),
            )
          : _DetentSheet(
              initialSize: sheetInitialSize,
              maxSize: drawerMaxSize ?? RaftSheetMetrics.largeDetent,
              closesOnDrag: dragDismissible,
              onExtent: drawerMaxSize == null
                  ? null
                  : (size) => _drawerExtent.value = size,
              builder: (controller, drag) => surface(
                RaftSheetScope(
                  scrollController: controller,
                  pointerDrag: drag,
                  child: body,
                ),
              ),
            ),
    );
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final form = formOf(context);
    final frame = capturedThemes!.wrap(
      _PresentedFrame(route: this, form: form),
    );
    // Esc closes whichever form it is. The sheet's framework route already
    // keeps it on one side of a separating fold; a dialog does the same.
    return RaftDismissScope(
      child: switch (form) {
        RaftSurfaceForm.sheet => super.buildPage(
          context,
          animation,
          secondaryAnimation,
        ),
        RaftSurfaceForm.dialog => DisplayFeatureSubScreen(child: frame),
        _ => frame,
      },
    );
  }

  @override
  Widget buildModalBarrier() {
    final barrier = RaftDialogBarrier(
      animation: animation!,
      dismissible: barrierDismissible,
      label: barrierLabel,
      capturedThemes: capturedThemes!,
    );
    // A full page covers the window; a scrim under it would only cost a blur.
    return Builder(
      builder: (context) {
        final form = formOf(context);
        if (form == RaftSurfaceForm.page) return const SizedBox.shrink();
        final maxSize = drawerMaxSize;
        if (form != RaftSurfaceForm.sheet || maxSize == null) return barrier;
        final minimum = RaftSheetMetrics.snapOverlayOpacity(
          RaftTokens.of(context),
        );
        return ValueListenableBuilder<double>(
          valueListenable: _drawerExtent,
          child: barrier,
          builder: (context, extent, child) => Opacity(
            opacity:
                (minimum +
                        (1 - minimum) *
                            (extent - sheetInitialSize) /
                            (maxSize - sheetInitialSize))
                    .clamp(minimum, 1),
            child: child,
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    if (drawerMaxSize != null) _drawerExtent.dispose();
    super.dispose();
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => switch (formOf(context)) {
    // The sheet animates itself, with the route's controller.
    RaftSurfaceForm.sheet => child,
    RaftSurfaceForm.dialog || RaftSurfaceForm.popover => child,
    RaftSurfaceForm.page => SlideTransition(
      position: animation.drive(
        Tween(begin: const Offset(0, 1), end: Offset.zero),
      ),
      child: child,
    ),
    RaftSurfaceForm.side => SlideTransition(
      position: animation.drive(
        Tween(begin: const Offset(1, 0), end: Offset.zero),
      ),
      child: child,
    ),
  };
}

/// The scrolling sheet: draggable detents (the opening size and the large
/// one) with one rule for closing it. A drag down to the bottom is a request
/// to close, answered the way Back and Esc are: [Navigator.maybePop]. A route
/// that vetoes the pop (`PopScope(canPop: false)`, a form with unsaved input)
/// hears `didPop: false` and the sheet slides back to its detent; the framework
/// would close it with a raw `Navigator.pop` instead. Without [closesOnDrag]
/// (a route opened with `dragDismissible: false`) a drag only moves between the detents: let go low or flung down, the sheet
/// slides back to its opening size. Back, Esc and the close button still
/// close it.
class _DetentSheet extends StatefulWidget {
  const _DetentSheet({
    required this.initialSize,
    required this.maxSize,
    required this.builder,
    this.closesOnDrag = true,
    this.onExtent,
  });
  final double initialSize, maxSize;
  final ValueChanged<double>? onExtent;
  final bool closesOnDrag;
  final Widget Function(ScrollController controller, RaftSheetPointerDrag drag)
  builder;

  @override
  State<_DetentSheet> createState() => _DetentSheetState();
}

class _DetentSheetState extends State<_DetentSheet>
    implements RaftSheetPointerDrag {
  final controller = DraggableScrollableController();
  bool asking = false;

  /// The height the sheet's sizes are fractions of.
  double extentHeight = 0;
  static const _minSize = .25;

  /// The lowest the sheet goes: a sheet a drag may not close stops at its
  /// opening size (the framework snaps to its minimum, which would strand it
  /// there).
  double get minSize => widget.closesOnDrag ? _minSize : widget.initialSize;

  List<double> get snapSizes => [
    if (widget.initialSize < widget.maxSize) widget.initialSize,
    widget.maxSize,
  ];

  @override
  void update(double dy) {
    if (!controller.isAttached || extentHeight <= 0) return;
    // Held just above the bottom: reaching it is a request to close, and
    // that is asked once, when the drag ends.
    controller.jumpTo(
      (controller.size - dy / extentHeight).clamp(
        widget.closesOnDrag ? _minSize + .01 : minSize,
        widget.maxSize,
      ),
    );
  }

  @override
  void end(double velocityDy) {
    if (!controller.isAttached) return;
    final size = controller.size;
    // Flung down, or let go below half the opening size: a request to close,
    // answered the way a finger's drag to the bottom is.
    if (widget.closesOnDrag &&
        (velocityDy > 700 || size < widget.initialSize / 2)) {
      // Reaching the bottom asks the route (see [onExtent]).
      unawaited(
        controller.animateTo(
          _minSize,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
        ),
      );
      return;
    }
    final target = velocityDy < -700
        ? widget.maxSize
        : snapSizes.reduce(
            (a, b) => (a - size).abs() <= (b - size).abs() ? a : b,
          );
    unawaited(
      controller.animateTo(
        target,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  bool onExtent(DraggableScrollableNotification n) {
    // Extent notifications arrive during layout. Repaint the sibling modal
    // barrier after this frame's layout has finished.
    final onExtent = widget.onExtent;
    if (onExtent != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) onExtent(n.extent);
      });
    }
    if (!widget.closesOnDrag || n.extent > n.minExtent + .001) return false;
    close();
    return false;
  }

  void close() {
    if (asking || !mounted) return;
    final route = ModalRoute.of(context);
    // A reversing sheet can still report its minimum extent. Its drag
    // belongs to that sheet, even after the route underneath becomes current.
    if (route?.isCurrent != true) return;
    asking = true;
    Navigator.of(context).maybePop().then((_) {
      asking = false;
      // Still open: the route said no. Back to the detent it was opened at.
      if (mounted && route?.isCurrent == true && controller.isAttached) {
        unawaited(
          controller.animateTo(
            widget.initialSize,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      extentHeight = box.maxHeight;
      return NotificationListener<DraggableScrollableNotification>(
        onNotification: onExtent,
        // ignore: raft_lints/avoid_raw_bottom_sheet -- the sheet's detents and nested-scroll coordination come from the framework
        child: DraggableScrollableSheet(
          controller: controller,
          expand: false,
          initialChildSize: widget.initialSize,
          minChildSize: minSize,
          maxChildSize: widget.maxSize,
          snap: true,
          snapSizes: snapSizes,
          // The framework closes at the bottom with a raw pop; this sheet asks.
          shouldCloseOnMinExtent: false,
          builder: (context, scroll) => widget.builder(scroll, this),
        ),
      );
    },
  );
}

/// Lets the route's super constructor take a builder that needs the route.
class _SheetBuilder {
  Widget Function(BuildContext)? target;
  Widget call(BuildContext context) => target!(context);
}

/// Opens [content] in the form [policy] gives the window's layout class.
Future<T?> showRaftPresented<T>(
  BuildContext context, {
  required RaftPresentationPolicy policy,
  required Widget Function(BuildContext context, RaftSurfaceForm form) content,
  String? label,
  RouteSettings? routeSettings,
  bool dismissible = true,
  bool dragDismissible = true,
  double dialogMaxWidth = 560,
  double? dialogMaxHeight,
  bool dialogFillsHeight = false,
  bool sheetFillsHeight = false,
  double sheetInitialSize = RaftSheetMetrics.largeDetent,
}) {
  final navigator = Navigator.of(context, rootNavigator: true);
  return navigator.push(
    raftPresentedRoute<T>(
      context,
      policy: policy,
      content: content,
      label: label,
      routeSettings: routeSettings,
      dismissible: dismissible,
      dragDismissible: dragDismissible,
      dialogMaxWidth: dialogMaxWidth,
      dialogMaxHeight: dialogMaxHeight,
      dialogFillsHeight: dialogFillsHeight,
      sheetFillsHeight: sheetFillsHeight,
      sheetInitialSize: sheetInitialSize,
    ),
  );
}

/// The route [showRaftPresented] pushes, for hosts that keep the route (to
/// close it, or to know whether it is open).
RaftPresentedRoute<T> raftPresentedRoute<T>(
  BuildContext context, {
  required RaftPresentationPolicy policy,
  required Widget Function(BuildContext context, RaftSurfaceForm form) content,
  String? label,
  RouteSettings? routeSettings,
  bool dismissible = true,
  bool dragDismissible = true,
  double dialogMaxWidth = 560,
  double? dialogMaxHeight,
  bool dialogFillsHeight = false,
  bool scrollDialogSurface = false,
  bool dialogScrollbar = true,
  bool sheetFillsHeight = false,
  double Function(BuildContext)? sheetFixedHeight,
  double sheetInitialSize = RaftSheetMetrics.largeDetent,
  double? drawerMaxSize,
}) {
  final navigator = Navigator.of(context, rootNavigator: true);
  return RaftPresentedRoute<T>(
    policy: policy,
    content: content,
    capturedThemes: InheritedTheme.capture(
      from: context,
      to: navigator.context,
    ),
    initialForm: policy.formFor(raftLayoutClassOf(context)),
    reduceMotion: MediaQuery.maybeDisableAnimationsOf(context) ?? false,
    label: label,
    settings: routeSettings,
    dismissible: dismissible,
    dragDismissible: dragDismissible,
    dialogMaxWidth: dialogMaxWidth,
    dialogMaxHeight: dialogMaxHeight,
    dialogFillsHeight: dialogFillsHeight,
    scrollDialogSurface: scrollDialogSurface,
    dialogScrollbar: dialogScrollbar,
    sheetFillsHeight: sheetFillsHeight,
    sheetFixedHeight: sheetFixedHeight,
    sheetInitialSize: sheetInitialSize,
    drawerMaxSize: drawerMaxSize,
  );
}

class _PresentedFrame extends StatelessWidget {
  const _PresentedFrame({required this.route, required this.form});
  final RaftPresentedRoute<dynamic> route;
  final RaftSurfaceForm form;

  @override
  Widget build(BuildContext context) {
    // The key lets the content move between frames with its state.
    final content = KeyedSubtree(
      key: route.contentKey,
      child: Builder(builder: (context) => route.content(context, form)),
    );
    switch (form) {
      case RaftSurfaceForm.page:
        return RaftPageFrame(child: content);
      case RaftSurfaceForm.side:
        return RaftSideFrame(width: route.sideWidth, child: content);
      case RaftSurfaceForm.dialog:
      case RaftSurfaceForm.popover:
      case RaftSurfaceForm.sheet:
        return RaftDialogFrame(
          maxWidth: route.dialogMaxWidth,
          maxHeight: route.dialogMaxHeight,
          fillsHeight: route.dialogFillsHeight,
          scrollSurface: route.scrollDialogSurface,
          showScrollbar: route.dialogScrollbar,
          child: content,
        );
    }
  }
}

/// The dialog frame: centered with the dialog inset around it.
class RaftDialogFrame extends StatelessWidget {
  const RaftDialogFrame({
    super.key,
    required this.child,
    required this.maxWidth,
    this.maxHeight,
    this.fillsHeight = false,
    this.scrollSurface = false,
    this.showScrollbar = true,
  });
  final Widget child;
  final double maxWidth;
  final double? maxHeight;
  final bool fillsHeight;

  /// Scroll the padded surface in the whole available viewport at normal
  /// text size. Large text retains the bounded, pinned-control form layout.
  final bool scrollSurface;

  /// Web's Modal backdrop draws no scrollbar. A surface that wants Web's bare
  /// backdrop turns it off; it also lets a press outside the card reach a
  /// dismissible barrier, which the scrollbar would otherwise swallow.
  final bool showScrollbar;

  /// Space between the window edge and the dialog.
  static const inset = RaftSpace.x4;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    if (scrollSurface &&
        !RaftScaled.grows(context) &&
        !fillsHeight &&
        maxHeight == null) {
      return SafeArea(
        child: LayoutBuilder(
          builder: (context, box) {
            final keyboard = MediaQuery.viewInsetsOf(context).bottom;
            final available = math.max(0.0, box.maxHeight - keyboard);
            return Padding(
              padding: EdgeInsets.only(bottom: keyboard),
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context)
                    .copyWith(scrollbars: showScrollbar),
                child: SingleChildScrollView(
                  // Let a tap outside the card reach the route's dismissible
                  // barrier; dragging can still scroll the full backdrop.
                  hitTestBehavior: HitTestBehavior.translucent,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: available),
                    child: Padding(
                      padding: const EdgeInsets.all(inset),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: maxWidth),
                          child: child,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );
    }
    final fixed = fillsHeight
        ? SizedBox(height: size.height - inset * 2, child: child)
        : child;
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(inset),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxWidth,
              maxHeight: maxHeight ?? double.infinity,
            ),
            child: fixed,
          ),
        ),
      ),
    );
  }
}

/// The full-page frame: opaque, inside the system insets, above the keyboard.
class RaftPageFrame extends StatelessWidget {
  const RaftPageFrame({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return BlockSemantics(
      child: ColoredBox(
        color: t.panel,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: MediaQuery.removeViewInsets(
            context: context,
            removeBottom: true,
            child: SafeArea(child: child),
          ),
        ),
      ),
    );
  }
}

/// The side-panel frame: docked to the trailing edge, full height.
class RaftSideFrame extends StatelessWidget {
  const RaftSideFrame({super.key, required this.child, required this.width});
  final Widget child;
  final double width;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final line = t.colors['line-muted']!;
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: SizedBox(
        width: width,
        height: double.infinity,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: t.panel,
            border: BorderDirectional(start: BorderSide(color: line, width: 1)),
          ),
          child: SafeArea(child: child),
        ),
      ),
    );
  }
}
