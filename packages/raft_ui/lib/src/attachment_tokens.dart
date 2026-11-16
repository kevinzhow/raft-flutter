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
  static const galleryGap = 8.0;

  /// `--control-embedded-inset`: the Raft card's right padding is this minus
  /// the 1px border (`pr-[calc(var(--control-embedded-inset)-1px)]`).
  static const embeddedInset = 6.0;

  /// Raft `message-image-gallery`: `gap-1`, root `max-w-[min(360px,100%)]`,
  /// and the `@min-[360px]` container step.
  static const raftGalleryGap = 4.0, raftGalleryMaxWidth = 360.0;
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

  /// raft-ui 0.95.3 FilePreviewBadge is neutral: one `fill-muted` chip for
  /// every known extension; the frozen looks keep the per-kind colours.
  bool get neutral => tokens.isRaftLook;
  Color? badgeBackground(String extension) {
    final role = kind(extension);
    if (role == null) return null;
    if (neutral) return tokens.colors['fill-muted'];
    if (role == 'neutral') {
      return tokens.dark ? tokens.colors['fill-strong']! : tokens.ink;
    }
    return (tokens.dark
        ? AttachmentPrimitive.dark
        : AttachmentPrimitive.light)[role];
  }

  Color badgeForeground(String extension) {
    final role = kind(extension);
    if (neutral) return tokens.colors['foreground-muted']!;
    if (role == 'neutral') {
      return tokens.dark ? tokens.strong : tokens.colors['foreground-inverse']!;
    }
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
  bool get _raft => tokens.isRaftLook;

  /// Raft: `py-2 pl-2.5 pr-[embedded-inset - 1px]` inside the 1px border.
  EdgeInsets get contentInset =>
      (_raft
          ? const EdgeInsets.fromLTRB(
              10,
              8,
              AttachmentPrimitive.embeddedInset - 1,
              8,
            )
          : AttachmentPrimitive.bodyInset) +
      EdgeInsets.all(file.border().width);
  TextStyle badgeLabel(String extension) => _raft
      // `font-mono text-[10px] leading-none font-bold text-foreground-muted`.
      ? RaftTypography.mono(
          tokens,
          size: 10,
          line: 10,
          color: semantics.badgeForeground(extension),
        ).copyWith(fontWeight: FontWeight.w700)
      : RaftTypography.mono(
          tokens,
          size: 9,
          line: 9,
          color: semantics.badgeForeground(extension),
        ).copyWith(fontWeight: FontWeight.w600);
  BorderRadius get badgeRadius => BorderRadius.circular(4);
  Border? get badgeBorder => null;

  /// FilePreviewBadge brutal `shadow-raft-sm`; elegant has none. Raft: the
  /// `ring-1 ring-line-hairline` (outside the box, like a CSS ring).
  List<BoxShadow>? get badgeShadows => _raft
      ? [BoxShadow(color: tokens.colors['line-hairline']!, spreadRadius: 1)]
      : null;

  /// The card's corner: `rounded-container` in the Raft look.
  BorderRadius get cardRadius =>
      _raft ? tokens.corner('radius.container', fallback: 10) : file.radius;

  /// Raft: the hairline stays on hover and focus (the fill and the focus ring
  /// carry those states); the frozen looks darken the border.
  BorderSide cardBorder({bool hovered = false, bool focused = false}) =>
      _raft ? file.border() : file.border(hovered: hovered, focused: focused);

  /// `text-callout font-semibold` (14/20, 14/22 on desktop); frozen: 12/16 bold.
  TextStyle get cardTitle => _raft
      ? tokens.scale(
          tokens.typeSlot('callout'),
          weight: FontWeight.w600,
          color: tokens.ui.foreground,
        )
      : file.title.copyWith(fontWeight: FontWeight.w700);

  /// Meta and summary lines: `font-mono text-mono-meta text-foreground-hint`.
  TextStyle get metadata => _raft
      ? tokens.scale(
          tokens.typeSlot('mono-meta'),
          mono: true,
          color: tokens.ui.foregroundHint,
        )
      : RaftTypography.body(
          tokens,
          size: 10,
          line: 20,
          color: tokens.colors['foreground-placeholder'],
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
