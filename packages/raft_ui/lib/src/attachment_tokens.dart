import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';
import 'tokens/tokens.dart';
import 'design_primitives.dart';

/// raft-ui 0.5.27 FilePreviewBadge and message-image-gallery primitives.
/// OKLCH roles are resolved by the actual Chromium renderer and retained in
/// attachment-badge-colors.json; dimensions come from the pinned recipe.
abstract final class AttachmentPrimitive {
  static const badgeSize = Size(28, 14);
  static const badgeGap = 6.0;
  static const galleryGap = 8.0;
  static const wideAspect = 2.2, tallAspect = .55;
  static const compactRowHeight = 128.0, regularRowHeight = 144.0;
  static const compactThreeRowHeight = 112.0, regularThreeRowHeight = 128.0;
  static const rowBreakpoint = 640.0, columnsBreakpoint = 768.0;
  static const bodyInset = EdgeInsets.symmetric(horizontal: 10, vertical: 8);
  static const singleImageMaxWidth = 416.0, singleImageMaxHeight = 288.0;
  static const mobileGalleryMaxWidth = 352.0, desktopGalleryMaxWidth = 448.0;
  static const mobileGalleryReserve = 112.0;

  /// One short fade for an image preview that arrives from the network;
  /// cached previews appear without it.
  static const previewFade = Duration(milliseconds: 120);
  static const light = <String, Color>{
    'rose': Color(0xffed3e51),
    'blue': Color(0xff0077cd),
    'amber': Color(0xff935b00),
    'emerald': Color(0xff008651),
    'violet': Color(0xff784db6),
  };
  static const dark = <String, Color>{
    'rose': Color(0xff89202b),
    'blue': Color(0xff004985),
    'amber': Color(0xff6c4300),
    'emerald': Color(0xff005932),
    'violet': Color(0xff543282),
  };
  static const darkText = <String, Color>{
    'rose': Color(0xfffdc8c9),
    'blue': Color(0xffb7d8fb),
    'amber': Color(0xfff7d69e),
    'emerald': Color(0xff9ce4bd),
    'violet': Color(0xffdaccf7),
  };
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
  Color? badgeBackground(String extension) {
    final role = kind(extension);
    if (role == null) return null;
    if (role == 'neutral')
      return tokens.dark ? tokens.colors['fill-strong']! : tokens.ink;
    return (tokens.dark
        ? AttachmentPrimitive.dark
        : AttachmentPrimitive.light)[role];
  }

  Color badgeForeground(String extension) {
    final role = kind(extension);
    if (role == 'neutral')
      return tokens.dark ? tokens.strong : tokens.colors['foreground-inverse']!;
    return tokens.dark ? AttachmentPrimitive.darkText[role]! : Colors.white;
  }
}

/// Component recipe separates the image gallery from the file metadata chip.
class AttachmentComponentRecipe {
  AttachmentComponentRecipe(this.tokens)
    : file = RaftAttachmentRecipe(tokens),
      semantics = AttachmentSemantic(tokens);
  final RaftTokens tokens;
  final RaftAttachmentRecipe file;
  final AttachmentSemantic semantics;
  EdgeInsets get contentInset =>
      AttachmentPrimitive.bodyInset + EdgeInsets.all(file.border().width);
  TextStyle badgeLabel(String extension) => RaftTypography.mono(
    tokens,
    size: 9,
    line: 9,
    color: semantics.badgeForeground(extension),
  ).copyWith(fontWeight: tokens.brutal ? FontWeight.w700 : FontWeight.w600);
  BorderRadius get badgeRadius => BorderRadius.circular(tokens.brutal ? 0 : 4);
  Border? get badgeBorder => tokens.brutal
      ? Border.all(color: RaftPrimitiveColors.black, width: 2)
      : null;
  TextStyle get metadata => RaftTypography.body(
    tokens,
    size: 10,
    line: 20,
    color: tokens.brutal
        ? RaftPrimitiveColors.black.withValues(alpha: .45)
        : tokens.colors['foreground-placeholder'],
  );
  Color get actionForeground => tokens.brutal
      ? RaftPrimitiveColors.black.withValues(alpha: .6)
      : tokens.colors['foreground-icon']!;
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
