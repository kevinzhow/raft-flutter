import 'hover_region.dart';
import 'control_typography.dart';
import 'recipe_surface.dart';

import 'package:flutter/material.dart';

import 'mobile_page_header.dart';

import '../recipes.dart';
import 'design_primitives.dart';
import 'flex_shrink_row.dart';
import 'icons.dart';
import 'inline_badge_editor.dart';
import 'localization.dart';
import 'search_result_surface.dart' show RaftTaskFilterButton;
import 'theme.dart';
import 'panel_layout.dart' show RaftCssText;
import 'raft/badge.dart';
import 'raft/button.dart';
import 'raft/ui_tokens.dart';
import 'text_scaling.dart' show RaftScaled;

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
    final flat = t.option('resource.rows', or: 'cards') == 'flat';
    final muted = flat ? t.ui.foregroundHint : t.colors['foreground-muted']!;
    TextStyle meta(Color color) => RaftTypography.body(
      t,
      size: 12,
      line: 16,
      weight: flat ? FontWeight.w500 : FontWeight.w700,
      color: color,
    );
    return RaftFlexShrinkRow(
      truncating: flat,
      fixed: flat
          ? {
              0,
              if (thread) 1,
              1 + (thread ? 1 : 0) + (sender.isNotEmpty ? 1 : 0),
            }
          : const {},
      gap: 8, // gap-2
      children: [
        Text(channelLabel, style: meta(muted)),
        if (thread)
          Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 4, // gap-1
            children: [
              RaftIcon(RaftGlyph.messageSquare, size: 10, color: muted),
              Flexible(
                child: Text(raftText(context, 'Thread'), style: meta(muted)),
              ),
            ],
          ),
        if (sender.isNotEmpty)
          flat
              ? RaftFlexShrinkRow(
                  gap: 4,
                  truncating: true,
                  fixed: avatar != null ? const {0} : const {},
                  children: [
                    ?avatar,
                    Text(
                      sender,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: meta(t.colors['foreground-strong']!)
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 4,
                  children: [
                    ?avatar,
                    Flexible(
                      child: Text(
                        sender,
                        style: meta(t.colors['foreground-strong']!),
                      ),
                    ),
                  ],
                ),
        Text(
          time,
          maxLines: flat ? 1 : null,
          softWrap: !flat,
          style: RaftTypography.mono(t, size: 12, line: 16, color: muted),
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
    if (t.option('resource.rows', or: 'cards') == 'flat') {
      // SavedPanel.tsx:149-159: pressed state is carried by the filled bookmark,
      // with transparent surface/border and foreground ink (no pink sticker).
      return Semantics(
        toggled: true,
        child: RaftButton(
          label: '',
          glyph: RaftGlyph.bookmarkFilled,
          semanticLabel: raftText(
            context,
            widget.label ?? 'Remove Saved Message',
          ),
          uiVariant: RaftButtonVariant.ghost,
          uiSize:
              MediaQuery.sizeOf(context).width <
                  RaftLayoutMetrics.desktopBreakpoint
              ? RaftButtonSize.iconLg
              : RaftButtonSize.iconMd,
          onPressed: widget.onPressed,
        ),
      );
    }
    final base = RaftPanelToggleActionRecipe.resolve(
      theme: RaftRecipeTheme.elegant,
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
      label: raftText(context, widget.label ?? 'Remove Saved Message'),
      excludeSemantics: true,
      onTap: widget.onPressed,
      child: RaftHoverRegion(
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
              decoration: base.decoration(rt).copyWith(color: pressedFill),
              child: RaftIcon(
                RaftGlyph.bookmarkFilled,
                size: svg?.width ?? 14,
                color: t.colors['accent-strong']!,
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

/// TasksPanel channel-mode "Create Task": Button sm outline `h-8 gap-1 text-xs
/// font-bold` with Plus 12.
class RaftNewTaskButton extends StatelessWidget {
  const RaftNewTaskButton({super.key, required this.onPressed});
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => Semantics(
    label: raftText(context, 'Create Task'),
    button: true,
    excludeSemantics: true,
    child: RaftTaskFilterButton(
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 4,
        children: [
          const RaftIcon(RaftGlyph.plus, size: 12),
          Text(raftText(context, 'Create Task')),
        ],
      ),
    ),
  );
}

/// raft-ui Badge (badge recipe) with an optional leading 10px glyph, as the
/// Activity rows use it.
class RaftResourceBadge extends StatelessWidget {
  const RaftResourceBadge({
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
    if (t.option('resource.badge', or: 'pill') == 'sticker') {
      return RaftBadge(
        label: label,
        variant: variant,
        appearance: appearance,
        glyph: glyph,
      );
    }
    final root = RaftBadgeRecipe.resolve(
      theme: t.option('control.edge', or: 'ring') == 'inkBorder'
          ? RaftRecipeTheme.brutal
          : RaftRecipeTheme.elegant,
      appearance: appearance,
      variant: variant,
      states: RaftRecipeStates({
        if (t.dark) RaftRecipeStates.dark,
        if (glyph != null) 'has:svg',
      }),
      tokens: rt,
    ).root;
    final base = root.textStyle(rt);
    final style = RaftControlTypography.of(
      context,
      base.copyWith(
        // Badge sets no family: it inherits the host `font-display`.
        fontFamily: base.fontFamily ?? t.headingFont,
        fontFamilyFallback: base.fontFamilyFallback ?? const ['sans-serif'],
        color: base.color ?? t.strong,
      ),
    );
    return Container(
      // The recipe height is a minimum: a taller line box (Android Chinese
      // control profile, larger text) grows the capsule instead of clipping.
      constraints: BoxConstraints(minHeight: root.height ?? 0),
      padding: root.padding,
      // CSS rounded-full radii are reduced to half the box's height. Passing
      // the generated max-double radius into Skia instead overflows its
      // radius arithmetic and paints a square badge; a large finite radius
      // paints the same capsule at any height.
      decoration: root
          .decoration(rt)
          .copyWith(borderRadius: BorderRadius.circular(9999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: root.columnGap ?? 4,
        children: [
          if (glyph != null) RaftIcon(glyph!, size: 10, color: style.color),
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
    if (MediaQuery.sizeOf(context).width <
        RaftLayoutMetrics.desktopBreakpoint) {
      return RaftMobileBackButton(
        onPressed: onPressed,
        tooltip: raftText(context, label),
      );
    }
    final t = RaftTokens.of(context), rt = t.recipeTokens;
    return RaftTouchTargetExpander(
      minSize: const Size.square(RaftMetrics.touchTarget),
      child: RaftInteractive(
        semanticLabel: raftText(context, label),
        onPressed: onPressed,
        builder: (context, state) {
          final base = RaftPanelActionRecipe.resolve(
            theme: t.recipeTheme,
            tokens: rt,
            states: t.recipeStates(
              hovered: state.hovered,
              pressed: state.pressed,
              focusVisible: state.focusVisible,
              disabled: !state.enabled,
            ),
          ).base;
          return RaftRecipeBox(
            style: base,
            tokens: rt,
            child: RaftIcon(
              RaftGlyph.arrowLeft,
              size: base.target('& > svg')?.width ?? 14,
            ),
          );
        },
      ),
    );
  }
}

/// Web box metrics of the resource pages that are written directly in the
/// product JSX (not in a raft-ui recipe), resolved from their Tailwind classes.
abstract final class RaftResourceMetrics {
  /// Tailwind preflight `html { line-height: 1.5 }`, inherited by text whose
  /// recipe leaves line-height unset.
  static const double documentLineHeight = 1.5;

  /// `gap-2` (flex/wrap rows of filter chips, trigger icon gaps).
  static const double gap2 = 8;

  /// `gap-1.5` (picker trigger content: icon, label, indicator).
  static const double gap1_5 = 6;

  /// `gap-2.5` (task card stacks).
  static const double gap2_5 = 10;

  /// MessageSearchPage results wrapper `<div class="p-4">`.
  static const EdgeInsets searchResultsInset = EdgeInsets.all(16);

  /// Activity section's retained conversation-list viewport.
  static const EdgeInsets activityListInset = EdgeInsets.all(16);

  /// MessageSearchPage summary wrapper `<div class="mb-3 px-1">`.
  static const EdgeInsets searchSummaryInset = EdgeInsets.symmetric(
    horizontal: 4,
  );

  /// ThreadsInbox `inbox-toolbar`: `h-[54px] px-4`.
  static const double activityToolbarHeight = 54;

  /// The toolbar height is a minimum: the segmented filter grows with the
  /// text size and the bar with it.
  static const BoxConstraints activityToolbarConstraints = BoxConstraints(
    minHeight: activityToolbarHeight,
  );

  /// ThreadsInbox toolbar `gap-3`; outline `h-8 px-2 text-xs font-bold`.
  static const double activityToolbarGap = 12;
  static const double activityToolbarActionHeight = 32;
  static const EdgeInsets activityToolbarActionInset = EdgeInsets.symmetric(
    horizontal: 8,
  );
  static const TextStyle activityToolbarActionLabel = TextStyle(
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w700,
  );

  /// PanelHeader Elegant mobile `pl-5 pr-3.5 gap-2`, meta `mt-1`.
  static const EdgeInsets elegantMobileHeaderInset = EdgeInsets.only(
    left: 20,
    right: 14,
  );
  static const double elegantHeaderGap = 8;
  static const double elegantHeaderMetaGap = 4;
  static const EdgeInsets activityToolbarInset = EdgeInsets.symmetric(
    horizontal: 16,
  );
}

/// ThreadsInbox's Mark all read action: Web v1.21.23 uses Button sm ghost;
/// a57b9dab uses its outline recipe. The caller owns the read mutation.
class RaftResourceMarkReadButton extends StatelessWidget {
  const RaftResourceMarkReadButton({super.key, required this.onPressed});
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    if (t.option('resource.markRead', or: 'outline') == 'ghost') {
      return RaftButton(
        label: 'Mark all read',
        semanticLabel: raftText(context, 'Mark all read'),
        uiVariant: RaftButtonVariant.ghost,
        uiSize: RaftButtonSize.sm,
        onPressed: onPressed,
      );
    }
    return RaftInteractive(
      semanticLabel: raftText(context, 'Mark all read'),
      onPressed: onPressed,
      builder: (context, state) => ExcludeSemantics(
        child: RaftRecipeBox(
          style: RaftButtonRecipe.resolve(
            theme: t.option('control.edge', or: 'ring') == 'inkBorder'
                ? RaftRecipeTheme.brutal
                : RaftRecipeTheme.elegant,
            variant: RaftButtonRecipeVariant.outline,
            size: RaftButtonRecipeSize.sm,
            states: t.recipeStates(
              hovered: state.hovered,
              pressed: state.pressed,
              focusVisible: state.focusVisible,
            ),
            tokens: t.recipeTokens,
          ).root,
          tokens: t.recipeTokens,
          height: RaftResourceMetrics.activityToolbarActionHeight,
          padding: RaftResourceMetrics.activityToolbarActionInset,
          alignment: Alignment.center,
          child: RaftCssText(
            raftText(context, 'Mark all read'),
            style: RaftResourceMetrics.activityToolbarActionLabel,
            controlLabel: true,
          ),
        ),
      ),
    );
  }
}

/// The Web inbox lets its flex track shrink, while the earlier themes scroll
/// their separate filters. The child retains the product input callbacks.
class RaftResourceFilterViewport extends StatelessWidget {
  const RaftResourceFilterViewport({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) =>
      RaftTokens.of(context).option('resource.rows', or: 'cards') == 'flat' &&
          !RaftScaled.grows(context)
      ? child
      : SingleChildScrollView(
          primary: false,
          scrollDirection: Axis.horizontal,
          child: child,
        );
}
