// raft-flutter parity EXTENSION suite builders (tool/parity-ext): the media
// viewer (lightbox) for a video attachment. Ids
// `components.attachment.viewer.<state>.<theme>`, dispatched on props.extCase
// like tool/parity-ext/host/VideoViewerCases.tsx (Web's real
// VideoAttachmentPreviewModal with a data: WebM).
//
// The real RaftAttachmentPreviewShell + RaftVideoViewer are mounted with the
// clip's first frame (tool/parity-ext/fixtures/video-viewer-frame.png, 360x640,
// frame 0 of the WebM Web plays) standing in for the native surface, which a
// widget test cannot decode. The capture is the 1280x800 viewer.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

import '../parity_harness.dart';

const _frameFile = '../../tool/parity-ext/fixtures/video-viewer-frame.png';
final Uint8List _frameBytes = File(_frameFile).readAsBytesSync();
final MemoryImage _frame = MemoryImage(_frameBytes);

Widget _build(ParityContext ctx) => ctx.frame(
  width: ctx.width,
  height: ctx.height,
  padding: EdgeInsets.zero,
  child: SizedBox(
    width: ctx.width,
    height: ctx.height,
    child: Material(
      type: MaterialType.transparency,
      child: RaftAttachmentPreviewShell(
        filename: 'phone-clip.webm',
        dark: true,
        onClose: () {},
        onDownload: () {},
        child: RaftVideoViewer(
          filename: 'phone-clip.webm',
          videoSize: const Size(360, 640),
          touch: false,
          duration: const Duration(seconds: 3),
          volume: 100,
          video: ColoredBox(
            color: Colors.black,
            child: Image.memory(_frameBytes, fit: BoxFit.fill),
          ),
          onTogglePlay: () {},
          onSeek: (_) {},
          onVolume: (_) {},
          onDownload: () {},
        ),
      ),
    ),
  ),
);

ParityCase _case() => ParityCase(
  widgets: const [
    'raft_ui:RaftAttachmentPreviewShell',
    'raft_ui:RaftVideoViewer',
    'raft_ui:RaftVideoControlBar',
  ],
  notes:
      'Extension suite (not official). Web draws the browser-native controls '
      'in the video; Flutter draws RaftVideoControlBar (same layout and fade).',
  settle: const Duration(milliseconds: 300),
  build: _build,
  interact: (WidgetTester t, ParityContext ctx) async {
    await t.runAsync(() async {
      await precacheImage(_frame, t.element(find.byType(Material).first));
    });
    await t.pump(const Duration(milliseconds: 100));
    await t.pump(const Duration(milliseconds: 100));
  },
);

/// Every extension media viewer case, keyed by id (3 themes each).
final Map<String, ParityCase> extAttachmentViewerCases = {
  for (final theme in const ['brutal', 'elegant', 'elegant-dark'])
    'components.attachment.viewer.video-paused.$theme': _case(),
};
