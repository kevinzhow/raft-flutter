import 'dart:ui' show SemanticsRole;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'design_primitives.dart';
import 'icons.dart';
import 'localization.dart';
import 'recipe_surface.dart';
import 'raft/ui_tokens.dart';
import 'recipes/notification_center.g.dart';
import 'theme.dart';

/// Pure status roles from raft-ui 0.5.52; the mounted app emits the first three.
enum RaftNotificationKind { error, warning, info, success }

@immutable
class RaftNotificationAction {
  const RaftNotificationAction({
    required this.label,
    this.onPressed,
    this.primary = false,
    this.enabled = true,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool primary, enabled;
}

/// Display data only. The caller supplies current, authorized actions and order.
@immutable
class RaftNotificationEntry {
  const RaftNotificationEntry({
    required this.id,
    required this.kind,
    required this.title,
    this.glyph,
    this.iconForeground,
    this.body,
    this.bodyContent,
    this.actions = const [],
  }) : assert(body == null || bodyContent == null);
  final String id, title;
  final RaftNotificationKind kind;
  final RaftGlyph? glyph;

  /// Mounted Web glyphs override the generic status foreground with strong.
  /// The adapter supplies that theme role; the status fill remains unchanged.
  final Color? iconForeground;
  final String? body;
  final Widget? bodyContent;
  final List<RaftNotificationAction> actions;
}

// Tier 1: original utility geometry and canonical OKLCH atoms, not samples.
// Geometry: NotificationCenter.tsx35–77 and raft-ui index.mjs14717–15131.
// Colors: foundation.css371–373,449–459,489–492. Conversion receipt is in
// reports/raft-notification-center-audit/notification-atoms.json.
abstract final class _NotificationPrimitives {
  static const double width = 320, height = 288, icon = 35, glyph = 18;
  static const double itemInset = 12, headerGap = 8, bodyGap = 2;
  static const double actionGap = 8, badge = 10;
  static const dangerMuted = Color(0xffd33c30);
  static const warningMuted = Color(0xffac571d);
  static const infoMuted = Color(0xff007592);
  static const successMuted = Color(0xff0c7d43);
  static const badgeHighlight = Color(0x8cffffff);
  static const double badgeInsetOffset = .5, badgeInsetBlurSigma = .5;
  static const emptyOuterInset = EdgeInsets.symmetric(
    horizontal: 24,
    vertical: 32,
  );
  static const emptyInnerInset = EdgeInsets.symmetric(horizontal: 16);
  static const double emptyGap = 8, emptyGlyph = 36;
  static const double actionFont = 11, actionLine = 16.5, actionHorizontal = 8;
}

// Tier 2: semantic mappings. Missing shared muted state roles are derived from
// the original dark washes; -soft has different OKLCH and must not substitute.
class _NotificationSemantics {
  const _NotificationSemantics(this.tokens);
  final RaftTokens tokens;
  Color get surface => tokens.popover;
  Color get header => Colors.transparent;
  Color get line => tokens.colors['line-hairline']!;
  Color iconFill(RaftNotificationKind kind) {
    if (!tokens.dark) {
      return tokens
          .colors[switch (kind) {
            RaftNotificationKind.error => 'danger',
            RaftNotificationKind.warning => 'warning',
            RaftNotificationKind.info => 'info',
            RaftNotificationKind.success => 'success',
          }]!
          .withValues(alpha: .8);
    }
    return switch (kind) {
      RaftNotificationKind.error =>
        _NotificationPrimitives.dangerMuted.withValues(alpha: .3),
      RaftNotificationKind.warning =>
        _NotificationPrimitives.warningMuted.withValues(alpha: .28),
      RaftNotificationKind.info => _NotificationPrimitives.infoMuted.withValues(
        alpha: .28,
      ),
      RaftNotificationKind.success =>
        _NotificationPrimitives.successMuted.withValues(alpha: .28),
    };
  }

  Color iconForeground(RaftNotificationKind kind) =>
      tokens.colors[switch (kind) {
        RaftNotificationKind.error => 'danger-strong',
        RaftNotificationKind.warning => 'warning-strong',
        RaftNotificationKind.info => 'info-strong',
        RaftNotificationKind.success => 'success-strong',
      }]!;
}

/// Tier 3: mounted notification recipe, distinct from generic menu geometry.
class RaftNotificationRecipe {
  const RaftNotificationRecipe(this.tokens);
  final RaftTokens tokens;
  _NotificationSemantics get _semantic => _NotificationSemantics(tokens);
  double get width => _NotificationPrimitives.width;
  double get height => _NotificationPrimitives.height;
  EdgeInsets get headerInset => const EdgeInsets.symmetric(horizontal: 12);
  EdgeInsets get itemInset =>
      const EdgeInsets.all(_NotificationPrimitives.itemInset);
  double get rowGap => 12;
  BorderRadius get iconRadius {
    final size = tokens.desktop
        ? tokens.size('desktop.controlRadius', fallback: 8)
        : tokens.size('css.control-radius', fallback: 10);
    return BorderRadius.circular(size);
  }

  BorderRadius get radius => BorderRadius.circular(6);
  BorderSide get divider => BorderSide(color: _semantic.line, width: 1);
  Color get background => _semantic.surface;
  Color get headerBackground => _semantic.header;
  Color iconFill(RaftNotificationKind kind) => _semantic.iconFill(kind);
  Color iconForeground(RaftNotificationKind kind) =>
      _semantic.iconForeground(kind);
  TextStyle get title => tokens.scale(tokens.typeSlot('headline'));
  TextStyle get count => tokens.scale(
    tokens.typeSlot('mono-meta'),
    mono: true,
    color: tokens.ui.foregroundHint,
  );
  TextStyle get itemTitle =>
      tokens.scale(tokens.typeSlot('subhead'), weight: FontWeight.w700);
  TextStyle get body =>
      tokens.scale(tokens.typeSlot('callout'), color: tokens.muted);
}

/// Controlled, noninteractive attention mark. The bell owns its count semantics.
/// Source Status attention/md: no pulse is requested by the mounted trigger.
class RaftNotificationAttention extends StatelessWidget {
  const RaftNotificationAttention({super.key, required this.count});
  final int count;
  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    final t = RaftTokens.of(context);
    final fill = t.colors['primary-400']!;
    return ExcludeSemantics(
      child: Container(
        width: _NotificationPrimitives.badge,
        height: _NotificationPrimitives.badge,
        decoration: BoxDecoration(
          color: fill,
          shape: BoxShape.circle,
          border: Border.all(color: fill.withValues(alpha: .58)),
        ),
        child: const CustomPaint(
          foregroundPainter: _NotificationAttentionInsetPainter(),
        ),
      ),
    );
  }
}

/// Pure mounted surface. The app owns placement, authority, data and dismissal.
class RaftNotificationCenter extends StatefulWidget {
  const RaftNotificationCenter({
    super.key,
    required this.entries,
    this.title = 'Notifications',
    this.countLabel,
    this.emptyTitle = 'No notifications',
    this.emptyBody = "You'll see things here that need your attention.",
    this.semanticLabel = 'Notification Center',
    this.listLabel = 'Notifications',
    this.width = _NotificationPrimitives.width,
    this.height = _NotificationPrimitives.height,
    this.onDismiss,
    this.autofocus = false,
  });

  /// The mounted Web uses a 320px desktop popup and 8px mobile gutters.
  static double popupWidth(double viewportWidth, {required bool mobile}) =>
      (viewportWidth - 16).clamp(
        0,
        mobile ? 480 : _NotificationPrimitives.width,
      );

  final List<RaftNotificationEntry> entries;
  final String title, emptyTitle, emptyBody, semanticLabel, listLabel;
  final String? countLabel;
  final double width, height;
  final VoidCallback? onDismiss;

  /// At keyboard opening, focus the first enabled action, or this surface if
  /// none exists. Later data updates retain the person's current focus.
  final bool autofocus;
  @override
  State<RaftNotificationCenter> createState() => _RaftNotificationCenterState();
}

class _RaftNotificationCenterState extends State<RaftNotificationCenter> {
  final popupFocus = FocusNode(debugLabel: 'Notification center fallback');
  final openingActionFocus = FocusNode(
    debugLabel: 'Notification center opening action',
  );
  (String id, String label)? openingAction;
  @override
  void initState() {
    super.initState();
    if (!widget.autofocus) return;
    // Bind once to the first enabled action at keyboard opening. Retain its
    // identity across updates; a newly appended/reordered row must not take
    // focus from the action the person is currently using.
    for (final entry in widget.entries) {
      for (final action in entry.actions) {
        if (!action.enabled || action.onPressed == null) continue;
        openingAction = (entry.id, action.label);
        break;
      }
      if (openingAction != null) break;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final target =
          openingActionFocus.context != null &&
              openingActionFocus.canRequestFocus
          ? openingActionFocus
          : popupFocus;
      target.requestFocus();
    });
  }

  @override
  void dispose() {
    openingActionFocus.dispose();
    popupFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final r = RaftNotificationRecipe(t);
    final popup = RaftNotificationCenterRecipe.resolve(
      states: t.recipeStates(),
      tokens: t.recipeTokens,
    ).popup;
    final count =
        widget.countLabel ??
        (widget.entries.isEmpty
            ? raftText(context, 'all clear')
            : '${widget.entries.length} ${raftText(context, widget.entries.length == 1 ? 'item' : 'items')}');
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            widget.onDismiss?.call(),
      },
      child: Focus(
        key: const Key('notification-center-focus'),
        focusNode: popupFocus,
        skipTraversal: true,
        child: FocusTraversalGroup(
          policy: ReadingOrderTraversalPolicy(),
          child: Semantics(
            container: true,
            explicitChildNodes: true,
            role: SemanticsRole.dialog,
            label: raftText(context, widget.semanticLabel),
            child: RaftRecipeBox(
              key: const Key('notification-center-surface'),
              style: popup,
              tokens: t.recipeTokens,
              applyText: false,
              width: widget.width,
              height: widget.height,
              child: ClipRRect(
                // The surface's own corner (`rounded-container`): a smaller clip
                // lets the opaque rows paint over the ring at the corners.
                borderRadius: popup.borderRadius ?? r.radius,
                child: Column(
                  children: [
                    Container(
                      key: const Key('notification-center-header'),
                      constraints: const BoxConstraints(minHeight: 52),
                      padding: r.headerInset,
                      decoration: BoxDecoration(
                        color: r.headerBackground,
                        border: Border(
                          bottom: BorderSide(color: t.ui.lineSeam),
                        ),
                      ),
                      child: LayoutBuilder(
                        builder: (context, bounds) => Row(
                          children: [
                            Expanded(
                              child: Semantics(
                                header: true,
                                child: Text(
                                  raftText(context, widget.title),
                                  style: r.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            const SizedBox(
                              width: _NotificationPrimitives.headerGap,
                            ),
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: bounds.maxWidth / 2,
                              ),
                              child: Text(
                                count,
                                style: r.count,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        key: const Key('notification-center-scroller'),
                        child: widget.entries.isEmpty
                            ? _empty(context, r)
                            : Semantics(
                                // Scrollable contributes its own semantics
                                // node. The actual list belongs inside it so
                                // every list item has a list parent.
                                container: true,
                                explicitChildNodes: true,
                                role: SemanticsRole.list,
                                label: raftText(context, widget.listLabel),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    for (
                                      var i = 0;
                                      i < widget.entries.length;
                                      i++
                                    ) ...[
                                      if (i > 0)
                                        SizedBox(
                                          height: r.divider.width,
                                          child: Padding(
                                            padding: EdgeInsetsDirectional.only(
                                              start:
                                                  RaftSpace.x4 +
                                                  _NotificationPrimitives.icon +
                                                  r.rowGap,
                                            ),
                                            child: ColoredBox(
                                              color: r.divider.color,
                                            ),
                                          ),
                                        ),
                                      _NotificationRow(
                                        key: ValueKey(
                                          'notification-entry-${widget.entries[i].id}',
                                        ),
                                        entry: widget.entries[i],
                                        recipe: r,
                                        openingActionFocus:
                                            openingAction?.$1 ==
                                                widget.entries[i].id
                                            ? openingActionFocus
                                            : null,
                                        openingActionLabel:
                                            openingAction?.$1 ==
                                                widget.entries[i].id
                                            ? openingAction?.$2
                                            : null,
                                      ),
                                    ],
                                  ],
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
      ),
    );
  }

  Widget _empty(BuildContext context, RaftNotificationRecipe r) => Padding(
    // Preserve EmptyState root and the mounted app's nested body insets.
    key: const Key('notification-center-empty'),
    padding: _NotificationPrimitives.emptyOuterInset,
    child: Padding(
      padding: _NotificationPrimitives.emptyInnerInset,
      child: Column(
        children: [
          // Web layout/NotificationCenter.tsx:61 `<CheckCircle2 size={36} />`.
          RaftIcon(
            RaftGlyph.checkCircle2,
            size: _NotificationPrimitives.emptyGlyph,
            color: r.tokens.muted,
          ),
          const SizedBox(height: 16),
          Text(
            raftText(context, widget.emptyTitle),
            textAlign: TextAlign.center,
            style: RaftTypography.body(r.tokens, weight: FontWeight.w700),
          ),
          const SizedBox(height: _NotificationPrimitives.emptyGap),
          Text(
            raftText(context, widget.emptyBody),
            textAlign: TextAlign.center,
            style: r.body.copyWith(color: r.tokens.muted),
          ),
        ],
      ),
    ),
  );
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({
    super.key,
    required this.entry,
    required this.recipe,
    this.openingActionFocus,
    this.openingActionLabel,
  });
  final RaftNotificationEntry entry;
  final RaftNotificationRecipe recipe;
  final FocusNode? openingActionFocus;
  final String? openingActionLabel;
  @override
  Widget build(BuildContext context) {
    // raft-ui DEFAULT_STATUS_ICON (0.5.52 dist/index.mjs:14438); its lucide-react
    // 1.55.0 is the same build the Web imports, so one geometry serves both.
    final glyph =
        entry.glyph ??
        switch (entry.kind) {
          RaftNotificationKind.error ||
          RaftNotificationKind.warning => RaftGlyph.triangleAlert,
          RaftNotificationKind.info => RaftGlyph.info,
          RaftNotificationKind.success => RaftGlyph.checkCircle2,
        };
    return Semantics(
      container: true,
      role: SemanticsRole.listItem,
      child: Padding(
        padding: recipe.itemInset,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              label: raftText(context, switch (entry.kind) {
                RaftNotificationKind.error => 'Error',
                RaftNotificationKind.warning => 'Warning',
                RaftNotificationKind.info => 'Info',
                RaftNotificationKind.success => 'Success',
              }),
              child: ExcludeSemantics(
                child: Container(
                  width: _NotificationPrimitives.icon,
                  height: _NotificationPrimitives.icon,
                  decoration: BoxDecoration(
                    color: recipe.iconFill(entry.kind),
                    borderRadius: recipe.iconRadius,
                    border: null,
                  ),
                  child: Center(
                    child: RaftIcon(
                      glyph,
                      size: _NotificationPrimitives.glyph,
                      color:
                          entry.iconForeground ??
                          recipe.iconForeground(entry.kind),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: recipe.rowGap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.title, style: recipe.itemTitle),
                  if (entry.bodyContent != null || entry.body != null)
                    Padding(
                      padding: const EdgeInsets.only(
                        top: _NotificationPrimitives.bodyGap,
                      ),
                      child: DefaultTextStyle(
                        style: recipe.body,
                        child: entry.bodyContent ?? Text(entry.body!),
                      ),
                    ),
                  if (entry.actions.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(
                        top: _NotificationPrimitives.actionGap,
                      ),
                      child: Wrap(
                        spacing: _NotificationPrimitives.actionGap,
                        runSpacing: _NotificationPrimitives.actionGap,
                        children: [
                          for (final action in entry.actions)
                            _action(context, action),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _action(BuildContext context, RaftNotificationAction action) {
    final scale =
        MediaQuery.textScalerOf(context)
            .scale(_NotificationPrimitives.actionFont) /
        _NotificationPrimitives.actionFont;
    final buttonRecipe = _NotificationActionRecipe(
      recipe.tokens,
      primary: action.primary,
    );
    return RaftControl(
      key: ValueKey('notification-action-${entry.id}-${action.label}'),
      focusNode: action.label == openingActionLabel ? openingActionFocus : null,
      onPressed: action.enabled ? action.onPressed : null,
      semanticLabel: action.label,
      tooltip: action.label,
      visualHeight: RaftMetrics.buttonXs * scale,
      recipe: buttonRecipe,
      padding: const EdgeInsets.symmetric(
        horizontal: _NotificationPrimitives.actionHorizontal,
      ),
      child: Text(
        action.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: (RaftTypography.body(
          recipe.tokens,
          size: _NotificationPrimitives.actionFont,
          line: _NotificationPrimitives.actionLine,
          weight: FontWeight.w500,
        )).copyWith(color: buttonRecipe.foreground),
      ),
    );
  }
}

class _NotificationActionRecipe extends RaftControlRecipe {
  _NotificationActionRecipe(RaftTokens tokens, {required this.primary})
    : super(
        tokens,
        variant: primary
            ? RaftControlVariant.primary
            : RaftControlVariant.outline,
        visualHeight: RaftMetrics.buttonXs,
      );
  final bool primary;
  @override
  Color get background => super.background;
  @override
  Color backgroundFor({bool hovered = false}) =>
      super.backgroundFor(hovered: hovered);
}

// Native drawing of Status's inset 0 .5px 1px white/55% shadow.
// The recipe is source-derived; platform raster equivalence still needs capture.
class _NotificationAttentionInsetPainter extends CustomPainter {
  const _NotificationAttentionInsetPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final circle = Path()..addOval(rect);
    final outside = Path.combine(
      PathOperation.difference,
      Path()..addRect(rect.inflate(4)),
      Path()..addOval(
        rect.shift(const Offset(0, _NotificationPrimitives.badgeInsetOffset)),
      ),
    );
    canvas.save();
    canvas.clipPath(circle);
    canvas.drawPath(
      outside,
      Paint()
        ..color = _NotificationPrimitives.badgeHighlight
        ..maskFilter = const MaskFilter.blur(
          BlurStyle.normal,
          _NotificationPrimitives.badgeInsetBlurSigma,
        ),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_NotificationAttentionInsetPainter oldDelegate) => false;
}
