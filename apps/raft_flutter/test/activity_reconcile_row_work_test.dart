import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/activity_card_row.dart';
import 'package:raft_flutter/features/resource_view.dart';
import 'package:raft_ui/raft_ui.dart';

import 'activity_incremental_refresh_test.dart'
    show activityFixture, channelRow, shown;

void main() {
  testWidgets('a socket reconcile leaves an unchanged mounted card alone', (
    tester,
  ) async {
    final (client, workspace) = activityFixture();
    addTearDown(client.dispose);
    addTearDown(workspace.dispose);
    addTearDown(() async => tester.pumpWidget(const SizedBox.shrink()));
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: ResourceView(
            controller: workspace,
            section: 'activity',
            onMessage: (_, _) async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final unchanged = find.byWidgetPredicate(
      (widget) => widget is ActivityCardRow && widget.row['channelId'] == 'ch4',
    );
    final Element element = tester.element(unchanged);
    final before = workspace.inboxQueries.length;
    var rebuilds = 0;
    final previous = debugOnRebuildDirtyWidget;
    debugOnRebuildDirtyWidget = (dirty, firstBuild) {
      if (identical(dirty, element)) rebuilds++;
      previous?.call(dirty, firstBuild);
    };
    addTearDown(() => debugOnRebuildDirtyWidget = previous);

    workspace.inbox[0] = {
      ...channelRow(0),
      'lastMessagePreview': 'Edited public preview',
    };
    client.emit('message:updated', {'id': 'm0', 'channelId': 'ch0'});
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pumpAndSettle();

    expect(workspace.inboxQueries, hasLength(before + 1));
    expect(shown('Edited public preview'), findsOneWidget);
    expect(tester.element(unchanged), same(element));
    expect(rebuilds, 0);

    workspace.channels = [
      for (final channel in workspace.channels)
        if (channel.id == 'ch4')
          RaftChannel({...channel.json, 'activityMuted': true})
        else
          channel,
    ];
    workspace.inbox[0] = {
      ...channelRow(0),
      'lastMessagePreview': 'Edited again',
    };
    client.emit('message:updated', {'id': 'm0', 'channelId': 'ch0'});
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pumpAndSettle();

    expect(shown('Edited again'), findsOneWidget);
    expect(
      find.descendant(
        of: unchanged,
        matching: find.byKey(const ValueKey('conversation-card-muted')),
      ),
      findsOneWidget,
    );
    expect(tester.element(unchanged), same(element));
    expect(rebuilds, 1);
  });
}
