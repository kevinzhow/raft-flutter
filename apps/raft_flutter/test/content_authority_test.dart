import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/platform/content_coordinator.dart';
import 'package:raft_flutter/platform/content_target.dart';
import 'package:raft_flutter/platform/native_notifications.dart';

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://fixture.example',
        sessionStore: MemorySessionStore(),
      );
  final stream = StreamController<RaftEvent>.broadcast(sync: true);
  Completer<List<RaftRecord>>? memberships;
  bool denied = false;
  Map<String, dynamic>? canonical;
  int reads = 0;
  @override
  Stream<RaftEvent> get events => stream.stream;
  @override
  Future<List<RaftRecord>> servers() async => memberships == null
      ? [
          RaftRecord({'id': 's', 'slug': 'team'}),
        ]
      : memberships!.future;
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    reads++;
    if (denied) throw const RaftApiException('Forbidden');
    if (path.startsWith('/channels/')) return {'id': 'c', 'serverId': 's'};
    return {
      'messages': [
        {'id': 'm', 'channelId': 'c'},
      ],
      if (canonical != null) 'canonicalTarget': canonical,
    };
  }
}

class _Workspace extends WorkspaceController {
  _Workspace(super.client);
  final jumps = <String>[];
  @override
  Future<void> jumpToMessage(
    String id,
    String? message, {
    bool navigate = true,
  }) async {
    jumps.add('$id/$message');
  }
}

class _Notifications extends NativeNotificationService {
  _Notifications() {
    enabled = true;
    permitted = true;
    available = true;
  }
  final sent = <String>[];
  @override
  bool get receivesMessages => true;
  @override
  Future<void> initialize() async {}
  @override
  Future<void> bind(String? scope) async {}
  @override
  Future<void> show({
    required String title,
    required String body,
    required String payload,
  }) async {
    sent.add(payload);
  }
}

void main() {
  late _Client c;
  late _Workspace w;
  late _Notifications n;
  late NativeContentCoordinator links;
  setUp(() async {
    c = _Client()..user = RaftRecord({'id': 'alice'});
    c.selectServer('s');
    w = _Workspace(c)..foreground = false;
    n = _Notifications();
    links = NativeContentCoordinator(
      notifications: n,
      links: const Stream.empty(),
    );
    await links.init();
    links.bindWorkspace(w);
  });
  tearDown(() async {
    await links.dispose();
    w.dispose();
    await c.stream.close();
  });
  test('fresh membership/channel/message authority required before content navigation', () async {
    await links.navigate(
      const ContentTarget(serverSlug: 'team', channelId: 'c', messageId: 'm'),
    );
    expect(w.jumps, ['c/m']);
    expect(c.reads, 2);
    c.denied = true;
    await links.navigate(
      const ContentTarget(serverId: 's', channelId: 'c', messageId: 'm'),
    );
    expect(w.jumps, ['c/m']);
  });
  test(
    'other server and contradictory thread identity cannot navigate',
    () async {
      await links.navigate(
        const ContentTarget(serverId: 'other', channelId: 'c', messageId: 'm'),
      );
      c.canonical = {
        'kind': 'thread',
        'messageId': 'm',
        'threadParentMessageId': 'different',
        'threadChannelId': 't',
      };
      await links.navigate(
        const ContentTarget(
          serverId: 's',
          channelId: 'c',
          messageId: 'm',
          parentMessageId: 'p',
          threadId: 't',
        ),
      );
      expect(w.jumps, isEmpty);
    },
  );
  test('late request after account switch cannot navigate', () async {
    c.memberships = Completer();
    final pending = links.navigate(
      const ContentTarget(serverId: 's', channelId: 'c', messageId: 'm'),
    );
    c.user = RaftRecord({'id': 'bob'});
    w.setError('changed');
    c.memberships!.complete([
      RaftRecord({'id': 's'}),
    ]);
    await pending;
    expect(w.jumps, isEmpty);
    expect(c.reads, 0);
  });
  test(
    'notification tap payload binds origin principal and active server',
    () async {
      for (final change in [
        {'origin': 'https://other.example'},
        {'principal': 'bob'},
        {'serverId': 'other'},
      ]) {
        n.onTap!(
          jsonEncode({
            'origin': c.origin,
            'principal': 'alice',
            'serverId': 's',
            'uri': 'raft://v1/servers/s/channels/c/messages/m',
            ...change,
          }),
        );
      }
      await Future<void>.delayed(Duration.zero);
      expect(w.jumps, isEmpty);
      n.onTap!(
        jsonEncode({
          'origin': c.origin,
          'principal': 'alice',
          'serverId': 's',
          'uri': 'raft://v1/servers/s/channels/c/messages/m',
        }),
      );
      await Future<void>.delayed(Duration.zero);
      expect(w.jumps, ['c/m']);
    },
  );
  test('only eligible server notification event delivers, duplicates/read surface suppress', () async {
    final p = {
      'serverId': 's',
      'kind': 'channel',
      'channelId': 'c',
      'messageId': 'm',
      'title': 'Raft',
      'body': 'Server plain preview',
    };
    c.stream.add(RaftEvent('message:new', p));
    c.stream.add(RaftEvent('notification:push', {...p, 'serverId': 'other'}));
    await Future<void>.delayed(Duration.zero);
    expect(n.sent, isEmpty);
    c.stream.add(RaftEvent('notification:push', p));
    c.stream.add(RaftEvent('notification:push', p));
    await Future<void>.delayed(Duration.zero);
    expect(n.sent, hasLength(1));
    w.foreground = true;
    w.section = 'chat';
    w.channel = RaftChannel({'id': 'c'});
    c.stream.add(RaftEvent('notification:push', {...p, 'messageId': 'm2'}));
    await Future<void>.delayed(Duration.zero);
    expect(n.sent, hasLength(1));
  });
}
