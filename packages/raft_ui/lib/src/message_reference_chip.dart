// In-body message references (Web MessageItem.tsx markdown `a` renderer):
// MentionLink → raft-ui MessageReferenceText (primary for self, secondary
// otherwise); #channel / dm → MessageReferenceChip variant accent; thread
// refs → chip variant link; message permalinks → text primary; task refs →
// raft-ui TaskChip variant="inline" (status icon + `#N`), unknown tasks →
// Badge variant muted. Every visual value resolves from the generated
// raft-ui recipes.
import 'package:flutter/material.dart';

import 'mounted_task_chip.dart';
import 'recipes/badge.g.dart';
import 'recipes/message_reference.g.dart';
import 'recipes/recipe_runtime.dart';
import 'recipes/task_chip.g.dart';
import 'recipes/token_binding.dart';
import 'theme.dart';

enum RaftReferenceKind {
  /// MentionLink of the viewer (`MessageReferenceText variant="primary"`).
  selfMention,

  /// MentionLink of someone else (`MessageReferenceText variant="secondary"`).
  mention,

  /// `#channel` / `dm:@peer` (`MessageReferenceChip variant="accent"`).
  channel,

  /// Thread refs (`MessageReferenceChip variant="link"`).
  thread,

  /// Message permalinks (`MessageReferenceText variant="primary"`).
  message,

  /// Known task (`TaskChip variant="inline"`).
  task,

  /// Unknown task number (`Badge variant="muted"`).
  unknownTask,
}

@immutable
class RaftReferenceAppearance {
  const RaftReferenceAppearance(this.kind, {this.taskStatus});
  final RaftReferenceKind kind;
  final RaftMessageTaskStatus? taskStatus;
}

RaftRecipeTheme _theme(RaftTokens t) =>
    t.brutal ? RaftRecipeTheme.brutal : RaftRecipeTheme.elegant;

/// Inline span for one reference inside a markdown paragraph. [base] is the
/// surrounding paragraph style (the recipes use `font-size: inherit`).
/// References are short `whitespace-nowrap` boxes, so they are WidgetSpans
/// that stay focusable links (Web renders `<a href>`): Enter/Space activate,
/// semantics carry the link URL.
InlineSpan raftReferenceSpan(
  BuildContext context, {
  required String label,
  required String href,
  required TextStyle base,
  RaftReferenceAppearance? appearance,
  TextStyle? linkStyle,
  VoidCallback? onTap,
}) {
  final t = RaftTokens.of(context);
  final resolver = RaftRecipeTokens(t);
  Widget child;
  if (appearance == null) {
    child = Text(label, style: base.merge(linkStyle));
  } else if (appearance.kind == RaftReferenceKind.mention) {
    // `display: inline` text: bold, underline (decoration-black/30,
    // decoration-2, underline-offset-2).
    final s = RaftMessageReferenceRecipe.resolve(
      theme: _theme(t),
      variant: RaftMessageReferenceRecipeVariant.secondary,
      tokens: resolver,
    ).root;
    final decoration = RaftColorRef.fromCss(s['text-decoration-color']);
    child = Text(
      label,
      style: base.copyWith(
        fontWeight: s.fontWeight,
        color: s.color?.resolve(resolver) ?? base.color,
        decoration: TextDecoration.underline,
        decorationColor: decoration?.resolve(
          resolver,
          currentColor: base.color,
        ),
        decorationThickness: 2,
      ),
    );
  } else {
    child = RaftReferenceChip(
      label: label,
      appearance: appearance,
      fontSize: base.fontSize ?? 14,
      fontFamily: base.fontFamily,
      fontFamilyFallback: base.fontFamilyFallback,
    );
  }
  return WidgetSpan(
    alignment: PlaceholderAlignment.baseline,
    baseline: TextBaseline.alphabetic,
    child: _ReferenceLink(label: label, href: href, onTap: onTap, child: child),
  );
}

class _ReferenceLink extends StatefulWidget {
  const _ReferenceLink({
    required this.label,
    required this.href,
    required this.child,
    this.onTap,
  });
  final String label, href;
  final Widget child;
  final VoidCallback? onTap;
  @override
  State<_ReferenceLink> createState() => _ReferenceLinkState();
}

class _ReferenceLinkState extends State<_ReferenceLink> {
  bool focused = false;
  @override
  Widget build(BuildContext context) => FocusableActionDetector(
    enabled: widget.onTap != null,
    onShowFocusHighlight: (value) => setState(() => focused = value),
    actions: {
      ActivateIntent: CallbackAction<ActivateIntent>(
        onInvoke: (_) {
          widget.onTap?.call();
          return null;
        },
      ),
    },
    child: Semantics(
      link: true,
      linkUrl: Uri.tryParse(widget.href),
      label: widget.label,
      onTap: widget.onTap,
      child: ExcludeSemantics(
        child: MouseRegion(
          // In-message refs keep the arrow cursor (`cursor-default`).
          cursor: SystemMouseCursors.basic,
          child: GestureDetector(
            onTap: widget.onTap,
            child: DecoratedBox(
              // `focus-visible:outline-2 focus-visible:outline-offset-2`.
              position: DecorationPosition.foreground,
              decoration: BoxDecoration(
                border: focused
                    ? Border.all(color: RaftTokens.of(context).strong, width: 2)
                    : null,
              ),
              child: widget.child,
            ),
          ),
        ),
      ),
    ),
  );
}

/// Inline-flex reference box: `leading-[1.2em]`, `[font-size:inherit]`,
/// baseline-aligned with the sentence.
class RaftReferenceChip extends StatelessWidget {
  const RaftReferenceChip({
    super.key,
    required this.label,
    required this.appearance,
    this.fontSize = 14,
    this.fontFamily,
    this.fontFamilyFallback,
  });
  final String label;
  final RaftReferenceAppearance appearance;
  final double fontSize;
  final String? fontFamily;
  final List<String>? fontFamilyFallback;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final resolver = RaftRecipeTokens(t);
    late final RaftSlotStyle s;
    Color? background, foreground, iconColor;
    Border? border;
    Widget? icon;
    var lineHeight = 1.2;
    var weight = FontWeight.w500;
    switch (appearance.kind) {
      case RaftReferenceKind.task:
        final status = appearance.taskStatus ?? RaftMessageTaskStatus.todo;
        s = RaftTaskChipRecipe.resolveProps({
          'theme': _theme(t).name,
          'variant': 'inline',
          'status': switch (status) {
            RaftMessageTaskStatus.todo => 'todo',
            RaftMessageTaskStatus.inProgress => 'in-progress',
            RaftMessageTaskStatus.inReview => 'in-review',
            RaftMessageTaskStatus.done => 'done',
            RaftMessageTaskStatus.closed => 'closed',
          },
        }, tokens: resolver)['root']!;
        // Status fill/ink/border: the same TaskChip status table as the
        // footer chip.
        final colors = RaftMessageTaskChipRecipe(t, status);
        background = colors.background;
        foreground = colors.foreground;
        iconColor = colors.iconForeground;
        border = Border.fromBorderSide(colors.side());
        // `[&>svg]:size-[0.857em]`.
        icon = SizedBox.square(
          dimension: fontSize * .857,
          child: FittedBox(
            child: RaftMessageTaskStatusIcon(
              status: status,
              color: iconColor,
              inverse: t.brutal ? Colors.white : t.colors['layer-panel']!,
            ),
          ),
        );
      case RaftReferenceKind.unknownTask:
        s = RaftBadgeRecipe.resolve(
          theme: _theme(t),
          variant: RaftBadgeRecipeVariant.muted,
          uppercase: false,
          tokens: resolver,
        ).root;
        lineHeight = 1;
      case RaftReferenceKind.selfMention || RaftReferenceKind.message:
        s = RaftMessageReferenceRecipe.resolve(
          theme: _theme(t),
          variant: RaftMessageReferenceRecipeVariant.primary,
          tokens: resolver,
        ).root;
      case RaftReferenceKind.channel:
        s = RaftMessageReferenceRecipe.resolve(
          theme: _theme(t),
          variant: RaftMessageReferenceRecipeVariant.accent,
          tokens: resolver,
        ).root;
      case RaftReferenceKind.thread || RaftReferenceKind.mention:
        s = RaftMessageReferenceRecipe.resolve(
          theme: _theme(t),
          variant: RaftMessageReferenceRecipeVariant.link,
          tokens: resolver,
        ).root;
    }
    final decoration = s.decoration(resolver);
    final size = s.fontSize ?? fontSize;
    weight = s.fontWeight ?? weight;
    final text = TextStyle(
      fontFamily: fontFamily ?? t.headingFont,
      fontFamilyFallback: fontFamilyFallback,
      fontSize: size,
      height:
          s['line-height'] is CssNum &&
              (s['line-height'] as CssNum).unit == 'em'
          ? (s['line-height'] as CssNum).value
          : s.lineHeight ?? lineHeight,
      fontWeight: weight,
      letterSpacing: s.letterSpacing,
      color: foreground ?? s.color?.resolve(resolver) ?? t.strong,
      leadingDistribution: TextLeadingDistribution.even,
    );
    final gap = s.columnGap ?? 4;
    final chip = Container(
      height: appearance.kind == RaftReferenceKind.unknownTask
          ? s.height
          : null,
      padding: s.padding,
      decoration: decoration.copyWith(
        color: background ?? decoration.color,
        border: border ?? decoration.border,
      ),
      // `items-baseline` + `[&>svg]:self-center`: the label is the only
      // baseline child, so the row (and the WidgetSpan) align on it while
      // the glyph centres on the line box.
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[icon, SizedBox(width: gap)],
          Flexible(
            // CSS uses the declared line-height as the inline-flex line box.
            // RenderParagraph rounds its natural height to whole pixels.
            child: SizedBox(
              height: size * (text.height ?? lineHeight),
              child: Text(
                label,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: text,
                // CSS line-height fixes the line box even when a CJK fallback
                // glyph has taller font metrics than the surrounding face.
                strutStyle: StrutStyle.fromTextStyle(
                  text,
                  leading: 0,
                  leadingDistribution: TextLeadingDistribution.even,
                  forceStrutHeight: true,
                ),
              ),
            ),
          ),
        ],
      ),
    );
    return chip;
  }
}
