import 'package:flutter/material.dart';

import 'components.dart';
import 'localization.dart';
import 'theme.dart';

/// Selection replaces the composer on one conversation surface.
class RaftSelectionToolbar extends StatelessWidget {
  const RaftSelectionToolbar({
    super.key,
    required this.selected,
    required this.total,
    required this.onExit,
    this.onSelectAll,
    this.onCopyMarkdown,
    this.onPreview,
    this.onForward,
    this.busy = false,
    this.error,
    this.limit = 30,
  });
  final int selected, total, limit;
  final VoidCallback onExit;
  final VoidCallback? onSelectAll, onCopyMarkdown, onPreview, onForward;
  final bool busy;
  final String? error;
  @override
  Widget build(BuildContext context) => Material(
    color: RaftTokens.of(context).panel,
    child: Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: raftText(context, 'Exit selection'),
                onPressed: busy ? null : onExit,
                icon: const Icon(Icons.close),
              ),
              Expanded(
                child: Text(
                  raftFormat(context, '{count} selected', {'count': selected}),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                tooltip: raftText(context, 'Select all loaded messages'),
                onPressed: busy || total > limit ? null : onSelectAll,
                icon: const Icon(Icons.select_all),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              RaftButton(
                label: 'Copy Markdown',
                icon: Icons.copy,
                secondary: true,
                onPressed: busy || selected == 0 ? null : onCopyMarkdown,
              ),
              if (onForward != null)
                RaftButton(
                  label: 'Forward',
                  icon: Icons.forward,
                  secondary: true,
                  onPressed: busy || selected == 0 ? null : onForward,
                ),
              RaftButton(
                label: 'Preview image',
                icon: Icons.image_outlined,
                busy: busy,
                onPressed: selected == 0 ? null : onPreview,
              ),
            ],
          ),
          if (total > limit)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                raftFormat(context, 'Select up to {count} messages.', {
                  'count': limit,
                }),
              ),
            ),
          if (error != null)
            Semantics(
              liveRegion: true,
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  error!,
                  style: TextStyle(
                    color: RaftTokens.of(context).colors['danger-strong'],
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

/// A full-content clone uses the conversation's current theme and layout width.
/// API state, platform export and rasterization belong to the application.
class RaftMessageExportSurface extends StatelessWidget {
  const RaftMessageExportSurface({
    super.key,
    required this.width,
    required this.messages,
  });
  final double width;
  final List<Widget> messages;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Material(
      color: RaftTokens.of(context).canvas,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: messages,
      ),
    ),
  );
}

/// Actions become available only after the complete image exists for review.
class RaftImageReview extends StatelessWidget {
  const RaftImageReview({
    super.key,
    required this.preview,
    required this.onClose,
    this.onSave,
    this.onShare,
    this.busy = false,
    this.error,
  });
  final Widget preview;
  final VoidCallback onClose;
  final VoidCallback? onSave, onShare;
  final bool busy;
  final String? error;
  @override
  Widget build(BuildContext context) => Material(color: RaftTokens.of(context).panel, child: Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                raftText(context, 'Share selected messages'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            IconButton(
              tooltip: raftText(context, 'Close preview'),
              onPressed: busy ? null : onClose,
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      ),
      const Divider(height: 1),
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: preview,
        ),
      ),
      if (error != null)
        Semantics(
          liveRegion: true,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(error!),
          ),
        ),
      const Divider(height: 1),
      Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            RaftButton(
              label: 'Cancel',
              secondary: true,
              onPressed: busy ? null : onClose,
            ),
            if (onSave != null)
              RaftButton(
                label: 'Save image',
                icon: Icons.download_outlined,
                busy: busy,
                onPressed: onSave,
              ),
            if (onShare != null)
              RaftButton(
                label: 'Share image',
                icon: Icons.share_outlined,
                secondary: true,
                onPressed: busy ? null : onShare,
              ),
          ],
        ),
      ),
    ],
  ));
}
