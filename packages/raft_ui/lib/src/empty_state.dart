import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';

import 'icons.dart';
import 'panel_layout.dart' show RaftCssText;
import 'theme.dart';

/// The metrics of raft-ui 0.95.3 `EmptyState` that change with a mouse from
/// 768 (`md:pointer-fine`): sides 16 (`px-(--page-inset)`) instead of 24, the
/// title `text-headline` 16/24 instead of 17/22, the description `text-callout`
/// 14/22 instead of 14/20. By touch the pack's own tokens stand.
({
  double inline,
  double titleSize,
  double titleLine,
  double bodySize,
  double bodyLine,
})
raftEmptyStateMetrics(RaftTokens t) {
  if (t.desktop) {
    final title = t.typeSlot('headline'), body = t.typeSlot('callout');
    return (
      inline: 16, // `--page-inset`
      titleSize: title.fontSize,
      titleLine: title.lineHeight,
      bodySize: body.fontSize,
      bodyLine: body.lineHeight,
    );
  }
  return (
    inline: t.size('space.emptyInline', fallback: 24),
    titleSize: t.size('type.emptyTitle.size', fallback: 17),
    titleLine: t.size('type.emptyTitle.line', fallback: 22),
    bodySize: t.size('type.emptyBody.size', fallback: 14),
    bodyLine: t.size('type.emptyBody.line', fallback: 20),
  );
}

/// raft-ui `EmptyState`: a [glyph] (36px, `foreground-hint`), a bold title, one
/// sentence and at most one [action], centred. Semantic copy belongs to the
/// caller; every visual value comes from the theme pack. Without a [glyph] the
/// pack's `emptyState.defaultGlyph` stands in (a Lucide message square).
class RaftEmptyState extends StatelessWidget {
  const RaftEmptyState({
    super.key,
    required this.title,
    required this.detail,
    this.glyph,
    this.action,
    this.titleHeading = false,
  });

  final String title, detail;

  /// Web `titleHeading`: the title is the heading of an area this empty state
  /// fills on its own (a screen reader finds it by heading).
  final bool titleHeading;

  /// Lucide glyph.
  final RaftGlyph? glyph;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final css = t.option('emptyState.textLayout', or: 'css') == 'css';
    final bodyBase = DefaultTextStyle.of(context).style;
    final m = raftEmptyStateMetrics(t);
    final titleSize = m.titleSize;
    final bodySize = m.bodySize;
    final titleStyle = TextStyle(
      locale: t.textLocale,
      fontFamilyFallback: t.fontFallback,
      fontWeight: FontWeight.w700,
      letterSpacing: 0,
      fontFamily: t.fontFamily('font.emptyTitle'),
      fontSize: titleSize,
      height: m.titleLine / titleSize,
      color: t.colors['foreground-empty-title'] ?? t.muted,
    );
    final bodyStyle = bodyBase.copyWith(
      fontSize: bodySize,
      height: m.bodyLine / bodySize,
      color: t.colors['foreground-empty-body'] ?? t.muted,
    );
    Widget text(String value, TextStyle style) => css
        ? RaftCssText(value, style: style, textAlign: TextAlign.center)
        : Text(value, style: style, textAlign: TextAlign.center);
    final size = t.size('size.emptyGlyph', fallback: 36);
    final iconColor = t.colors['foreground-empty-icon'] ?? t.strong;
    final forum =
        glyph == null &&
        t.option('emptyState.defaultGlyph', or: 'messageSquare') == 'forum';
    final effectiveGlyph = glyph ?? (forum ? null : RaftGlyph.messageSquare);
    final contentMax = t.size('size.emptyContentMax', fallback: 384);
    final descriptionMax = t.size('size.emptyDescriptionMax', fallback: 300);
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: m.inline,
          vertical: t.size('space.emptyBlock', fallback: 48),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: contentMax > 0 ? contentMax : double.infinity,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (effectiveGlyph != null)
                RaftIcon(effectiveGlyph, size: size, color: iconColor)
              else
                Icon(Icons.forum_outlined, size: size, color: iconColor),
              SizedBox(height: t.size('space.emptyIconAfter', fallback: 16)),
              Semantics(header: titleHeading, child: text(title, titleStyle)),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: descriptionMax > 0
                      ? descriptionMax
                      : double.infinity,
                ),
                child: text(detail, bodyStyle),
              ),
              if (action != null)
                Padding(
                  padding: EdgeInsets.only(
                    top: t.size('space.emptyActionBefore', fallback: 20),
                  ),
                  child: action,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
