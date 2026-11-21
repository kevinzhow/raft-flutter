import 'package:flutter/rendering.dart' show OverflowBoxFit;
import 'package:flutter/widgets.dart';

import '../recipe_surface.dart';
import '../recipes/file_preview.g.dart';
import '../recipes/recipe_runtime.dart';
import '../space.dart';
import '../text_scaling.dart';
import '../theme.dart';

enum RaftFilePreviewKind { document, code, media }

/// The FilePreview illustration and its extension badge from raft-ui.
class RaftFilePreview extends StatelessWidget {
  const RaftFilePreview({
    super.key,
    required this.kind,
    this.label,
    this.scale = 1,
  });

  final RaftFilePreviewKind kind;
  final String? label;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final tokens = t.recipeTokens;
    final slots = RaftFilePreviewRecipe.resolve(
      states: t.recipeStates(),
      tokens: tokens,
    );
    final artwork = switch (kind) {
      RaftFilePreviewKind.document => slots.document,
      RaftFilePreviewKind.code => slots.code,
      RaftFilePreviewKind.media => slots.media,
    };
    return Transform.scale(
      scale: scale,
      child: SizedBox(
        width: slots.root.width,
        height: slots.root.height,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            RaftRecipeBox(
              style: artwork,
              tokens: tokens,
              decorationOverride: (decoration) {
                final corner = artwork['border-top-right-radius'];
                if (corner case CssNum(unit: '%', :final value)) {
                  final radius = artwork.borderRadius ?? BorderRadius.zero;
                  final horizontalRadius = artwork.width! * value / 100;
                  final verticalRadius = artwork.height! * value / 100;
                  return decoration.copyWith(
                    borderRadius: radius.copyWith(
                      topRight: Radius.elliptical(
                        horizontalRadius,
                        verticalRadius,
                      ),
                    ),
                  );
                }
                return decoration;
              },
              alignment: kind == RaftFilePreviewKind.code
                  ? Alignment.center
                  : null,
              child: switch (kind) {
                RaftFilePreviewKind.document => _document(t),
                RaftFilePreviewKind.code => _code(slots, tokens),
                RaftFilePreviewKind.media => null,
              },
            ),
            if (label case final extension?)
              Positioned(
                right: slots.badge.length('right'),
                bottom: slots.badge.length('bottom'),
                child: RaftRecipeBox(
                  style: slots.badge,
                  tokens: tokens,
                  child: Text(
                    extension,
                    softWrap: false,
                    textScaler: RaftChrome.boundedScalerOf(context),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _document(RaftTokens t) {
    final line = SizedBox(
      height: RaftSpace.half,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: t.colors['ink-10'],
          shape: const StadiumBorder(),
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: RaftSpace.x1_5,
      children: [
        line,
        for (final (left, right) in const [(1, 2), (1, 1), (1, 2)])
          Row(
            spacing: RaftSpace.half,
            children: [
              Expanded(flex: left, child: line),
              Expanded(flex: right, child: line),
            ],
          ),
      ],
    );
  }

  Widget _code(RaftFilePreviewRecipeStyle slots, RaftTokenResolver tokens) {
    Widget glyph(String text) => RaftRecipeBox(
      style: slots.codeGlyph,
      tokens: tokens,
      child: Text(text, textScaler: TextScaler.noScaling),
    );
    return RaftRecipeBox(
      style: slots.codeStack,
      tokens: tokens,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: RaftSpace.hairline,
        children: [
          for (final (row, line, start, end) in [
            (slots.codeRow, slots.codeTagLine, '<', '>'),
            (slots.codeRowIndent, slots.codeAttributeLine, '<', '>'),
            (slots.codeTextRow, slots.codeTextLine, '', ''),
            (slots.codeRowIndent, slots.codeAttributeLine, '</', '>'),
            (slots.codeRowIndent, slots.codeSelfClosingLine, '<', '/>'),
            (slots.codeRow, slots.codeTagLine, '</', '>'),
          ])
            Padding(
              padding: row.padding,
              child: OverflowBox(
                maxWidth: double.infinity,
                alignment: AlignmentDirectional.centerStart,
                fit: OverflowBoxFit.deferToChild,
                child: Row(
                  spacing: row.columnGap ?? 0,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (start.isNotEmpty) glyph(start),
                    RaftRecipeBox(style: line, tokens: tokens),
                    if (end.isNotEmpty) glyph(end),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
