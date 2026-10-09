import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/recipes.dart' hide RaftPanelHeaderRecipe;

/// VirtualizedTaskStack's tanstack measurement rounds each observed row to
/// whole CSS pixels. Keep the card's fractional box, but use that same row
/// extent when placing the following cards/sections.
class SourceTaskRowExtent extends SingleChildRenderObjectWidget {
  const SourceTaskRowExtent({super.key, required super.child});
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _SourceTaskRowExtent();
}

class _SourceTaskRowExtent extends RenderProxyBox {
  @override
  void performLayout() {
    child!.layout(constraints.loosen(), parentUsesSize: true);
    size = constraints.constrain(
      Size(child!.size.width, child!.size.height.roundToDouble()),
    );
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final measured = child!.getDryLayout(constraints.loosen());
    return constraints.constrain(
      Size(measured.width, measured.height.roundToDouble()),
    );
  }
}

/// Page component tokens traced to SavedPanel SavedItem and ThreadsInbox
/// InboxRow at Web 26f77ef. A panel card and an inbox card have different fills.
class RaftConversationCardRecipe {
  const RaftConversationCardRecipe(this.tokens, {this.saved = false});
  final RaftTokens tokens;
  final bool saved;
  static const inset = EdgeInsets.all(12);
  static const gap = 8.0;
  // ThreadsInbox timestamp and overlaid action both use transition-opacity.
  static const actionFade = Duration(milliseconds: 150);
  Color get background => saved || tokens.brutal ? tokens.panel : tokens.card;
  Color get hoverBackground => tokens.colors['fill-muted']!;
  BorderSide get border => BorderSide(
    // SavedItem Card: `theme-brutal:border-2 theme-brutal:border-black`.
    color: saved && tokens.brutal
        ? tokens.colors['color-black']!
        : tokens.dark
        ? Colors.transparent
        : tokens.brutal && !saved
        ? tokens.colors['color-black']!.withValues(alpha: .3)
        : tokens.colors[saved && tokens.brutal ? 'line-strong' : 'line-muted']!,
    width: saved && !tokens.brutal ? .5 : tokens.border,
  );
  BorderRadius get radius => BorderRadius.circular(
    tokens.brutal
        ? 0
        : saved
        ? 8
        : 6,
  );
  TextStyle get body =>
      RaftTypography.body(
        tokens,
        size: saved ? 14 : 12,
        line: saved ? 20 : 16,
        color: saved ? tokens.ink : tokens.strong,
      ).copyWith(
        fontFamily: saved || tokens.brutal
            ? tokens.bodyFont
            : tokens.headingFont,
      );
  TextStyle get metadata =>
      RaftTypography.body(
        tokens,
        size: 12,
        line: 16,
        color: tokens.muted,
      ).copyWith(
        fontFamily: saved || tokens.brutal
            ? tokens.bodyFont
            : tokens.headingFont,
        fontWeight: FontWeight.w700,
      );
  TextStyle titleStyle(bool unread) => body.copyWith(
    fontSize: 14,
    height: 20 / 14,
    color: titleColor(unread),
    fontWeight: unread ? FontWeight.w700 : FontWeight.w600,
  );
  TextStyle get timestamp => RaftTypography.mono(
    tokens,
    size: 12,
    line: saved ? 16 : 20,
    color: saved
        ? tokens.muted
        : tokens.brutal
        ? tokens.colors['color-black']!.withValues(alpha: .4)
        : tokens.colors['foreground-placeholder'],
  );
  Color get titleIconColor => tokens.brutal
      ? tokens.colors['color-black']!.withValues(alpha: .45)
      : tokens.colors['foreground-placeholder']!;
  Color titleColor(bool unread) => tokens.brutal
      ? tokens.colors['color-black']!.withValues(alpha: unread ? 1 : .55)
      : unread
      ? tokens.strong
      : tokens.muted;
  Color get senderColor => tokens.brutal
      ? tokens.colors['color-black']!.withValues(alpha: .7)
      : tokens.muted;
}

/// Explicit semantic paint keeps Ink surfaces from borrowing a distant Material
/// ancestor. The surface owns hover/focus; nested actions do not open the card.
class RaftConversationCard extends StatefulWidget {
  const RaftConversationCard({
    super.key,
    required this.child,
    required this.onOpen,
    this.saved = false,
    this.onContextMenu,
    this.semanticLabel,
    this.actions,
  });
  final Widget child;
  final VoidCallback onOpen;
  final bool saved;
  final VoidCallback? onContextMenu;
  final String? semanticLabel;
  final Widget? actions;

  static bool actionsVisibleOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<_ConversationActionScope>()
          ?.visible ??
      false;
  @override
  State<RaftConversationCard> createState() => _RaftConversationCardState();
}

class _RaftConversationCardState extends State<RaftConversationCard> {
  bool hovered = false, focused = false;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final recipe = RaftConversationCardRecipe(t, saved: widget.saved);
    final showActions =
        hovered || focused || RaftDensityScope.of(context) == RaftDensity.touch;
    final rt = RaftRecipeTokens(t);
    // raft-ui Card root shadow (brutal themeShadowMd, elegant themeShadowXs);
    // SavedItem opts out with `shadow-none`.
    final cardStyle = RaftCardRecipe.resolve(
      theme: t.brutal ? RaftRecipeTheme.brutal : RaftRecipeTheme.elegant,
      states: RaftRecipeStates({if (t.dark) RaftRecipeStates.dark}),
      tokens: rt,
    ).root;
    Widget surface(Widget child) {
      if (widget.saved) {
        return Material(
          color: hovered || focused
              ? recipe.hoverBackground
              : recipe.background,
          shape: RoundedRectangleBorder(
            borderRadius: recipe.radius,
            side: recipe.border,
          ),
          clipBehavior: Clip.antiAlias,
          child: child,
        );
      }
      // Card's dark elevation contains an inset top-light and a dark outer
      // ring. The shared CSS painter retains both and keeps outer shadows
      // outside a translucent background throughout transitions.
      return RaftRecipeBox(
        style: cardStyle,
        tokens: rt,
        padding: EdgeInsets.zero,
        applyText: false,
        clip: true,
        decorationOverride: (base) => base.copyWith(
          color: hovered || focused
              ? recipe.hoverBackground
              : recipe.background,
          border: Border.fromBorderSide(recipe.border),
          borderRadius: recipe.radius,
        ),
        child: Material(type: MaterialType.transparency, child: child),
      );
    }

    return _ConversationActionScope(
      visible: widget.actions != null && showActions,
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        // Source group-focus-within includes the row's nested action button.
        onFocusChange: (value) => setState(() => focused = value),
        child: MouseRegion(
          onEnter: (_) => setState(() => hovered = true),
          onExit: (_) => setState(() => hovered = false),
          child: Semantics(
            button: true,
            label: widget.semanticLabel,
            child: surface(
              InkWell(
                splashFactory: NoSplash.splashFactory,
                highlightColor: Colors.transparent,
                hoverColor: Colors.transparent,
                focusColor: Colors.transparent,
                onTap: widget.onOpen,
                onLongPress: widget.onContextMenu,
                onSecondaryTap: widget.onContextMenu,
                borderRadius: recipe.radius,
                child: Padding(
                  // RecipeBox includes its CSS border in Container padding;
                  // the Saved Material shape only paints the border.
                  padding: RaftConversationCardRecipe.inset.add(
                    EdgeInsets.all(widget.saved ? recipe.border.width : 0),
                  ),
                  child: Stack(
                    children: [
                      widget.child,
                      if (widget.actions != null)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: ExcludeSemantics(
                            excluding: !showActions,
                            child: IgnorePointer(
                              ignoring: !showActions,
                              child: AnimatedOpacity(
                                opacity: showActions ? 1 : 0,
                                duration:
                                    MediaQuery.disableAnimationsOf(context)
                                    ? Duration.zero
                                    : RaftConversationCardRecipe.actionFade,
                                child: Material(
                                  color: recipe.background,
                                  child: widget.actions!,
                                ),
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
      ),
    );
  }
}

class _ConversationActionScope extends InheritedWidget {
  const _ConversationActionScope({required this.visible, required super.child});
  final bool visible;
  @override
  bool updateShouldNotify(_ConversationActionScope oldWidget) =>
      visible != oldWidget.visible;
}

/// InboxRow hides its timestamp when the overlaid action is available, while
/// keeping the timestamp's layout width so hover never changes title wrapping.
class RaftConversationTimestamp extends StatelessWidget {
  const RaftConversationTimestamp({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final hidden = RaftConversationCard.actionsVisibleOf(context);
    return ExcludeSemantics(
      excluding: hidden,
      child: AnimatedOpacity(
        opacity: hidden ? 0 : 1,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : RaftConversationCardRecipe.actionFade,
        child: child,
      ),
    );
  }
}

/// Source relativeTime.ts unit selection and numeric:auto words. The injected
/// clock keeps public visual fixtures reproducible without changing live time.
String resourceRelativeTime(
  String? value, {
  DateTime? now,
  bool chinese = false,
}) {
  final time = value == null ? null : DateTime.tryParse(value);
  if (time == null) return '';
  final delta = time.difference(now ?? DateTime.now()).inMilliseconds;
  final abs = delta.abs();
  final unit = abs < 3600000
      ? 'minute'
      : abs < 86400000
      ? 'hour'
      : 'day';
  final divisor = unit == 'minute'
      ? 60000
      : unit == 'hour'
      ? 3600000
      : 86400000;
  // JavaScript Math.round rounds negative half values toward positive infinity.
  final count = (delta / divisor + .5).floor();
  if (chinese) {
    if (count == 0) {
      return unit == 'minute'
          ? '此刻'
          : unit == 'hour'
          ? '这一小时'
          : '今天';
    }
    if (unit == 'day' && count == -1) return '昨天';
    if (unit == 'day' && count == 1) return '明天';
    final label = unit == 'minute'
        ? '分钟'
        : unit == 'hour'
        ? '小时'
        : '天';
    return '${count.abs()} $label${count < 0 ? '前' : '后'}';
  }
  if (count == 0) {
    return unit == 'minute'
        ? 'this minute'
        : unit == 'hour'
        ? 'this hour'
        : 'today';
  }
  if (unit == 'day' && count == -1) return 'yesterday';
  if (unit == 'day' && count == 1) return 'tomorrow';
  final label = '$unit${count.abs() == 1 ? '' : 's'}';
  return count < 0 ? '${count.abs()} $label ago' : 'in $count $label';
}
