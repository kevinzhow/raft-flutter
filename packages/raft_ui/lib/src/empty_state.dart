import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';

import 'icons.dart';
import 'panel_layout.dart' show RaftCssText;
import 'theme.dart';

/// raft-ui `EmptyState`: a [glyph] (36px, `foreground-hint`), a bold title, one
/// sentence and at most one [action], centred. Semantic copy belongs to the
/// caller; every visual value comes from the theme pack. Without a [glyph] the
/// pack's `emptyState.defaultGlyph` stands in (the Raft look: a Lucide message
/// square; the frozen Elegant and Brutal looks keep their original forum mark).
class RaftEmptyState extends StatelessWidget {
  const RaftEmptyState({
    super.key,
    required this.title,
    required this.detail,
    this.glyph,
    this.action,
  });

  final String title, detail;

  /// Lucide glyph.
  final RaftGlyph? glyph;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final css = t.option('emptyState.textLayout', or: 'css') == 'css';
    final bodyBase = DefaultTextStyle.of(context).style;
    final titleSize = t.size('type.emptyTitle.size', fallback: 17);
    final bodySize = t.size('type.emptyBody.size', fallback: 14);
    final titleStyle = TextStyle(
      locale: t.textLocale,
      fontFamilyFallback: t.fontFallback,
      fontWeight: FontWeight.w700,
      letterSpacing: 0,
      fontFamily: t.fontFamily('font.emptyTitle'),
      fontSize: titleSize,
      height: t.size('type.emptyTitle.line', fallback: 22) / titleSize,
      color: t.colors['foreground-empty-title'] ?? t.muted,
    );
    final bodyStyle = bodyBase.copyWith(
      fontSize: bodySize,
      height: t.size('type.emptyBody.line', fallback: 20) / bodySize,
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
          horizontal: t.size('space.emptyInline', fallback: 24),
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
              text(title, titleStyle),
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
