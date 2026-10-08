import 'package:flutter/material.dart';

import '../recipes.dart';
import 'design_primitives.dart';
import 'flex_shrink_row.dart';
import 'icons.dart';
import 'inline_badge_editor.dart';
import 'localization.dart';
import 'theme.dart';

/// SavedItem metadata row (packages/web/src/components/saved/SavedPanel.tsx):
/// `flex items-center gap-2 text-xs` with the channel label, the optional
/// thread marker (MessageSquare 10), the sender (avatar + name, inline-flex
/// gap-1) and the mono relative time.
class RaftSavedItemMeta extends StatelessWidget {
  const RaftSavedItemMeta({
    super.key,
    required this.channelLabel,
    required this.time,
    this.thread = false,
    this.sender = '',
    this.avatar,
  });
  final String channelLabel, time, sender;
  final bool thread;
  final Widget? avatar;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final black = t.colors['color-black']!;
    final muted = t.colors['foreground-muted']!;
    TextStyle meta(Color brutal, Color elegant) => RaftTypography.body(
      t,
      size: 12,
      line: 16,
      weight: FontWeight.w700,
      color: t.brutal ? brutal : elegant,
    );
    return RaftFlexShrinkRow(
      gap: 8, // gap-2
      children: [
        Text(channelLabel, style: meta(black.withValues(alpha: .5), muted)),
        if (thread)
          Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 4, // gap-1
            children: [
              RaftIcon(
                RaftGlyph.messageSquare,
                size: 10,
                color: t.brutal ? black.withValues(alpha: .4) : muted,
              ),
              Flexible(
                child: Text(
                  raftText(context, 'Thread'),
                  style: meta(black.withValues(alpha: .4), muted),
                ),
              ),
            ],
          ),
        if (sender.isNotEmpty)
          Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 4, // gap-1
            children: [
              ?avatar,
              Flexible(
                child: Text(
                  sender,
                  style: meta(black, t.colors['foreground-strong']!),
                ),
              ),
            ],
          ),
        Text(
          time,
          style: RaftTypography.mono(
            t,
            size: 12,
            line: 16,
            color: t.brutal ? black.withValues(alpha: .4) : muted,
          ),
        ),
      ],
    );
  }
}

/// SavedItem's remove control: raft-ui PanelToggleAction `pressed` with
/// `data-pressed:text-accent-strong theme-brutal:data-pressed:text-brutal-orange
/// data-pressed:bg-accent-soft/30` and a filled Bookmark 14.
class RaftSavedToggle extends StatefulWidget {
  const RaftSavedToggle({super.key, required this.onPressed, this.label});
  final VoidCallback onPressed;
  final String? label;
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
    final pressedFill = t.colors['accent-soft']!.withValues(alpha: .3);
    final svg = base.target('& > svg');
    return Semantics(
      button: true,
      toggled: true,
      label: raftText(context, widget.label ?? 'Remove saved message'),
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
              decoration: base
                  .decoration(rt)
                  .copyWith(
                    color: t.brutal
                        ? Color.alphaBlend(
                            pressedFill,
                            t.colors['color-white']!,
                          )
                        : pressedFill,
                  ),
              child: RaftIcon(
                RaftGlyph.bookmarkFilled,
                size: svg?.width ?? 14,
                color: t.brutal
                    ? t.colors['color-brutal-orange']!
                    : t.colors['accent-strong']!,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// SavedPanel `saved-infinite-scroll-sentinel`: `flex min-h-10 items-center
/// justify-center py-3`, "Loading" (text-xs font-bold) while a page loads.
class RaftInfiniteScrollSentinel extends StatelessWidget {
  const RaftInfiniteScrollSentinel({super.key, required this.loading});
  final bool loading;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 40),
      padding: const EdgeInsets.symmetric(vertical: 12),
      alignment: Alignment.center,
      child: loading
          ? Text(
              raftText(context, 'Loading'),
              style: RaftTypography.body(
                t,
                size: 12,
                line: 16,
                weight: FontWeight.w700,
                color: t.colors['foreground-muted'],
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}

/// TasksPanel channel-mode "New Task": Button sm outline `h-8 gap-1 text-xs
/// font-bold` with Plus 12.
class RaftNewTaskButton extends StatelessWidget {
  const RaftNewTaskButton({super.key, required this.onPressed});
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => RaftControl(
    variant: RaftControlVariant.outline,
    visualHeight: 32,
    semanticLabel: raftText(context, 'New Task'),
    onPressed: onPressed,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 4,
      children: [
        const RaftIcon(RaftGlyph.plus, size: 12),
        Text(raftText(context, 'New Task')),
      ],
    ),
  );
}

/// raft-ui Badge (badge recipe) with an optional leading 10px glyph, as the
/// Activity rows use it (`uppercase={false}`).
class RaftRecipeBadge extends StatelessWidget {
  const RaftRecipeBadge({
    super.key,
    required this.label,
    this.variant = RaftBadgeRecipeVariant.default_,
    this.appearance = RaftBadgeRecipeAppearance.solid,
    this.glyph,
  });
  final String label;
  final RaftBadgeRecipeVariant variant;
  final RaftBadgeRecipeAppearance appearance;
  final RaftGlyph? glyph;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context), rt = RaftRecipeTokens(t);
    final root = RaftBadgeRecipe.resolve(
      theme: t.brutal ? RaftRecipeTheme.brutal : RaftRecipeTheme.elegant,
      appearance: appearance,
      variant: variant,
      uppercase: false,
      states: RaftRecipeStates({
        if (t.dark) RaftRecipeStates.dark,
        if (glyph != null) 'has:svg',
      }),
      tokens: rt,
    ).root;
    final base = root.textStyle(rt);
    final style = base.copyWith(
      // Badge sets no family: it inherits the host `font-display`.
      fontFamily: base.fontFamily ?? t.headingFont,
      fontFamilyFallback: base.fontFamilyFallback ?? const ['sans-serif'],
      color: base.color ?? t.strong,
    );
    return Container(
      height: root.height,
      padding: root.padding,
      decoration: root.decoration(rt),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: root.columnGap ?? 4,
        children: [
          if (glyph != null)
            RaftIcon(glyph!, size: 10, color: style.color),
          Text(label, maxLines: 1, style: style),
        ],
      ),
    );
  }
}

/// PanelHeader mobile back: raft-ui PanelAction (panelAction recipe) with
/// ArrowLeft 14 (packages/web/src/components/ui/PanelHeader.tsx). Layout is
/// the Web box; the touch target stays 48px.
class RaftPanelBackAction extends StatelessWidget {
  const RaftPanelBackAction({super.key, this.onPressed, this.label = 'Back'});
  final VoidCallback? onPressed;
  final String label;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context), rt = RaftRecipeTokens(t);
    final base = RaftPanelActionRecipe.resolve(
      theme: t.brutal ? RaftRecipeTheme.brutal : RaftRecipeTheme.elegant,
      states: RaftRecipeStates({if (t.dark) RaftRecipeStates.dark}),
      tokens: rt,
    ).base;
    return RaftTouchTargetExpander(
      minSize: const Size.square(RaftMetrics.touchTarget),
      child: Semantics(
        button: true,
        label: raftText(context, label),
        excludeSemantics: true,
        onTap: onPressed,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: Container(
            padding: base.padding,
            decoration: base.decoration(rt),
            child: RaftIcon(
              RaftGlyph.arrowLeft,
              size: base.target('& > svg')?.width ?? 14,
              color: base.color?.resolve(rt) ?? t.strong,
            ),
          ),
        ),
      ),
    );
  }
}
