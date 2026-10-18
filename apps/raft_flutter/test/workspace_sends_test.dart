import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/data/shared_draft_attachment.dart';

typedef _Receipt = ({RaftMessage message, Map<String, dynamic> receipt});

class _Request {
  _Request(this.channel, this.text, this.randomId);
  final String channel, text, randomId;
  final result = Completer<_Receipt>();
  Map<String, dynamic> row(int seq) => {
    'id': 'accepted-$seq',
    'channelId': channel,
    'content': text,
    'randomId': randomId,
    'seq': '$seq',
    'senderId': 'author',
    'senderType': 'user',
    'senderName': 'Author',
    'createdAt': '2026-10-15T00:00:00Z',
  };
  void accept(int seq) => result.complete((
    message: RaftMessage(row(seq)),
    receipt: <String, dynamic>{},
  ));
  void reject() => result.completeError(
    const RaftApiException('Fixture refusal', status: 403),
  );
}

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://sends.invalid',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'author', 'displayName': 'Author'});
    selectServer('s1');
  }
  final injected = StreamController<RaftEvent>.broadcast(sync: true);
  final requests = <_Request>[];
  var holdLimits = false;
  final limits = <Completer<dynamic>>[];
  @override
  Stream<RaftEvent> get events => injected.stream;
  @override
  void connect() {}
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    if (holdLimits && path == '/attachments/upload-capabilities') {
      final limit = Completer<dynamic>();
      limits.add(limit);
      return limit.future;
    }
    if (path == '/channels/real-dm') {
      return {'id': 'real-dm', 'type': 'dm', 'joined': true, 'serverId': 's1'};
    }
    if (path.startsWith('/messages/channel/')) {
      return {'messages': [], 'hasMore': false};
    }
    return [];
  }

  @override
  Future<_Receipt> sendWithReceipt(
    String channelId,
    String content, {
    List<String>? attachments,
    List<Map<String, dynamic>>? mentions,
    String? randomId,
    bool asTask = false,
    String? timezone,
  }) {
    final request = _Request(channelId, content, randomId!);
    requests.add(request);
    return request.result.future;
  }
}

WorkspaceController _editor(_Client client, {WorkspaceController? root}) {
  final w = WorkspaceController(
    client,
    ownsClient: false,
    composer: root?.composer,
  );
  w.server = RaftRecord({'id': client.serverId, 'role': 'owner'});
  w.channel = RaftChannel({'id': 'c1', 'joined': true});
  w.channels = [w.channel!];
  w.ledger.switchServer(client.serverId);
  return w;
}

Future<void> _entered(_Client client, int count) async {
  for (var i = 0; i < 50 && client.requests.length < count; i++) {
    await Future<void>.delayed(Duration.zero);
  }
  expect(client.requests.length, count);
}

void main() {
  late _Client client;
  late WorkspaceController root;
  final futures = <Future<bool>>[];
  setUp(() {
    client = _Client();
    root = _editor(client);
    futures.clear();
  });
  tearDown(() async {
    for (final limit in client.limits) {
      if (!limit.isCompleted) limit.complete(null);
    }
    for (final request in client.requests) {
      if (!request.result.isCompleted) request.reject();
    }
    await Future.wait(futures);
    root.dispose();
    await client.injected.close();
    await client.dispose();
  });

  test(
    'shared editors present one pending row with the same stable key',
    () async {
      final other = _editor(client, root: root);
      addTearDown(other.dispose);
      futures.add(root.send('shared send'));
      await _entered(client, 1);
      expect(root.timeline().single.content, 'shared send');
      expect(other.timeline().single.content, 'shared send');
      expect(
        other.messageKey(other.timeline().single),
        root.messageKey(root.timeline().single),
      );
    },
  );

  test(
    'closing the sending editor preserves failure and later draft text',
    () async {
      final other = _editor(client, root: root);
      futures.add(other.send('failed text'));
      await _entered(client, 1);
      root.saveDraft('newer text');
      other.dispose();
      client.requests.single.reject();
      expect(await futures.single, false);
      expect(root.drafts['c1'], 'failed text\nnewer text');
      expect(root.timeline(), isEmpty);
    },
  );

  test(
    'closing the sending editor keeps its HTTP receipt in the live window',
    () async {
      final other = _editor(client, root: root);
      futures.add(other.send('accepted after close'));
      await _entered(client, 1);
      other.dispose();
      client.requests.single.accept(1);
      expect(await futures.single, true);
      expect(root.timeline().single.id, 'accepted-1');
      expect(WorkspaceController.isPendingSend(root.timeline().single), false);
    },
  );

  test(
    'socket confirmation followed by HTTP failure finishes the attempt',
    () async {
      futures.add(root.send('same text'));
      await _entered(client, 1);
      final first = client.requests.single;
      client.injected.add(RaftEvent('message:new', first.row(1)));
      first.reject();
      expect(await futures.single, true);
      futures.add(root.send('same text'));
      await _entered(client, 2);
      expect(client.requests.last.randomId, isNot(first.randomId));
    },
  );

  test(
    'old account receipt cannot retire a new account retry with the same id',
    () async {
      futures.add(root.send('old text', randomId: 'same-local-id'));
      await _entered(client, 1);
      client.selectServer('s2');
      root.server = RaftRecord({'id': 's2', 'role': 'owner'});
      root.ledger.switchServer('s2');
      root.composer.clearOwnedBy(root);
      futures.add(root.send('new text', randomId: 'same-local-id'));
      await _entered(client, 2);
      client.requests.first.accept(1);
      await futures.first;
      client.requests[1].reject();
      expect(await futures[1], false);
      futures.add(root.send('new text'));
      await _entered(client, 3);
      expect(client.requests.last.randomId, 'same-local-id');
      expect(root.timeline().every((row) => row.content != 'old text'), true);
    },
  );

  test(
    'parallel sends and a middle refusal follow accepted server sequence',
    () async {
      for (final text in ['one', 'two', 'three']) {
        futures.add(root.send(text));
      }
      await _entered(client, 3);
      root.saveDraft('still typing');
      client.requests[1].reject();
      expect(await futures[1], false);
      expect(root.drafts['c1'], 'two\nstill typing');
      client.requests[2].accept(10);
      client.requests[0].accept(11);
      await Future.wait(futures);
      expect(root.timeline().map((row) => row.content), ['three', 'one']);
      futures.add(root.send('two'));
      await _entered(client, 4);
      expect(client.requests[3].randomId, client.requests[1].randomId);
      client.requests[3].accept(12);
      expect(await futures[3], true);
      expect(root.timeline().map((row) => row.content), [
        'three',
        'one',
        'two',
      ]);
    },
  );

  test('resolving a shared DM keeps the pending membership hold', () async {
    root.channel = WorkspaceController.pendingDm(
      key: 'peer',
      serverId: 's1',
      name: 'Peer',
    );
    final pendingId = root.channel!.id;
    root.holdShared(pendingId);
    root.saveDraft('shared caption');
    final adopting = root.adoptResolvedDm(
      pendingId,
      RaftChannel({
        'id': 'real-dm',
        'type': 'dm',
        'joined': true,
        'serverId': 's1',
      }),
    );
    try {
      expect(root.shareHolds.containsKey('real-dm'), true);
      expect(root.shareHolds['real-dm'], isNull);
      expect(root.sharedBlocked(), true);
      expect(root.drafts['real-dm'], 'shared caption');
      expect(client.requests, isEmpty);
    } finally {
      await adopting;
    }
  });

  test(
    'pending display coordinates stay between their accepted neighbors',
    () async {
      for (final text in ['one', 'two', 'three']) {
        futures.add(root.send(text));
      }
      await _entered(client, 3);
      final keys = root.timeline().map(root.messageKey).toList();
      client.requests[0].accept(1);
      await futures[0];
      expect(root.timeline().map((row) => row.content), [
        'one',
        'two',
        'three',
      ]);
      expect(root.timeline().map(root.messageKey), keys);
      client.requests[2].accept(3);
      await futures[2];
      expect(root.timeline().map((row) => row.content), [
        'one',
        'two',
        'three',
      ]);
      expect(root.timeline().map(root.messageKey), keys);
    },
  );

  test(
    'a late receipt after role change cannot publish private content',
    () async {
      futures.add(root.send('owner content'));
      await _entered(client, 1);
      root.server = RaftRecord({'id': 's1', 'role': 'guest'});
      client.requests.single.accept(1);
      await futures.single;
      expect(root.ledger.messages('c1'), isEmpty);
    },
  );
  test(
    'a retired upload-limit request cannot unlock a new queued draft',
    () async {
      client.holdLimits = true;
      SharedDraftAttachment file(String name) => SharedDraftAttachment(
        reference: {'fixture': name},
        filename: name,
        mimeType: 'text/plain',
        sizeBytes: 1,
        openRead: () => Stream.value([1]),
        release: () async {},
      );
      await root.stageSharedDraft('old queued', [file('old.txt')]);
      root.saveDraft('');
      futures.add(root.send('old queued'));
      for (var i = 0; i < 20 && client.limits.isEmpty; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(client.limits, hasLength(1));
      client.selectServer('s2');
      root.server = RaftRecord({'id': 's2', 'role': 'owner'});
      root.ledger.switchServer('s2');
      root.composer.clearOwnedBy(root);
      await root.stageSharedDraft('new queued', [file('new.txt')]);
      root.saveDraft('');
      futures.add(root.send('new queued'));
      for (var i = 0; i < 20 && client.limits.length < 2; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(client.limits, hasLength(2));
      client.limits.first.complete({'maxBytes': 1024});
      expect(await futures.first, false);
      expect(root.uploadsReady(), false);
      client.limits.last.complete(null);
      expect(await futures.last, false);
      expect(client.requests, isEmpty);
      expect(root.drafts['c1'], 'new queued');
    },
  );

  test('a send never notifies a different conversation editor', () async {
    final other = _editor(client, root: root);
    other.channel = RaftChannel({'id': 'c2', 'joined': true});
    addTearDown(other.dispose);
    var changes = 0;
    other.addListener(() => changes++);
    futures.add(root.send('only channel one'));
    await _entered(client, 1);
    expect(changes, 0);
    client.requests.single.accept(1);
    await futures.single;
    expect(changes, 0);
    expect(other.timeline(), isEmpty);
  });

  test(
    'a new draft cannot reuse an older abandoned failure identity',
    () async {
      futures.add(root.send('first draft'));
      await _entered(client, 1);
      client.requests.first.reject();
      await futures.first;
      futures.add(root.send('different draft'));
      await _entered(client, 2);
      client.requests[1].accept(1);
      await futures[1];
      futures.add(root.send('first draft'));
      await _entered(client, 3);
      expect(
        client.requests[2].randomId,
        isNot(client.requests.first.randomId),
      );
    },
  );
}
