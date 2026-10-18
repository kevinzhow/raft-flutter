import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/shared_draft_attachment.dart';
import 'package:raft_flutter/data/workspace_controller.dart';

import 'app_global_server_selector_test.dart' show RootCache;

class DraftClient extends RaftClient {
  DraftClient()
    : super(
        origin: 'https://fixture.invalid',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'alice'});
    selectServer('s');
  }
  int uploads = 0, messages = 0;
  bool failSend = true;
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    if (path == '/attachments/upload-capabilities') return {'maxBytes': 1024};
    if (path.startsWith('/messages/channel/')) {
      return {'messages': [], 'hasMore': false};
    }
    return [];
  }

  @override
  Future<List<Map<String, dynamic>>> uploadStream(
    String channelId,
    Stream<List<int>> Function() openRead,
    int length,
    String filename, {
    UploadCancellation? cancellation,
    void Function(int, int)? onProgress,
    String? mimeType,
  }) async {
    expect(await openRead().expand((chunk) => chunk).toList(), [1, 2, 3]);
    uploads++;
    return [
      {'id': 'attachment', 'filename': filename},
    ];
  }

  @override
  Future<({RaftMessage message, Map<String, dynamic> receipt})> sendWithReceipt(
    String channelId,
    String content, {
    List<String>? attachments,
    List<Map<String, dynamic>>? mentions,
    String? randomId,
    bool asTask = false,
    String? timezone,
  }) async {
    messages++;
    expect(attachments, ['attachment']);
    if (failSend) throw const RaftApiException('Temporary send failure');
    return (
      message: RaftMessage({
        'id': 'message',
        'channelId': channelId,
        'content': content,
        'randomId': randomId,
      }),
      receipt: <String, dynamic>{},
    );
  }
}

class FailingCache extends RootCache {
  @override
  Future<void> write(
    String origin,
    String principal,
    String server,
    String kind,
    String id,
    dynamic value,
  ) async {
    if (kind == 'draft') throw StateError('Disk full');
    return super.write(origin, principal, server, kind, id, value);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('shared draft appends once, restores local references, survives failed send, releases only after success', () async {
    final c = DraftClient(), cache = RootCache();
    var releases = 0;
    final file = SharedDraftAttachment(
      reference: const {'token': 'opaque', 'file': 'item-0'},
      filename: 'photo.jpg',
      mimeType: 'image/jpeg',
      sizeBytes: 3,
      openRead: () => Stream.value([1, 2, 3]),
      release: () async {
        releases++;
      },
    );
    WorkspaceController controller() =>
        WorkspaceController(
            c,
            cache: cache,
            restoreSharedAttachment: (_, origin, principal) async =>
                origin == c.origin && principal == 'alice' ? file : null,
          )
          ..server = RaftRecord({'id': 's', 'role': 'member'})
          ..channel = RaftChannel({
            'id': 'c',
            'name': 'general',
            'joined': true,
          });
    final w = controller();
    w.saveDraft('Existing draft');
    await w.stageSharedDraft('Caption', [file], sourceToken: 'opaque');
    await w.stageSharedDraft('Caption', [file], sourceToken: 'opaque');
    expect(w.drafts['c'], 'Existing draft\n\nCaption');
    expect(w.uploads(), hasLength(1));
    expect(c.uploads, 0);
    expect(c.messages, 0);
    expect(w.uploadsReady(), true);
    final restored = controller();
    await restored.selectChannel(w.channel!, autoRead: false);
    expect(restored.drafts['c'], w.drafts['c']);
    expect(restored.uploads().single.queued, true);
    restored.saveDraft(''); // ordinary composer hands off its text before send
    expect(await restored.send('Edited caption'), false);
    expect(c.uploads, 1);
    expect(releases, 0);
    expect(restored.uploads().single.id, 'attachment');
    expect(restored.drafts['c'], 'Edited caption');
    c.failSend = false;
    restored.saveDraft('');
    expect(await restored.send('Edited caption'), true);
    expect(c.uploads, 1);
    expect(c.messages, 2);
    expect(releases, 1);
    expect(restored.uploads(), isEmpty);
    await restored.flushCache();
    expect(await cache.read(c.origin, 'alice', 's', 'draft', 'c'), isNull);
    restored.dispose();
    w.dispose();
    await c.dispose();
  });
  test(
    'failed draft persistence rolls back the handoff without uploading',
    () async {
      final c = DraftClient();
      final w = WorkspaceController(c, cache: FailingCache())
        ..channel = RaftChannel({'id': 'c', 'joined': true});
      w.drafts['c'] = 'Existing';
      await expectLater(
        w.stageSharedDraft('Incoming', [], sourceToken: 'opaque'),
        throwsStateError,
      );
      expect(w.drafts['c'], 'Existing');
      expect(w.uploads(), isEmpty);
      expect(c.uploads, 0);
      expect(c.messages, 0);
      w.dispose();
      await c.dispose();
    },
  );
}
