import 'package:flutter/material.dart';

import 'design_primitives.dart';
import 'status_bar.dart';
import 'theme.dart';

/// How a panel surface is presented on screen.
enum RaftPanelPresentation {
  /// Beside another column (rail, sidebar, list) or inside a window / modal:
  /// the panel is a raft-ui `Panel edge="attached"` and draws its left edge.
  attached,

  /// A full-width standalone phone page (width below
  /// [RaftLayoutMetrics.desktopBreakpoint]): nothing sits to its left, so it
  /// draws no left edge (owner decision 2026-10-12, intended difference from
  /// Web).
  phonePage,
}

/// The Web line a surface draws at its left edge.
enum RaftPanelEdgeStyle {
  /// `Panel edge="attached"`: Brutal `border-l-2 border-black`, Elegant
  /// `border-l border-line-muted` (thread / profile / settings panels, the
  /// task thread inside its modal).
  attachedPanel,

  /// ThreadsInbox `ActivityInboxPanel`: Elegant `border-l`, Brutal `!border-l`
  /// (1px), the line beside the rail.
  activityInbox,

  /// OverflowSheet / channel settings drawer: Brutal `border-l-2
  /// border-line-strong`, Elegant none (the drawer is a rounded card).
  drawer,
}

/// The ONE rule for the left edge of attached panels:
///
/// **the attached left edge shows everywhere except when the surface is
/// rendered as a full-width standalone phone page.**
///
/// Every panel surface asks this class; none compares widths or checks its own
/// "mobile" / "detail" / "page" flag. [presentationOf] is the only place that
/// decides what a phone page is, and it reads the same predicate as
/// [RaftLayoutMetrics.desktopBreakpoint] (so the whole width range from a
/// foldable up draws the edge). `test/panel_edge_registry_test.dart` fails on
/// an ad hoc width-gated left border, and `panel_edge_matrix_test.dart`
/// asserts the line at phone, foldable and desktop widths.
abstract final class RaftPanelEdge {
  /// The presentation of the surface built under [context].
  static RaftPanelPresentation presentationOf(BuildContext context) =>
      forWidth(MediaQuery.sizeOf(context).width);

  /// [presentationOf] for a viewport width (previews and tests).
  static RaftPanelPresentation forWidth(double width) =>
      width < RaftLayoutMetrics.desktopBreakpoint
      ? RaftPanelPresentation.phonePage
      : RaftPanelPresentation.attached;

  /// Whether a surface with [presentation] draws its left edge.
  static bool drawsEdge(RaftPanelPresentation presentation) =>
      presentation == RaftPanelPresentation.attached;

  /// The edge line for [style] in theme [t], or null when the theme has none.
  static BorderSide? side(RaftTokens t, RaftPanelEdgeStyle style) {
    switch (style) {
      case RaftPanelEdgeStyle.attachedPanel:
        return BorderSide(color: t.colors['line-muted']!, width: 1);
      case RaftPanelEdgeStyle.activityInbox:
        final width = t.size('stroke.activityInboxEdge', fallback: 1);
        return width == 0 ? null : BorderSide(color: t.line, width: width);
      case RaftPanelEdgeStyle.drawer:
        return null;
    }
  }

  /// The left border a surface draws under [context] (null on a phone page
  /// and for themes without that edge).
  static Border? left(
    BuildContext context, [
    RaftPanelEdgeStyle style = RaftPanelEdgeStyle.attachedPanel,
  ]) => leftFor(RaftTokens.of(context), presentationOf(context), style);

  /// The Activity panel's divider against the navigation column.
  ///
  /// On the left this is [left]. When [RaftNavigationColumnScope] says the
  /// column is on the right, the column already draws the divider that faces
  /// the content, so this returns null. Painting [left] there puts a 1px line
  /// on the window's far edge.
  ///
  /// Settings, the task thread and the channel drawers stay on [left]. Their
  /// line is a column divider or the drawer's own leading edge. It does not
  /// sit on the window when the navigation column is on the right.
  static Border? besideNavigation(
    BuildContext context, [
    RaftPanelEdgeStyle style = RaftPanelEdgeStyle.activityInbox,
  ]) {
    if (RaftNavigationColumnScope.onRightOf(context)) return null;
    return left(context, style);
  }

  /// [left] for an explicit [presentation].
  static Border? leftFor(
    RaftTokens t,
    RaftPanelPresentation presentation, [
    RaftPanelEdgeStyle style = RaftPanelEdgeStyle.attachedPanel,
  ]) {
    if (!drawsEdge(presentation)) return null;
    final line = side(t, style);
    return line == null ? null : Border(left: line);
  }

  /// Web master/detail (`MainLayout` col-2 wrapper `border-r border-line-muted`): the
  /// divider between the list and the detail beside it. It is the same edge as
  /// the detail's left edge, drawn inside the master's width like Web does.
  static Border? masterRight(BuildContext context) {
    if (!drawsEdge(presentationOf(context))) return null;
    final t = RaftTokens.of(context);
    return Border(right: BorderSide(color: t.colors['line-muted']!, width: 1));
  }
}

/// Published by the desktop shell around the content column.
///
/// [onRight] is true when the navigation column sits on the physical right.
/// It is false when that column is on the left, and when no shell has
/// published a side. [RaftPanelEdge.besideNavigation] reads it.
///
/// [RaftRailEdgeScope] is the other "on the right" flag. That scope wraps
/// the rail, and menus the rail opens read it so they open toward the
/// content. This scope wraps the content column. The two subtrees do not
/// overlap. Do not read one in place of the other.
class RaftNavigationColumnScope extends InheritedWidget {
  const RaftNavigationColumnScope({
    super.key,
    required this.onRight,
    required super.child,
  });

  /// The navigation column sits on the physical right.
  final bool onRight;

  static bool onRightOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<RaftNavigationColumnScope>()
          ?.onRight ??
      false;

  @override
  bool updateShouldNotify(RaftNavigationColumnScope oldWidget) =>
      onRight != oldWidget.onRight;
}

/// The master column of a master/detail layout: [RaftPanelEdge.masterRight]
/// while [split] (a detail is open beside it), nothing otherwise. The widget
/// chain is the same either way, so the master keeps its state when the detail
/// opens and closes. The divider takes space inside the master's width (CSS
/// border box) and continues up under the status bar like the other columns.
class RaftPanelMasterEdge extends StatelessWidget {
  const RaftPanelMasterEdge({
    super.key,
    required this.split,
    required this.child,
  });
  final bool split;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final edge = split ? RaftPanelEdge.masterRight(context) : null;
    final backdrop = RaftTokens.of(context).canvas;
    return RaftStatusBarSource(
      color: Colors.transparent,
      border: edge == null
          ? null
          : Border(
              right: edge.right.copyWith(
                color: Color.alphaBlend(edge.right.color, backdrop),
              ),
            ),
      child: Container(
        key: const Key('desktop-master-edge'),
        decoration: BoxDecoration(border: edge),
        child: child,
      ),
    );
  }
}
