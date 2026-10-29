import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';

typedef _Receipt = ({RaftMessage message, Map<String, dynamic> receipt});

Map<String, dynamic> _row(String channel, int seq, {String? content}) => {
  'id': '$channel-$seq',
  'channelId': channel,
  'seq': '$seq',
  'content': content ?? '$channel row $seq',
  'senderId': 'other',
  'senderType': 'user',
  'createdAt': '2026-10-15T00:00:00Z',
};

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://window-ports.invalid',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'alice'});
    selectServer('s');
  }
  final injected = StreamController<RaftEvent>.broadcast(sync: true);
  final calls = <String>[];
  Completer<Map<String, dynamic>>? page;
  Completer<_Receipt>? sending;
  Completer<dynamic>? threadLookup;
  String? sendingId;
  @override
  Stream<RaftEvent> get events => injected.stream;
  void emit(String event, Map<String, dynamic> payload) =>
      injected.add(RaftEvent(event, payload));
  @override
  void connect() {}
  @override
  void joinChannel(String id) {}
  @override
  Future<Map<String, dynamic>> messagePage(
    String id, {
    int limit = 50,
    BigInt? before,
    BigInt? after,
  }) async {
    calls.add('page:$id');
    if (page != null) return page!.future;
    return {
      'messages': [_row(id, 1), _row(id, 2)],
      'threadSummariesByParentMessageId': {},
    };
  }

  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    calls.add('GET:$path');
    if (path == '/agents') {
      return [
        {'id': 'agent', 'name': 'Agent', 'status': 'active'},
      ];
    }
    if (path.endsWith('/sidebar-order')) {
      return {
        'pinned': ['beta'],
      };
    }
    if (path == '/channels/alpha/threads/alpha-2') {
      if (threadLookup != null) return threadLookup!.future;
      return {'threadChannelId': 'thread-alpha'};
    }
    if (path == '/messages/context/alpha-2') {
      return {
        'messages': [_row('alpha', 2)],
      };
    }
    return [];
  }

  @override
  Future<dynamic> post(String path, {dynamic data}) async {
    calls.add('POST:$path');
    if (path.endsWith('/read')) {
      return {'maxReadSeq': 100, 'readStateVersion': 1};
    }
    return {};
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
    calls.add('send:$channelId');
    sendingId = randomId;
    sending = Completer<_Receipt>();
    return sending!.future;
  }
}

Future<void> _until(bool Function() complete) async {
  for (var i = 0; i < 100 && !complete(); i++) {
    await Future<void>.delayed(Duration.zero);
  }
  expect(complete(), isTrue, reason: 'The fixture operation did not complete.');
}

void main() {
  late _Client client;
  late WorkspaceController w;
  setUp(() async {
    client = _Client();
    w = WorkspaceController(client)
      ..server = RaftRecord({'id': 's', 'role': 'owner'})
      ..channels = [
        for (final id in ['alpha', 'beta'])
          RaftChannel({'id': id, 'type': 'private', 'joined': true}),
      ];
    w.messageDomain.ledger.switchServer('s');
    await w.selectChannel(w.channels.last, autoRead: false, navigate: false);
    await w.selectChannel(w.channels.first, autoRead: false, navigate: false);
  });
  tearDown(() async {
    w.dispose();
    await client.injected.close();
  });

  test(
    'reads reuse row versions and stable scoped objects without requests',
    () {
      final before = List.of(client.calls);
      final window = w.messageDomain.messageWindow!;
      expect(identical(window, w.messageDomain.messageWindow), isTrue);
      expect(identical(window, w.messageWindows.channel('alpha')), isTrue);
      expect(window.rows, w.messageDomain.messages);
      expect(window.timeline, w.messageDomain.timeline());
      expect(
        identical(window.rows.first, w.messageDomain.messages.first),
        isTrue,
      );
      expect(() => window.rows.clear(), throwsUnsupportedError);
      expect(window.channelId, 'alpha');
      expect(window.scope.channelId, 'alpha');
      expect(window.loading, w.messageDomain.state.channelLoading);
      expect(window.hasMore, w.messageDomain.state.hasMore);
      expect(window.historyLimited, w.messageDomain.state.historyLimited);
      expect(client.calls, before);
    },
  );

  test('directory, sidebar and another channel produce zero current-window changes', () async {
    await w.entityDirectory.preload();
    final window = w.messageDomain.messageWindow!;
    final beta = w.messageWindows.channel('beta')!;
    final rows = window.rows;
    var changes = 0, betaChanges = 0, workspaceChanges = 0;
    window.changes.addListener(() => changes++);
    beta.changes.addListener(() => betaChanges++);
    w.addListener(() => workspaceChanges++);

    client.emit('agent:seen', {
      'agentId': 'agent',
      'lastSeenAt': '2026-10-15T01:00:00Z',
    });
    expect(
      w.entityDirectory.agent('agent')!['lastSeenAt'],
      '2026-10-15T01:00:00Z',
    );
    expect(
      changes,
      0,
      reason: 'The directory heartbeat is not a message change.',
    );
    client.emit('pinned:updated', {});
    await _until(() => w.sidebarOrder['pinned'] is List);
    expect(w.sidebarOrder['pinned'], ['beta']);
    expect(workspaceChanges, greaterThan(0));
    expect(
      changes,
      0,
      reason: 'The accepted sidebar update is not a window change.',
    );
    client.emit('message:new', _row('beta', 3));
    expect(w.messageDomain.ledger.contains('beta', 'beta-3'), isTrue);
    expect(beta.rows.last.id, 'beta-3');
    expect(betaChanges, 1);
    expect(changes, 0, reason: 'The other channel must stay isolated.');
    expect(identical(rows, window.rows), isTrue);

    client.emit('message:new', _row('alpha', 3));
    expect(changes, 1, reason: 'A visible new message must notify.');
    expect(window.rows.last.id, 'alpha-3');
    client.emit('message:updated', _row('alpha', 3, content: 'Edited'));
    expect(changes, 2, reason: 'An accepted edit must notify.');
    expect(window.rows.last.content, 'Edited');
    expect(betaChanges, 1);
  });

  test(
    'load and boundary changes notify, unrelated windows stay quiet',
    () async {
      final window = w.messageDomain.messageWindow!;
      final beta = w.messageWindows.channel('beta')!;
      var changes = 0, betaChanges = 0;
      window.changes.addListener(() => changes++);
      beta.changes.addListener(() => betaChanges++);
      client.page = Completer<Map<String, dynamic>>();
      final opening = w.selectChannel(
        w.channel!,
        autoRead: false,
        navigate: false,
      );
      expect(window.loading, isTrue);
      expect(changes, 1);
      client.page!.complete({
        'messages': [_row('alpha', 1), _row('alpha', 2)],
        'historyLimited': true,
      });
      await opening;
      expect(window.loading, isFalse);
      expect(window.historyLimited, isTrue);
      expect(window.rows, w.messageDomain.messages);
      expect(changes, greaterThan(1));
      expect(betaChanges, 0);
    },
  );

  test(
    'pending and accepted projections use the same rows as the legacy API',
    () async {
      final window = w.messageDomain.messageWindow!;
      final sending = w.send('Pending window', randomId: 'window-send');
      await _until(() => client.sending != null);
      expect(window.timeline.last.content, 'Pending window');
      expect(
        identical(window.timeline.last, w.messageDomain.timeline().last),
        isTrue,
      );
      final key = w.messageDomain.messageKey(window.timeline.last);
      final row = {
        ..._row('alpha', 3),
        'content': 'Pending window',
        'randomId': client.sendingId,
      };
      client.emit('message:new', row);
      expect(
        window.timeline.where((row) => row.content == 'Pending window'),
        hasLength(1),
      );
      client.sending!.complete((
        message: RaftMessage(row),
        receipt: <String, dynamic>{},
      ));
      expect(await sending, isTrue);
      expect(
        identical(window.timeline.last, w.messageDomain.timeline().last),
        isTrue,
      );
      expect(w.messageDomain.messageKey(window.timeline.last), key);
    },
  );

  test(
    'a retained channel window keeps its rows after the source moves',
    () async {
      final alpha = w.messageDomain.messageWindow!;
      expect(identical(alpha, w.messageWindows.channel('alpha')), isTrue);
      await w.selectChannel(w.channels.last, autoRead: false, navigate: false);
      expect(identical(w.messageWindows.channel('alpha'), alpha), isTrue);
      expect(alpha.rows.every((row) => row.channelId == 'alpha'), isTrue);
      expect(w.messageDomain.messageWindow!.channelId, 'beta');
      expect(alpha.visible, isFalse);
    },
  );

  test(
    'thread identity survives resolution and reopening without sending reads',
    () async {
      await w.openThreadIdentity(
        parentChannelId: 'alpha',
        parentMessageId: 'alpha-2',
        navigate: false,
      );
      final window = w.messageDomain.threadWindow!;
      expect(window.scope.parentMessageId, 'alpha-2');
      expect(window.channelId, 'thread-alpha');
      expect(window.rows, w.replies);
      expect(window.timeline, w.messageDomain.timeline(thread: true));
      final reads = client.calls.where((call) => call.endsWith('/read')).length;
      final presentation = Object();
      w.setChatTabPresentation(presentation, false);
      expect(window.visible, isFalse);
      w.releaseChatTabPresentation(presentation);
      w.setConversationPresentation(presentation, main: true, thread: false);
      expect(window.visible, isFalse);
      w.releaseConversationPresentation(presentation);
      expect(window.visible, isTrue);
      w.closeThread();
      expect(window.visible, isFalse);
      expect(window.retired, isFalse);
      expect(window.rows.map((row) => row.id), [
        'thread-alpha-1',
        'thread-alpha-2',
      ]);
      await w.openThreadIdentity(
        parentChannelId: 'alpha',
        parentMessageId: 'alpha-2',
        navigate: false,
      );
      expect(identical(window, w.messageDomain.threadWindow), isTrue);
      expect(
        client.calls.where((call) => call.endsWith('/read')).length,
        reads,
      );
    },
  );

  test(
    'the same parent window survives unresolved, failed and retried lookup',
    () async {
      client.threadLookup = Completer<dynamic>();
      final failed = w.openThreadIdentity(
        parentChannelId: 'alpha',
        parentMessageId: 'alpha-2',
        navigate: false,
      );
      await _until(
        () => client.calls.contains('GET:/channels/alpha/threads/alpha-2'),
      );
      final window = w.messageDomain.threadWindow!;
      expect(window.channelId, isNull);
      expect(window.loading, isTrue);
      expect(window.resolving, isTrue);
      client.threadLookup!.completeError(
        const RaftApiException('Fixture lookup failed', status: 500),
      );
      await failed;
      expect(window.loading, isFalse);
      expect(window.error, isNotNull);
      expect(window.rows, isEmpty);

      client.threadLookup = null;
      await w.openThreadIdentity(
        parentChannelId: 'alpha',
        parentMessageId: 'alpha-2',
        navigate: false,
      );
      expect(identical(window, w.messageDomain.threadWindow), isTrue);
      expect(window.channelId, 'thread-alpha');
      expect(window.error, isNull);
      expect(window.rows, w.replies);
    },
  );

  test('old references retire on channel revocation, account replacement and disposal', () async {
    final alpha = w.messageDomain.messageWindow!;
    final beta = w.messageWindows.channel('beta')!;
    client.emit('channel:removed', {'channelId': 'beta'});
    expect(beta.retired, isTrue);
    expect(beta.rows, isEmpty);
    expect(beta.visible, isFalse);
    expect(alpha.retired, isFalse);
    client.user = RaftRecord({'id': 'other-account'});
    // A late reader cannot expose data under a replacement identity even
    // before the owner has delivered its next notification.
    expect(alpha.retired, isTrue);
    expect(alpha.rows, isEmpty);
    expect(
      w.messageDomain.messageWindow,
      isNull,
      reason: 'Old accepted rows do not admit a new identity.',
    );
    w.notifyListeners();
    await w.selectChannel(w.channel!, autoRead: false, navigate: false);
    expect(w.messageDomain.messageWindow, isNotNull);
    expect(identical(w.messageDomain.messageWindow, alpha), isFalse);
    w.dispose();
    expect(w.messageWindows.channel('alpha'), isNull);
    expect(alpha.rows, isEmpty);
  });
}
