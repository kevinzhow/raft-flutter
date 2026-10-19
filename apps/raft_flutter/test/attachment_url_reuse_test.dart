import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/attachment_view.dart';
import 'package:raft_flutter/platform/attachment_files.dart';
import 'package:raft_ui/raft_ui.dart';

final png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAIAAACQkWg2AAAAGUlEQVR4nGP8V7uCgRTARJLqUQ2jGoaUBgC7qgJDBU0aZAAAAABJRU5ErkJggg==',
);

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://example.invalid',
        sessionStore: MemorySessionStore(),
      );
  final reads = <String>[];
  final batches = <List>[];
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    reads.add(path);
    return {
      'url': 'https://storage.example.invalid/${reads.length}',
      'expiresAt': DateTime.now()
          .add(const Duration(seconds: 300))
          .toIso8601String(),
    };
  }

  @override
  Future<dynamic> post(String path, {dynamic data}) async {
    batches.add((data as Map)['attachmentIds'] as List);
    return {
      'urls': [
        for (final id in data['attachmentIds'] as List)
          {'id': id, 'url': 'https://storage.example.invalid/b/$id'},
      ],
    };
  }
}

class _Files extends AttachmentFiles {
  final urls = <String>[];
  @override
  Future<Uint8List> image(
    String url, {
    required CancelToken cancel,
    void Function(int, int)? onProgress,
  }) async {
    urls.add(url);
    return png;
  }
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 40)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  Future<(_Client, _Files, WorkspaceController)> mount(
    WidgetTester tester, {
    Map<String, dynamic> extra = const {},
    String? messageId,
    bool settleFirst = true,
    bool pdf = false,
  }) async {
    final client = _Client()..user = RaftRecord({'id': 'alice'});
    client.selectServer('server');
    final w = WorkspaceController(client)
      ..server = RaftRecord({'id': 'server', 'role': 'owner'})
      ..channel = RaftChannel({'id': 'channel', 'joined': true});
    w.channels = [w.channel!];
    w.messageDomain.ledger.switchServer('server');
    w.messageDomain.ledger.ingest([
      {'id': 'host', 'channelId': 'channel', 'seq': '1', 'content': 'x'},
    ], expectedGeneration: w.messageDomain.ledger.generation);
    w.messageDomain.visibleIds['channel'] = {'host'};
    final files = _Files();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      w.dispose();
      await client.dispose();
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(RaftFamily.elegant),
        home: Scaffold(
          body: AttachmentView(
            controller: w,
            files: files,
            messageId: messageId,
            metadata: {
              'id': pdf ? 'doc' : 'image',
              'filename': pdf ? 'doc.pdf' : 'image.png',
              'mimeType': pdf ? 'application/pdf' : 'image/png',
              ...extra,
            },
          ),
        ),
      ),
    );
    if (settleFirst) await settle(tester);
    return (client, files, w);
  }

  testWidgets('a second open of the same attachment reads no signed URL', (
    tester,
  ) async {
    final (client, files, _) = await mount(tester);
    // The list preview resolved the URL once, through the batch route (the
    // tiles of one frame share a request).
    expect(client.batches, [
      ['image'],
    ]);
    expect(client.reads, isEmpty);
    for (var open = 0; open < 3; open++) {
      await tester.tap(find.byTooltip('Preview image.png'));
      await tester.pump();
      await settle(tester);
      expect(find.byTooltip('Close preview'), findsOneWidget);
      await tester.tap(find.byTooltip('Close preview'));
      await settle(tester);
      expect(find.byTooltip('Close preview'), findsNothing);
    }
    expect(
      client.batches.length + client.reads.length,
      1,
      reason: 'lightbox opens reuse the cached signed URL',
    );
    expect(files.urls.toSet().length, 1, reason: 'every transfer used it');
  });

  testWidgets('a thumbnailed image signs nothing until it is opened', (
    tester,
  ) async {
    final (client, files, _) = await mount(
      tester,
      messageId: 'host',
      extra: {'thumbnailUrl': 'https://storage.example.invalid/thumb'},
    );
    // The list tile loads the public thumbnail directly.
    expect(files.urls, ['https://storage.example.invalid/thumb']);
    expect(client.batches, isEmpty, reason: 'no batch signing ahead of time');
    expect(client.reads, isEmpty, reason: 'no single signing ahead of time');
    // Time passing and the tile staying on screen sign nothing either.
    await settle(tester);
    expect(client.batches.length + client.reads.length, 0);
    await tester.tap(find.byTooltip('Preview image.png'));
    await tester.pump();
    await settle(tester);
    expect(
      client.batches.length + client.reads.length,
      1,
      reason: 'the open signs the original once',
    );
    expect(files.urls.last, startsWith('https://storage.example.invalid/'));
    expect(files.urls.last, isNot('https://storage.example.invalid/thumb'));
    await tester.tap(find.byTooltip('Close preview'));
    await settle(tester);
  });

  testWidgets('hover and press sign no URL; only the open does', (
    tester,
  ) async {
    final (client, _, _) = await mount(
      tester,
      messageId: 'host',
      pdf: true,
    );
    expect(client.reads, isEmpty, reason: 'nothing is requested on build');
    expect(client.batches, isEmpty);
    final card = find.byType(RaftAttachmentCard);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(card));
    await settle(tester);
    expect(client.batches, isEmpty, reason: 'hover is not a request');
    expect(client.reads, isEmpty);
    // A press (finger down, not yet a tap) is not a request either.
    final press = await tester.startGesture(tester.getCenter(card));
    await settle(tester);
    expect(client.batches, isEmpty, reason: 'press is not a request');
    expect(client.reads, isEmpty);
    await press.cancel();
  });

  testWidgets('hover and press on a thumbnailed image sign no URL', (
    tester,
  ) async {
    final (client, _, _) = await mount(
      tester,
      messageId: 'host',
      extra: {'thumbnailUrl': 'https://storage.example.invalid/thumb'},
    );
    final card = find.byType(RaftAttachmentCard);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(card));
    await settle(tester);
    final press = await tester.startGesture(tester.getCenter(card));
    await settle(tester);
    await press.cancel();
    expect(client.batches, isEmpty);
    expect(client.reads, isEmpty);
  });
}
