import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_flutter/features/custom_protocol_link.dart';
import 'package:raft_ui/raft_ui.dart';

import 'message_presentation_test.dart' show fixture;

/// Web v1.21.12 message row: the `data-followed-by` / `data-follows-system`
/// rhythm markers written by the list, and the custom-protocol link
/// confirmation (task #734). Row geometry itself is pinned to the generated
/// raft-ui recipe in packages/raft_ui/test/message_row_recipe_test.dart.
void main() {
  Map<String, dynamic> message(
    String id,
    int seq,
    String sender, {
    String type = 'user',
    String messageType = 'chat',
    String content = 'Body',
    String createdAt = '2026-06-22T02:30:00Z',
  }) => {
    'id': id,
    'channelId': 'c1',
    'seq': seq,
    'senderId': sender,
    'senderType': type,
    'senderName': 'Name $sender',
    'messageType': messageType,
    'sourceServerId': 's1',
    'content': content,
    'createdAt': createdAt,
  };

  Future<void> mountChat(
    WidgetTester t,
    List<Map<String, dynamic>> rows,
  ) async {
    final (w, transport) = (await t.runAsync(() => fixture('owner')))!;
    addTearDown(w.dispose);
    w.messageDomain.ledger.switchServer('s1');
    w.messageDomain.ledger.ingest(
      rows,
      expectedGeneration: w.messageDomain.ledger.generation,
    );
    w.messageDomain.visibleIds['c1'] = {
      for (final r in rows) r['id'] as String,
    };
    transport.routes['GET /agents'] = (_) => [];
    transport.routes['GET /servers/s1/members'] = (_) => [
      for (final id in {for (final r in rows) r['senderId'] as String})
        {'userId': id, 'name': id, 'role': 'member'},
    ];
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(RaftFamily.elegant),
        home: Scaffold(body: RaftChatView(controller: w)),
      ),
    );
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 40)),
    );
    await t.pumpAndSettle();
  }

  RaftMessageTile tile(WidgetTester t, String id) =>
      t.widget<RaftMessageTile>(find.byKey(ValueKey('message-$id')));

  testWidgets('rows carry the followed-by and follows-system markers', (
    t,
  ) async {
    await mountChat(t, [
      message('a1', 1, 'alice'),
      message('a2', 2, 'alice'),
      message('b1', 3, 'bob'),
      message('sys', 4, 'system', type: 'system', messageType: 'system'),
      message('c1', 5, 'bob'),
    ]);
    // a1 is followed by a continuation of the same sender; a2 by another
    // sender's row (a new group); a system note always breaks the run; the
    // last row has nothing after it.
    expect(tile(t, 'a1').followedBy, RaftMessageFollowedBy.compact);
    expect(tile(t, 'a2').followedBy, RaftMessageFollowedBy.group);
    expect(tile(t, 'b1').followedBy, RaftMessageFollowedBy.group);
    expect(tile(t, 'c1').followedBy, isNull);
    expect(tile(t, 'a1').followsSystem, isFalse);
    expect(tile(t, 'c1').followsSystem, isTrue);
    expect(tile(t, 'b1').continuation, isFalse);
    expect(tile(t, 'a2').continuation, isTrue);
    expect(t.takeException(), isNull);
  });

  testWidgets('the rhythm tightens a followed row and keeps the last row', (
    t,
  ) async {
    await mountChat(t, [
      message('a1', 1, 'alice'),
      message('a2', 2, 'alice'),
      message('b1', 3, 'bob'),
      message('c1', 4, 'carol'),
    ]);
    double height(String id) =>
        t.getSize(find.byKey(ValueKey('message-$id'))).height;
    // Elegant desktop rows. Padding below: 2 before a continuation (a1),
    // 6 before a new group (b1), 12 at the list end (c1); the body margin
    // below (6) is dropped whenever a row follows.
    expect(height('b1') - height('a1'), 6 - 2);
    expect(height('c1') - height('b1'), (12 + 6) - 6);
    expect(t.takeException(), isNull);
  });

  group('custom protocol links', () {
    Future<List<String>> mount(WidgetTester t) async {
      final launched = <String>[];
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/url_launcher'),
        (call) async {
          if (call.method == 'launch' || call.method == 'canLaunch') {
            if (call.method == 'launch') {
              launched.add((call.arguments as Map)['url'] as String);
            }
            return true;
          }
          return null;
        },
      );
      addTearDown(
        () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/url_launcher'),
          null,
        ),
      );
      await mountChat(t, [
        message(
          'l1',
          1,
          'alice',
          content: '[note](obsidian://open?vault=work&file=Plan)',
        ),
        message('l2', 2, 'bob', content: '[site](https://example.org/page)'),
        message('l3', 3, 'carol', content: '[bad](javascript:alert(1))'),
      ]);
      return launched;
    }

    testWidgets('an obsidian link asks first and opens only when confirmed', (
      t,
    ) async {
      final launched = await mount(t);
      await t.tap(find.text('note', findRichText: true));
      await t.pumpAndSettle();
      expect(find.text('Open external link?'), findsOneWidget);
      expect(
        find.text(
          'This link uses the obsidian protocol and will open in an external application:',
        ),
        findsOneWidget,
      );
      expect(find.text('obsidian://open?vault=work&file=Plan'), findsOneWidget);
      expect(launched, isEmpty);
      await t.tap(find.text('Cancel'));
      await t.pumpAndSettle();
      expect(find.text('Open external link?'), findsNothing);
      expect(launched, isEmpty);
      // The prompt is not a one-off: it is shown again, and Open link opens.
      await t.tap(find.text('note', findRichText: true));
      await t.pumpAndSettle();
      await t.tap(find.text('Open link'));
      await t.pumpAndSettle();
      expect(find.text('Open external link?'), findsNothing);
      expect(launched, ['obsidian://open?vault=work&file=Plan']);
      expect(t.takeException(), isNull);
    });

    testWidgets('https opens at once and other schemes are not links', (
      t,
    ) async {
      final launched = await mount(t);
      await t.tap(find.text('site', findRichText: true));
      await t.pumpAndSettle();
      expect(find.text('Open external link?'), findsNothing);
      expect(launched, ['https://example.org/page']);
      await t.tap(find.text('bad', findRichText: true));
      await t.pumpAndSettle();
      expect(find.text('Open external link?'), findsNothing);
      expect(launched, hasLength(1));
      expect(t.takeException(), isNull);
    });

    test('only the allowlisted custom schemes are custom links', () {
      expect(isAllowedCustomProtocol(Uri.parse('obsidian://open')), isTrue);
      expect(isAllowedCustomProtocol(Uri.parse('OBSIDIAN://open')), isTrue);
      for (final other in [
        'javascript:alert(1)',
        'file:///etc/passwd',
        'vscode://x',
        'https://example.org',
        'mailto:a@b.c',
      ]) {
        expect(
          isAllowedCustomProtocol(Uri.parse(other)),
          isFalse,
          reason: other,
        );
      }
    });
  });
}
