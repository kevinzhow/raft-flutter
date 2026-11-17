// raft-ui 0.95.3 `SelectionToolbar` / `SelectionToolbarDock` (wip), the generic
// bar over a list or page while items are selected: the count, the actions on
// the selection, More while some are out of the row, then x. One row at any
// width: what does not fit gives way, in this order (selection-toolbar.mjs
// :14-27): the secondary actions into More (the last first), then the labels
// (the last first), then the other actions into More (the last first). The
// count and x never do. The steps are taken by the shared fit engine
// (raft/fit_toolbar.dart), so nothing flickers.
//
// Facts and callbacks only: the app owns the selection, each action's work,
// the popovers it opens from [RaftSelectionBarAction.onPressed] and what each
// action shows in More. Not the message select-mode bar (RaftSelectionToolbar
// in message_export.dart, v1.21 SelectModeToolbar), which is a separate
// package's surface.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'design_primitives.dart';
import 'icons.dart';
import 'localization.dart';
import 'raft/button.dart';
import 'raft/fit_toolbar.dart';
import 'popover_anchor.dart';
import 'raft/ui_tokens.dart';
import 'recipes/recipe_runtime.dart' show CssNum, RaftSlotStyle;
import 'system_inset.dart';
import 'theme.dart';
import 'token_geometry.dart';
import 'tokens/tokens.dart';

/// The order things give way in (selection-toolbar.mjs `HINT_STEP` ...).
const int raftSelectionBarSecondaryStep = 20;
const int raftSelectionBarLabelStep = 30;
const int raftSelectionBarMoreStep = 40;

/// One action on the selection (`SelectionToolbarAction`): a 14px icon and a
/// label, an `md` ghost button with a mouse on a desktop, a 44px bar button
/// showing its icon alone on a phone and a touch screen.
@immutable
class RaftSelectionBarAction {
  const RaftSelectionBarAction({
    required this.id,
    required this.label,
    required this.glyph,
    this.onPressed,
    this.onOpen,
    this.menuEntries,
    this.menu = false,
    this.secondary = false,
    this.enabled = true,
    this.moreEntries = const [],
    this.popover,
  });

  /// Names the action's key (`selection-bar-action-<id>`).
  final String id;

  /// Already translated; the accessible name and, once the label has gone, the
  /// tooltip.
  final String label;
  final RaftGlyph glyph;

  /// The action ran.
  final VoidCallback? onPressed;

  /// The action opens something of the app's (the assignee picker): [anchor]
  /// is the button's context, to anchor the popup on. Implies [menu].
  final void Function(BuildContext anchor)? onOpen;

  /// The bar opens this menu upward from the action (the status menu).
  final List<RaftMenuEntry>? menuEntries;

  /// The bar opens this popover of the app's (the searchable assignee
  /// picker) anchored on the action, over it where there is no room under;
  /// [close] closes it. Implies [menu].
  final Widget Function(BuildContext context, VoidCallback close)? popover;

  /// A chevron after the label: the action opens something. Implied by
  /// [menuEntries] and [onOpen].
  final bool menu;

  /// Gives way to More before any label does.
  final bool secondary;
  final bool enabled;

  /// What the action shows in More (`moreItem`). Empty: a plain action shows
  /// its label, a [menuEntries] action its entries, any other [menu] action
  /// nothing (it would vanish: give it its entries, flattened as the app
  /// wants).
  final List<RaftMenuEntry> moreEntries;
}

/// Where the bar floats (`SelectionToolbarDock`): centred, 12px above the
/// bottom of the list or page it sits in (plus the safe area), 20px from its
/// sides. Put it in a [Stack] over that list.
class RaftSelectionBarDock extends StatelessWidget {
  const RaftSelectionBarDock({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Positioned(
    left: 0,
    right: 0,
    bottom: 0,
    child: Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 12 + raftBottomInset(context)),
      child: Center(child: child),
    ),
  );
}

/// The floating bar for selected items (`SelectionToolbar`): "N selected", the
/// [actions], More, then x ([onClear], as Escape does). A toolbar of one Tab
/// stop with the arrow keys inside.
class RaftSelectionBar extends StatelessWidget {
  const RaftSelectionBar({
    super.key,
    required this.count,
    required this.semanticLabel,
    required this.actions,
    required this.onClear,
    this.clearLabel,
    this.moreLabel,
  });

  /// What the actions act on.
  final int count;

  /// The toolbar's accessible name, translated by the app.
  final String semanticLabel;
  final List<RaftSelectionBarAction> actions;
  final VoidCallback onClear;

  /// Default: "Clear selection (Esc)" and "More".
  final String? clearLabel, moreLabel;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final desktop = t.desktop;
    final air = desktop ? RaftDesktopMetrics.headerAir : RaftLight.headerAir;
    final height = desktop
        ? RaftDesktopMetrics.headerHeight
        : RaftLight.headerHeight;
    final clear = clearLabel ?? raftText(context, 'Clear selection (Esc)');
    final more = moreLabel ?? raftText(context, 'More');
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): onClear},
      child: DecoratedBox(
        key: const ValueKey('selection-bar'),
        decoration: BoxDecoration(
          color: t.popover,
          borderRadius: t.corner('radius.container', fallback: 10),
          // `ring-1 ring-line-seam shadow-float`, the ring listed first.
          boxShadow: [
            for (final layer in t.shadowLayers('shadow.float').reversed)
              if (!layer.inset) layer.toBoxShadow(),
            BoxShadow(color: t.colors['line-seam']!, spreadRadius: 1),
          ],
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: height),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: air),
              child: RaftFitToolbar(
                shrinkWrap: true,
                semanticLabel: semanticLabel,
                // `gap-0 md:pointer-fine:gap-1`.
                gap: desktop ? 4 : 0,
                children: [
                  RaftFitGroup(
                    firstLine: true,
                    items: [
                      _BarCount(count: count),
                      for (final action in actions) _BarAction(action),
                      _BarMore(label: more),
                      _BarClose(label: clear, onPressed: onClear),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// `--bar-button-size` and its corner (28 and 8 with a mouse on a desktop, 44
/// and 10 on a phone and a touch screen).
({double size, double radius, double square}) _bar(RaftTokens t) => t.desktop
    ? (
        size: RaftDesktopMetrics.barButtonSize,
        radius: RaftDesktopMetrics.controlRadius,
        square: RaftDesktopMetrics.controlHeight,
      )
    : (
        size: RaftLight.barButtonSize,
        radius: RaftLight.barButtonRadius,
        square: RaftLight.barButtonSize,
      );

RaftSlotStyle _barStyle(
  RaftSlotStyle style, {
  required double radius,
  double? left,
  double? right,
}) => style.copyWith(
  properties: {
    ...style.properties,
    if (left != null) 'padding-left': CssNum(left, 'px'),
    if (right != null) 'padding-right': CssNum(right, 'px'),
    for (final corner in const [
      'top-left',
      'top-right',
      'bottom-left',
      'bottom-right',
    ])
      'border-$corner-radius': CssNum(radius, 'px'),
  },
);

class _BarCount extends RaftFitItem {
  const _BarCount({required this.count});
  final int count;

  @override
  Widget buildForm(
    BuildContext context,
    RaftFitForm form, {
    required bool probe,
    List<RaftMenuEntry> moreEntries = const [],
  }) {
    final t = RaftTokens.of(context);
    final template = raftText(context, '{number} selected');
    final at = template.indexOf('{number}');
    final before = at < 0 ? template : template.substring(0, at);
    final after = at < 0 ? '' : template.substring(at + '{number}'.length);
    final style = t
        .scale(
          RaftTypeScale.callout,
          weight: FontWeight.w700,
          color: t.ui.foreground,
        )
        .copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
    final text = Text.rich(
      key: probe ? null : const ValueKey('selection-bar-count'),
      TextSpan(
        style: style,
        children: [
          TextSpan(text: before),
          if (at >= 0)
            TextSpan(
              text: '$count',
              style: TextStyle(fontFamily: t.monoFont),
            ),
          TextSpan(text: after),
        ],
      ),
      maxLines: 1,
      softWrap: false,
    );
    return Padding(
      // `pr-0 pl-2 md:pointer-fine:px-2`.
      padding: EdgeInsetsDirectional.only(start: 8, end: t.desktop ? 8 : 0),
      child: Semantics(
        container: true,
        liveRegion: true,
        label: template.replaceAll('{number}', '$count'),
        child: ExcludeSemantics(child: text),
      ),
    );
  }
}

class _BarAction extends RaftFitItem {
  _BarAction(this.action)
    : super(
        labelOrder: raftSelectionBarLabelStep,
        moreOrder: action.secondary
            ? raftSelectionBarSecondaryStep
            : raftSelectionBarMoreStep,
        moreItem: _moreEntries(action),
      );
  final RaftSelectionBarAction action;

  static List<RaftMenuEntry> _moreEntries(RaftSelectionBarAction a) {
    if (a.moreEntries.isNotEmpty) return a.moreEntries;
    final entries = a.menuEntries;
    if (entries != null) return entries;
    if (a.menu || a.onOpen != null || a.popover != null) return const [];
    return [
      RaftMenuEntry(
        label: a.label,
        glyph: a.glyph,
        onPressed: a.enabled ? a.onPressed : null,
      ),
    ];
  }

  @override
  bool get hasLabelForm => true;

  @override
  Widget buildForm(
    BuildContext context,
    RaftFitForm form, {
    required bool probe,
    List<RaftMenuEntry> moreEntries = const [],
  }) {
    final t = RaftTokens.of(context);
    final bar = _bar(t);
    final hasMenu =
        action.menu ||
        action.menuEntries != null ||
        action.onOpen != null ||
        action.popover != null;
    // Labels show with a mouse on a desktop only, and only until the label
    // step is taken (`sr-only md:pointer-fine:not-sr-only
    // md:pointer-fine:in-data-fit-label:sr-only`).
    final showLabel = t.desktop && form == RaftFitForm.full;

    Widget button(FocusNode? focusNode, VoidCallback? press) => RaftButton(
      key: probe || action.menuEntries != null
          ? null
          : ValueKey('selection-bar-action-${action.id}'),
      uiVariant: RaftButtonVariant.ghost,
      uiSize: RaftButtonSize.md,
      glyph: action.glyph,
      label: showLabel ? action.label : '',
      semanticLabel: action.label,
      tooltip: !probe && t.desktop && !showLabel ? action.label : null,
      trailingGlyph: showLabel && hasMenu ? RaftGlyph.chevronDown : null,
      iconInlineStart: false,
      focusNode: focusNode,
      disabled: !action.enabled,
      onPressed: action.enabled ? press : null,
      physicalHeight: bar.size,
      visualWidth: showLabel ? null : bar.square,
      styleBuilder: (context, state, style) => _barStyle(
        style,
        radius: bar.radius,
        // `md:pointer-fine:pr-3 pl-2.5` (a menu: pr-2.5); square without a label.
        left: showLabel ? 10 : 0,
        right: showLabel ? (hasMenu ? 10 : 12) : 0,
      ),
    );

    final entries = action.menuEntries;
    if (probe) return button(null, () {});
    if (entries != null) {
      return RaftDropdownMenu(
        key: ValueKey('selection-bar-action-${action.id}'),
        label: action.label,
        entries: entries,
        side: RaftDropdownSide.top,
        align: RaftDropdownAlign.start,
        sideOffset: 8,
        enabled: action.enabled,
        triggerBuilder: (context, focusNode, press) => button(focusNode, press),
      );
    }
    if (action.popover != null) {
      return _BarPopover(popover: action.popover!, button: button);
    }
    return Builder(
      builder: (anchor) => button(
        null,
        () => action.onOpen != null
            ? action.onOpen!(anchor)
            : action.onPressed?.call(),
      ),
    );
  }
}

/// An action's popover: anchored on the button, opened by it, closed by an
/// outside press or the app's own close.
class _BarPopover extends StatefulWidget {
  const _BarPopover({required this.popover, required this.button});
  final Widget Function(BuildContext context, VoidCallback close) popover;
  final Widget Function(FocusNode? focusNode, VoidCallback? press) button;

  @override
  State<_BarPopover> createState() => _BarPopoverState();
}

class _BarPopoverState extends State<_BarPopover> {
  final _menu = MenuController();
  final _anchor = GlobalKey();
  final _focus = FocusNode(debugLabel: 'selection-bar-popover');

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RaftPopoverAnchor(
    controller: _menu,
    anchorKey: _anchor,
    childFocusNode: _focus,
    gap: 8,
    collisionPadding: 8,
    popup: Builder(builder: (context) => widget.popover(context, _menu.close)),
    builder: (context, controller, child) => KeyedSubtree(
      key: _anchor,
      child: widget.button(
        _focus,
        () => controller.isOpen ? controller.close() : controller.open(),
      ),
    ),
  );
}

/// `SelectionToolbarMore`: shown only while some action is in it; its menu
/// opens upward and lists each such action's `moreItem`, in order.
class _BarMore extends RaftFitItem {
  const _BarMore({required this.label});
  final String label;

  @override
  bool get isMore => true;

  @override
  Widget buildForm(
    BuildContext context,
    RaftFitForm form, {
    required bool probe,
    List<RaftMenuEntry> moreEntries = const [],
  }) {
    final t = RaftTokens.of(context);
    final bar = _bar(t);
    Widget trigger(FocusNode? focusNode, VoidCallback? press) => RaftButton(
      uiVariant: RaftButtonVariant.ghost,
      uiSize: RaftButtonSize.iconMd,
      glyph: RaftGlyph.ellipsis,
      semanticLabel: label,
      tooltip: probe ? null : label,
      focusNode: focusNode,
      onPressed: press ?? () {},
      physicalHeight: bar.size,
      visualWidth: bar.square,
      styleBuilder: (context, state, style) =>
          _barStyle(style, radius: bar.radius),
    );
    if (probe) return trigger(null, null);
    return RaftDropdownMenu(
      key: const ValueKey('selection-bar-more'),
      label: label,
      entries: moreEntries,
      side: RaftDropdownSide.top,
      align: RaftDropdownAlign.end,
      sideOffset: 8,
      triggerBuilder: (context, focusNode, press) => trigger(focusNode, press),
    );
  }
}

/// `SelectionToolbarClose`: x, last; ends the selection, as Escape does.
class _BarClose extends RaftFitItem {
  const _BarClose({required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;

  @override
  Widget buildForm(
    BuildContext context,
    RaftFitForm form, {
    required bool probe,
    List<RaftMenuEntry> moreEntries = const [],
  }) {
    final t = RaftTokens.of(context);
    final bar = _bar(t);
    return RaftButton(
      key: probe ? null : const ValueKey('selection-bar-clear'),
      uiVariant: RaftButtonVariant.ghost,
      uiSize: RaftButtonSize.iconMd,
      glyph: RaftGlyph.x,
      semanticLabel: label,
      tooltip: probe ? null : label,
      onPressed: onPressed,
      physicalHeight: bar.size,
      visualWidth: bar.size,
      styleBuilder: (context, state, style) =>
          _barStyle(style, radius: bar.radius),
    );
  }
}
