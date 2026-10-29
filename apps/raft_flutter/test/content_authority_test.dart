import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/platform/content_coordinator.dart';
import 'package:raft_flutter/platform/content_target.dart';
import 'package:raft_flutter/platform/native_notifications.dart';
import 'package:raft_flutter/platform/windows_tray.dart';

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
    bool replaceEntry = false,
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
    int? unread,
    bool quiet = false,
    String? conversation,
  }) async {
    sent.add(payload);
  }
}

class _WindowsNotifications extends _Notifications {
  int presentations = 0;
  @override
  TargetPlatform get platform => TargetPlatform.windows;
  @override
  Future<void> presentWindow() async {
    presentations++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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
  test(
    'share wake bypasses content navigation even before account restoration',
    () {
      var wakes = 0;
      links.onIncomingShare = () => wakes++;
      links.bindWorkspace(null);
      links.receiveLink(Uri.parse('raft://share/${'a' * 32}'));
      expect(wakes, 1);
      expect(c.reads, 0);
      expect(w.jumps, isEmpty);
      links.bindWorkspace(w);
      links.receiveLink(Uri.parse('raft://share/${'a' * 32}'));
      links.receiveLink(
        Uri.parse('raft://share/${'a' * 32}?path=/tmp/private'),
      );
      links.receiveLink(Uri.parse('raft://oauth/callback?code=fixture'));
      expect(wakes, 2);
      expect(c.reads, 0);
      expect(w.jumps, isEmpty);
    },
  );
  test(
    'Windows taps restore the window and retain message authorization',
    () async {
      await links.dispose();
      final windows = _WindowsNotifications();
      n = windows;
      links = NativeContentCoordinator(
        notifications: n,
        links: const Stream.empty(),
      );
      await links.init();
      links.bindWorkspace(w);
      expect(links.desktop, isNotNull);
      n.onTap!('raft-notification-test');
      await Future<void>.delayed(Duration.zero);
      expect(windows.presentations, 1);
      expect(w.jumps, isEmpty);
      final payload = jsonEncode({
        'origin': c.origin,
        'principal': 'alice',
        'serverId': 's',
        'uri': 'raft://v1/servers/s/channels/c/messages/m',
      });
      c.denied = true;
      n.onTap!(payload);
      await Future<void>.delayed(Duration.zero);
      expect(w.jumps, isEmpty);
      c.denied = false;
      n.onTap!(payload);
      await Future<void>.delayed(Duration.zero);
      expect(w.jumps, ['c/m']);
      expect(windows.presentations, 3);
    },
  );
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
  test(
    'foreground app suppresses OS alerts even when workspace is covered',
    () async {
      // A server picker covers the workspace without backgrounding the app.
      w.foreground = false;
      links.didChangeAppLifecycleState(AppLifecycleState.resumed);
      c.stream.add(
        RaftEvent('notification:push', {
          'serverId': 's',
          'kind': 'channel',
          'channelId': 'c',
          'messageId': 'picker',
          'title': 'Raft',
          'body': 'preview',
        }),
      );
      await Future<void>.delayed(Duration.zero);
      expect(n.sent, isEmpty);
      expect(await links.pollBackground(), true);
    },
  );

  test('Windows tray hide backgrounds a resumed workspace and opens the delivery gate', () async {
    await links.dispose();
    const channel = MethodChannel('test/windows-tray');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => {'available': true},
    );
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    n = _WindowsNotifications();
    links = NativeContentCoordinator(
      notifications: n,
      links: const Stream.empty(),
      tray: WindowsTray(platform: TargetPlatform.windows, channel: channel),
    );
    await links.init();
    links.bindWorkspace(w);
    links.didChangeAppLifecycleState(AppLifecycleState.resumed);
    w.setForeground(true);
    final push = {
      'serverId': 's',
      'kind': 'channel',
      'channelId': 'c',
      'messageId': 'visible',
      'title': 'Raft',
      'body': 'Synthetic preview',
    };
    c.stream.add(RaftEvent('notification:push', push));
    await Future<void>.delayed(Duration.zero);
    expect(n.sent, isEmpty);
    final hidden = Completer<void>();
    messenger.handlePlatformMessage(
      channel.name,
      const StandardMethodCodec().encodeMethodCall(
        const MethodCall('hidden', true),
      ),
      (_) => hidden.complete(),
    );
    await hidden.future;
    expect(links.appForeground, false);
    expect(w.foreground, false);
    expect(n.deliveryAllowed!(), true);
    expect(w.jumps, isEmpty);
    // ShowWindow + SetForegroundWindow restores Flutter's resumed lifecycle.
    // The root reacts to onForegroundChanged and restores workspace visibility.
    links.onForegroundChanged = () => w.setForeground(links.appForeground);
    links.didChangeAppLifecycleState(AppLifecycleState.resumed);
    expect(links.appForeground, true);
    expect(w.foreground, true);
    expect(n.deliveryAllowed!(), false);
  });

  test('only eligible server notification event delivers, duplicates/foreground suppress', () async {
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
    w.section = 'tasks';
    c.stream.add(RaftEvent('notification:push', {...p, 'messageId': 'm3'}));
    await Future<void>.delayed(Duration.zero);
    expect(n.sent, hasLength(1));
    expect(await links.pollBackground(), true);
  });
}
