import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_flutter/features/external_identity.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'message_presentation_test.dart' show fixture;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'profile slot: opening pushes, retargeting and closing replace',
    () async {
      final (w, _) = await fixture('owner');
      addTearDown(w.dispose);
      w.location; // binds the initial entry
      final before = w.navigation.entries.length;
      final revision = w.navigationRevision;
      w.openProfile(RaftProfileKind.agent, 'a1');
      expect(w.location.profile?.kind, RaftProfileKind.agent);
      expect(w.location.profile?.id, 'a1');
      expect(w.navigation.entries.length, before + 1);
      w.openProfile(RaftProfileKind.human, 'u1');
      expect(w.location.profile?.kind, RaftProfileKind.human);
      expect(w.navigation.entries.length, before + 1);
      w.openProfile(RaftProfileKind.agent, 'a2', agentTab: 'activity');
      expect(w.location.agentTab, 'activity');
      w.closeProfile();
      expect(w.location.profile, isNull);
      expect(w.location.agentTab, isNull);
      // A profile never retires a pending message window.
      expect(w.navigationRevision, revision);
    },
  );

  test('an external author keeps its frozen attribution', () async {
    final (w, _) = await fixture('owner');
    addTearDown(w.dispose);
    w.openProfile(
      RaftProfileKind.external,
      'm1',
      channelId: 'c1',
      externalAuthor: {'displayName': 'Ada', 'provider': 'slack'},
    );
    expect(w.location.profile?.kind, RaftProfileKind.external);
    expect(w.location.profile?.channelId, 'c1');
    expect(w.externalProfile('m1')?['displayName'], 'Ada');
    // Without a channel anchor an external profile cannot be restored.
    w.closeProfile();
    w.openProfile(RaftProfileKind.external, 'm2');
    expect(w.location.profile, isNull);
  });

  testWidgets('the external detail panel names provider, kind and workspace', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final (w, _) = (await tester.runAsync(() => fixture('owner')))!;
    addTearDown(w.dispose);
    var closed = 0, back = 0;
    Widget host({VoidCallback? onBack}) => MaterialApp(
      theme: raftTheme(RaftFamily.elegant),
      home: Scaffold(
        body: ExternalIdentityDetailPanel(
          controller: w,
          profile: const {
            'displayName': 'Ada Lovelace',
            'provider': 'slack',
            'actorKind': 'guest',
            'workspaceName': 'Acme Product Studio',
          },
          onClose: () => closed++,
          onBack: onBack,
        ),
      ),
    );
    await tester.pumpWidget(host());
    expect(find.text('Ada Lovelace'), findsWidgets);
    expect(find.text('Slack · Guest'), findsWidgets);
    expect(find.text('Acme Product Studio'), findsOneWidget);
    expect(find.text('FROM'), findsOneWidget);
    expect(find.text('External identity'), findsOneWidget);
    await tester.tap(find.byTooltip('Close'));
    expect(closed, 1);
    // A page-stack back leads the header (phone).
    await tester.pumpWidget(host(onBack: () => back++));
    await tester.tap(find.byKey(const Key('external-mobile-back')));
    expect(back, 1);
    // Unknown providers read as sent, unknown kinds as external participant.
    expect(
      externalIdentitySubtitle(
        tester.element(find.byType(ExternalIdentityDetailPanel)),
        'matrix',
        null,
      ),
      'matrix · External participant',
    );
    expect(RaftExternalInitials.initials(' ada lovelace'), 'AD');
  });

  Future<dynamic> mountChat(
    WidgetTester tester,
    List<Map<String, dynamic>> rows,
  ) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final (w, api) = (await tester.runAsync(() => fixture('owner')))!;
    addTearDown(w.dispose);
    w.messageDomain.ledger.switchServer('s1');
    w.messageDomain.ledger.ingest(
      rows,
      expectedGeneration: w.messageDomain.ledger.generation,
    );
    w.messageDomain.visibleIds['c1'] = {
      for (final r in rows) r['id'] as String,
    };
    api.routes['GET /servers/s1/setup-projection'] = (_) => {
      'phase': 'complete',
      'surface': 'complete',
      'blocksChat': false,
    };
    api.routes['GET /channels/threads/followed'] = (_) => {'threads': []};
    api.routes['GET /agents'] = (_) => [];
    api.routes['GET /servers/s1/members'] = (_) => [];
    api.routes['GET /channels/c1/available-mentions'] = (_) => {
      'humans': [],
      'agents': [],
    };
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(RaftFamily.elegant),
        home: Scaffold(body: RaftChatView(controller: w)),
      ),
    );
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    return w;
  }

  Map<String, dynamic> row(String id, int seq, Map<String, dynamic> extra) => {
    'id': id,
    'channelId': 'c1',
    'seq': '$seq',
    'messageType': 'chat',
    'content': 'Hello $id',
    'createdAt': '2026-06-22T02:30:00.000Z',
    ...extra,
  };

  testWidgets('tapping a sender avatar opens that sender\'s profile panel', (
    tester,
  ) async {
    final w = await mountChat(tester, [
      row('m1', 1, {
        'senderId': 'bob',
        'senderType': 'user',
        'senderName': 'Bob',
      }),
      row('m2', 2, {
        'senderId': 'cindy',
        'senderType': 'agent',
        'senderName': 'Cindy',
      }),
      row('m3', 3, {
        'senderId': 'slack-ada',
        'senderType': 'external_projection',
        'senderName': 'Ada',
        'externalAuthor': {
          'displayName': 'Ada Lovelace',
          'provider': 'slack',
          'actorKind': 'human',
        },
      }),
    ]);
    final avatars = find.byType(RaftAvatarButton);
    expect(avatars, findsNWidgets(3));
    // Rows are newest-first in the widget tree.
    await tester.tap(find.byKey(const ValueKey('sender-avatar-m1')));
    await tester.pump();
    expect(w.location.profile?.kind, RaftProfileKind.human);
    expect(w.location.profile?.id, 'bob');
    await tester.tap(find.byKey(const ValueKey('sender-avatar-m2')));
    await tester.pump();
    expect(w.location.profile?.kind, RaftProfileKind.agent);
    expect(w.location.profile?.id, 'cindy');
    await tester.tap(find.byKey(const ValueKey('sender-avatar-m3')));
    await tester.pump();
    expect(w.location.profile?.kind, RaftProfileKind.external);
    expect(w.location.profile?.id, 'm3');
    expect(w.location.profile?.channelId, 'c1');
    expect(w.externalProfile('m3')?['displayName'], 'Ada Lovelace');
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('a mention opens the profile panel instead of a dialog', (
    tester,
  ) async {
    final w = await mountChat(tester, [
      row('m1', 1, {
        'senderId': 'bob',
        'senderType': 'user',
        'senderName': 'Bob',
        'content': 'ping @cindy now',
        'mentions': [
          {'type': 'agent', 'id': 'cindy', 'name': 'cindy'},
        ],
      }),
    ]);
    await tester.tapAt(
      tester.getCenter(find.textContaining('@cindy', findRichText: true).first),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.byType(AlertDialog), findsNothing);
    expect(w.location.profile?.kind, RaftProfileKind.agent);
    expect(w.location.profile?.id, 'cindy');
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  });
}
