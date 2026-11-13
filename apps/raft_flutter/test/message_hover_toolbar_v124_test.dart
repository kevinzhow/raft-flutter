import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/device_preferences.dart';
import 'package:raft_flutter/data/reaction_favorite.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'message_presentation_test.dart' show fixture, MessageAdapter;

/// Web v1.24 MessageHoverToolbar: reaction (the person's most-used emoji),
/// Reply in Thread, Forward, Save, More; a click on the reaction button
/// toggles that emoji, resting on it opens every reaction
/// (reactionFavorite.ts, useToolbarQuickReaction.ts).
void main() {
  setUp(resetReactionUsageCacheForTests);
  tearDown(DevicePreferences.reset);

  Future<(WorkspaceController, MessageAdapter)> mount(
    WidgetTester t, {
    List<Map<String, dynamic>> reactions = const [
      {
        'emoji': '👀',
        'count': 1,
        'reactorIds': ['bob'],
        'reactorNames': ['Bob'],
      },
    ],
  }) async {
    final (w, transport) = (await t.runAsync(() => fixture('member')))!;
    addTearDown(w.dispose);
    w.messageDomain.ledger.switchServer('s1');
    w.messageDomain.ledger.ingest([
      {
        'id': 'm1',
        'channelId': 'c1',
        'seq': 1,
        'senderId': 'bob',
        'senderType': 'user',
        'senderName': 'Bob',
        'createdAt': '2026-11-01T09:00:00Z',
        'content': 'Hover me',
        'reactions': reactions,
      },
    ], expectedGeneration: w.messageDomain.ledger.generation);
    w.messageDomain.visibleIds['c1'] = {'m1'};
    transport.routes['GET /agents'] = (_) => [];
    transport.routes['GET /servers/s1/members'] = (_) => [];
    transport.routes['GET /tasks'] = (_) => [];
    transport.routes['GET /messages/m1/reactions/viewer'] = (_) => {
      'serverId': 's1',
      'messageId': 'm1',
      'viewerVersion': 1,
      'reactedEmojis': [
        for (final r in reactions)
          if ((r['reactorIds'] as List).contains('alice')) r['emoji'],
      ],
    };
    transport.routes['POST /messages/m1/reactions'] = (o) => {
      'id': 'm1',
      'reactions': [
        {
          'emoji': (o.data as Map)['emoji'],
          'count': 1,
          'reactorIds': ['alice'],
          'reactorNames': ['Alice'],
        },
      ],
    };
    t.view.physicalSize = const Size(1200, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme().copyWith(platform: TargetPlatform.linux),
        home: Scaffold(
          body: RaftDensityScope(
            density: RaftDensity.desktop,
            child: RaftChatView(controller: w),
          ),
        ),
      ),
    );
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 40)),
    );
    await t.pumpAndSettle();
    return (w, transport);
  }

  Future<TestGesture> hoverRow(WidgetTester t) async {
    final mouse = await t.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(t.getCenter(find.byType(RaftMessageRow)));
    await t.pump(const Duration(milliseconds: 200));
    return mouse;
  }

  List<String> toolbarKeys(WidgetTester t) => [
    for (final e
        in find
            .descendant(
              of: find.byType(RaftMessageToolbar),
              matching: find.byWidgetPredicate(
                (w) =>
                    w.key is ValueKey<String> &&
                    (w.key as ValueKey<String>).value.startsWith('message-') &&
                    !(w.key as ValueKey<String>).value.startsWith(
                      'message-quick-react',
                    ),
              ),
            )
            .evaluate())
      (e.widget.key as ValueKey<String>).value,
  ];

  testWidgets('the buttons follow the message menu, with Forward and More', (
    t,
  ) async {
    await mount(t);
    await hoverRow(t);
    expect(toolbarKeys(t), [
      'message-react-m1',
      'message-thread-m1',
      'message-forward-m1',
      'message-save-m1',
      'message-more-m1',
    ]);
    expect(find.byTooltip('Like · hover for more reactions'), findsOneWidget);
  });

  testWidgets('a click toggles the favorite and counts it; no picker opens', (
    t,
  ) async {
    final (_, transport) = await mount(t);
    final mouse = await hoverRow(t);
    final button = t.getCenter(
      find.byKey(const ValueKey('message-quick-react-m1')),
    );
    await mouse.moveTo(button);
    await t.pump(const Duration(milliseconds: 100));
    await mouse.down(button);
    await mouse.up();
    for (var i = 0; i < 4; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await t.pump(const Duration(milliseconds: 50));
    }
    final posts = transport.calls.where(
      (c) => c.method == 'POST' && c.path == '/messages/m1/reactions',
    );
    expect(posts.map((c) => (c.data as Map)['emoji']), ['👍']);
    expect(find.byType(RaftQuickReactionPicker), findsNothing);
    expect(currentFavoriteReaction('https://example.invalid', 'alice'), '👍');
  });

  testWidgets('a tap by touch opens the picker instead of reacting', (t) async {
    final (_, transport) = await mount(t);
    await hoverRow(t);
    await t.tap(find.byKey(const ValueKey('message-quick-react-m1')));
    await t.pump();
    expect(find.byType(RaftQuickReactionPicker), findsOneWidget);
    expect(
      transport.calls.where(
        (c) => c.method == 'POST' && c.path == '/messages/m1/reactions',
      ),
      isEmpty,
    );
  });

  testWidgets('resting on the button opens every reaction', (t) async {
    await mount(t);
    final mouse = await hoverRow(t);
    await mouse.moveTo(
      t.getCenter(find.byKey(const ValueKey('message-quick-react-m1'))),
    );
    await t.pump(const Duration(milliseconds: 300));
    expect(find.byType(RaftQuickReactionPicker), findsNothing);
    await t.pump(const Duration(milliseconds: 250));
    await t.pump();
    expect(find.byType(RaftQuickReactionPicker), findsOneWidget);
  });

  testWidgets('the most-used reaction leads, pressed once you added it', (
    t,
  ) async {
    SharedPreferences.setMockInitialValues({
      reactionUsageStorageKey('https://example.invalid', 'alice'): jsonEncode({
        '🎉': {'count': 3, 'lastUsedAt': 1},
        '👍': {'count': 1, 'lastUsedAt': 2},
      }),
    });
    await t.runAsync(DevicePreferences.load);
    await mount(
      t,
      reactions: [
        {
          'emoji': '🎉',
          'count': 1,
          'reactorIds': ['alice'],
          'reactorNames': ['Alice'],
        },
      ],
    );
    await hoverRow(t);
    final button = t.widget<RaftMessageToolbarAction>(
      find.byKey(const ValueKey('message-quick-react-m1')),
    );
    expect(button.label, 'Remove 🎉');
    expect(button.pressed, isTrue);
  });

  test('usage: most count wins, ties go to the newest, 32 kept', () {
    expect(pickFavoriteReaction({}), '👍');
    expect(
      pickFavoriteReaction({
        '🎉': (count: 2, lastUsedAt: 1),
        '🔥': (count: 2, lastUsedAt: 5),
      }),
      '🔥',
    );
    var usage = <String, ReactionUsageEntry>{};
    for (var i = 0; i < 40; i++) {
      usage = addReactionUsage(usage, 'e$i', i);
    }
    expect(usage.length, reactionUsageLimit);
    expect(usage.containsKey('e0'), isFalse);
    expect(parseReactionUsage('not json'), isEmpty);
    expect(
      parseReactionUsage(
        encodeReactionUsage({'👀': (count: 1, lastUsedAt: 9)}),
      ),
      {'👀': (count: 1, lastUsedAt: 9)},
    );
  });
}
