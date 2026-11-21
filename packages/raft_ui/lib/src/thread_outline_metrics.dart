import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'design_primitives.dart';
import 'theme.dart';

/// ConversationOutline: density and placement shared by the rail, popover
/// and drawer. The host owns the rows and what selecting one does.
abstract final class RaftThreadOutlineMetrics {
  static const timelineInset = EdgeInsetsDirectional.only(end: 36);
  static const railMinWidth = 360.0;
  static const railWidth = 28.0;
  static const railExtent = 240.0;
  static const tickExtent = 10.0;
  static const previewWidth = 300.0;
  static const previewHeight = 300.0;
  static const headerHeight = 44.0;
  static const listPadding = EdgeInsets.fromLTRB(6, 4, 6, 8);
  static const titlePadding = EdgeInsets.symmetric(horizontal: 16);
  static const metadataPadding = EdgeInsets.only(top: 2);
  static const metadataGap = 6.0;
  static const railRight = 8.0;
  static const mediumRow = 44.0;
  static const compactRow = 30.0;
  static const currentTick = Size(22, 3);
  static const tick = Size(12, 2);

  static double popoverWidth(double viewport) => math.min(360, viewport - 16);
  static double popoverHeight(double viewport) => math.min(560, viewport - 96);

  static EdgeInsetsDirectional rowPadding(bool compact) =>
      EdgeInsetsDirectional.fromSTEB(12, compact ? 2 : 8, 6, compact ? 2 : 8);

  static BorderRadius rowCorners(RaftTokens tokens) =>
      RaftShapes.control(tokens, mediumRow);

  static BorderRadius get tickCorners => BorderRadius.circular(tick.height);
}

/// Keeps the outline gutter inside the timeline viewport so the active
/// search-row fill can reach it while message content stays clear of the rail.
class RaftThreadOutlineGutter extends InheritedWidget {
  const RaftThreadOutlineGutter({
    super.key,
    required this.visible,
    required super.child,
  });

  final bool visible;

  EdgeInsetsDirectional get inset => visible
      ? RaftThreadOutlineMetrics.timelineInset
      : EdgeInsetsDirectional.zero;

  static EdgeInsetsDirectional? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<RaftThreadOutlineGutter>()
      ?.inset;

  static double contentWidth(BuildContext context, double viewportWidth) =>
      viewportWidth - (maybeOf(context)?.end ?? 0);

  @override
  bool updateShouldNotify(RaftThreadOutlineGutter oldWidget) =>
      visible != oldWidget.visible;
}
