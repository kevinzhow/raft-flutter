import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/recipes.dart' hide RaftPanelHeaderRecipe;

/// Page component tokens traced to SavedPanel SavedItem and ThreadsInbox
/// InboxRow at Web 26f77ef. A panel card and an inbox card have different fills.
class RaftConversationCardRecipe {
  const RaftConversationCardRecipe(this.tokens, {this.saved = false});
  final RaftTokens tokens;
  final bool saved;
  static const inset = EdgeInsets.all(12);
  static const gap = 8.0;
  Color get background => saved || tokens.brutal ? tokens.panel : tokens.card;
  Color get hoverBackground => tokens.colors['fill-muted']!;
  BorderSide get border => BorderSide(
    // SavedItem Card: `theme-brutal:border-2 theme-brutal:border-black`.
    color: saved && tokens.brutal
        ? Colors.black
        : saved && tokens.dark
        ? Colors.transparent
        : tokens.brutal && !saved
        ? tokens.strong.withValues(alpha: .3)
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
  TextStyle get body => RaftTypography.body(
    tokens,
    size: saved ? 14 : 12,
    line: saved ? 20 : 16,
    color: saved ? tokens.ink : tokens.strong,
  );
  TextStyle get metadata => RaftTypography.body(
    tokens,
    size: 12,
    line: 16,
    color: tokens.muted,
  ).copyWith(fontWeight: FontWeight.w700);
  TextStyle get timestamp => RaftTypography.mono(
    tokens,
    size: 12,
    line: saved ? 16 : 20,
    color: saved ? tokens.muted : tokens.colors['foreground-placeholder'],
  );
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
    return MouseRegion(
      onEnter: (_) => setState(() => hovered = true),
      onExit: (_) => setState(() => hovered = false),
      child: Semantics(
        button: true,
        label: widget.semanticLabel,
        child: Material(
          color: hovered || focused
              ? recipe.hoverBackground
              : recipe.background,
          shape: RoundedRectangleBorder(
            borderRadius: recipe.radius,
            side: recipe.border,
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            splashFactory: NoSplash.splashFactory,
            highlightColor: Colors.transparent,
            hoverColor: Colors.transparent,
            focusColor: Colors.transparent,
            onTap: widget.onOpen,
            onLongPress: widget.onContextMenu,
            onSecondaryTap: widget.onContextMenu,
            onFocusChange: (value) => setState(() => focused = value),
            borderRadius: recipe.radius,
            child: Padding(
              // CSS content box = border + padding; Material paints the side
              // inside its shape without insetting the child.
              padding: RaftConversationCardRecipe.inset.add(
                EdgeInsets.all(recipe.border.width),
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
                            duration: MediaQuery.disableAnimationsOf(context)
                                ? Duration.zero
                                : const Duration(milliseconds: 150),
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


/// SavedItem's remove control: raft-ui PanelToggleAction `pressed` with
/// `data-pressed:text-accent-strong theme-brutal:data-pressed:text-brutal-orange
/// data-pressed:bg-accent-soft/30` and a filled Bookmark 14
/// (packages/web/src/components/saved/SavedPanel.tsx).
class RaftSavedToggle extends StatefulWidget {
  const RaftSavedToggle({super.key, required this.onPressed, this.tooltip});
  final VoidCallback onPressed;
  final String? tooltip;
  @override
  State<RaftSavedToggle> createState() => _RaftSavedToggleState();
}

class _RaftSavedToggleState extends State<RaftSavedToggle> {
  bool hovered = false;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context), rt = RaftRecipeTokens(t);
    final base = RaftPanelToggleActionRecipe.resolve(
      theme: t.brutal ? RaftRecipeTheme.brutal : RaftRecipeTheme.elegant,
      states: RaftRecipeStates({
        'data-pressed',
        if (hovered) RaftRecipeStates.hover,
        if (t.dark) RaftRecipeStates.dark,
      }),
      tokens: rt,
    ).base;
    final icon = t.brutal
        ? t.colors['color-brutal-orange']!
        : t.colors['accent-strong']!;
    final decoration = base.decoration(rt);
    final svg = base.target('& > svg');
    return Semantics(
      button: true,
      toggled: true,
      label: raftText(context, widget.tooltip ?? 'Remove saved message'),
      excludeSemantics: true,
      onTap: widget.onPressed,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => hovered = true),
        onExit: (_) => setState(() => hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed,
          child: Transform.translate(
            offset: base.translate ?? Offset.zero,
            child: Container(
              padding: base.padding,
              decoration: decoration.copyWith(
                color: Color.alphaBlend(
                  t.colors['accent-soft']!.withValues(alpha: .3),
                  t.brutal ? Colors.white : Colors.transparent,
                ),
              ),
              child: RaftIcon(
                RaftGlyph.bookmarkFilled,
                size: svg?.width ?? 14,
                color: icon,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
