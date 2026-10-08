import 'package:flutter/material.dart';

import 'previews.dart';
import 'raft_ui.dart';

@RaftPreviews('Attachment')
Widget attachmentPreview() => const _AttachmentPreview();

class _AttachmentPreview extends StatefulWidget {
  const _AttachmentPreview();
  @override
  State<_AttachmentPreview> createState() => _AttachmentPreviewState();
}

class _AttachmentPreviewState extends State<_AttachmentPreview> {
  String result = 'Ready';
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RaftAttachmentCard(
            filename: '日本語・设计.png',
            mimeType: 'image/png',
            sizeBytes: 143360,
            preview: const SizedBox(
              height: 100,
              child: Center(child: Icon(Icons.image_outlined, size: 64)),
            ),
            onOpen: () => setState(() => result = 'Preview opened'),
            onDownload: () => setState(() => result = 'Download requested'),
            onShare: () => setState(() => result = 'Share sheet requested'),
          ),
          const SizedBox(height: 12),
          RaftAttachmentCard(
            filename: 'report.pdf',
            mimeType: 'application/pdf',
            sizeBytes: 5242880,
            error: 'Preview failed',
            onOpen: () => setState(() => result = 'Document opened'),
            onRetry: () => setState(() => result = 'Preview retried'),
          ),
          const SizedBox(height: 12),
          const RaftAttachmentCard(
            filename: 'reviewed-export.png',
            mimeType: 'image/png',
            sizeBytes: 2048,
            exportMode: true,
            preview: SizedBox(
              height: 100,
              child: Center(child: Icon(Icons.image_outlined, size: 64)),
            ),
            onOpen: null,
          ),
          Semantics(
            liveRegion: true,
            child: Text(result, key: const Key('preview-result')),
          ),
        ],
      ),
    ),
  );
}
