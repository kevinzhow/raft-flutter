import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/conversation_finder_model.dart';
import 'package:raft_flutter/features/sidebar_conversation_finder.dart';

import 'quick_switcher_workspace_test.dart' show mount;

final finder = find.byKey(const Key('sidebar-conversation-finder'));
final input = find.byKey(const Key('sidebar-conversation-finder-input'));
final results = find.byKey(const Key('sidebar-conversation-finder-results'));
Finder row(String key) =>
    find.byKey(ValueKey('sidebar-conversation-finder-$key'));

Future<void> type(WidgetTester t, String text) async {
  await t.tap(input);
  await t.pump();
  await t.enterText(input, text);
  await t.pumpAndSettle();
}

void main() {
  group('model (Web conversationFinderModel)', () {
    RaftChannel ch(
      String id,
      String name, {
      String type = 'channel',
      String? d,
    }) =>
        RaftChannel({'id': id, 'name': name, 'type': type, 'description': ?d});
    final built = buildFinderResults(
      channels: [
        ch('c1', 'general', d: ' team chat '),
        ch('c2', 'secret', type: 'private'),
        ch('d9', 'raw', type: 'dm'),
        ch('t1', 'thread', type: 'thread'),
      ],
      dms: [
        RaftChannel({
          'id': 'dm-bob',
          'type': 'dm',
          'name': 'raw',
          'peerId': 'bob',
          'peerType': 'user',
          'peerName': 'bob',
          'peerDisplayName': 'Bob B',
        }),
        RaftChannel({
          'id': 'dm-bot',
          'type': 'dm',
          'peerId': 'a1',
          'peerType': 'agent',
          'peerName': 'robot',
        }),
      ],
      agents: [
        {'id': 'a1', 'name': 'robot'},
        {'id': 'a2', 'name': 'helper', 'displayName': 'Helper'},
      ],
      members: [
        {'userId': 'me', 'name': 'me'},
        {'userId': 'bob', 'name': 'bob', 'displayName': 'Bob B'},
        {'userId': 'eve', 'name': 'eve', 'displayName': 'Eve E'},
        {'userId': 'sam', 'name': 'sam'},
      ],
      currentUserId: 'me',
      agentTag: 'Agent',
    );

    test('DMs and threads are not channels; each conversation once', () {
      expect(
        [for (final r in built) r.key],
        [
          'channel:c1',
          'channel:c2',
          'dm:dm-bob',
          'dm:dm-bot',
          // a1 has a DM: it is not listed again; bob and the user are not either.
          'agent:a2',
          'human:eve',
          'human:sam',
        ],
      );
      final byKey = {for (final r in built) r.key: r};
      expect(byKey['channel:c1']!.sublabel, 'team chat');
      expect(byKey['channel:c2']!.private, isTrue);
      expect(byKey['dm:dm-bob']!.label, 'Bob B');
      expect(byKey['dm:dm-bot']!.sublabel, 'Agent');
      expect(byKey['agent:a2']!.label, 'Helper');
      expect(byKey['human:eve']!.sublabel, '@eve');
      expect(byKey['human:sam']!.sublabel, isNull);
    });

    test(
      'ranking: names first, an empty query lists nothing, capped at 20',
      () {
        final entries = finderSearchEntries(built);
        expect(rankFinderResults('', entries), isEmpty);
        expect(rankFinderResults('  ', entries), isEmpty);
        expect(
          [for (final r in rankFinderResults('gen', entries)) r.key].first,
          'channel:c1',
        );
        // The description is a weaker field than the name.
        expect(rankFinderResults('team', entries).single.key, 'channel:c1');
        final many = finderSearchEntries([
          for (var i = 0; i < 40; i++)
            ConversationMatch(kind: 'channel', id: 'c$i', label: 'room $i'),
        ]);
        expect(rankFinderResults('room', many), hasLength(finderMaxRendered));
      },
    );
  });

  testWidgets('a pointer desktop shows the box above the chat list', (t) async {
    await mount(t);
    expect(finder, findsOneWidget);
    expect(find.text('Find a conversation…'), findsOneWidget);
    expect(results, findsNothing);
    // Pinned above the list: it sits above the first sidebar row.
    expect(
      t.getTopLeft(finder).dy,
      lessThan(t.getTopLeft(find.byKey(const Key('nav-saved'))).dy),
    );
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('touch platforms and the phone Home list have no box', (t) async {
    await mount(t);
    expect(finder, findsNothing);
  });

  testWidgets('a narrow pointer window (phone layout) has no box', (t) async {
    await mount(t, size: const Size(390, 844));
    expect(finder, findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('typing lists matches over the list and keeps the field '
      'focused; Enter opens the highlighted one', (t) async {
    final (_, w) = await mount(t);
    await type(t, 'des');
    expect(results, findsOneWidget);
    expect(row('channel:c-design'), findsOneWidget);
    expect(find.text('Design work'), findsOneWidget);
    expect(t.widget<TextField>(input).focusNode!.hasFocus, isTrue);
    // The list floats over the sidebar below the box.
    expect(
      t.getTopLeft(results).dy,
      greaterThanOrEqualTo(t.getBottomLeft(finder).dy),
    );
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await t.pumpAndSettle();
    expect(w.channel!.id, 'c-design');
    expect(results, findsNothing);
    expect(t.widget<TextField>(input).controller!.text, isEmpty);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('arrow keys move the highlight, Escape closes and clears', (
    t,
  ) async {
    final (_, w) = await mount(t);
    // "o" matches ops and the people/agents containing an o, in rank order.
    await type(t, 'o');
    expect(results, findsOneWidget);
    final first = w.channel!.id;
    await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await t.pump();
    await t.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await t.pump();
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pumpAndSettle();
    expect(results, findsNothing);
    expect(t.widget<TextField>(input).controller!.text, isEmpty);
    expect(w.channel!.id, first);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('a press outside the field and the list closes it; a press on '
      'a result opens it', (t) async {
    final (_, w) = await mount(t);
    await type(t, 'ops');
    expect(results, findsOneWidget);
    await t.tapAt(const Offset(900, 450));
    await t.pumpAndSettle();
    expect(results, findsNothing);
    expect(w.channel!.id, 'c-general');

    await type(t, 'ops');
    await t.tap(row('channel:c-ops'));
    await t.pumpAndSettle();
    expect(w.channel!.id, 'c-ops');
    expect(results, findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('no match says so', (t) async {
    await mount(t);
    await type(t, 'zzzzzz');
    expect(find.text('No matches'), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('a person with a DM is the DM row; an agent without one gets a '
      'new DM', (t) async {
    final (client, w) = await mount(t);
    w.dms = [
      RaftChannel({
        'id': 'dm-bob',
        'type': 'dm',
        'peerId': 'bob',
        'peerType': 'user',
        'peerDisplayName': 'Bob',
        'joined': true,
      }),
    ];
    w.notifyListeners();
    await t.pump();
    await type(t, 'bob');
    // Bob has a DM: that DM represents him, there is no second "human" row.
    expect(row('dm:dm-bob'), findsOneWidget);
    expect(row('human:bob'), findsNothing);
    await t.tap(row('dm:dm-bob'));
    await t.pumpAndSettle();
    expect(w.channel!.id, 'dm-bob');
    expect(client.calls.where((c) => c == 'POST:/channels/dm'), isEmpty);

    await type(t, 'cindy');
    expect(row('agent:a-cindy'), findsOneWidget);
    expect(find.text('Agent'), findsOneWidget);
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await t.pumpAndSettle();
    expect(client.calls.where((c) => c == 'POST:/channels/dm'), hasLength(1));
    expect(w.channel!.id, 'dm-new');
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('the parity switch hides it', (t) async {
    SidebarFinderLayer.hiddenForParity = true;
    addTearDown(() => SidebarFinderLayer.hiddenForParity = false);
    await mount(t);
    expect(finder, findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));
}
