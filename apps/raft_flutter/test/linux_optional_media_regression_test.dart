import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/inline_attachment_media.dart';
import 'package:raft_flutter/features/attachment_preview_dialog.dart';
import 'package:raft_flutter/platform/attachment_player.dart';
import 'package:raft_flutter/platform/attachment_preview_files.dart';
import 'package:raft_flutter/platform/native_sharing.dart';
import 'package:raft_ui/raft_ui.dart';

import 'attachment_html_test.dart' show waitForHtmlCompletion;
import 'linux_dependency_fixture.dart';
import 'message_presentation_test.dart' show fixture;

class _Player implements AttachmentPlayer {
  final events = StreamController<AttachmentPlayback>.broadcast();
  @override
  Stream<AttachmentPlayback> get changes => events.stream;
  @override
  AttachmentPlayback get playback =>
      const AttachmentPlayback(duration: Duration(seconds: 3));
  @override
  bool get usesPlatformView => false;
  @override
  Widget video() => const Text('Playable video');
  @override
  Future<void> open(AttachmentSource source) async {}
  @override
  Future<void> toggle() async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> seek(Duration value) async {}
  @override
  Future<void> volume(double value) async {}
  @override
  Future<void> dispose() async {
    unawaited(events.close());
  }
}

class _Files extends AttachmentPreviewFiles {
  _Files(this.lease);
  final SharedFileLease lease;
  int calls = 0;
  @override
  Future<SharedFileLease?> load(
    String url,
    String filename, {
    required CancelToken cancel,
    required bool Function() authorized,
    void Function(int, int)? onProgress,
  }) async {
    calls++;
    return lease;
  }
}

class _Pdf extends NativePdfRenderer {
  int calls = 0;
  @override
  Future<NativePdfPage> render(
    File file,
    int page, {
    required CancelToken cancel,
    required bool Function() authorized,
  }) async {
    calls++;
    return NativePdfPage(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
      ),
      1,
    );
  }
}

void main() {
  late DependencyHost host;
  setUp(() {
    host = DependencyHost()..bind();
  });
  tearDown(() {
    host.unbind();
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets(
    'missing mpv does not construct a player; audio retry works after install',
    (t) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      try {
        final (w, api) = (await t.runAsync(() => fixture('owner')))!;
        addTearDown(w.dispose);
        addTearDown(() => t.pumpWidget(const SizedBox()));
        api.routes['GET /attachments/a/url'] = (_) => {
          'url': 'https://media.invalid/audio',
        };
        var created = 0;
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(),
            home: Scaffold(
              body: InlineAudioAttachment(
                controller: w,
                metadata: const {'id': 'a', 'filename': 'audio.mp3'},
                authorized: () => true,
                pending: false,
                playerFactory: () {
                  created++;
                  return _Player();
                },
              ),
            ),
          ),
        );
        await t.pump(const Duration(milliseconds: 700));
        await waitForHtmlCompletion(
          t,
          () =>
              find
                  .byKey(const Key('linux-dependency-notice-mpv'))
                  .evaluate()
                  .isNotEmpty ||
              created > 0,
        );
        expect(created, 0);
        expect(
          find.byKey(const Key('linux-dependency-notice-mpv')),
          findsOneWidget,
        );
        host.installed.add('mpv');
        await t.tap(find.byKey(const Key('linux-dependency-retry-mpv')));
        await waitForHtmlCompletion(t, () => created > 0);
        await t.pumpAndSettle();
        expect(created, 1);
        expect(
          find.byKey(const Key('linux-dependency-notice-mpv')),
          findsNothing,
        );
        await t.pumpWidget(const SizedBox());
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  testWidgets(
    'missing Poppler avoids download/conversion; retry restores actual PDF page widget',
    (t) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      try {
        final (w, api) = (await t.runAsync(() => fixture('owner')))!;
        addTearDown(w.dispose);
        addTearDown(() => t.pumpWidget(const SizedBox()));
        api.routes['GET /attachments/p/url'] = (_) => {
          'url': 'https://media.invalid/paper.pdf',
        };
        final folder = (await t.runAsync(
          () => Directory.systemTemp.createTemp('raft-optional308-pdf-'),
        ))!;
        final file = File('${folder.path}/paper.pdf');
        await t.runAsync(() => file.writeAsBytes([1, 2, 3]));
        addTearDown(() async {
          if (await folder.exists()) await folder.delete(recursive: true);
        });
        final files = _Files(SharedFileLease(file));
        final pdf = _Pdf();
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(),
            home: Scaffold(
              body: AttachmentPreviewDialog(
                controller: w,
                metadata: const {'id': 'p', 'filename': 'paper.pdf'},
                authorized: () => true,
                onClose: () {},
                onDownload: () async {},
                files: files,
                pdf: pdf,
              ),
            ),
          ),
        );
        await waitForHtmlCompletion(
          t,
          () =>
              find
                  .byKey(const Key('linux-dependency-notice-poppler'))
                  .evaluate()
                  .isNotEmpty ||
              pdf.calls > 0,
        );
        expect(pdf.calls, 0);
        expect(files.calls, 0);
        expect(
          find.byKey(const Key('linux-dependency-notice-poppler')),
          findsOneWidget,
        );
        host.installed.add('poppler');
        await t.tap(find.byKey(const Key('linux-dependency-retry-poppler')));
        await waitForHtmlCompletion(t, () => pdf.calls > 0);
        await t.pumpAndSettle();
        expect(
          find.byKey(const Key('linux-dependency-notice-poppler')),
          findsNothing,
        );
        expect(find.text('1 / 1'), findsOneWidget);
        expect(find.byType(Image), findsOneWidget);
        await t.pumpWidget(const SizedBox());
        await t.pump(const Duration(milliseconds: 1));
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );
}
