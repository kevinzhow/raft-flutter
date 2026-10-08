import 'package:flutter/material.dart';

import 'theme.dart';
import 'icons.dart';
import 'design_primitives.dart';
import 'attachment_tokens.dart';
import 'localization.dart';

class RaftAttachmentCard extends StatelessWidget {
  const RaftAttachmentCard({
    super.key,
    required this.filename,
    required this.onOpen,
    this.onDownload,
    this.onShare,
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
  });
  final String filename, mimeType;
  final int? sizeBytes;
  final double? imageWidth, imageHeight;
  final Size? imageExtent;
  final Widget? preview;
  final VoidCallback? onOpen, onDownload, onRetry, onShare, onCancel;
  final bool busy, exportMode;
  final String? error;

  static String formatSize(int value) {
    if (value < 1024) return '$value B';
    if (value < 1024 * 1024) return '${(value / 1024).toStringAsFixed(1)} KB';
    return '${(value / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final recipe = RaftAttachmentRecipe(t);
    final component = AttachmentComponentRecipe(t);
    final imageCard = mimeType.toLowerCase().split(';').first.trim().startsWith('image/') && mimeType.toLowerCase().split(';').first.trim() != 'image/svg+xml';
    final extension = filename.split('.').last.toUpperCase();
    final badge = component.semantics.badgeBackground(extension);
    Widget title() => Row(
      children: [
        if (badge != null) ...[
          Container(
            width: AttachmentPrimitive.badgeSize.width,
            height: AttachmentPrimitive.badgeSize.height,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: badge,
              border: component.badgeBorder,
              borderRadius: component.badgeRadius,
            ),
            child: Text(
              extension,
              maxLines: 1,
              style: component.badgeLabel(extension),
            ),
          ),
          const SizedBox(width: AttachmentPrimitive.badgeGap),
        ],
        Expanded(
          child: Text(
            filename,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: recipe.title.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
    final content = SizedBox(
      width: recipe.size.width,
      height: recipe.size.height,
      child: Padding(
        padding: component.contentInset,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            title(),
            Row(
              children: [
                Expanded(
                  child: Text(
                    sizeBytes == null ? '' : formatSize(sizeBytes!),
                    style: component.metadata,
                    maxLines: 1,
                  ),
                ),
                if (onDownload == null && onShare == null)
                  RaftIcon(RaftGlyph.eye, size: 12, color: component.actionForeground),
              ],
            ),
          ],
        ),
      ),
    );
    if (imageCard)
      return LayoutBuilder(
        builder: (context, constraints) {
          final size = imageExtent ?? component.imageSize(
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
            child: Tooltip(
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
                        onTap: exportMode ? null : onOpen,
                        child:
                            preview ??
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
                    if (!exportMode)
                      Positioned(
                        right: 4,
                        bottom: 4,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (onShare != null)
                              RaftIconButton(
                                glyph: RaftGlyph.share2,
                                tooltip:
                                    '${raftText(context, 'Share')} $filename',
                                onPressed: busy ? null : onShare,
                                visualSize: 24,
                                minimumTargetSize: 48,
                                glyphSize: 12,
                              ),
                            if (onDownload != null)
                              RaftIconButton(
                                glyph: RaftGlyph.download,
                                tooltip:
                                    '${raftText(context, 'Download')} $filename',
                                onPressed: busy ? null : onDownload,
                                visualSize: 24,
                                minimumTargetSize: 48,
                                glyphSize: 12,
                              ),
                          ],
                        ),
                      ),
                    if (error != null && !exportMode && onRetry != null)
                      Align(
                        alignment: Alignment.bottomLeft,
                        child: RaftTextButton(
                          label: 'Retry preview',
                          onPressed: onRetry,
                          variant: RaftControlVariant.ghost,
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
      width: recipe.size.width,
      child: _AttachmentSurface(
        recipe: recipe,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
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
                if (!exportMode)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (onShare != null)
                          RaftIconButton(
                            glyph: RaftGlyph.share2,
                            tooltip: '${raftText(context, 'Share')} $filename',
                            onPressed: busy ? null : onShare,
                            visualSize: 24,
                            minimumTargetSize: 48,
                            glyphSize: 12,
                          ),
                        if (onDownload != null)
                          RaftIconButton(
                            glyph: RaftGlyph.download,
                            tooltip:
                                '${raftText(context, 'Download')} $filename',
                            onPressed: busy ? null : onDownload,
                            visualSize: 24,
                            minimumTargetSize: 48,
                            glyphSize: 12,
                          ),
                      ],
                    ),
                  ),
              ],
            ),
            if (busy && !exportMode) const LinearProgressIndicator(),
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

/// One shared surface state controls the source file border. Descendant open,
/// download, share and retry controls retain their independent focus/actions.
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
  Widget build(BuildContext context) => MouseRegion(
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
