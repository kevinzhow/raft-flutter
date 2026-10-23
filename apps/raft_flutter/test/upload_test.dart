import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/platform/attachment_files.dart';

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://example.invalid',
        sessionStore: MemorySessionStore(),
      );
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async => {
    'maxBytes': 1024,
  };
  final uploadedChannels = <String>[];
  final responses = <Completer<List<Map<String, dynamic>>>>[];
  final cancellations = <UploadCancellation>[];
  @override
  Future<List<Map<String, dynamic>>> upload(
    String channelId,
    Uint8List bytes,
    String filename, {
    UploadCancellation? cancellation,
    void Function(int, int)? onProgress,
    String? mimeType,
  }) {
    uploadedChannels.add(channelId);
    onProgress?.call(2, 4);
    cancellations.add(cancellation!);
    final response = Completer<List<Map<String, dynamic>>>();
    responses.add(response);
    return response.future;
  }
}

/// A transfer starts after the capability probe (Web `uploadAttachmentFile`).
Future<void> started(int Function() responses, int count) async {
  for (var i = 0; i < 50 && responses() < count; i++) {
    await Future<void>.delayed(Duration.zero);
  }
  expect(responses(), count);
}

void main() {
  test('upload failure retains draft; retry succeeds; removed transfer cannot reappear', () async {
    final client = _Client();
    final w = WorkspaceController(client)
      ..channel = RaftChannel({'id': 'channel', 'name': 'general'});
    final pending = w.attachUpload('日本語.txt', Uint8List.fromList([1, 2, 3, 4]));
    final draft = w.uploads().single;
    await started(() => client.responses.length, 1);
    expect(draft.progress, .5);
    expect(w.uploadsReady(), false);
    client.responses.single.completeError(
      RaftApiException.response('File storage unavailable.', status: 500, body: {'error': 'File storage unavailable.'}),
    );
    await pending;
    expect(draft.error, 'File storage unavailable.');
    final retry = w.retryUpload(draft);
    expect(draft.error, isNull);
    await started(() => client.responses.length, 2);
    client.responses.last.complete([
      {'id': 'attachment'},
    ]);
    await retry;
    expect(w.uploadsReady(), true);
    expect(draft.id, 'attachment');
    final discarded = w.attachUpload('cancel.txt', Uint8List.fromList([1]));
    final removed = w.uploads().last;
    await started(() => client.responses.length, 3);
    w.removeUpload(removed);
    expect(client.cancellations.last.cancelled, true);
    client.responses.last.complete([
      {'id': 'must-not-reappear'},
    ]);
    await discarded;
    expect(w.uploads(), [draft]);
    expect(removed.id, isNull);
    w.dispose();
    await client.dispose();
  });
  test(
    'batch selection never uploads remaining files after channel adoption',
    () async {
      final client = _Client();
      final w = WorkspaceController(client)
        ..channel = RaftChannel({'id': 'first'});
      final pending = w.attachSelection([
        (name: 'first.txt', bytes: Uint8List.fromList([1])),
        (name: 'second.txt', bytes: Uint8List.fromList([2])),
      ], text: (key, args) => key);
      await Future<void>.delayed(Duration.zero);
      expect(client.uploadedChannels, ['first']);
      w.channel = RaftChannel({'id': 'second'});
      client.responses.single.complete([
        {'id': 'first-attachment'},
      ]);
      await pending;
      expect(client.uploadedChannels, ['first']);
      expect(w.uploads(), isEmpty);
      w.dispose();
      await client.dispose();
    },
  );
  test('same generation role change fences remaining batch files', () async {
    final client = _Client();
    final w = WorkspaceController(client)
      ..server = RaftRecord({'id': 'server', 'role': 'owner'})
      ..channel = RaftChannel({'id': 'channel'});
    final pending = w.attachSelection([
      (name: 'first.txt', bytes: Uint8List.fromList([1])),
      (name: 'second.txt', bytes: Uint8List.fromList([2])),
    ], text: (key, args) => key);
    await Future<void>.delayed(Duration.zero);
    w.server = RaftRecord({'id': 'server', 'role': 'member'});
    client.responses.single.complete([
      {'id': 'first-attachment'},
    ]);
    await pending;
    expect(client.uploadedChannels, ['channel']);
    w.dispose();
    await client.dispose();
  });
  test('empty files are rejected before network or draft insertion', () async {
    final client = _Client();
    final w = WorkspaceController(client)
      ..channel = RaftChannel({'id': 'channel'});
    await expectLater(
      w.attachUpload('empty', Uint8List(0)),
      throwsA(isA<RaftApiException>()),
    );
    expect(w.uploads(), isEmpty);
    expect(client.responses, isEmpty);
    w.dispose();
    await client.dispose();
  });
  test('download filename cannot escape chosen folder and URL capabilities cannot use file/userinfo', () {
    expect(AttachmentFiles.safeFilename('../../秘密.txt'), '秘密.txt');
    expect(AttachmentFiles.safeFilename(r'C:\outside\日本語.txt'), '日本語.txt');
    expect(
      () => AttachmentFiles.attachmentUri('file:///etc/passwd'),
      throwsFormatException,
    );
    expect(
      () => AttachmentFiles.attachmentUri('https://secret@example.com/file'),
      throwsFormatException,
    );
  });
}
