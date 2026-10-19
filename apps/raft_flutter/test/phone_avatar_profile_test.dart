import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/external_identity.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';

import 'message_presentation_test.dart' show MessageAdapter;
import 'workspace_source_location_contract_test.dart' show pageFixture;
import 'support/app_services_fixture.dart';

/// Web `MessageItem` -> `SenderAvatar` button -> `openProfile`: on a phone the
/// profile (`profile=` slot) is a full-page overlay in the real
/// WorkspaceView (never just a location change), Back returns to the chat at
/// the same scroll offset; folded and desktop widths show it as well (a
/// side column on desktop).
void main() {
  Map<String, dynamic> row(String id, int seq, Map<String, dynamic> extra) => {
    'id': id,
    'channelId': 'c1',
    'seq': '$seq',
    'messageType': 'chat',
    'content': 'Hello $id',
    'createdAt': '2026-06-22T02:30:00.000Z',
    ...extra,
  };

  // Newest last. m1..m6 filler so the list scrolls on a phone; the sender
  // rows sit near the bottom, `mention` pings an agent.
  List<Map<String, dynamic>> rows() => [
    for (var i = 1; i <= 14; i++)
      row('f$i', i, {
        'senderId': 'u2',
        'senderType': 'user',
        'senderName': 'Dana',
        'content': 'Filler message number $i with some body text to wrap',
      }),
    row('mh', 15, {
      'senderId': 'bob',
      'senderType': 'user',
      'senderName': 'Bob',
      'content': 'human row',
    }),
    row('ma', 16, {
      'senderId': 'a1',
      'senderType': 'agent',
      'senderName': 'Cindy',
      'content': 'agent row',
    }),
    row('mx', 17, {
      'senderId': 'slack-ada',
      'senderType': 'external_projection',
      'senderName': 'Ada',
      'content': 'external row',
      'externalAuthor': {
        'displayName': 'Ada Lovelace',
        'provider': 'slack',
        'actorKind': 'human',
        'workspaceName': 'Acme Product Studio',
      },
    }),
    row('mm', 18, {
      'senderId': 'u2',
      'senderType': 'user',
      'senderName': 'Dana',
      'content': 'ping @cindy please',
      'mentions': [
        {'type': 'agent', 'id': 'a1', 'name': 'cindy'},
      ],
    }),
    row('mt', 19, {
      'senderId': 'u2',
      'senderType': 'user',
      'senderName': 'Dana',
      'content': 'thread parent',
      'replyCount': 1,
    }),
  ];

  Future<void> frames(WidgetTester t, [int n = 14]) async {
    for (var i = 0; i < n; i++) {
      await t.pump(const Duration(milliseconds: 50));
    }
  }

  Future<(WorkspaceController, MessageAdapter)> mount(
    WidgetTester t,
    Size size,
  ) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final (w, api) = await pageFixture(t, section: 'chat');
    api.routes['GET /messages/channel/c1'] = (_) => {'messages': rows()};
    api.routes['GET /channels/c1/available-mentions'] = (_) => {
      'humans': [],
      'agents': [],
    };
    const agent = {
      'id': 'a1',
      'name': 'cindy',
      'displayName': 'Cindy',
      'status': 'active',
      'runtime': 'claude',
      'model': 'sonnet',
    };
    api.routes['GET /agents'] = (_) => [agent];
    api.routes['GET /servers/s1/members'] = (_) => [
      {'userId': 'bob', 'name': 'bob', 'displayName': 'Bob', 'role': 'member'},
      {'userId': 'u2', 'name': 'dana', 'displayName': 'Dana', 'role': 'member'},
    ];
    api.routes['GET /channels/c1/threads/mt'] = (_) => {
      'threadChannelId': 't1',
    };
    api.routes['GET /messages/channel/t1'] = (_) => {
      'messages': [
        row('mt', 1, {
          'channelId': 't1',
          'senderId': 'u2',
          'senderType': 'user',
          'senderName': 'Dana',
          'content': 'thread parent',
        }),
      ],
    };
    api.routes['GET /channels/threads/followers'] = (_) => {
      'threads': [
        {
          'threadChannelId': 't1',
          'canManage': true,
          'agents': [
            {
              'id': 'a1',
              'name': 'Cindy',
              'displayName': 'Cindy',
              'status': 'active',
              'avatarUrl': 'pixel:robot',
              'isCurrentServer': true,
              'canRemove': true,
            },
          ],
        },
      ],
    };
    api.routes['GET /agents/a1'] = (_) => agent;
    api.routes['GET /servers/s1/machines'] = (_) => {'machines': []};
    api.routes['GET /agents/a1/skills'] = (_) => {
      'global': [],
      'workspace': [],
    };
    api.routes['GET /servers/s1/members/bob/profile'] = (_) => {
      'userId': 'bob',
      'displayName': 'Bob',
    };
    await t.runAsync(() => w.entityDirectory.preload());
    w.messageDomain.ledger.ingest(
      rows(),
      expectedGeneration: w.messageDomain.ledger.generation,
    );
    w.messageDomain.visibleIds['c1'] = {
      for (final r in rows()) r['id'] as String,
    };
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(RaftFamily.elegant),
        home: withAppServices(
          WorkspaceView(
            controller: w,
            appearance: RaftAppearance(light: RaftFamily.elegant),
            onAppearance: (_) async {},
            onLogout: () async {},
          ),
        ),
      ),
    );
    await frames(t, 30);
    return (w, api);
  }

  double chatOffset(WidgetTester t) {
    final scrollables = [
      for (final e in find.byType(Scrollable).evaluate())
        if (((e as StatefulElement).state as ScrollableState).position.axis ==
            Axis.vertical)
          e.state as ScrollableState,
    ];
    // The chat timeline is the tallest vertical scrollable.
    scrollables.sort(
      (a, b) =>
          b.position.maxScrollExtent.compareTo(a.position.maxScrollExtent),
    );
    return scrollables.first.position.pixels;
  }

  Finder avatar(String id) => find.byKey(ValueKey('sender-avatar-$id'));

  for (final size in const [Size(390, 844), Size(816, 900), Size(1280, 800)]) {
    final phone = size.width < 600;
    testWidgets(
      'sender avatars open the profile view (${size.width.toInt()})',
      (t) async {
        final (w, _) = await mount(t, size);
        expect(find.byKey(const Key('profile-panel')), findsNothing);
        await t.drag(find.byType(RaftMessageRow).first, const Offset(0, 150));
        await frames(t, 10);
        final scrolled = chatOffset(t);
        expect(scrolled, isNot(0), reason: 'the chat is scrolled up from live');

        Future<void> expectProfile(Key key) async {
          expect(find.byKey(const Key('profile-panel')), findsOneWidget);
          expect(find.byKey(key), findsOneWidget);
          if (phone) {
            // A full page: the profile fills the viewport.
            final rect = t.getRect(find.byKey(const Key('profile-panel')));
            expect(rect.width, size.width);
            expect(rect.height, greaterThan(size.height * 0.8));
          }
        }

        Future<void> back(double? before) async {
          Finder inPanel(String tip) => find.descendant(
            of: find.byKey(const Key('profile-panel')),
            matching: find.byTooltip(tip),
          );
          // A page leads with Back (phone / folded); the side column closes.
          final control = [
            for (final tip in ['Back', 'Close profile', 'Close'])
              if (inPanel(tip).evaluate().isNotEmpty) inPanel(tip),
          ];
          expect(control, isNotEmpty);
          await t.tap(control.first.first);
          await frames(t, 20);
          expect(find.byKey(const Key('profile-panel')), findsNothing);
          expect(w.location.profile, isNull);
          if (before != null) {
            expect(chatOffset(t), before, reason: 'scroll position kept');
          }
        }

        for (final (id, key) in const [
          ('mh', ValueKey('profile-human-bob')),
          ('ma', ValueKey('profile-agent-a1')),
          ('mx', ValueKey('profile-external-mx')),
        ]) {
          expect(avatar(id), findsOneWidget, reason: id);
          await t.ensureVisible(avatar(id));
          await frames(t, 4);
          final offset = chatOffset(t);
          await t.tap(avatar(id));
          await frames(t, 20);
          await expectProfile(key);
          final panel = find.byKey(const Key('profile-panel'));
          Finder named(String text) =>
              find.descendant(of: panel, matching: find.text(text));
          if (key == const ValueKey('profile-external-mx')) {
            expect(find.byType(ExternalIdentityDetailPanel), findsOneWidget);
            expect(named('Ada Lovelace'), findsWidgets);
            expect(named('Acme Product Studio'), findsOneWidget);
          } else if (key == const ValueKey('profile-agent-a1')) {
            expect(named('Cindy'), findsWidgets);
          } else {
            expect(named('Bob'), findsWidgets);
          }
          await back(offset);
        }

        // An @mention chip opens that agent's profile.
        final mention = find.textContaining('@cindy', findRichText: true).first;
        await t.ensureVisible(mention);
        await frames(t, 4);
        final mentionOffset = chatOffset(t);
        await t.tapAt(t.getCenter(mention));
        await frames(t, 20);
        await expectProfile(const ValueKey('profile-agent-a1'));
        expect(w.location.profile?.id, 'a1');
        await back(mentionOffset);

        // A thread follower row opens the agent's profile over the thread.
        await t.runAsync(
          () => w.messageDomain.threads.openThread(
            RaftMessage(rows().firstWhere((r) => r['id'] == 'mt')),
          ),
        );
        await frames(t, 30);
        expect(w.location.thread, isNotNull);
        final trigger = find.byKey(
          const Key('thread-followers-header-trigger'),
        );
        expect(trigger, findsOneWidget);
        await t.tap(trigger);
        await frames(t, 20);
        await t.tap(find.text('Cindy').last);
        await frames(t, 20);
        await expectProfile(const ValueKey('profile-agent-a1'));
        // Closing returns to the thread, not past it.
        await back(null);
        expect(find.byKey(const Key('profile-panel')), findsNothing);
        expect(w.location.thread, isNotNull);
        expect(trigger, findsOneWidget);
      },
    );
  }

  testWidgets('the system back gesture closes a phone profile page', (t) async {
    final (w, _) = await mount(t, const Size(390, 844));
    await t.tap(avatar('ma'));
    await frames(t, 20);
    expect(find.byKey(const ValueKey('profile-agent-a1')), findsOneWidget);
    expect(find.byKey(const Key('profile-panel')), findsOneWidget);
    await t.binding.handlePopRoute();
    await frames(t, 20);
    expect(find.byKey(const Key('profile-panel')), findsNothing);
    expect(w.location.profile, isNull);
    expect(avatar('ma'), findsOneWidget, reason: 'the chat is back');
  });

  testWidgets(
    'wide: a tap outside the profile panel dismisses it, non-blocking',
    (t) async {
      final (w, _) = await mount(t, const Size(1280, 800));
      final panel = find.byKey(const Key('profile-panel'));
      Future<void> open(String id) async {
        await t.ensureVisible(avatar(id));
        await frames(t, 4);
        await t.tap(avatar(id));
        await frames(t, 20);
      }

      await open('mh');
      expect(panel, findsOneWidget);
      expect(w.location.profile?.id, 'bob');
      final entries = w.navigation.entries.length;
      final rect = t.getRect(panel);

      // Inside the panel: nothing closes.
      await t.tapAt(rect.center);
      await frames(t, 10);
      expect(panel, findsOneWidget);

      // Another avatar retargets the profile (replace, not close + push).
      await t.ensureVisible(avatar('ma'));
      await frames(t, 4);
      await t.tap(avatar('ma'));
      await frames(t, 20);
      expect(panel, findsOneWidget);
      expect(w.location.profile?.kind, RaftProfileKind.agent);
      expect(w.location.profile?.id, 'a1');
      expect(w.navigation.entries.length, entries);
      expect(find.byKey(const ValueKey('profile-agent-a1')), findsOneWidget);

      // The blank area of the timeline (right of the message text, left of the
      // panel) closes it like the X.
      await t.tapAt(Offset(rect.left - 24, 420));
      await frames(t, 20);
      expect(panel, findsNothing);
      expect(w.location.profile, isNull);

      // Reopen, then tap a control outside: it still does its job (a mention
      // chip opens the agent profile) rather than only closing the panel.
      await open('mh');
      expect(w.location.profile?.id, 'bob');
      final mention = find.textContaining('@cindy', findRichText: true).first;
      await t.ensureVisible(mention);
      await frames(t, 4);
      await t.tapAt(t.getCenter(mention));
      await frames(t, 20);
      expect(w.location.profile?.id, 'a1');
      expect(panel, findsOneWidget);

      // A drag (scroll) outside is not a tap.
      await t.dragFrom(Offset(rect.left - 200, 500), const Offset(0, 80));
      await frames(t, 10);
      expect(panel, findsOneWidget);
    },
  );
}
