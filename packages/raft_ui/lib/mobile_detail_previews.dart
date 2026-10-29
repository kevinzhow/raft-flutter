import 'package:flutter/material.dart';

import 'previews.dart';
import 'raft_ui.dart';

@RaftPreviews('Mobile DM settings page', size: Size(390, 844))
Widget mobileDmSettingsPreview() => const _DmSettingsPreview();

@RaftPreviews('Mobile attachment image page', size: Size(390, 844))
Widget mobileAttachmentImagePreview() => const _AttachmentPagePreview();

@RaftPreviews('Mobile attachment document page', size: Size(390, 844))
Widget mobileAttachmentDocumentPreview() =>
    const _AttachmentPagePreview(document: true);

@RaftPreviews('Mobile attachment loading page', size: Size(390, 844))
Widget mobileAttachmentLoadingPreview() =>
    const _AttachmentPagePreview(loading: true);

@RaftPreviews('Mobile attachment error page', size: Size(390, 844))
Widget mobileAttachmentErrorPreview() =>
    const _AttachmentPagePreview(error: true);

class _DmSettingsPreview extends StatefulWidget {
  const _DmSettingsPreview();
  @override
  State<_DmSettingsPreview> createState() => _DmSettingsPreviewState();
}

class _DmSettingsPreviewState extends State<_DmSettingsPreview> {
  bool pinned = false, closed = false;
  @override
  Widget build(BuildContext context) => closed
      ? RaftButton(
          label: 'Open Settings',
          onPressed: () => setState(() => closed = false),
        )
      : RaftChannelSettingsSheet(
          page: true,
          title: 'Conversation Settings',
          channelName: 'alice',
          channelLabel: 'Alice',
          onClose: () => setState(() => closed = true),
          sections: [
            RaftSheetSection('Preferences', [
              RaftSheetSwitchRow(
                title: 'Pin Channel',
                description:
                    'Keep this conversation at the top of your sidebar.',
                value: pinned,
                onChanged: (value) => setState(() => pinned = value),
              ),
            ]),
          ],
        );
}

class _AttachmentPagePreview extends StatefulWidget {
  const _AttachmentPagePreview({
    this.document = false,
    this.loading = false,
    this.error = false,
  });
  final bool document, loading, error;
  @override
  State<_AttachmentPagePreview> createState() => _AttachmentPagePreviewState();
}

class _AttachmentPagePreviewState extends State<_AttachmentPagePreview> {
  bool closed = false;
  String? receipt;
  @override
  Widget build(BuildContext context) => closed
      ? RaftButton(
          label: 'Open Preview',
          onPressed: () => setState(() => closed = false),
        )
      : RaftAttachmentLightbox(
          page: true,
          title: widget.document ? 'research.md' : '日本語・设计.png',
          onClose: () => setState(() => closed = true),
          footer: RaftTextButton(
            label: receipt ?? 'Download Original',
            glyph: RaftGlyph.download,
            onPressed: () => setState(() => receipt = 'Download requested'),
          ),
          child: widget.loading
              ? const Center(child: RaftSpinner())
              : widget.error
              ? const Center(
                  child: Text(
                    'Preview unavailable. Download the original file.',
                  ),
                )
              : widget.document
              ? const RaftDocumentPreview(
                  data: {
                    'kind': 'text',
                    'text':
                        '# Research\n\nA document attachment opened as a mobile page.',
                  },
                )
              : Center(
                  child: InteractiveViewer(
                    child: Container(
                      width: 260,
                      height: 340,
                      color: RaftTokens.of(context).accent,
                      child: const Center(
                        child: RaftIcon(RaftGlyph.image, size: 96),
                      ),
                    ),
                  ),
                ),
        );
}
