import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/attachment_view.dart';
import 'package:raft_flutter/platform/attachment_files.dart';

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://example.invalid',
        sessionStore: MemorySessionStore(),
      );
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async => {
    'url': 'https://storage.example.invalid/private-signed-capability',
  };
}

class _Files extends AttachmentFiles {
  final pending = Completer<Uint8List>();
  CancelToken? cancellation;
  @override
  Future<Uint8List> image(String url, {required CancelToken cancel}) {
    cancellation = cancel;
    return pending.future;
  }
}

void main() {
  testWidgets(
    'server revocation cancels image transfer and late private bytes never render',
    (tester) async {
      final client = _Client()..user = RaftRecord({'id': 'alice'});
      client.selectServer('server');
      final w = WorkspaceController(client)
        ..channel = RaftChannel({'id': 'channel'});
      final files = _Files();
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.brutal),
          home: Scaffold(
            body: AttachmentView(
              controller: w,
              files: files,
              metadata: const {
                'id': 'private-file',
                'filename': 'private.png',
                'mimeType': 'image/png',
              },
            ),
          ),
        ),
      );
      await tester.pump();
      expect(files.cancellation, isNotNull);
      w.revokeServer('server');
      await tester.pump();
      expect(files.cancellation!.isCancelled, true);
      files.pending.complete(
        base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAIAAACQkWg2AAAAGUlEQVR4nGP8V7uCgRTARJLqUQ2jGoaUBgC7qgJDBU0aZAAAAABJRU5ErkJggg==',
        ),
      );
      await tester.pump();
      expect(
        tester
            .widget<RaftAttachmentCard>(find.byType(RaftAttachmentCard))
            .preview,
        isNull,
      );
      await tester.pumpWidget(const SizedBox());
      w.dispose();
      await client.dispose();
    },
  );
  testWidgets('revocation closes an already open private image preview', (
    tester,
  ) async {
    final client = _Client()..user = RaftRecord({'id': 'alice'});
    client.selectServer('server');
    final w = WorkspaceController(client)
      ..channel = RaftChannel({'id': 'channel'});
    final files = _Files()
      ..pending.complete(
        base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAIAAACQkWg2AAAAGUlEQVR4nGP8V7uCgRTARJLqUQ2jGoaUBgC7qgJDBU0aZAAAAABJRU5ErkJggg==',
        ),
      );
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(RaftFamily.brutal),
        home: Scaffold(
          body: AttachmentView(
            controller: w,
            files: files,
            metadata: const {
              'id': 'private-file',
              'filename': 'private.png',
              'mimeType': 'image/png',
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'private.png'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Close preview'), findsOneWidget);
    w.revokeServer('server');
    await tester.pumpAndSettle();
    expect(find.byTooltip('Close preview'), findsNothing);
    expect(
      tester
          .widget<RaftAttachmentCard>(find.byType(RaftAttachmentCard))
          .preview,
      isNull,
    );
    await tester.pumpWidget(const SizedBox());
    w.dispose();
    await client.dispose();
  });
  testWidgets(
    'closing the host message invalidates its preview even if the channel stays selected',
    (tester) async {
      final client = _Client()..user = RaftRecord({'id': 'alice'});
      client.selectServer('server');
      final w = WorkspaceController(client)
        ..channel = RaftChannel({'id': 'channel'});
      w.ledger.switchServer('server');
      w.ledger.ingest([
        {
          'id': 'host',
          'channelId': 'channel',
          'seq': '1',
          'content': 'private',
        },
      ], expectedGeneration: w.ledger.generation);
      w.visibleIds['channel'] = {'host'};
      final bytes = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAIAAACQkWg2AAAAGUlEQVR4nGP8V7uCgRTARJLqUQ2jGoaUBgC7qgJDBU0aZAAAAABJRU5ErkJggg==',
      );
      final files = _Files()..pending.complete(bytes);
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.brutal),
          home: Scaffold(
            body: AttachmentView(
              controller: w,
              messageId: 'host',
              files: files,
              metadata: const {
                'id': 'file',
                'filename': 'private.png',
                'mimeType': 'image/png',
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'private.png'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Close preview'), findsOneWidget);
      w.visibleIds['channel'] = {};
      w.notifyListeners();
      await tester.pumpAndSettle();
      expect(find.byTooltip('Close preview'), findsNothing);
      expect(
        PaintingBinding.instance.imageCache.containsKey(MemoryImage(bytes)),
        false,
      );
      w.visibleIds['channel'] = {'host'};
      w.notifyListeners();
      await tester.pump();
      expect(
        tester
            .widget<RaftAttachmentCard>(find.byType(RaftAttachmentCard))
            .preview,
        isNull,
      );
      await tester.pumpWidget(const SizedBox());
      w.dispose();
      await client.dispose();
    },
  );
  testWidgets(
    'export waits for image completion and signals only current scope once',
    (tester) async {
      final client = _Client()..user = RaftRecord({'id': 'alice'});
      client.selectServer('server');
      final w = WorkspaceController(client)
        ..channel = RaftChannel({'id': 'channel'});
      final files = _Files();
      var ready = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.brutal),
          home: Scaffold(
            body: AttachmentView(
              controller: w,
              files: files,
              exportMode: true,
              onExportReady: () => ready++,
              metadata: const {
                'id': 'file',
                'filename': 'proof.png',
                'mimeType': 'image/png',
              },
            ),
          ),
        ),
      );
      await tester.pump();
      expect(ready, 0);
      files.pending.complete(
        base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAIAAACQkWg2AAAAGUlEQVR4nGP8V7uCgRTARJLqUQ2jGoaUBgC7qgJDBU0aZAAAAABJRU5ErkJggg==',
        ),
      );
      await tester.pumpAndSettle();
      expect(ready, 1);
      expect(find.byTooltip('Download proof.png'), findsNothing);
      w.revokeServer('server');
      await tester.pumpAndSettle();
      expect(ready, 1);
      await tester.pumpWidget(const SizedBox());
      w.dispose();
      await client.dispose();
    },
  );
  testWidgets('disposing an attachment closes its owned preview route', (
    tester,
  ) async {
    final client = _Client()..user = RaftRecord({'id': 'alice'});
    client.selectServer('server');
    final w = WorkspaceController(client)
      ..channel = RaftChannel({'id': 'channel'});
    final files = _Files()
      ..pending.complete(
        base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAIAAACQkWg2AAAAGUlEQVR4nGP8V7uCgRTARJLqUQ2jGoaUBgC7qgJDBU0aZAAAAABJRU5ErkJggg==',
        ),
      );
    final show = ValueNotifier(true);
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(RaftFamily.brutal),
        home: Scaffold(
          body: ValueListenableBuilder<bool>(
            valueListenable: show,
            builder: (_, visible, _) => visible
                ? AttachmentView(
                    controller: w,
                    files: files,
                    metadata: const {
                      'id': 'file',
                      'filename': 'private.png',
                      'mimeType': 'image/png',
                    },
                  )
                : const SizedBox(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'private.png'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Close preview'), findsOneWidget);
    show.value = false;
    await tester.pumpAndSettle();
    expect(find.byTooltip('Close preview'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    show.dispose();
    w.dispose();
    await client.dispose();
  });
  testWidgets(
    'export loads a ledger descendant of a visible parent and revokes on parent removal',
    (t) async {
      final client = _Client()..user = RaftRecord({'id': 'alice'});
      client.selectServer('server');
      final w = WorkspaceController(client)
        ..channel = RaftChannel({'id': 'channel'});
      w.ledger.switchServer('server');
      w.ledger.ingest([
        {
          'id': 'parent',
          'channelId': 'channel',
          'threadId': 'thread',
          'seq': '1',
          'content': 'parent',
        },
        {'id': 'reply', 'channelId': 'thread', 'seq': '1', 'content': 'reply'},
      ], expectedGeneration: w.ledger.generation);
      w.visibleIds['channel'] = {'parent'};
      expect(w.replies, isEmpty);
      final files = _Files();
      var ready = 0;
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.brutal),
          home: Scaffold(
            body: AttachmentView(
              controller: w,
              messageId: 'reply',
              files: files,
              exportMode: true,
              onExportReady: () => ready++,
              metadata: const {
                'id': 'file',
                'filename': 'reply.png',
                'mimeType': 'image/png',
              },
            ),
          ),
        ),
      );
      await t.pump();
      expect(files.cancellation, isNotNull);
      final bytes = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAIAAACQkWg2AAAAGUlEQVR4nGP8V7uCgRTARJLqUQ2jGoaUBgC7qgJDBU0aZAAAAABJRU5ErkJggg==',
      );
      files.pending.complete(bytes);
      await t.pumpAndSettle();
      expect(ready, 1);
      expect(
        t.widget<RaftAttachmentCard>(find.byType(RaftAttachmentCard)).preview,
        isNotNull,
      );
      w.visibleIds['channel'] = {};
      w.notifyListeners();
      await t.pumpAndSettle();
      expect(
        t.widget<RaftAttachmentCard>(find.byType(RaftAttachmentCard)).preview,
        isNull,
      );
      expect(files.cancellation!.isCancelled, true);
      expect(
        PaintingBinding.instance.imageCache.containsKey(MemoryImage(bytes)),
        false,
      );
      expect(ready, 1);
      await t.pumpWidget(const SizedBox());
      w.dispose();
      await client.dispose();
    },
  );
}
