import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Maps a scrollbar thumb drag onto a timeline.
abstract interface class RaftTimelineThumbDriver {
  /// Freezes the timeline's content model for a drag; returns the thumb's
  /// fraction of the track (0 = top), or null when it cannot be dragged.
  double? beginThumbDrag();

  /// Shows the content at [fraction] of the frozen model.
  void moveThumb(double fraction);

  void endThumbDrag();
}

/// The desktop scrollbar of a message timeline: the Material scrollbar's
/// look and interactions, with a thumb drag mapped through [driver].
///
/// The default scrollbar maps the pointer onto the live scroll range. A
/// timeline's range is partly estimated and grows when history lands, so the
/// same pointer position kept mapping to a new offset (an older page landing
/// under a thumb held at the top jumped the content to the new top, which
/// requested the next page, and so on) and the thumb drifted from the
/// pointer. Here the thumb follows the pointer exactly against a model frozen
/// at the press; the live range applies again after release.
class RaftTimelineScrollbar extends RawScrollbar {
  const RaftTimelineScrollbar({
    super.key,
    required super.child,
    required ScrollController super.controller,
    required this.driver,
  }) : super(
         // ds-allow: platform scrollbar chrome; mirrors the Material desktop Scrollbar this replaces (material/scrollbar.dart)
         fadeDuration: const Duration(milliseconds: 300),
         timeToFade: const Duration(milliseconds: 600),
         pressDuration: Duration.zero,
       );

  final RaftTimelineThumbDriver driver;

  @override
  RawScrollbarState<RaftTimelineScrollbar> createState() =>
      _RaftTimelineScrollbarState();
}

class _ThumbGrab {
  _ThumbGrab(this.start, this.fraction, this.movable, this.metrics);

  /// Pointer main-axis position and thumb fraction at the press.
  final double start, fraction;

  /// Track length the thumb can travel.
  final double movable;

  /// Scroll metrics at the press; the thumb is painted against them.
  final ScrollMetrics metrics;
  late double current = fraction;

  ScrollMetrics paint() {
    final range = metrics.maxScrollExtent - metrics.minScrollExtent;
    return FixedScrollMetrics(
      minScrollExtent: metrics.minScrollExtent,
      maxScrollExtent: metrics.maxScrollExtent,
      pixels: metrics.minScrollExtent + current * range,
      viewportDimension: metrics.viewportDimension,
      axisDirection: metrics.axisDirection,
      devicePixelRatio: metrics.devicePixelRatio,
    );
  }
}

class _RaftTimelineScrollbarState
    extends RawScrollbarState<RaftTimelineScrollbar> {
  // Material desktop scrollbar defaults (material/scrollbar.dart).
  static const _thicknessIdle = 8.0, _thicknessWithTrack = 12.0;
  static const _margin = 2.0, _minLength = 48.0;
  // ds-allow: platform scrollbar chrome; mirrors the Material desktop Scrollbar this replaces (material/scrollbar.dart)
  static const _radius = Radius.circular(8);

  late final AnimationController hover = AnimationController(
    vsync: this,
    // ds-allow: platform scrollbar chrome; mirrors the Material desktop Scrollbar this replaces (material/scrollbar.dart)
    duration: const Duration(milliseconds: 200),
  )..addListener(updateScrollbarPainter);
  bool hovering = false;
  late ColorScheme colors;
  late ScrollbarThemeData theme;
  _ThumbGrab? grab;

  Set<WidgetState> get states => {
    if (grab != null) WidgetState.dragged,
    if (hovering) WidgetState.hovered,
  };

  @override
  bool get showScrollbar =>
      grab != null || (theme.thumbVisibility?.resolve(states) ?? false);

  @override
  bool get enableGestures => theme.interactive ?? true;

  bool get trackVisible => theme.trackVisibility?.resolve(states) ?? false;

  @override
  void didChangeDependencies() {
    // ds-allow: platform scrollbar chrome; mirrors the Material desktop Scrollbar this replaces (material/scrollbar.dart)
    colors = Theme.of(context).colorScheme;
    theme = ScrollbarTheme.of(context);
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    hover.dispose();
    super.dispose();
  }

  Color thumbColor() {
    final s = states, onSurface = colors.onSurface;
    final light = colors.brightness == Brightness.light;
    final themed = theme.thumbColor?.resolve(s);
    if (s.contains(WidgetState.dragged)) {
      return themed ?? onSurface.withValues(alpha: light ? .6 : .75);
    }
    final hovered = onSurface.withValues(alpha: light ? .5 : .65);
    if (trackVisible) return themed ?? hovered;
    return Color.lerp(
      themed ?? onSurface.withValues(alpha: light ? .1 : .3),
      themed ?? hovered,
      hover.value,
    )!;
  }

  @override
  void updateScrollbarPainter() {
    final s = states, track = showScrollbar && trackVisible;
    final light = colors.brightness == Brightness.light;
    scrollbarPainter
      ..color = thumbColor()
      ..trackColor = track
          ? theme.trackColor?.resolve(s) ??
                colors.onSurface.withValues(alpha: light ? .03 : .05)
          // ds-allow: platform scrollbar chrome; mirrors the Material desktop Scrollbar this replaces (material/scrollbar.dart)
          : const Color(0x00000000)
      ..trackBorderColor = track
          ? theme.trackBorderColor?.resolve(s) ??
                colors.onSurface.withValues(alpha: light ? .1 : .25)
          // ds-allow: platform scrollbar chrome; mirrors the Material desktop Scrollbar this replaces (material/scrollbar.dart)
          : const Color(0x00000000)
      ..textDirection = Directionality.of(context)
      ..thickness =
          theme.thickness?.resolve(s) ??
          (s.contains(WidgetState.hovered) && trackVisible
              ? _thicknessWithTrack
              : _thicknessIdle)
      ..radius = theme.radius ?? _radius
      ..crossAxisMargin = theme.crossAxisMargin ?? _margin
      ..mainAxisMargin = theme.mainAxisMargin ?? 0
      ..minLength = theme.minThumbLength ?? _minLength
      ..padding = MediaQuery.paddingOf(context)
      ..ignorePointer = !enableGestures;
  }

  double mainAxis(Offset offset, ScrollMetrics metrics) =>
      switch (metrics.axisDirection) {
        AxisDirection.down => offset.dy,
        AxisDirection.up => -offset.dy,
        AxisDirection.right => offset.dx,
        AxisDirection.left => -offset.dx,
      };

  @override
  void handleThumbPressStart(Offset localPosition) {
    // Holds the position in a drag activity (no ballistic or alignment
    // fights the thumb) and shows the bar.
    super.handleThumbPressStart(localPosition);
    final controller = widget.controller!;
    if (!controller.hasClients) return;
    final position = controller.position;
    final range = position.maxScrollExtent - position.minScrollExtent;
    final fraction = widget.driver.beginThumbDrag();
    // Track length per unit of scroll range, from the painter's own mapping.
    final perUnit = range > 0 ? scrollbarPainter.getTrackToScroll(1) : 0;
    if (fraction == null || perUnit <= 0) return;
    grab = _ThumbGrab(
      mainAxis(localPosition, position),
      fraction,
      range / perUnit,
      position.copyWith(),
    );
    setState(() {});
    scrollbarPainter.update(grab!.paint(), position.axisDirection);
  }

  @override
  // The update is mapped through the frozen model instead of the live range
  // (see the class comment); RawScrollbar's own mapping must not run.
  // ignore: must_call_super
  void handleThumbPressUpdate(Offset localPosition) {
    final g = grab;
    if (g == null) {
      super.handleThumbPressUpdate(localPosition);
      return;
    }
    final fraction =
        (g.fraction +
                (mainAxis(localPosition, g.metrics) - g.start) / g.movable)
            .clamp(0.0, 1.0);
    // At either end the driver still hears every move (reaching for more).
    if (fraction == g.current && fraction > 0 && fraction < 1) return;
    g.current = fraction;
    scrollbarPainter.update(g.paint(), g.metrics.axisDirection);
    widget.driver.moveThumb(fraction);
  }

  @override
  void handleThumbPressEnd(Offset localPosition, Velocity velocity) {
    if (grab != null) {
      grab = null;
      widget.driver.endThumbDrag();
      setState(() {});
      final controller = widget.controller!;
      if (controller.hasClients) {
        final position = controller.position;
        scrollbarPainter.update(position, position.axisDirection);
      }
    }
    super.handleThumbPressEnd(localPosition, velocity);
  }

  @override
  void handleHover(PointerHoverEvent event) {
    super.handleHover(event);
    if (isPointerOverScrollbar(event.position, event.kind, forHover: true)) {
      setState(() => hovering = true);
      hover.forward();
    } else if (hovering) {
      setState(() => hovering = false);
      hover.reverse();
    }
  }

  @override
  void handleHoverExit(PointerExitEvent event) {
    super.handleHoverExit(event);
    setState(() => hovering = false);
    hover.reverse();
  }

  /// Runs after RawScrollbar's own listeners: while the thumb is held, its
  /// painter keeps the frozen metrics at the pointer's fraction.
  bool keepGrab(Notification notification) {
    final g = grab;
    if (g != null) scrollbarPainter.update(g.paint(), g.metrics.axisDirection);
    return false;
  }

  @override
  Widget build(BuildContext context) =>
      NotificationListener<ScrollNotification>(
        onNotification: keepGrab,
        child: NotificationListener<ScrollMetricsNotification>(
          onNotification: keepGrab,
          child: super.build(context),
        ),
      );
}
