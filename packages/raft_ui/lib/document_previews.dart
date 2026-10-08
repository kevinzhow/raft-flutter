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
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(
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
      RaftMediaControls(
        playing: playing,
        position: position,
        duration: const Duration(minutes: 2),
        volume: volume,
        onPlayPause: () => setState(() => playing = !playing),
        onSeek: (v) => setState(() => position = v),
        onVolume: (v) => setState(() => volume = v),
      ),
      const RaftMediaControls(
        playing: false,
        position: Duration.zero,
        duration: Duration.zero,
      ),
    ],
  );
}
