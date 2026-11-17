import 'token_geometry.dart';

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';
import 'design_primitives.dart';
import 'raft/ui_tokens.dart';

/// raft-ui 0.5.52 FilePreviewBadge and message-image-gallery primitives.
/// OKLCH roles are resolved by the actual Chromium renderer and retained in
/// attachment-badge-colors.json; dimensions come from the pinned recipe.
abstract final class AttachmentPrimitive {
  static const badgeSize = Size(28, 14);
  static const badgeGap = 6.0;

  /// `--control-embedded-inset`: the Raft card's right padding is this minus
  /// the 1px border (`pr-[calc(var(--control-embedded-inset)-1px)]`).
  static const embeddedInset = 6.0;

  /// Raft `message-image-gallery`: `gap-1`, root `max-w-[min(360px,100%)]`,
  /// and the `@min-[360px]` container step.
  static const raftGalleryGap = 4.0, raftGalleryMaxWidth = 360.0;
  static const wideAspect = 2.2, tallAspect = .55;
  static const compactRowHeight = 128.0, regularRowHeight = 144.0;
  static const compactThreeRowHeight = 112.0, regularThreeRowHeight = 128.0;
  static const columnsBreakpoint = 768.0;
  static const singleImageMaxWidth = 416.0, singleImageMaxHeight = 288.0;
  static const mobileGalleryMaxWidth = 352.0, desktopGalleryMaxWidth = 448.0;
  static const mobileGalleryReserve = 112.0;

  /// One short fade for an image preview that arrives from the network;
  /// cached previews appear without it.
  static const previewFade = Duration(milliseconds: 120);
}

/// Semantic file kinds exactly match attachmentBadgeType.ts; unknown stays bare.
class AttachmentSemantic {
  const AttachmentSemantic(this.tokens);
  final RaftTokens tokens;
  static const kinds = <String, String>{
    'pdf': 'rose',
    'doc': 'blue',
    'docx': 'blue',
    'txt': 'neutral',
    'md': 'neutral',
    'markdown': 'neutral',
    'csv': 'neutral',
    'json': 'neutral',
    'zip': 'amber',
    'html': 'violet',
    'png': 'emerald',
    'jpg': 'emerald',
    'jpeg': 'emerald',
    'gif': 'emerald',
    'webp': 'emerald',
    'svg': 'emerald',
    'mp4': 'blue',
    'mov': 'blue',
  };
  String? kind(String extension) => kinds[extension.toLowerCase()];

  /// raft-ui 0.95.3 FilePreviewBadge is neutral: one `fill-muted` chip for
  /// every known extension.
  Color? badgeBackground(String extension) {
    final role = kind(extension);
    if (role == null) return null;
    return tokens.colors['fill-muted'];
  }

  Color badgeForeground(String extension) => tokens.colors['foreground-muted']!;
}

/// Component recipe separates the image gallery from the file metadata chip.
class AttachmentComponentRecipe {
  AttachmentComponentRecipe(this.tokens)
    : file = RaftAttachmentRecipe(tokens),
      semantics = AttachmentSemantic(tokens);
  final RaftTokens tokens;
  final RaftAttachmentRecipe file;
  final AttachmentSemantic semantics;

  /// Raft: `py-2 pl-2.5 pr-[embedded-inset - 1px]` inside the 1px border.
  EdgeInsets get contentInset =>
      const EdgeInsets.fromLTRB(
        10,
        8,
        AttachmentPrimitive.embeddedInset - 1,
        8,
      ) +
      EdgeInsets.all(file.border().width);

  /// `font-mono text-[10px] leading-none font-bold text-foreground-muted`.
  TextStyle badgeLabel(String extension) => RaftTypography.mono(
    tokens,
    size: 10,
    line: 10,
    color: semantics.badgeForeground(extension),
  ).copyWith(fontWeight: FontWeight.w700);
  BorderRadius get badgeRadius => BorderRadius.circular(4);
  Border? get badgeBorder => null;

  /// The `ring-1 ring-line-hairline` (outside the box, like a CSS ring).
  List<BoxShadow>? get badgeShadows => [
    BoxShadow(color: tokens.colors['line-hairline']!, spreadRadius: 1),
  ];

  /// The card's corner: `rounded-container`.
  BorderRadius get cardRadius =>
      tokens.corner('radius.container', fallback: 10);

  /// The hairline stays on hover and focus (the fill and the focus ring carry
  /// those states).
  BorderSide cardBorder() => file.border();

  /// `text-callout font-semibold` (14/20, 14/22 on desktop).
  TextStyle get cardTitle => tokens.scale(
    tokens.typeSlot('callout'),
    weight: FontWeight.w600,
    color: tokens.ui.foreground,
  );

  /// Meta and summary lines: `font-mono text-mono-meta text-foreground-hint`.
  TextStyle get metadata => tokens.scale(
    tokens.typeSlot('mono-meta'),
    mono: true,
    color: tokens.ui.foregroundHint,
  );
  Color get actionForeground => tokens.colors['foreground-icon']!;
  Size imageSize({
    required double viewportWidth,
    required double availableWidth,
    double? width,
    double? height,
  }) {
    final maxWidth = math.min(
      availableWidth,
      viewportWidth >= 768
          ? AttachmentPrimitive.desktopGalleryMaxWidth
          : math.min(
              AttachmentPrimitive.mobileGalleryMaxWidth,
              math.max(
                1.0,
                viewportWidth - AttachmentPrimitive.mobileGalleryReserve,
              ),
            ),
    );
    if (width == null ||
        height == null ||
        width <= 0 ||
        height <= 0 ||
        !width.isFinite ||
        !height.isFinite) {
      final reserved = math.min(file.size.width, maxWidth).toDouble();
      return Size(reserved, reserved * 3 / 4);
    }
    final scale = math.min(
      1.0,
      math.min(
        AttachmentPrimitive.singleImageMaxWidth / width,
        AttachmentPrimitive.singleImageMaxHeight / height,
      ),
    );
    final reserved = math
        .min((width * scale).roundToDouble(), maxWidth)
        .toDouble();
    return Size(reserved, reserved * height / width);
  }
}
