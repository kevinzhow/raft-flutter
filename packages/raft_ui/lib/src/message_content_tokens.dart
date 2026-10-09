import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import 'design_primitives.dart';
import 'message_table_border.dart';
import 'theme.dart';
import 'tokens/tokens.dart';

/// Pinned BASE/DOCUMENT_MARKDOWN_COMPONENTS and ShowMoreToggle primitives.
/// Source: Web 26f77ef, MarkdownContent.tsx and ui/ShowMoreToggle.tsx.
abstract final class MessageContentPrimitive {
  static const linkLight = Color(0xff1d4ed8), linkDark = Color(0xff93c5fd);
  static const compactGap = 4.0, documentGap = 12.0;
  static const compactListIndent = 20.0, documentListIndent = 24.0;
  static const tableInset = EdgeInsets.symmetric(horizontal: 8, vertical: 4);
  static const inlineCodeScale = .875;
  static const collapseHeight = 320.0, collapseFadeHeight = 48.0;
  static const toggleSize = 11.0, toggleGap = 4.0;
}

class MessageContentSemantic {
  const MessageContentSemantic(this.tokens);
  final RaftTokens tokens;
  Color get link => tokens.dark
      ? MessageContentPrimitive.linkDark
      : MessageContentPrimitive.linkLight;
  Color get quote => tokens.brutal
      ? RaftPrimitiveColors.black.withValues(alpha: .7)
      : tokens.muted;
  Color get quoteEdge => tokens.brutal
      ? RaftPrimitiveColors.black.withValues(alpha: .4)
      : tokens.colors['line-muted']!;
  Color get collapseFade =>
      tokens.brutal ? RaftPrimitiveColors.white : tokens.panel;
  Color get toggleHover =>
      tokens.brutal ? RaftPrimitiveColors.black : tokens.strong;
  Color get toggle => tokens.brutal
      ? RaftPrimitiveColors.black.withValues(alpha: .6)
      : tokens.muted;
}

class MessageContentRecipe {
  MessageContentRecipe(
    this.tokens, {
    this.fontSize = 14,
    this.document = false,
    this.mountedMessage = false,
    this.foreground,
    this.lineHeight,
  }) : semantic = MessageContentSemantic(tokens);

  /// Caller line-height override (e.g. `leading-relaxed` comment bodies).
  final double? lineHeight;
  final RaftTokens tokens;
  final double fontSize;
  final bool document;

  /// MessageItem's inherited compact prose tracking; document prose is separate.
  final bool mountedMessage;
  final Color? foreground;
  final MessageContentSemantic semantic;
  TextStyle get body =>
      RaftTypography.body(
        tokens,
        size: fontSize,
        line: lineHeight ?? (document
            ? 24
            : mountedMessage
            ? switch (fontSize) {
                12 => 16.0,
                16 => 24.0,
                _ => fontSize * 20 / 14,
              }
            : fontSize * 20 / 14),
        // raft-ui messageItem `body`: brutal `text-sm text-black`.
        color:
            foreground ??
            (mountedMessage && !document
                ? (tokens.brutal ? RaftPrimitiveColors.black : tokens.muted)
                : tokens.strong),
      ).copyWith(
        fontFamily: document ? tokens.headingFont : tokens.bodyFont,
        letterSpacing: mountedMessage && !document && !tokens.brutal
            ? -fontSize * .01
            : 0,
      );
  TextStyle get toggle =>
      RaftTypography.body(
        tokens,
        size: MessageContentPrimitive.toggleSize,
        line: 16,
        weight: FontWeight.w900,
        color: semantic.toggle,
      ).copyWith(
        decoration: TextDecoration.underline,
        decorationColor: semantic.toggle,
      );
  TextStyle heading(int level) {
    final size = document
        ? switch (level) {
            1 => 30.0,
            2 => 24.0,
            3 => 20.0,
            _ => fontSize,
          }
        : fontSize *
              switch (level) {
                1 => 1.286,
                2 => 1.143,
                3 => 1.071,
                _ => 1.0,
              };
    // Markdown headings inherit the prose face, unlike Text.Heading.
    return RaftTypography.body(
      tokens,
      size: size,
      line: size * 1.25,
      weight: FontWeight.w700,
      color: level == 6
          ? tokens.muted
          : foreground ??
                (mountedMessage && !document && !tokens.brutal
                    ? tokens.muted
                    : tokens.strong),
    ).copyWith(
      fontFamily: document ? tokens.headingFont : tokens.bodyFont,
      letterSpacing: mountedMessage && !document && !tokens.brutal
          ? -fontSize * .01
          : 0,
    );
  }

  /// The Markdown builder adds blockSpacing before each non-first block.
  /// Remove that contribution from heading top margins and avoid adding the
  /// source bottom margin a second time. The first heading has no prior gap.
  Map<String, MarkdownPaddingBuilder> headingPadding(String source) {
    final first = RegExp(r'^#{1,6}\s').firstMatch(source.trimLeft());
    final firstLevel = first == null ? 0 : first.group(0)!.trim().length;
    final gap = document
        ? MessageContentPrimitive.documentGap
        : MessageContentPrimitive.compactGap;
    return {
      for (var level = 1; level <= 6; level++)
        'h$level': _HeadingPadding(
          first: firstLevel == level,
          firstTop: document
              ? switch (level) {
                  1 => 24.0,
                  2 => 20.0,
                  3 => 16.0,
                  _ => 4.0,
                }
              : switch (level) {
                  1 => 12.0,
                  2 || 3 => 8.0,
                  _ => 4.0,
                },
          precedingGap: gap,
        ),
      // Web markdown `hr`: `my-2`, collapsing with the neighbours' `mb-1`
      // (flutter_markdown already inserts blockSpacing between blocks).
      'hr': _RulePadding(
        first: source.trimLeft().startsWith(RegExp(r'(-{3,}|\*{3,}|_{3,})\s*(\n|$)')),
        margin: 8,
        blockGap: gap,
      ),
    };
  }

  // Elegant's th/td/table all have the same 1px collapsed stroke. Flutter
  // TableBorder paints about grid lines without allocating layout space. Split
  // each shared stroke across neighboring cells and contain outer paint with
  // half-stroke padding. Brutal's mixed header/body strokes require a separate
  // per-row renderer; do not pretend uniform allocation is correct there.
  double get collapsedTableHalfStroke => tokens.brutal ? 0 : tokens.border / 2;
  EdgeInsets get tableCellInset =>
      MessageContentPrimitive.tableInset +
      EdgeInsets.all(collapsedTableHalfStroke);
  EdgeInsets get tableOuterInset =>
      const EdgeInsets.symmetric(vertical: 4) +
      EdgeInsets.all(collapsedTableHalfStroke);
  MarkdownStyleSheet stylesheet(BuildContext context) =>
      MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
        p: body,
        // `border-t border-line-muted`; brutal `border-t-2 border-black`.
        horizontalRuleDecoration: BoxDecoration(
          border: Border(
            top: tokens.brutal
                ? const BorderSide(color: Colors.black, width: 2)
                : BorderSide(color: tokens.colors['line-muted']!),
          ),
        ),
        blockSpacing: document
            ? MessageContentPrimitive.documentGap
            : MessageContentPrimitive.compactGap,
        listIndent: document
            ? MessageContentPrimitive.documentListIndent
            : MessageContentPrimitive.compactListIndent,
        listBulletPadding: EdgeInsets.zero,
        listBullet: body,
        h1: heading(1),
        h2: heading(2),
        h3: heading(3),
        h4: heading(4),
        h5: heading(5),
        h6: heading(6),
        h1Padding: EdgeInsets.only(top: document ? 12 : 8, bottom: 0),
        h2Padding: EdgeInsets.only(top: document ? 8 : 4, bottom: 0),
        h3Padding: EdgeInsets.only(top: 4, bottom: 0),
        h4Padding: const EdgeInsets.only(top: 0, bottom: 0),
        h5Padding: const EdgeInsets.only(top: 0, bottom: 0),
        h6Padding: const EdgeInsets.only(top: 0, bottom: 0),
        blockquote: body.copyWith(
          color: semantic.quote,
          fontStyle: FontStyle.italic,
        ),
        blockquotePadding: const EdgeInsets.only(left: 12),
        blockquoteDecoration: BoxDecoration(
          border: Border(left: BorderSide(color: semantic.quoteEdge, width: 2)),
        ),
        tableHead: body.copyWith(
          fontWeight: FontWeight.w700,
          color: tokens.brutal ? RaftPrimitiveColors.black : tokens.strong,
        ),
        tableHeadAlign: TextAlign.left,
        tableBody: body,
        tableColumnWidth: const IntrinsicColumnWidth(),
        tablePadding: tableOuterInset,
        tableHeadCellsDecoration: BoxDecoration(
          color: tokens.brutal
              ? tokens.colors['color-brutal-cyan']
              : tokens.colors['info-soft'],
        ),
        tableCellsPadding: tableCellInset,
        tableHeadCellsPadding: tableCellInset,
        tableBorder: tokens.brutal
            ? TableBorder.all(
                color: RaftPrimitiveColors.black,
                width: tokens.border,
              )
            : MessageCollapsedTableBorder(
                color: tokens.colors['line-muted']!,
                width: tokens.border,
              ),
        a: body.copyWith(
          color: semantic.link,
          decoration: TextDecoration.underline,
          decorationThickness: 2,
          decorationColor: semantic.link,
        ),
        code:
            RaftTypography.mono(
              tokens,
              size: fontSize * MessageContentPrimitive.inlineCodeScale,
              line: fontSize * MessageContentPrimitive.inlineCodeScale * 1.3,
              color: tokens.ink,
            ).copyWith(
              backgroundColor: tokens.brutal
                  ? tokens.strong.withValues(alpha: .05)
                  : tokens.colors['fill-muted'],
            ),
      );
}

/// AttachmentPreviewSurfaces table/text reader component recipe.
class DocumentAttachmentRecipe {
  const DocumentAttachmentRecipe(this.tokens);
  final RaftTokens tokens;
  EdgeInsets get inset => const EdgeInsets.all(16);
  EdgeInsets markdownInset(double viewportWidth) => EdgeInsets.symmetric(
    horizontal: viewportWidth >= 768 ? 40 : 24,
    vertical: viewportWidth >= 768 ? 48 : 32,
  );
  EdgeInsets get textInset => const EdgeInsets.all(16);
  Color get background => tokens.brutal
      ? tokens.product.brutalCream.withValues(alpha: .45)
      : tokens.colors['layer-canvas-muted']!;
  Color get paper => tokens.panel;
  double get maxColumnWidth => 220;
  TextStyle get tableText =>
      RaftTypography.mono(tokens, size: 11, line: 20, color: tokens.strong);
  TextStyle get text =>
      RaftTypography.mono(tokens, size: 12, line: 20, color: tokens.strong);
  TextStyle get heading => RaftTypography.body(
    tokens,
    size: 12,
    line: 16,
    weight: FontWeight.w700,
    color: tokens.brutal ? tokens.strong.withValues(alpha: .55) : tokens.muted,
  );
  Color get tableHeader => tokens.brutal
      ? tokens.product.brutalCream
      : tokens.colors['layer-canvas-muted']!;
  Color get rowStripe => RaftPrimitiveColors.black.withValues(alpha: .03);
  BorderSide get border => BorderSide(
    color: tokens.brutal
        ? RaftPrimitiveColors.black
        : tokens.colors['line-muted']!,
    width: tokens.border,
  );
  EdgeInsets get cellInset => MessageContentPrimitive.tableInset;
}

/// Per-build heading padding, never cached across account/content changes.
class _RulePadding extends MarkdownPaddingBuilder {
  _RulePadding({
    required this.first,
    required this.margin,
    required this.blockGap,
  });
  bool first;
  final double margin, blockGap;
  EdgeInsets current = EdgeInsets.zero;
  @override
  void visitElementBefore(dynamic element) {
    final collapsed = (margin - blockGap).clamp(0.0, margin).toDouble();
    current = EdgeInsets.only(top: first ? margin : collapsed, bottom: collapsed);
    first = false;
  }

  @override
  EdgeInsets getPadding() => current;
}

class _HeadingPadding extends MarkdownPaddingBuilder {
  _HeadingPadding({
    required this.first,
    required this.firstTop,
    required this.precedingGap,
  });
  bool first;
  final double firstTop, precedingGap;
  EdgeInsets current = EdgeInsets.zero;
  @override
  void visitElementBefore(dynamic element) {
    current = EdgeInsets.only(
      top: first
          ? firstTop
          : (firstTop - precedingGap).clamp(0.0, double.infinity).toDouble(),
    );
    first = false;
  }

  @override
  EdgeInsets getPadding() => current;
}
