import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/platform/linux_desktop_identity.dart';
import 'package:raft_flutter/platform/native_notifications.dart';

import 'native_notifications_test.dart' show NotificationPluginFixture;

// Implement the plugin contract without invoking its real Linux constructor,
// which eagerly opens libc and creates a desktop notification manager.
class _LinuxServer implements LinuxFlutterLocalNotificationsPlugin {
  _LinuxServer({this.markup = false, this.offline = false});
  final bool markup, offline;
  @override
  Future<LinuxServerCapabilities> getCapabilities() async {
    if (offline) throw StateError('no notification server');
    return LinuxServerCapabilities(
      otherCapabilities: const {},
      body: true,
      bodyHyperlinks: markup,
      bodyImages: markup,
      bodyMarkup: markup,
      iconMulti: false,
      iconStatic: true,
      persistence: false,
      sound: false,
      actions: true,
      actionIcons: false,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

String _payload(String uri) => jsonEncode({
  'origin': 'https://api.test',
  'principal': 'u1',
  'serverId': 's1',
  'uri': uri,
});

const _channel = 'raft://v1/servers/s1/channels/c1/messages/';
const _scope = 'https://api.test\nu1\ns1';

Future<(NativeNotificationService, NotificationPluginFixture)> _service({
  LinuxFlutterLocalNotificationsPlugin? server,
  LinuxNotificationDetails Function()? details,
}) async {
  final plugin = NotificationPluginFixture()
    ..linux = server ?? _LinuxServer()
    ..initialized.complete(true);
  final service = NativeNotificationService(
    plugin: plugin,
    platform: TargetPlatform.linux,
    linuxDetails: details,
  );
  await service.bind(_scope);
  return (service, plugin);
}

void main() {
  test('Linux receives messages with the system owning the switch', () async {
    final (service, plugin) = await _service();
    expect(service.receivesMessages, isTrue);
    expect(service.systemManaged, isTrue);
    // No app-owned opt-in or permission prompt, like macOS after a grant.
    expect(service.available, isTrue);
    expect(service.permitted, isTrue);
    expect(service.enabled, isTrue);
    expect(plugin.settings!.linux!.defaultActionName, isNotEmpty);
    await service.bind(null);
    expect(service.enabled, isFalse);
  });

  test('Linux alert stays off without a notification server', () async {
    final plugin = NotificationPluginFixture()..initialized.complete(false);
    final service = NativeNotificationService(
      plugin: plugin,
      platform: TargetPlatform.linux,
    );
    await service.bind(_scope);
    expect(service.available, isFalse);
    expect(service.enabled, isFalse);
    await service.show(
      title: 'a',
      body: 'b',
      payload: _payload('${_channel}m1'),
    );
    expect(plugin.sent, isEmpty);
  });

  test('a conversation is one replaceable notification', () async {
    final (service, plugin) = await _service();
    Future<void> send(String uri) =>
        service.show(title: 't', body: 'b', payload: _payload(uri));
    await send('${_channel}m1');
    await send('${_channel}m2');
    await send('raft://v1/servers/s1/channels/c2/messages/m3');
    await send('raft://v1/servers/s1/dms/d1/messages/m4');
    await send('raft://v1/servers/s1/dms/d1/messages/m5');
    await send(
      'raft://v1/servers/s1/channels/c1/threads/t1'
      '?parentMessageId=p1&messageId=r1',
    );
    await send(
      'raft://v1/servers/s1/channels/c1/threads/t1'
      '?parentMessageId=p1&messageId=r2',
    );
    final ids = plugin.ids;
    expect(ids, hasLength(7));
    expect(ids[0], ids[1], reason: 'same channel replaces in place');
    expect(ids[3], ids[4], reason: 'same DM replaces in place');
    expect(ids[5], ids[6], reason: 'same thread replaces in place');
    expect({ids[0], ids[2], ids[3], ids[5]}, hasLength(4));
    // A different account or server never replaces this one's alert.
    await service.bind('https://api.test\nu2\ns1');
    await service.show(
      title: 't',
      body: 'b',
      payload: _payload('${_channel}m1'),
    );
    expect(plugin.ids.last, isNot(ids[0]));
  });

  test('macOS keeps one notification per message', () async {
    final plugin = NotificationPluginFixture()..initialized.complete(true);
    final service = NativeNotificationService(
      plugin: plugin,
      platform: TargetPlatform.macOS,
    );
    expect(service.receivesMessages, isTrue);
    service
      ..enabled = true
      ..permitted = true
      ..available = true;
    await service.bind(_scope);
    service
      ..enabled = true
      ..permitted = true
      ..available = true;
    for (final id in ['m1', 'm2']) {
      await service.show(
        title: 't',
        body: 'b',
        payload: _payload('$_channel$id'),
      );
    }
    expect(plugin.ids.toSet(), hasLength(plugin.ids.length));
  });

  test('alerts carry the app icon, IM category and launcher id', () async {
    final (service, plugin) = await _service(
      details: () => linuxMessageNotificationDetails(
        iconPath: '/opt/raft/data/icons/raft.png',
        desktopEntry: 'app.raft.raft_flutter',
      ),
    );
    await service.show(
      title: 'Alice',
      body: 'hello',
      payload: _payload('${_channel}m1'),
    );
    final linux = plugin.details.single!.linux!;
    expect(
      (linux.icon as FilePathLinuxIcon).path,
      '/opt/raft/data/icons/raft.png',
    );
    expect(linux.category, LinuxNotificationCategory.imReceived);
    expect(linux.urgency, LinuxNotificationUrgency.normal);
    final hint = linux.customHints!.single;
    expect(hint.name, 'desktop-entry');
    expect(hint.value.value, 'app.raft.raft_flutter');
    // The test notification uses the same presentation.
    expect(await service.test(), isTrue);
    expect(
      plugin.details.last!.linux!.category,
      LinuxNotificationCategory.imReceived,
    );
  });

  test('message text is escaped only for servers that render markup', () async {
    const text = 'a <b>bold</b> & <a href="x">link</a>';
    for (final markup in [true, false]) {
      final (service, plugin) = await _service(
        server: _LinuxServer(markup: markup),
      );
      await service.show(
        title: '<i>title</i>',
        body: text,
        payload: _payload('${_channel}m1'),
      );
      expect(
        plugin.bodies.single,
        markup
            ? 'a &lt;b&gt;bold&lt;/b&gt; &amp; &lt;a href="x"&gt;link&lt;/a&gt;'
            : text,
      );
    }
    final (service, plugin) = await _service(
      server: _LinuxServer(offline: true),
    );
    await service.show(
      title: 't',
      body: '<b>',
      payload: _payload('${_channel}m1'),
    );
    expect(plugin.bodies.single, '<b>');
    expect(linuxEscapeMarkup('&lt;'), '&amp;lt;');
  });

  group('icon and launcher resolution', () {
    test('uses the bundled icon next to the executable', () {
      String? bundled(Map<String, String> env) => linuxAppIconPath(
        environment: env,
        executable: '/opt/raft/raft_flutter',
        exists: (p) => p == '/opt/raft/data/$linuxIconRelative',
      );
      expect(
        bundled({'HOME': '/home/a'}),
        '/opt/raft/data/icons/hicolor/256x256/apps/app.raft.raft_flutter.png',
      );
      expect(
        linuxAppIconPath(
          environment: {},
          executable: '/opt/raft/raft_flutter',
          exists: (_) => false,
        ),
        isNull,
      );
    });

    test('prefers the registered copy while running from an AppImage', () {
      final installed = '/home/a/.local/share/$linuxIconRelative';
      expect(
        linuxAppIconPath(
          environment: {'HOME': '/home/a', 'APPIMAGE': '/x/Raft.AppImage'},
          executable: '/tmp/.mount_x/raft/raft_flutter',
          exists: (_) => true,
        ),
        installed,
      );
      // A native install ignores a stale user copy.
      expect(
        linuxAppIconPath(
          environment: {'HOME': '/home/a'},
          executable: '/opt/raft/raft_flutter',
          exists: (_) => true,
        ),
        '/opt/raft/data/$linuxIconRelative',
      );
    });

    test('the desktop-entry hint follows the registered launcher', () {
      const file =
          '/home/a/.local/share/applications/'
          '$linuxAppImageDesktopId.desktop';
      expect(
        linuxDesktopEntryId(
          environment: {'HOME': '/home/a', 'APPIMAGE': '/x/R.AppImage'},
          exists: (p) => p == file,
        ),
        linuxAppImageDesktopId,
      );
      expect(
        linuxDesktopEntryId(
          environment: {'HOME': '/home/a', 'APPIMAGE': '/x/R.AppImage'},
          exists: (_) => false,
        ),
        linuxApplicationId,
      );
      expect(
        linuxDesktopEntryId(
          environment: {'HOME': '/home/a'},
          exists: (_) => true,
        ),
        linuxApplicationId,
      );
    });

    test('XDG_DATA_HOME wins and must be absolute', () {
      expect(linuxDataHome({'XDG_DATA_HOME': '/d', 'HOME': '/h'}), '/d');
      expect(
        linuxDataHome({'XDG_DATA_HOME': 'rel', 'HOME': '/h'}),
        '/h/.local/share',
      );
      expect(linuxDataHome({}), isNull);
    });
  });
}
