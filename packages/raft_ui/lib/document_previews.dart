import 'package:flutter/material.dart';

import 'previews.dart';
import 'raft_ui.dart';

@RaftPreviews('Document and media preview')
Widget documentMediaPreview() => const _Preview();

class _Preview extends StatefulWidget {
  const _Preview();
  @override
  State<_Preview> createState() => _PreviewState();
}

class _PreviewState extends State<_Preview> {
  bool playing = false;
  Duration position = Duration.zero;
  double volume = 100;
  @override
  // This gallery combines independently scrollable media demos. The gallery
  // itself must also scroll when the audio controls grow with the text.
  Widget build(BuildContext context) => ListView(
    children: [
      SizedBox(
        height: 160,
        child: RaftDocumentPreview(
          data: const {
            'kind': 'xlsx',
            'sheetCount': 2,
            'sheets': [
              {
                'name': '日本語・设计',
                'headers': ['Name', '値'],
                'rows': [
                  ['Raft', '42'],
                ],
                'rowCount': 1,
                'columnCount': 2,
              },
              {
                'name': 'Second',
                'headers': ['State'],
                'rows': [
                  ['Ready'],
                ],
                'rowCount': 1,
                'columnCount': 1,
              },
            ],
          },
        ),
      ),
      SizedBox(
        height: 260,
        child: RaftVideoViewer(
          filename: 'walkthrough.mp4',
          videoSize: const Size(720, 1280),
          video: const ColoredBox(color: Color(0xFF3D5A79)),
          playing: playing,
          position: position,
          duration: const Duration(minutes: 2),
          volume: volume,
          onTogglePlay: () => setState(() => playing = !playing),
          onSeek: (v) => setState(() => position = v),
          onVolume: (v) => setState(() => volume = v),
          onDownload: () {},
        ),
      ),
      RaftAudioPreview(
        filename: 'standup.mp3',
        playing: playing,
        position: position,
        duration: const Duration(minutes: 2),
        volume: volume / 100,
        onTogglePlay: () => setState(() => playing = !playing),
        onSeek: (v) => setState(() => position = v),
        onVolume: (v) => setState(() => volume = v * 100),
      ),
    ],
  );
}

@RaftPreviews('Markdown section comments', size: Size(856, 944))
Widget markdownSectionCommentsPreview() => const _MarkdownCommentsPreview();

class _MarkdownCommentsPreview extends StatefulWidget {
  const _MarkdownCommentsPreview();
  @override
  State<_MarkdownCommentsPreview> createState() =>
      _MarkdownCommentsPreviewState();
}

class _MarkdownCommentsPreviewState extends State<_MarkdownCommentsPreview> {
  final comments = RaftAttachmentCommentState()..commentMode = true;
  @override
  void initState() {
    super.initState();
    comments.addListener(changed);
  }

  void changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    comments.removeListener(changed);
    comments.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RaftAttachmentCommentScope(
    state: comments,
    child: Column(
      children: [
        const Expanded(
          child: RaftDocumentPreview(
            data: {
              'kind': 'markdown',
              'markdown': '# Guide\n\nSelect text with a pointer or tap a section on touch.\n\n## Usage\n\nDiscuss this paragraph.\n\n## Usage\n\nA repeated heading has its own location.',
            },
          ),
        ),
        Wrap(
          spacing: 8,
          children: [
            if (comments.pendingAnchor case final anchor?)
              RaftCommentAnchorChip(
                label: '§ ${anchor['data']['headingTitle']}',
                removeLabel: 'Remove Anchor',
                onRemove: comments.clearAnchor,
              ),
            RaftButton.text(
              onPressed: () => comments.jump({
                'type': 'md-section',
                'data': {'headingId': 'usage-2', 'headingTitle': 'Usage'},
              }),
              child: const Text('Jump to second Usage'),
            ),
          ],
        ),
      ],
    ),
  );
}
