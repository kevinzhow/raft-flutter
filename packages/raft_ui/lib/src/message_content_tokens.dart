import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import 'design_primitives.dart';
import 'theme.dart';
import 'primitive_tokens.dart';

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
      ? RaftPrimitives.rgbaff000000.withValues(alpha: .7)
      : tokens.muted;
  Color get quoteEdge => tokens.brutal
      ? RaftPrimitives.rgbaff000000.withValues(alpha: .4)
      : tokens.colors['line-muted']!;
  Color get collapseFade => tokens.brutal ? RaftPrimitives.rgbaffffffff : tokens.panel;
  Color get toggle => tokens.brutal
      ? RaftPrimitives.rgbaff000000.withValues(alpha: .6)
      : tokens.muted;
}

class MessageContentRecipe {
  MessageContentRecipe(this.tokens, {this.fontSize = 14, this.document = false})
    : semantic = MessageContentSemantic(tokens);
  final RaftTokens tokens;
  final double fontSize;
  final bool document;
  final MessageContentSemantic semantic;
  TextStyle get body => RaftTypography.body(tokens,
      size: fontSize, line: document ? 24 : fontSize * 20 / 14, color: tokens.ink).copyWith(fontFamily: document ? tokens.headingFont : tokens.bodyFont);
  TextStyle get toggle => RaftTypography.body(tokens,
      size: MessageContentPrimitive.toggleSize, line: 16,
      weight: FontWeight.w900, color: semantic.toggle).copyWith(
        decoration: TextDecoration.underline,
        decorationColor: semantic.toggle);
  TextStyle heading(int level) {
    final size = document
        ? switch (level) { 1 => 30.0, 2 => 24.0, 3 => 20.0, _ => fontSize }
        : fontSize * switch (level) { 1 => 1.286, 2 => 1.143, 3 => 1.071, _ => 1.0 };
    // Markdown headings inherit the prose face, unlike Text.Heading.
    return RaftTypography.body(tokens, size: size, line: size * 1.25,
        weight: FontWeight.w700, color: level == 6 ? tokens.muted : tokens.ink).copyWith(fontFamily: document ? tokens.headingFont : tokens.bodyFont);
  }
  MarkdownStyleSheet stylesheet(BuildContext context) =>
      MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
        p: body,
        blockSpacing: document ? MessageContentPrimitive.documentGap : MessageContentPrimitive.compactGap,
        listIndent: document ? MessageContentPrimitive.documentListIndent : MessageContentPrimitive.compactListIndent,
        listBulletPadding: EdgeInsets.zero,
        listBullet: body,
        h1: heading(1), h2: heading(2), h3: heading(3),
        h4: heading(4), h5: heading(5), h6: heading(6),
        h1Padding: EdgeInsets.only(top: document ? 24 : 12, bottom: document ? 12 : 4),
        h2Padding: EdgeInsets.only(top: document ? 20 : 8, bottom: document ? 10 : 4),
        h3Padding: EdgeInsets.only(top: document ? 16 : 8, bottom: document ? 8 : 4),
        h4Padding: const EdgeInsets.only(top: 4, bottom: 2),
        h5Padding: const EdgeInsets.only(top: 4, bottom: 2),
        h6Padding: const EdgeInsets.only(top: 4, bottom: 2),
        blockquote: body.copyWith(color: semantic.quote, fontStyle: FontStyle.italic),
        blockquotePadding: const EdgeInsets.only(left: 12),
        blockquoteDecoration: BoxDecoration(border: Border(left: BorderSide(color: semantic.quoteEdge, width: 2))),
        tableHead: body.copyWith(fontWeight: FontWeight.w700),
        tableHeadAlign: TextAlign.left,
        tableBody: body,
        tableColumnWidth: const IntrinsicColumnWidth(),
        tablePadding: const EdgeInsets.symmetric(vertical: 4),
        tableHeadCellsDecoration: BoxDecoration(color: tokens.brutal ? tokens.colors['color-brutal-cyan'] : tokens.colors['info-soft']),
        tableCellsPadding: MessageContentPrimitive.tableInset,
        tableHeadCellsPadding: MessageContentPrimitive.tableInset,
        tableBorder: TableBorder.all(color: tokens.brutal ? RaftPrimitives.rgbaff000000 : tokens.colors['line-muted']!, width: tokens.border),
        a: body.copyWith(color: semantic.link, decoration: TextDecoration.underline, decorationThickness: 2, decorationColor: semantic.link),
        code: RaftTypography.mono(tokens, size: fontSize * MessageContentPrimitive.inlineCodeScale, line: fontSize * MessageContentPrimitive.inlineCodeScale * 1.3, color: tokens.ink).copyWith(backgroundColor: tokens.brutal ? tokens.strong.withValues(alpha: .05) : tokens.colors['fill-muted']),
      );
}

/// AttachmentPreviewSurfaces table/text reader component recipe.
class DocumentAttachmentRecipe {
  const DocumentAttachmentRecipe(this.tokens);
  final RaftTokens tokens;
  EdgeInsets get inset => const EdgeInsets.all(16);
  EdgeInsets markdownInset(double viewportWidth) => EdgeInsets.symmetric(horizontal: viewportWidth >= 768 ? 40 : 24, vertical: viewportWidth >= 768 ? 48 : 32);
  EdgeInsets get textInset => const EdgeInsets.all(16);
  Color get background => tokens.brutal
      ? RaftPrimitives.cream200.withValues(alpha: .45)
      : tokens.colors['layer-canvas-muted']!;
  Color get paper => tokens.panel;
  double get maxColumnWidth => 220;
  TextStyle get tableText => RaftTypography.mono(tokens, size: 11, line: 20, color: tokens.strong);
  TextStyle get text => RaftTypography.mono(tokens, size: 12, line: 20, color: tokens.strong);
  TextStyle get heading => RaftTypography.body(tokens, size: 12, line: 16,
      weight: FontWeight.w700, color: tokens.brutal ? tokens.strong.withValues(alpha: .55) : tokens.muted);
  Color get tableHeader => tokens.brutal
      ? RaftPrimitives.cream200
      : tokens.colors['layer-canvas-muted']!;
  Color get rowStripe => RaftPrimitives.rgbaff000000.withValues(alpha: .03);
  BorderSide get border => BorderSide(color: tokens.brutal ? RaftPrimitives.rgbaff000000 : tokens.colors['line-muted']!, width: tokens.border);
  EdgeInsets get cellInset => MessageContentPrimitive.tableInset;
}
