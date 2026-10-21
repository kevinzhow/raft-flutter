import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/quick_switcher.dart';
import 'package:raft_ui/raft_ui.dart';

import 'quick_switcher_test.dart' show catalog;

void main() {
  testWidgets('the overlay matches the Web message hit badges and labels', (
    t,
  ) async {
    QuickSwitcherData read() => QuickSwitcherData(
      catalog: catalog(),
      visited: const [],
      agents: const [],
      members: const [],
      origin: 'https://public-fixture.invalid',
      dms: const [
        {'id': 'dm-bob', 'peerDisplayName': 'Bob Builder', 'peerName': 'bob'},
      ],
    );
    final changes = ValueNotifier(0);
    addTearDown(changes.dispose);
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(RaftFamily.elegant),
        home: Scaffold(
          body: Material(
            type: MaterialType.transparency,
            child: QuickSwitcher(
              listenable: changes,
              data: read,
              onClose: () {},
              onOpenEntity: (_, _) {},
              onOpenMessage: (_, _) {},
              onSearchAll: (_) {},
              searchMessages: (_) async => [
                {
                  'id': 'm1',
                  'channelId': 'dm-bob',
                  'channelType': 'dm',
                  'channelName': 'raw-dm-name',
                  'channelArchivedAt': '2026-01-01T00:00:00Z',
                  'senderName': 'Bob',
                  'snippet': 'needle one',
                  'createdAt': '2020-01-01T00:00:00Z',
                },
                {
                  'id': 'm2',
                  'channelId': 'c-ops',
                  'channelType': 'channel',
                  'channelName': 'ops',
                  'senderName': 'Bob',
                  'snippet': 'needle two',
                },
              ],
            ),
          ),
        ),
      ),
    );
    await t.enterText(find.byType(TextField).first, 'needle');
    await t.pump(const Duration(milliseconds: 250));
    await t.pump();
    final badges = t.widgetList<RaftBadge>(find.byType(RaftBadge)).toList();
    expect(
      badges.singleWhere((b) => b.label.toUpperCase() == 'ARCHIVED').uppercase,
      isTrue,
    );
    expect(
      badges.singleWhere((b) => b.label == 'Upgrade to view').uppercase,
      isFalse,
    );
    expect(find.text('Upgrade to view'), findsOneWidget);
    expect(find.text('@Bob Builder'), findsOneWidget);
    expect(find.text('unknown time'), findsOneWidget);
  });
}
