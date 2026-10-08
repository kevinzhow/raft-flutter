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

class _RebindingFiles extends AttachmentFiles {
  final pending = <Completer<Uint8List>>[];
  final cancellations = <CancelToken>[];
  @override
  Future<Uint8List> image(String url, {required CancelToken cancel}) {
    final next = Completer<Uint8List>();
    pending.add(next);
    cancellations.add(cancel);
    return next.future;
  }
}

Future<void> decodedPreview(WidgetTester tester) async {
  for (var i = 0; i < 40; i++) {
    final cards = find.byType(RaftAttachmentCard).evaluate();
    if (cards.isNotEmpty &&
        (cards.single.widget as RaftAttachmentCard).preview != null) {
      return;
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 10));
  }
  expect(
    tester.widget<RaftAttachmentCard>(find.byType(RaftAttachmentCard)).preview,
    isNotNull,
  );
}

void main() {
  testWidgets(
    'same keyed attachment slot withdraws old pending revision and rebinds controller',
    (t) async {
      WorkspaceController owner(String user) {
        final client = _Client()..user = RaftRecord({'id': user});
        client.selectServer('server');
        final w = WorkspaceController(client)
          ..server = RaftRecord({'id': 'server', 'role': 'owner'})
          ..channel = RaftChannel({'id': 'channel', 'joined': true});
        w.channels = [w.channel!];
        return w;
      }

      final first = owner('alice'), second = owner('bob');
      addTearDown(() async {
        first.dispose();
        second.dispose();
        await first.client.dispose();
        await second.client.dispose();
      });
      final files = _RebindingFiles();
      Widget host(WorkspaceController w, int revision) => MaterialApp(
        theme: raftTheme(RaftFamily.elegant),
        home: Scaffold(
          body: AttachmentView(
            key: const Key('same-slot'),
            controller: w,
            files: files,
            metadata: {
              'id': 'same-image',
              'filename': 'image.png',
              'mimeType': 'image/png',
              'contentVersion': revision,
            },
          ),
        ),
      );
      await t.pumpWidget(host(first, 1));
      await t.pump();
      final state = t.state(find.byType(AttachmentView));
      expect(files.pending.length, 1);
      await t.pumpWidget(host(first, 2));
      await t.pump();
      expect(t.state(find.byType(AttachmentView)), same(state));
      expect(files.pending.length, 2);
      expect(files.cancellations[0].isCancelled, true);
      final bytes = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAIAAACQkWg2AAAAGUlEQVR4nGP8V7uCgRTARJLqUQ2jGoaUBgC7qgJDBU0aZAAAAABJRU5ErkJggg==',
      );
      files.pending[0].complete(bytes);
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await t.pump();
      expect(
        t.widget<RaftAttachmentCard>(find.byType(RaftAttachmentCard)).preview,
        null,
      );
      files.pending[1].complete(bytes);
      await decodedPreview(t);
      expect(
        t.widget<RaftAttachmentCard>(find.byType(RaftAttachmentCard)).preview,
        isNotNull,
      );
      await t.pumpWidget(host(second, 2));
      await t.pump();
      expect(t.state(find.byType(AttachmentView)), same(state));
      expect(files.pending.length, 3);
      expect(
        t.widget<RaftAttachmentCard>(find.byType(RaftAttachmentCard)).preview,
        null,
      );
      first.revokeServer('server');
      await t.pump();
      expect(files.cancellations[2].isCancelled, false);
      files.pending[2].complete(bytes);
      await decodedPreview(t);
      second.revokeServer('server');
      await t.pump();
      expect(
        t.widget<RaftAttachmentCard>(find.byType(RaftAttachmentCard)).preview,
        null,
      );
      await t.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'server revocation cancels image transfer and late private bytes never render',
    (tester) async {
      final client = _Client()..user = RaftRecord({'id': 'alice'});
      client.selectServer('server');
      final w = WorkspaceController(client)
        ..server = RaftRecord({'id': 'server', 'role': 'owner'})
        ..channel = RaftChannel({'id': 'channel', 'joined': true});
      w.channels = [w.channel!];
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
      ..server = RaftRecord({'id': 'server', 'role': 'owner'})
      ..channel = RaftChannel({'id': 'channel', 'joined': true});
    w.channels = [w.channel!];
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
    await decodedPreview(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Preview private.png'));
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
        ..server = RaftRecord({'id': 'server', 'role': 'owner'})
        ..channel = RaftChannel({'id': 'channel', 'joined': true});
      w.channels = [w.channel!];
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
      await decodedPreview(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Preview private.png'));
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
        ..server = RaftRecord({'id': 'server', 'role': 'owner'})
        ..channel = RaftChannel({'id': 'channel', 'joined': true});
      w.channels = [w.channel!];
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
      await decodedPreview(tester);
      await tester.pumpAndSettle();
      await tester.pump();
      expect(ready, 1);
      expect(find.byTooltip('Download proof.png'), findsNothing);
      w.revokeServer('server');
      await tester.pumpAndSettle();
      await tester.pump();
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
      ..server = RaftRecord({'id': 'server', 'role': 'owner'})
      ..channel = RaftChannel({'id': 'channel', 'joined': true});
    w.channels = [w.channel!];
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
    await decodedPreview(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Preview private.png'));
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
        ..server = RaftRecord({'id': 'server', 'role': 'owner'})
        ..channel = RaftChannel({'id': 'channel', 'joined': true});
      w.channels = [w.channel!];
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
      await decodedPreview(t);
      await t.pumpAndSettle();
      await t.pump();
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
      await t.pump();
      expect(ready, 1);
      await t.pumpWidget(const SizedBox());
      w.dispose();
      await client.dispose();
    },
  );
}
