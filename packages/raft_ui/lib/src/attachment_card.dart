import 'package:flutter/material.dart';

import 'theme.dart';
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
    this.sizeBytes,
    this.mimeType = '',
    this.busy = false,
    this.exportMode = false,
    this.error,
    this.onRetry,
  });
  final String filename, mimeType;
  final int? sizeBytes;
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
    final tokens = RaftTokens.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: Material(
        color: tokens.sidebar,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: tokens.line, width: tokens.border),
          borderRadius: BorderRadius.circular(tokens.radius),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (preview != null)
              Semantics(
                label: '${raftText(context, 'Preview')} $filename',
                button: !exportMode,
                child: InkWell(
                  onTap: exportMode ? null : onOpen,
                  child: SizedBox(
                    height: 180,
                    width: double.infinity,
                    child: preview,
                  ),
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: exportMode
                      ? Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Icon(
                                mimeType.startsWith('image/')
                                    ? Icons.image_outlined
                                    : Icons.description_outlined,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      filename,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (sizeBytes != null)
                                      Text(
                                        formatSize(sizeBytes!),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: tokens.muted,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )
                      : TextButton.icon(
                          style: TextButton.styleFrom(
                            minimumSize: const Size(48, 48),
                          ),
                          onPressed: onOpen,
                          icon: Icon(
                            mimeType.startsWith('image/')
                                ? Icons.image_outlined
                                : Icons.description_outlined,
                          ),
                          label: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                filename,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (sizeBytes != null)
                                Text(
                                  formatSize(sizeBytes!),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: tokens.muted,
                                  ),
                                ),
                            ],
                          ),
                        ),
                ),
                if (!exportMode && onShare != null)
                  IconButton(
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    tooltip: '${raftText(context, 'Share')} $filename',
                    onPressed: busy ? null : onShare,
                    icon: const Icon(Icons.share_outlined),
                  ),
                if (!exportMode && onDownload != null)
                  IconButton(
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    tooltip: '${raftText(context, 'Download')} $filename',
                    onPressed: busy ? null : onDownload,
                    icon: const Icon(Icons.download_outlined),
                  ),
              ],
            ),
            if (busy && !exportMode) const LinearProgressIndicator(),
            if (!exportMode && busy && onCancel != null)
              TextButton(
                onPressed: onCancel,
                child: Text(raftText(context, 'Cancel')),
              ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  children: [
                    Text(error!),
                    if (!exportMode && onRetry != null)
                      TextButton(
                        onPressed: onRetry,
                        child: Text(raftText(context, 'Retry preview')),
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
