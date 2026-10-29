import 'package:flutter/material.dart';

import 'attachment_lightbox.dart' show RaftFileTypeBadge;
import 'design_primitives.dart';
import 'dialog_card.dart';
import 'icons.dart';
import 'recipes/button_variants.g.dart';
import 'localization.dart';
import 'theme.dart';

/// A file the app could not show in its own preview: the file head, the
/// specific reason, and what still gets the user to the content. [onOpen]
/// hands the file to the system's default app, [onDownload] saves it, and
/// [onRetry] tries again after a failed transfer. A null action is not shown;
/// while [busy] the actions wait.
class RaftPreviewUnavailable extends StatelessWidget {
  const RaftPreviewUnavailable({
    super.key,
    required this.filename,
    required this.meta,
    required this.reason,
    this.onOpen,
    this.onDownload,
    this.onRetry,
    this.busy = false,
  });
  final String filename, meta, reason;
  final VoidCallback? onOpen, onDownload, onRetry;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 88,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: t.card,
                  border: Border.all(color: t.colors['line-muted']!, width: 1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: RaftFileTypeBadge(
                  filename: filename,
                  size: const Size(40, 20),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                filename,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: RaftTypography.body(
                  t,
                  size: 15,
                  line: 20,
                  weight: FontWeight.w700,
                  color: t.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                meta,
                style: RaftTypography.body(
                  t,
                  size: 12,
                  line: 16,
                  color: t.muted,
                ),
              ),
              const SizedBox(height: 16),
              Semantics(
                liveRegion: true,
                child: Text(
                  raftText(context, reason),
                  key: const ValueKey('preview-unavailable-reason'),
                  textAlign: TextAlign.center,
                  style: RaftTypography.body(
                    t,
                    size: 14,
                    line: 20,
                    color: t.muted,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (onOpen != null)
                    RaftRecipeButton(
                      key: const ValueKey('preview-open-system'),
                      label: raftText(context, 'Open with System App'),
                      glyph: RaftGlyph.externalLink,
                      glyphSize: 12,
                      size: RaftButtonRecipeSize.sm,
                      onPressed: busy ? null : onOpen,
                    ),
                  if (onRetry != null)
                    RaftRecipeButton(
                      key: const ValueKey('preview-retry'),
                      label: raftText(context, 'Retry'),
                      glyph: RaftGlyph.refreshCw,
                      glyphSize: 12,
                      variant: RaftButtonRecipeVariant.outline,
                      size: RaftButtonRecipeSize.sm,
                      onPressed: busy ? null : onRetry,
                    ),
                  if (onDownload != null)
                    RaftRecipeButton(
                      key: const ValueKey('preview-download'),
                      label: raftText(context, 'Download'),
                      glyph: RaftGlyph.download,
                      glyphSize: 12,
                      variant: RaftButtonRecipeVariant.outline,
                      size: RaftButtonRecipeSize.sm,
                      onPressed: busy ? null : onDownload,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A line above a preview that shows only part of the file: says so, and
/// offers the way to the rest.
class RaftPreviewNotice extends StatelessWidget {
  const RaftPreviewNotice({
    super.key,
    required this.message,
    this.onOpen,
    this.onDownload,
  });
  final String message;
  final VoidCallback? onOpen, onDownload;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return Container(
      key: const ValueKey('preview-notice'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: t.panel,
        border: Border(bottom: BorderSide(color: t.colors['line-muted']!)),
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        children: [
          Semantics(
            liveRegion: true,
            child: Text(
              message,
              style: RaftTypography.body(t, size: 12, line: 16, color: t.muted),
            ),
          ),
          if (onOpen != null)
            RaftTextButton(
              key: const ValueKey('preview-open-system'),
              label: raftText(context, 'Open Full File'),
              glyph: RaftGlyph.externalLink,
              visualHeight: 28,
              onPressed: onOpen,
            ),
          if (onDownload != null)
            RaftTextButton(
              key: const ValueKey('preview-download'),
              label: raftText(context, 'Download'),
              glyph: RaftGlyph.download,
              visualHeight: 28,
              onPressed: onDownload,
            ),
        ],
      ),
    );
  }
}
