import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/attachment_limit_decision.dart';
import 'package:raft_flutter/data/upload_mime.dart';
import 'package:raft_flutter/data/workspace_controller.dart';

// Web MessageInput `addFiles` + `decideMessageAttachmentSelection`: files show
// at once as checking chips, the server ceiling decides, accepted files
// upload in turn (each fenced by the authority of the selection).
class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://example.invalid',
        sessionStore: MemorySessionStore(),
      );
  final limit = Completer<int?>();
  final uploads = <String, Completer<List<Map<String, dynamic>>>>{};
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    final max = await limit.future;
    return {'maxBytes': max};
  }

  @override
  Future<List<Map<String, dynamic>>> upload(
    String channelId,
    Uint8List bytes,
    String filename, {
    UploadCancellation? cancellation,
    void Function(int, int)? onProgress,
    String? mimeType,
  }) => (uploads[filename] = Completer()).future;
}

String _text(String key, Map<String, Object> args) => args.entries.fold(
  key,
  (text, e) => text.replaceAll('{${e.key}}', '${e.value}'),
);

({String name, Uint8List bytes}) _file(String name, int size) =>
    (name: name, bytes: Uint8List(size)..fillRange(0, size, 1));

void main() {
  WorkspaceController controller(_Client client) =>
      WorkspaceController(client)
        ..channel = RaftChannel({'id': 'channel', 'name': 'general'});

  test('files are checking chips until the ceiling decides, then upload in turn', () async {
    final client = _Client();
    final w = controller(client);
    final done = w.attachSelection([
      _file('a.png', 10),
      _file('b.pdf', 10),
    ], text: _text);
    await Future<void>.delayed(Duration.zero);
    expect(w.uploads().map((d) => (d.filename, d.checking)), [
      ('a.png', true),
      ('b.pdf', true),
    ]);
    expect(w.uploadsReady(), false);
    expect(client.uploads, isEmpty);
    client.limit.complete(100);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(w.uploads().every((d) => !d.checking), true);
    // The second file waits for the first and stays a plain (not checking) row.
    expect(client.uploads.keys, ['a.png']);
    client.uploads['a.png']!.complete([
      {'id': 'id'},
    ]);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(client.uploads.keys, ['a.png', 'b.pdf']);
    client.uploads['b.pdf']!.complete([
      {'id': 'id'},
    ]);
    await done;
    expect(w.uploadsReady(), true);
  });

  test('an empty file stays failed; one Pro would take raises the limit notice (v1.24)', () async {
    final client = _Client()..limit.complete(4096);
    final w = controller(client);
    await w.attachSelection([_file('e.txt', 0)], text: _text);
    // Web v1.24 `attachmentRejectionPlan`: what no plan changes stays in the
    // row, failed, saying why; no banner.
    final kept = w.uploads().single;
    expect(kept.notAttached!.reason, NotAttachedReason.empty);
    expect(kept.canRetry, false);
    expect(w.composerErrorFor(), isNull);
    w.removeUpload(kept);
    // A Free server, a file over its ceiling but within Pro's: it does not
    // stay, and the limit notice is queued for the upgrade.
    await w.attachSelection([_file('big.png', 8192)], text: _text);
    expect(w.uploads(), isEmpty);
    expect(w.composer.uploads.limitNotices.take()?.gate, 'upload_file_size');
  });

  test('the eleventh file stays failed as too many', () async {
    final client = _Client()..limit.complete(1024);
    final w = controller(client);
    final done = w.attachSelection([
      for (var i = 0; i < 11; i++) _file('f$i.txt', 4),
    ], text: _text);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(w.uploads(), hasLength(11));
    expect(w.uploads().last.notAttached!.reason, NotAttachedReason.count);
    for (var i = 0; i < 10; i++) {
      client.uploads['f$i.txt']!.complete([
        {'id': 'id'},
      ]);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
    }
    await done;
  });

  test('a row removed while checking releases its slot', () async {
    final client = _Client();
    final w = controller(client);
    final done = w.attachSelection([
      _file('a.png', 4),
      _file('b.png', 4),
    ], text: _text);
    await Future<void>.delayed(Duration.zero);
    w.removeUpload(w.uploads().first);
    client.limit.complete(100);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(w.uploads().map((d) => d.filename), ['b.png']);
    client.uploads.values.single.complete([
      {'id': 'id'},
    ]);
    await done;
  });

  test('an unknown ceiling refuses the whole batch', () async {
    final client = _Client()..limit.complete(null);
    final w = controller(client);
    await w.attachSelection([_file('a.png', 4)], text: _text);
    // Web v1.24: the file stays, failed, as "Not checked".
    expect(w.uploads().single.notAttached!.reason, NotAttachedReason.unchecked);
    expect(client.uploads, isEmpty);
  });

  test(
    'a checking draft whose scope changed is interrupted, not retryable',
    () async {
      final client = _Client();
      final w = controller(client);
      final done = w.attachSelection([_file('a.png', 4)], text: _text);
      final draft = w.uploads().single;
      w.channel = RaftChannel({'id': 'other', 'name': 'other'});
      client.limit.complete(100);
      await done;
      expect(draft.checking, false);
      expect(draft.canRetry, false);
      expect(
        draft.error,
        'File checking was interrupted. Remove it and attach again.',
      );
      await w.retryUpload(draft);
      expect(draft.error, isNotNull);
      expect(client.uploads, isEmpty);
    },
  );

  test('browser MIME types by extension; SVG is not previewable', () {
    expect(composerMimeType('Shot.PNG'), 'image/png');
    expect(composerMimeType('notes.pdf'), 'application/pdf');
    expect(composerMimeType('artifact.xyz'), '');
    expect(composerMimeType('noext'), '');
    expect(isPreviewableImageMime('image/png'), true);
    expect(isPreviewableImageMime('image/svg+xml'), false);
    expect(isPreviewableImageMime('video/mp4'), false);
    expect(isPreviewableImageMime(''), false);
  });
}
