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
          // Cold image preview: the reserved box is final and stays neutral.
          RaftAttachmentCard(
            filename: 'loading-photo.jpg',
            mimeType: 'image/jpeg',
            imageWidth: 4000,
            imageHeight: 3000,
            previewPending: true,
            onOpen: () => setState(() => result = 'Image preview opened'),
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

@RaftPreviews('Attachment transfer')
Widget attachmentTransferPreview() => const _AttachmentTransferPreview();

/// Pending, failed and file-preview states of an attachment. A list image
/// tile that is still loading shows only the neutral placeholder (Web's tinted
/// image box); the thin bottom bar with the `1.2 / 3.4 MB` chip belongs to
/// explicit file previews and downloads.
class _AttachmentTransferPreview extends StatefulWidget {
  const _AttachmentTransferPreview();
  @override
  State<_AttachmentTransferPreview> createState() =>
      _AttachmentTransferPreviewState();
}

class _AttachmentTransferPreviewState
    extends State<_AttachmentTransferPreview> {
  String result = 'Ready';
  final _halfway = ValueNotifier<RaftTransferProgress?>(
    const RaftTransferProgress(received: 1782579, total: 2936012),
  );
  final _idle = ValueNotifier<RaftTransferProgress?>(null);

  @override
  void dispose() {
    _halfway.dispose();
    _idle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RaftAttachmentCard(
            filename: 'IMG_4821.jpg',
            mimeType: 'image/jpeg',
            imageExtent: const Size(300, 200),
            previewPending: true,
            onOpen: () => setState(() => result = 'Viewer opened'),
          ),
          const SizedBox(height: 12),
          RaftAttachmentCard(
            filename: 'IMG_4823.jpg',
            mimeType: 'image/jpeg',
            imageExtent: const Size(300, 200),
            error: 'The image could not be loaded.',
            onRetry: () => setState(() => result = 'Retried'),
            onOpen: () => setState(() => result = 'Viewer opened'),
          ),
          const SizedBox(height: 12),
          RaftAttachmentCard(
            filename: '2026Q3-report.pdf',
            mimeType: 'application/pdf',
            sizeBytes: 2936012,
            metaLabel: 'application/pdf',
            downloadFailed: true,
            onOpen: () => setState(() => result = 'Download retried'),
          ),
          const SizedBox(height: 24),
          RaftFileTransferPanel(
            filename: '2026Q3-report.pdf',
            meta: 'PDF · 2.8 MB',
            progress: _halfway,
            onCancel: () => setState(() => result = 'Cancelled'),
          ),
          const SizedBox(height: 24),
          RaftFileTransferPanel(
            filename: '2026Q3-report.pdf',
            meta: 'PDF · 2.8 MB',
            progress: _idle,
            failed: true,
            onRetry: () => setState(() => result = 'Retried'),
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
