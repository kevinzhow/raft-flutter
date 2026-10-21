import 'hover_region.dart';

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';
import 'icons.dart';
import 'design_primitives.dart';
import 'attachment_lightbox.dart' show RaftFileTypeBadge;
import 'attachment_tokens.dart';
import 'attachment_transfer.dart';
import 'localization.dart';
import 'text_scaling.dart';
import 'tooltip.dart';

class RaftAttachmentCard extends StatelessWidget {
  const RaftAttachmentCard({
    super.key,
    required this.filename,
    required this.onOpen,
    this.onCancel,
    this.preview,
    this.imageWidth,
    this.imageHeight,
    this.imageExtent,
    this.sizeBytes,
    this.mimeType = '',
    this.busy = false,
    this.exportMode = false,
    this.error,
    this.onRetry,
    this.summary,
    this.metaLabel,
    this.previewAffordance = false,
    this.previewPending = false,
    this.downloadFailed = false,
  });
  final String filename, mimeType;

  /// Web AttachmentChip summary line (e.g. "Document preview").
  final String? summary;

  /// Web `AttachmentMetaText` label (mime type, "HTML preview", …); when set,
  /// the meta row reads `label · size` and ends with the decorative
  /// affordance glyph (Eye for previews, Download otherwise) instead of the
  /// download button.
  final String? metaLabel;
  final bool previewAffordance;

  /// Image cards only: the preview is still being fetched/decoded. The
  /// reserved box stays a neutral placeholder surface (Web's tinted image box):
  /// no spinner, no filename flash and no transfer text such as "Connecting…"
  /// (progress belongs to explicit downloads and previews, not list tiles).
  final bool previewPending;

  /// File cards: the last explicit download failed; tapping the card retries.
  final bool downloadFailed;
  final int? sizeBytes;
  final double? imageWidth, imageHeight;
  final Size? imageExtent;
  final Widget? preview;
  final VoidCallback? onOpen, onRetry, onCancel;
  final bool busy, exportMode;
  final String? error;

  static String formatSize(int value) {
    if (value < 1024) return '$value B';
    if (value < 1024 * 1024) return '${(value / 1024).toStringAsFixed(1)} KB';
    return '${(value / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// `text-[10px]` summary / meta lines: Brutal resolves the utility's 1.4286
  /// line height (14.29px); Elegant inherits the message content's
  /// `leading-5.25` (21px).
  static double metaLineHeight(RaftTokens t) => t.brutal ? 20 / 14 : 21 / 10;

  @override
  Widget build(BuildContext context) {
    if (!RaftScaled.grows(context)) return _card(context, double.infinity);
    return LayoutBuilder(
      builder: (context, constraints) => _card(
        context,
        constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width,
      ),
    );
  }

  Widget _card(BuildContext context, double availableWidth) {
    final t = RaftTokens.of(context);
    final recipe = RaftAttachmentRecipe(t);
    final component = AttachmentComponentRecipe(t);
    final imageCard =
        mimeType.toLowerCase().split(';').first.trim().startsWith('image/') &&
        mimeType.toLowerCase().split(';').first.trim() != 'image/svg+xml';
    final extension = filename.split('.').last.toUpperCase();
    final failedColor = RaftTransferRecipe(t).dangerText;
    final badge = component.semantics.badgeBackground(extension);
    final grows = RaftScaled.grows(context);
    Widget title() => Row(
      children: [
        if (badge != null) ...[
          RaftFileTypeBadge(
            filename: filename,
            size: AttachmentPrimitive.badgeSize,
          ),
          const SizedBox(width: AttachmentPrimitive.badgeGap),
        ],
        Expanded(
          // TruncatedAttachmentTooltip: the full name only when it is cut.
          child: RaftTooltip(
            message: filename,
            onlyWhenTruncated: true,
            excludeFromSemantics: true,
            child: Text(
              filename,
              // Above the default text size the name wraps instead of
              // being cut.
              maxLines: grows ? null : 1,
              overflow: grows ? TextOverflow.clip : TextOverflow.ellipsis,
              style: recipe.title.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
    // The 176x80 chip is a minimum above the default text size: its height
    // follows the text and its width grows with it (capped to the space the
    // card is given).
    final cardWidth = grows
        ? math.min(
            RaftScaled.extent(context, recipe.size.width, fontSize: 12),
            math.max(recipe.size.width, availableWidth),
          )
        : recipe.size.width;
    Widget sized({required Widget child}) => grows
        ? ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: cardWidth,
              maxWidth: cardWidth,
              minHeight: recipe.size.height,
            ),
            child: child,
          )
        : SizedBox(
            width: recipe.size.width,
            height: recipe.size.height,
            child: child,
          );
    final content = sized(
      child: Padding(
        padding: component.contentInset,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            title(),
            if (metaLabel != null && summary != null)
              // `mt-0.5 text-[10px] font-medium`, brutal `text-black/70`.
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: RaftTooltip(
                  message: summary!,
                  onlyWhenTruncated: true,
                  excludeFromSemantics: true,
                  child: Text(
                    summary!,
                    maxLines: grows ? null : 1,
                    overflow: grows ? TextOverflow.clip : TextOverflow.ellipsis,
                    style: component.metadata.copyWith(
                      height: metaLineHeight(t),
                      fontWeight: FontWeight.w500,
                      color: t.brutal
                          ? Colors.black.withValues(alpha: .7)
                          : t.colors['foreground-muted'],
                    ),
                  ),
                ),
              ),
            // The Spacer needs a bounded height; the grown chip has only a
            // minimum, so it keeps a small gap instead.
            if (metaLabel != null)
              if (grows) const SizedBox(height: 4) else const Spacer(),
            if (metaLabel != null)
              _WebMeta(
                label: downloadFailed
                    ? raftText(context, 'Download failed · tap to retry')
                    : metaLabel!,
                size: sizeBytes == null || sizeBytes! <= 0
                    ? null
                    : formatSize(sizeBytes!),
                style: component.metadata.copyWith(
                  height: metaLineHeight(t),
                  color: downloadFailed ? failedColor : null,
                ),
                separator: t.brutal
                    ? Colors.black.withValues(alpha: .35)
                    : t.colors['foreground-placeholder']!,
                glyph: previewAffordance ? RaftGlyph.eye : RaftGlyph.download,
                glyphColor: component.actionForeground,
                wrap: grows,
              )
            else
              Row(
                children: [
                  Expanded(
                    child: Text(
                      downloadFailed
                          ? '${sizeBytes == null ? '' : '${formatSize(sizeBytes!)} · '}${raftText(context, 'Download failed')}'
                          : (sizeBytes == null ? '' : formatSize(sizeBytes!)),
                      style: downloadFailed
                          ? component.metadata.copyWith(color: failedColor)
                          : component.metadata,
                      maxLines: 1,
                    ),
                  ),
                  RaftIcon(
                    RaftGlyph.eye,
                    size: 12,
                    color: component.actionForeground,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
    if (imageCard)
      return LayoutBuilder(
        builder: (context, constraints) {
          final size =
              imageExtent ??
              component.imageSize(
                viewportWidth: MediaQuery.sizeOf(context).width,
                availableWidth: constraints.maxWidth.isFinite
                    ? constraints.maxWidth
                    : MediaQuery.sizeOf(context).width,
                width: imageWidth,
                height: imageHeight,
              );
          return SizedBox(
            width: size.width,
            height: size.height,
            // RaftTooltip: rows scrolled under a resting pointer stay quiet.
            child: RaftTooltip(
              message: '${raftText(context, 'Preview')} $filename',
              child: Material(
                color: t.panel,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  side: BorderSide(
                    color: t.strong,
                    width: t.brutal ? t.border : 0,
                  ),
                  borderRadius: recipe.radius,
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Semantics(
                      label: '${raftText(context, 'Preview')} $filename',
                      button: !exportMode,
                      child: InkWell(
                        hoverColor: RaftHoverScope.materialHoverColor(context),
                        onTap: exportMode ? null : onOpen,
                        child:
                            preview ??
                            (previewPending && error == null ||
                                    error != null && onRetry != null
                                ? const RaftTransferPlaceholder()
                                : null) ??
                            Center(
                              child: busy
                                  ? const CircularProgressIndicator(
                                      strokeWidth: 2,
                                    )
                                  : Text(
                                      error ?? filename,
                                      style: recipe.title,
                                    ),
                            ),
                      ),
                    ),
                    if (!exportMode &&
                        preview == null &&
                        error != null &&
                        onRetry != null)
                      // Option A: tap the failed chip's band to retry;
                      // the rest of the tile still opens the viewer,
                      // which fetches the original itself.
                      Positioned.fill(
                        child: RaftImageTransferOverlay.failed(
                          onRetry: onRetry,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    return SizedBox(
      width: cardWidth,
      child: _AttachmentSurface(
        recipe: recipe,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (exportMode)
              content
            else
              TextButton(
                onPressed: busy ? null : onOpen,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  foregroundColor: t.strong,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: const RoundedRectangleBorder(),
                ),
                child: content,
              ),
            if (busy && !exportMode) const LinearProgressIndicator(),
            if (downloadFailed && !busy && !exportMode)
              const RaftTransferBar(failed: true),
            if (!exportMode && busy && onCancel != null)
              RaftTextButton(
                label: 'Cancel',
                onPressed: onCancel,
                variant: RaftControlVariant.ghost,
              ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  children: [
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        error!,
                        style: RaftTypography.body(t, size: 12, line: 16),
                      ),
                    ),
                    if (!exportMode && onRetry != null)
                      RaftTextButton(
                        label: 'Retry preview',
                        onPressed: onRetry,
                        variant: RaftControlVariant.ghost,
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// One shared surface state controls the source file border. The card itself
/// is the only action (open); Download lives in the viewer it opens.
class _AttachmentSurface extends StatefulWidget {
  const _AttachmentSurface({required this.recipe, required this.child});
  final RaftAttachmentRecipe recipe;
  final Widget child;
  @override
  State<_AttachmentSurface> createState() => _AttachmentSurfaceState();
}

class _AttachmentSurfaceState extends State<_AttachmentSurface> {
  bool hovered = false, focused = false;
  @override
  Widget build(BuildContext context) => RaftHoverRegion(
    onEnter: (_) => setState(() => hovered = true),
    onExit: (_) => setState(() => hovered = false),
    child: Focus(
      onFocusChange: (value) => setState(() => focused = value),
      child: Material(
        color: widget.recipe.background,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          side: widget.recipe.border(hovered: hovered, focused: focused),
          borderRadius: widget.recipe.radius,
        ),
        child: widget.child,
      ),
    ),
  );
}

/// `mt-auto flex items-center justify-between gap-1.5 text-[10px]`:
/// `label · size` (separator `text-black/35`) and the `size-3` decorative
/// affordance holding a 10px glyph.
class _WebMeta extends StatelessWidget {
  const _WebMeta({
    required this.label,
    required this.size,
    required this.style,
    required this.separator,
    required this.glyph,
    required this.glyphColor,
    this.wrap = false,
  });

  /// Above the default text size the label wraps instead of being cut.
  final bool wrap;
  final String label;
  final String? size;
  final TextStyle style;
  final Color separator, glyphColor;
  final RaftGlyph glyph;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      // The label is `flex-1 truncate`: it takes the free width, so the
      // separator and size sit just before the affordance.
      Expanded(
        child: Text(
          label,
          maxLines: wrap ? null : 1,
          overflow: wrap ? TextOverflow.clip : TextOverflow.ellipsis,
          style: style,
        ),
      ),
      if (size != null) ...[
        const SizedBox(width: 6),
        Text('·', style: style.copyWith(color: separator)),
        const SizedBox(width: 6),
        Text(size!, maxLines: 1, style: style),
      ],
      const SizedBox(width: 6),
      SizedBox.square(
        dimension: 12,
        child: Center(child: RaftIcon(glyph, size: 10, color: glyphColor)),
      ),
    ],
  );
}
