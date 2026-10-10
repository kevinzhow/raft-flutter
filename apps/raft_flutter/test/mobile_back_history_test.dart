import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_ui/raft_ui.dart';

import 'app_global_server_selector_test.dart' show RootFixture;

// Mounted ports of Source mobileBackNavigation.test.ts / .behavior.test.tsx.
// Every case drives the actual RaftApp (router, PopScope and WorkspaceView) on
// a phone viewport and presses the platform Back through the engine binding.

/// Records SystemNavigator.pop: the app leaving instead of handling Back.
List<String> watchAppExit(WidgetTester t) {
  final exits = <String>[];
  t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'SystemNavigator.pop') exits.add(call.method);
      return null;
    },
  );
  addTearDown(
    () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  return exits;
}

void main() {
  for (final theme in ['brutal', 'elegant-light']) {
    // mobileBackNavigation.test.ts:110–124 [T9]: a notification cold start at
    // a thread permalink walks thread → parent channel → server root with
    // semantic REPLACE fallbacks; the app never exits on these presses.
    testWidgets(
      '[N11] actual RaftApp $theme cold thread link: Back closes thread, then channel, then server Home without exiting',
      (t) async {
        final f = RootFixture();
        f.overrides['GET /messages/context/ma'] = (_) => {
          'messages': [
            {
              'id': 'ma',
              'channelId': 'ca',
              'seq': '1',
              'senderId': 'alice',
              'senderName': 'Alice',
              'content': 'Accepted a',
              'createdAt': '2026-10-10T00:00:00Z',
            },
          ],
        };
        await f.mount(
          t,
          theme,
          390,
          uri: Uri.parse('/s/alpha/channel/ca?thread=ca:ma'),
        );
        final exits = watchAppExit(t);
        final w = f.workspace(t);
        expect(w.location.route, RaftRoute.channel);
        expect(w.location.entityId, 'ca');
        expect(w.location.thread?.channelId, 'ca');
        expect(w.location.thread?.itemId, 'ma');
        expect(w.navigation.entries, hasLength(1));
        expect(find.byType(RaftThreadHeader), findsOneWidget);
        expect(
          find.byKey(const Key('workspace-mobile-navigation')),
          findsNothing,
        );

        expect(await t.binding.handlePopRoute(), isTrue);
        await f.flush(t);
        expect(exits, isEmpty);
        expect(w.location.toString(), '/s/alpha/channel/ca');
        expect(w.location.route, RaftRoute.channel);
        expect(find.byType(RaftThreadHeader), findsNothing);
        expect(
          t.widget<RaftChannelHeader>(find.byType(RaftChannelHeader)).name,
          'general-a',
        );
        // Cold fallback is a REPLACE: no in-app depth was invented.
        expect(w.navigation.entries, hasLength(1));
        expect(w.navigation.index, 0);

        expect(await t.binding.handlePopRoute(), isTrue);
        await f.flush(t);
        expect(exits, isEmpty);
        expect(w.location.toString(), '/s/alpha');
        expect(find.byKey(const Key('workspace-mobile-home')), findsOneWidget);
        expect(
          find.byKey(const Key('workspace-mobile-navigation')),
          findsOneWidget,
        );
        expect(find.byType(RaftChannelHeader), findsNothing);
        expect(w.navigation.entries, hasLength(1));
        expect(w.navigation.index, 0);
        await f.close(t);
      },
    );
  }

  for (final theme in ['brutal', 'elegant-light']) {
    // mobileBackNavigation.test.ts:126–145 [T10]: root → Search (PUSH) →
    // typed query (REPLACE) → result channel (PUSH); Back twice returns to the
    // exact search query and then Home, never looping back into the channel.
    testWidgets(
      '[N12] actual RaftApp $theme Home → Search query → result channel: Back returns to the query, then Home',
      (t) async {
        final f = RootFixture();
        f.overrides['GET /messages/search'] = (o) => {
          'results': [
            if (o.queryParameters['q'] == 'needle')
              {
                'id': 'ma',
                'channelId': 'ca',
                'channelName': 'general-a',
                'channelType': 'channel',
                'seq': '1',
                'senderId': 'alice',
                'senderType': 'user',
                'senderName': 'Alice',
                'content': 'Accepted needle',
                'createdAt': '2026-10-10T00:00:00Z',
              },
          ],
          'hasMore': false,
        };
        f.overrides['GET /messages/context/ma'] = (_) => {
          'messages': [
            {
              'id': 'ma',
              'channelId': 'ca',
              'seq': '1',
              'senderId': 'alice',
              'senderName': 'Alice',
              'content': 'Accepted needle',
              'createdAt': '2026-10-10T00:00:00Z',
            },
          ],
        };
        await f.mount(t, theme, 390, uri: Uri.parse('/s/alpha'));
        final exits = watchAppExit(t);
        final w = f.workspace(t);
        expect(w.location.toString(), '/s/alpha');
        final root = w.navigation.index;

        await t.tap(find.byKey(const Key('nav-search')));
        await f.flush(t);
        expect(w.location.route, RaftRoute.search);
        expect(w.navigation.index, root + 1);
        final field = find.byWidgetPredicate(
          (widget) =>
              widget is TextField &&
              widget.decoration?.hintText == 'Search messages',
        );
        await t.enterText(field, 'needle');
        await t.pump(const Duration(milliseconds: 250));
        await f.flush(t);
        // Typing replaces the Search entry's q; it adds no history depth.
        expect(w.location.query('q'), 'needle');
        expect(w.navigation.index, root + 1);
        expect(w.navigation.entries, hasLength(root + 2));

        await t.tap(find.byType(RaftSearchResultSurface).first);
        await f.flush(t);
        expect(w.location.route, RaftRoute.channel);
        expect(w.location.entityId, 'ca');
        expect(w.navigation.index, root + 2);
        expect(
          t.widget<RaftChannelHeader>(find.byType(RaftChannelHeader)).name,
          'general-a',
        );

        expect(await t.binding.handlePopRoute(), isTrue);
        await f.flush(t);
        expect(exits, isEmpty);
        expect(w.location.route, RaftRoute.search);
        expect(w.location.query('q'), 'needle');
        expect(w.navigation.index, root + 1);
        expect(find.byType(RaftChannelHeader), findsNothing);
        expect(t.widget<TextField>(field).controller!.text, 'needle');
        expect(find.byType(RaftSearchResultSurface), findsWidgets);

        expect(await t.binding.handlePopRoute(), isTrue);
        await f.flush(t);
        expect(exits, isEmpty);
        expect(w.location.toString(), '/s/alpha');
        expect(w.navigation.index, root);
        expect(find.byKey(const Key('workspace-mobile-home')), findsOneWidget);
        expect(
          find.byKey(const Key('workspace-mobile-navigation')),
          findsOneWidget,
        );
        // No loop: the forward branch is still Search → channel, untouched.
        expect(w.navigation.entries[root + 1].route, RaftRoute.search);
        expect(w.navigation.entries[root + 2].route, RaftRoute.channel);
        await f.close(t);
      },
    );
  }

  for (final theme in ['brutal', 'elegant-light']) {
    // mobileBackNavigation pure:163–182 [T14] and behavior:438–478,711–802
    // [T15]: after a restart the earlier entries are unknown, so Back takes the
    // semantic parent (REPLACE) instead of popping; one tap records one entry
    // however often the page rebuilds, so Back never lands on a duplicate.
    testWidgets(
      '[N16] actual RaftApp $theme restarted at a channel: Back uses the semantic parent; one tap is one history entry',
      (t) async {
        final f = RootFixture();
        await f.mount(t, theme, 390, uri: Uri.parse('/s/alpha/channel/ca'));
        final exits = watchAppExit(t);
        final w = f.workspace(t);
        expect(w.location.toString(), '/s/alpha/channel/ca');
        expect(w.navigation.entries, hasLength(1));
        expect(find.byType(RaftChannelHeader), findsOneWidget);

        // Unknown predecessor: semantic fallback, not a pop and not an exit.
        expect(await t.binding.handlePopRoute(), isTrue);
        await f.flush(t);
        expect(exits, isEmpty);
        expect(w.location.toString(), '/s/alpha');
        expect(w.navigation.entries, hasLength(1));
        expect(w.navigation.index, 0);
        expect(find.byKey(const Key('workspace-mobile-home')), findsOneWidget);

        // One actual row tap: exactly one PUSH, even across rebuilds and
        // repeated controller notifications.
        await t.tap(find.byKey(const ValueKey('sidebar-channel-ca')));
        await f.flush(t);
        expect(w.location.toString(), '/s/alpha/channel/ca');
        for (var i = 0; i < 3; i++) {
          w.notifyListeners();
          await f.flush(t);
        }
        expect(w.navigation.entries.map((e) => e.toString()), [
          '/s/alpha',
          '/s/alpha/channel/ca',
        ]);
        expect(w.navigation.index, 1);

        // Back on the same-URL origin entry is a real step to index 0 ...
        await t.tap(find.byKey(const Key('mobile-detail-back')));
        await f.flush(t);
        expect(w.location.toString(), '/s/alpha');
        expect(w.navigation.index, 0);
        expect(find.byType(RaftChannelHeader), findsNothing);
        expect(exits, isEmpty);
        // ... and there is no duplicated channel entry left to pop into: the
        // next Back leaves the root instead of reopening the channel.
        await t.binding.handlePopRoute();
        await f.flush(t);
        expect(exits, ['SystemNavigator.pop']);
        expect(w.location.toString(), '/s/alpha');
        expect(find.byType(RaftChannelHeader), findsNothing);
        await f.close(t);
      },
    );
  }
}
