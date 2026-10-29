import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/platform/desktop_title_bar.dart';
import 'package:raft_flutter/platform/window_title.dart';
import 'package:raft_ui/raft_ui.dart';

import 'flutter_test_config.dart' show leakDebt;
import 'workspace_source_location_contract_test.dart' show pageFixture;

void main() {
  // Leak debt (other): the controller's process-wide notifier, as in
  // desktop_title_bar_test.dart (docs/development.md, Leak tracking).
  leakDebt(const ['ValueNotifier<DesktopTitleBarState>']);
  group('Web getServerRouteDocumentTitle', () {
    test('channel, thread and plain workspace titles', () {
      String title({String? channel, String? thread, String name = 'Acme'}) =>
          serverRouteWindowTitle(
            serverName: name,
            serverSlug: 'acme-slug',
            channelLabel: channel,
            threadChannelLabel: thread,
          );
      expect(title(), 'Acme | Raft');
      expect(title(channel: '#general'), '#general | Acme | Raft');
      expect(
        title(channel: '#general', thread: '#general'),
        '#general - Thread | Acme | Raft',
      );
      // A thread names its parent channel even when the page is not that
      // channel; blank labels are as good as none.
      expect(title(thread: '@ada'), '@ada - Thread | Acme | Raft');
      expect(title(channel: '  ', thread: ''), 'Acme | Raft');
      // A blank workspace name falls back to the slug.
      expect(title(name: '   '), 'acme-slug | Raft');
    });

    test('DMs read @peer, channels #name, unknown or unnamed nothing', () {
      expect(windowTitleChannelLabel(null), isNull);
      expect(
        windowTitleChannelLabel(
          RaftChannel({'type': 'dm', 'name': 'x', 'peerName': 'ada'}),
        ),
        '@ada',
      );
      expect(
        windowTitleChannelLabel(
          RaftChannel({
            'type': 'dm',
            'name': 'x',
            'peerName': 'ada',
            'peerDisplayName': 'Ada L',
          }),
        ),
        '@Ada L',
      );
      expect(
        windowTitleChannelLabel(RaftChannel({'type': 'dm', 'name': 'raw'})),
        '@raw',
      );
      expect(
        windowTitleChannelLabel(
          RaftChannel({'type': 'channel', 'name': ' a '}),
        ),
        '#a',
      );
      expect(
        windowTitleChannelLabel(RaftChannel({'type': 'channel', 'name': ' '})),
        isNull,
      );
    });
  });

  testWidgets('the OS window follows the open conversation and thread', (
    tester,
  ) async {
    final titles = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel(DesktopTitleBarController.channelName),
      (call) async {
        if (call.method == 'setTitle') {
          titles.add((call.arguments as Map)['title'] as String);
        }
        return call.method == 'status'
            ? {'height': 0.0, 'fullscreen': false}
            : null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel(DesktopTitleBarController.channelName),
        null,
      ),
    );
    final (w, _) = await pageFixture(tester, section: 'chat');
    w.channels = [
      RaftChannel({'id': 'c1', 'name': 'general', 'joined': true}),
      RaftChannel({'id': 'c2', 'name': 'design', 'joined': true}),
    ];
    w.dms = [
      RaftChannel({
        'id': 'd1',
        'type': 'dm',
        'name': 'raw',
        'peerName': 'ada',
        'joined': true,
      }),
    ];
    w.navigation.navigate(RaftLocation.parse('/s/demo/channel/c1'));
    final controller = DesktopTitleBarController(
      platform: TargetPlatform.linux,
      web: false,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: DesktopTitleBar(
          controller: controller,
          workspace: w,
          child: const SizedBox.expand(),
        ),
      ),
    );
    expect(titles.last, '#general | Alpha | Raft');

    w.navigation.navigate(RaftLocation.parse('/s/demo/dm/d1'));
    w.notifyListeners();
    await tester.pump();
    expect(titles.last, '@ada | Alpha | Raft');

    w.navigation.navigate(
      RaftLocation.parse('/s/demo/channel/c2?thread=c2%3Aroot'),
    );
    w.notifyListeners();
    await tester.pump();
    expect(titles.last, '#design - Thread | Alpha | Raft');

    // A page that is no conversation names the workspace only; an unchanged
    // title is not sent twice.
    w.navigation.navigate(RaftLocation.parse('/s/demo/tasks'));
    w.notifyListeners();
    await tester.pump();
    final count = titles.length;
    expect(titles.last, 'Alpha | Raft');
    w.notifyListeners();
    await tester.pump();
    expect(titles, hasLength(count));

    // Leaving the workspace restores the plain app title.
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: DesktopTitleBar(
          controller: controller,
          child: const SizedBox.expand(),
        ),
      ),
    );
    expect(titles.last, 'Raft');
  });

  testWidgets('phone and web shells never address a runner', (tester) async {
    var calls = 0;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel(DesktopTitleBarController.channelName),
      (call) async {
        calls++;
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel(DesktopTitleBarController.channelName),
        null,
      ),
    );
    for (final controller in [
      DesktopTitleBarController(platform: TargetPlatform.android, web: false),
      DesktopTitleBarController(platform: TargetPlatform.linux, web: true),
    ]) {
      await controller.setTitle('anything');
    }
    expect(calls, 0);
  });
}
