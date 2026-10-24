import 'hover_region.dart';
import 'banner_recipe.dart';

import 'dart:ui' show SemanticsRole;

import 'package:flutter/widgets.dart';

import 'raft_underline.dart';
import 'icons.dart';
import 'localization.dart';
import 'recipe_surface.dart';
import 'recipes/banner.g.dart';
import 'recipes/recipe_runtime.dart' show RaftSlotStyle, RaftTokenResolver;
import 'theme.dart';

export 'recipes/banner.g.dart'
    show RaftBannerRecipeStatus, RaftBannerRecipeSize;

/// Product ui/Banner.tsx composition: BannerDescription keeps its own font
/// weight even when the caller makes the root bold. Geometry and colors come
/// from the generated public Banner recipe, including the real density axis.
class RaftBanner extends StatelessWidget {
  const RaftBanner({
    super.key,
    this.description = '',
    this.live = true,
    this.descriptionBuilder,
    this.title,
    this.status = RaftBannerRecipeStatus.warning,
    this.size = RaftBannerRecipeSize.md,
    this.strongPrefix,
    this.leading,
    this.descriptionWeight,
    this.titleGap,
    this.glyph,
    this.action,
    this.centerAction = false,
    this.descriptionTail,
    this.descriptionTailWeight,
    this.textAlign,
    this.footer,
  });

  /// An inline underlined link after the description copy, 4px (`ml-1`) from
  /// it: Web HistoryLimitBanner's `<button className="ml-1 underline">`.
  final ({String label, VoidCallback onPressed})? descriptionTail;

  /// Callsite `font-bold` on the tail link (ChatPanel's billing links).
  final FontWeight? descriptionTailWeight;

  /// Web `text-center` on the Banner root.
  final TextAlign? textAlign;

  /// ui/Banner.tsx `withIcon` / `icon`: the leading `svg` grid cell
  /// (`[&>svg]` size and intent colour from the recipe).
  final RaftGlyph? glyph;

  /// Rich body replacing the [description] text (Web `Banner` children that
  /// are not a plain string, e.g. a `<p>` with a `<strong>` plus a checkbox
  /// row). Receives the recipe description text style.
  final Widget Function(TextStyle style)? descriptionBuilder;

  /// Extra body content after the description (a button row).
  final Widget? footer;

  /// `actions` -> `BannerAction` (trailing grid cell, `gap-x` from the
  /// recipe).
  final Widget? action;

  /// Web `[&>div:last-child]:self-center`: center the action against the whole
  /// icon/body group while keeping the leading glyph aligned with its title.
  final bool centerAction;

  /// Measured space between title and description where the Web grid adds
  /// it (MachineDetailPanel disk-low banner: 4px); null keeps the recipe.
  final double? titleGap;

  /// Icon / Status node before the copy (Web Banner `icon`, `gap-x-2`).
  final Widget? leading;

  /// Callsite weight of the description content (e.g. a `font-bold` span).
  final FontWeight? descriptionWeight;

  /// Leading part of [description] rendered `<strong>` (rich catalog copy).
  final String? strongPrefix;
  final String description;

  /// False makes a dialog explanation static rather than a live alert.
  final bool live;
  final String? title;
  final RaftBannerRecipeStatus status;
  final RaftBannerRecipeSize size;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context), tokens = t.recipeTokens;
    final source = RaftBannerRecipe.resolve(
      theme: t.recipeTheme,
      status: status,
      size: size,
      states: t.recipeStates(
        extra: {
          'group/banner:data-size=${size.css}',
          'group/banner:data-status=${status.css}',
          if (glyph != null) 'has:>svg',
          if (action != null) 'has:>data-slot=banner-action',
          if (title != null)
            'has:>data-slot=banner-description+has:>data-slot=banner-title',
        },
      ),
      tokens: tokens,
    );
    final recipe = raftBannerSlots(t, source, size, status);
    // raft-ui 0.7 `banner`: `BannerAction` is `col-start-(--banner-text-col)
    // mt-2 flex flex-wrap gap-2`, a row under the copy; the description keeps
    // its own `font-normal` whatever the caller put on the root.
    final raft = t.option('banner.style', or: 'recipe') == 'raft';
    final trailing = raft ? null : action;
    final weight = raft ? null : descriptionWeight;
    final base = recipe.root.text(
      tokens,
      base: DefaultTextStyle.of(context).style,
    );
    return Semantics(
      role: live ? SemanticsRole.alert : null,
      child: RaftRecipeBox(
        style: recipe.root,
        tokens: tokens,
        child: _withLeading(
          context,
          recipe,
          tokens,
          trailing,
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (title != null)
                Padding(
                  // Measured: Web's Banner grid leaves 2px (Brutal) / 4px between title and description
                  // (also at `lg`) although the recipe declares no row gap.
                  padding: recipe.title.margin.copyWith(
                    bottom: titleGap ?? (4),
                  ),
                  child: Text(
                    raftText(context, title!),
                    style: recipe.title.text(tokens, base: base),
                  ),
                ),
              if (descriptionBuilder != null)
                descriptionBuilder!(recipe.description.text(tokens, base: base))
              else if (strongPrefix != null &&
                  description.startsWith(strongPrefix!))
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: strongPrefix,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      TextSpan(
                        text: description.substring(strongPrefix!.length),
                      ),
                    ],
                  ),
                  style: recipe.description.text(tokens, base: base),
                )
              else if (descriptionTail != null)
                _TailedDescription(
                  text: raftText(context, description),
                  tail: descriptionTail!,
                  tailWeight: descriptionTailWeight,
                  style: recipe.description
                      .text(tokens, base: base)
                      .copyWith(fontWeight: weight),
                  textAlign: textAlign,
                )
              else
                Text(
                  raftText(context, description),
                  textAlign: textAlign,
                  style: recipe.description
                      .text(tokens, base: base)
                      .copyWith(fontWeight: weight),
                ),
              ?footer,
              if (raft && action != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [action!],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _withLeading(
    BuildContext context,
    RaftBannerRecipeStyle recipe,
    RaftTokenResolver tokens,
    Widget? action,
    Widget content,
  ) {
    if (glyph == null && action == null) {
      return leading == null
          ? content
          : Row(
              children: [
                leading!,
                const SizedBox(width: 8),
                Expanded(child: content),
              ],
            );
    }
    final gap = recipe.root.columnGap ?? 8;
    final svg = recipe.root.target('& > svg');
    // Title + description: the svg spans both rows at the top (`mt-0.5`).
    final stacked = title != null;
    final brutal = recipe.root.borderWidth.top > 0;
    return LayoutBuilder(
      builder: (context, box) {
        // `@max-[24rem]` on the root container: the action drops to its own
        // full-width row, end aligned (`mt-2` Brutal / `mt-1` Elegant).
        final below = action != null && box.maxWidth <= 384;
        final main = _rowOf(
          context,
          stacked,
          gap,
          svg,
          recipe,
          tokens,
          content,
          below ? null : action,
        );
        if (!below) return main;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            main,
            Padding(
              padding: EdgeInsets.only(top: brutal ? 8 : 4),
              child: Align(alignment: Alignment.centerRight, child: action),
            ),
          ],
        );
      },
    );
  }

  Widget _rowOf(
    BuildContext context,
    bool stacked,
    double gap,
    RaftSlotStyle? svg,
    RaftBannerRecipeStyle recipe,
    RaftTokenResolver tokens,
    Widget content,
    Widget? action,
  ) {
    if (centerAction && action != null) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: _rowOf(
              context,
              stacked,
              gap,
              svg,
              recipe,
              tokens,
              content,
              null,
            ),
          ),
          SizedBox(width: gap),
          action,
        ],
      );
    }
    final t = RaftTokens.of(context);
    final start = t.option('banner.iconAlignment', or: 'center') == 'start';
    return Row(
      crossAxisAlignment: stacked || (start && !centerAction)
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        if (glyph != null) ...[
          Padding(
            padding: EdgeInsets.only(top: stacked && !start ? 2 : 0),
            child: RaftIcon(
              glyph!,
              size: size == RaftBannerRecipeSize.md
                  ? t.size('size.bannerGlyph', fallback: 16)
                  : svg?.width ?? 16,
              color: t.option('banner.iconColor', or: 'intent') == 'foreground'
                  ? t.ink
                  : svg?.textStyle(tokens).color ??
                        recipe.root.textStyle(tokens).color,
            ),
          ),
          SizedBox(width: gap),
        ],
        Expanded(child: content),
        if (action != null) ...[SizedBox(width: gap), action],
      ],
    );
  }
}

class _TailedDescription extends StatelessWidget {
  const _TailedDescription({
    required this.text,
    required this.tail,
    required this.style,
    this.tailWeight,
    this.textAlign,
  });
  final FontWeight? tailWeight;
  final String text;
  final ({String label, VoidCallback onPressed}) tail;
  final TextStyle style;
  final TextAlign? textAlign;

  /// The link is an atomic inline box (Web `<button className="ml-1">`): it
  /// wraps to the next line whole instead of breaking inside its label.
  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      text: text,
      children: [
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: Padding(
            padding: const EdgeInsets.only(left: 4),
            child: RaftHoverRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: tail.onPressed,
                child: RaftUnderlinedText(
                  raftText(context, tail.label),
                  style: style.copyWith(fontWeight: tailWeight),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
    textAlign: textAlign,
    style: style,
    // The baseline-aligned link box must not grow its line past the CSS
    // line-height (the inline-block link keeps the 20px line).
    strutStyle: StrutStyle.fromTextStyle(style, forceStrutHeight: true),
  );
}

/// Web HistoryLimitBanner.tsx: `Banner intent=warning density=sm` with
/// `mx-auto mb-3 max-w-md text-center font-bold justify-center` and an
/// underlined billing link. [inset] is the thread panel's `p-4` host.
class RaftHistoryLimitBanner extends StatelessWidget {
  const RaftHistoryLimitBanner({
    super.key,
    required this.message,
    this.linkLabel,
    this.onLink,
    this.inset = false,
  });

  /// [linkLabel] null renders the bare notice (ChatPanel's "Message not found"
  /// banner shares the HistoryLimitBanner classes without the billing link).
  final String message;
  final String? linkLabel;
  final VoidCallback? onLink;
  final bool inset;

  @override
  Widget build(BuildContext context) {
    final banner = Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 448),
          child: RaftBanner(
            key: const ValueKey('history-limit-banner'),
            size: RaftBannerRecipeSize.sm,
            textAlign: TextAlign.center,
            description: message,
            descriptionTail: linkLabel == null
                ? null
                : (label: linkLabel!, onPressed: onLink ?? () {}),
          ),
        ),
      ),
    );
    return inset
        ? Padding(padding: const EdgeInsets.all(16), child: banner)
        : banner;
  }
}
