import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/attachment_preview_dialog.dart';
import 'package:raft_flutter/platform/attachment_player.dart';
import 'package:raft_flutter/platform/attachment_preview_files.dart';
import 'package:raft_flutter/platform/native_sharing.dart';
import 'package:raft_ui/raft_ui.dart';

import 'fixtures/preview_samples.dart';

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://example.invalid',
        sessionStore: MemorySessionStore(),
      );
  final paths = <String>[];
  dynamic answer = {
    'status': 'ok',
    'data': {'kind': 'text', 'text': 'private document'},
  };
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    paths.add(path);
    return answer;
  }
}

class _Files extends AttachmentPreviewFiles {
  _Files(this.lease);
  final SharedFileLease lease;
  @override
  Future<SharedFileLease?> load(
    String url,
    String filename, {
    required CancelToken cancel,
    required bool Function() authorized,
  }) async => lease;
}

class _Player implements AttachmentPlayer {
  final events = StreamController<AttachmentPlayback>.broadcast();
  int pauses = 0, toggles = 0;
  bool disposed = false;
  @override
  Stream<AttachmentPlayback> get changes => events.stream;
  @override
  Widget video() => const ColoredBox(color: Colors.red);
  @override
  Future<void> open(File file) async {
    events.add(const AttachmentPlayback(duration: Duration(seconds: 3)));
  }

  @override
  Future<void> toggle() async {
    toggles++;
  }

  @override
  Future<void> pause() async {
    pauses++;
  }

  @override
  Future<void> seek(Duration value) async {}
  @override
  Future<void> volume(double value) async {}
  @override
  Future<void> dispose() async {
    disposed = true;
    await events.close();
  }
}

void main() {
  test('source media aliases and bounded document classification', () {
    for (final name in [
      'clip.MOV',
      'clip.webm',
      'audio.opus',
      'audio.weba',
      'report.pdf',
      'notes.kt',
      'table.xlsx',
    ]) {
      expect(
        attachmentPreviewKind({'filename': name}),
        isNotNull,
        reason: name,
      );
    }
    expect(
      attachmentPreviewKind({
        'filename': 'legacy.xls',
        'mimeType': 'application/vnd.ms-excel',
      }),
      isNull,
    );
    expect(
      attachmentPreviewKind({
        'filename': 'big.csv',
        'sizeBytes': 6 * 1024 * 1024,
      }),
      isNull,
    );
    expect(
      attachmentPreviewKind({
        'filename': 'index.html',
        'mimeType': 'text/html',
      }),
      isNull,
    );
    expect(attachmentPreviewKind({'filename': 'changes.patch'}), isNull);
    expect(
      attachmentPreviewKind({'mimeType': 'audio/mp4; charset=binary'}),
      'audio',
    );
  });
  test('real Poppler renders two pages and leaves no raster files', () async {
    if (!Platform.isLinux) return;
    final folder = await Directory.systemTemp.createTemp('raft-pdf-test-');
    try {
      final file = await File('${folder.path}/fixture.pdf')
          .writeAsBytes(previewPdf());
      final renderer = NativePdfRenderer();
      final first = await renderer.render(
        file,
        0,
        cancel: CancelToken(),
        authorized: () => true,
      );
      final second = await renderer.render(
        file,
        1,
        cancel: CancelToken(),
        authorized: () => true,
      );
      expect(first.pageCount, 2);
      expect(second.pageCount, 2);
      expect(first.bytes.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
      expect(first.bytes, isNot(orderedEquals(second.bytes)));
      expect(await folder.list().length, 1);
      await expectLater(
        renderer.render(file, 2, cancel: CancelToken(), authorized: () => true),
        throwsFormatException,
      );
      await expectLater(
        renderer.render(
          file,
          0,
          cancel: CancelToken(),
          authorized: () => false,
        ),
        throwsStateError,
      );
    } finally {
      await folder.delete(recursive: true);
    }
  });
  test(
    'download failure and revocation leave no private input lease',
    () async {
      final folder = await Directory.systemTemp.createTemp('raft-input-test-');
      final http = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final subscription = http.listen((request) {
        expect(request.headers.value('authorization'), isNull);
        request.response.statusCode = 500;
        request.response.close();
      });
      try {
        final files = AttachmentPreviewFiles(
          temporaryDirectory: () async => folder,
        );
        await expectLater(
          files.load(
            'http://127.0.0.1:${http.port}/private',
            'sample.wav',
            cancel: CancelToken(),
            authorized: () => true,
          ),
          throwsA(isA<DioException>()),
        );
        expect(
          await Directory('${folder.path}/raft-previews').list().length,
          0,
        );
        expect(
          await files.load(
            'http://127.0.0.1:${http.port}/private',
            'sample.wav',
            cancel: CancelToken(),
            authorized: () => false,
          ),
          isNull,
        );
      } finally {
        await http.close(force: true);
        await subscription.cancel();
        await folder.delete(recursive: true);
      }
    },
  );
  testWidgets(
    'structured preview uses mounted endpoint and revokes private text',
    (tester) async {
      final client = _Client();
      final w = WorkspaceController(client);
      var allowed = true, closed = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: AttachmentPreviewDialog(
            controller: w,
            metadata: const {'id': 'a', 'filename': 'note.txt'},
            authorized: () => allowed,
            onClose: () => closed++,
            onDownload: () async {},
          ),
        ),
      );
      await tester.pump();
      expect(find.text('private document'), findsOneWidget);
      expect(client.paths, ['/attachments/a/preview']);
      allowed = false;
      w.notifyListeners();
      await tester.pump();
      expect(closed, 1);
      expect(find.text('private document'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      w.dispose();
      await client.dispose();
    },
  );
  testWidgets(
    'playback pauses on background, revocation and cleans its lease',
    (tester) async {
      final folder = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('raft-player-test-'),
      ))!;
      final file = (await tester.runAsync(
        () => File('${folder.path}/a.wav').writeAsBytes(previewWav()),
      ))!;
      final lease = SharedFileLease(file);
      final player = _Player();
      final client = _Client()
        ..answer = {'url': 'https://example.invalid/signed'};
      final w = WorkspaceController(client);
      var allowed = true;
      await tester.pumpWidget(
        MaterialApp(
          home: AttachmentPreviewDialog(
            controller: w,
            metadata: const {'id': 'a', 'filename': 'a.wav'},
            authorized: () => allowed,
            onClose: () {},
            onDownload: () async {},
            files: _Files(lease),
            playerFactory: () => player,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.byType(RaftMediaControls), findsOneWidget);
      await tester.tap(find.byTooltip('Play'));
      expect(player.toggles, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(player.pauses, 1);
      allowed = false;
      w.notifyListeners();
      await tester.pump();
      expect(player.pauses, 2);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      bool present = true;
      for (var i = 0; i < 20 && present; i++) {
        present = (await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          return file.exists();
        }))!;
        await tester.pump();
      }
      expect(player.disposed, true);
      expect(present, false);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      w.dispose();
      await client.dispose();
      await tester.runAsync(() async {
        if (await folder.exists()) await folder.delete(recursive: true);
      });
    },
  );
}
