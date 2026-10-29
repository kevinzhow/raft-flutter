import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/resource_view.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'activity_incremental_refresh_test.dart'
    show activityFixture, channelRow, skeleton;
import 'support/app_services_fixture.dart';

void main() {
  for (final phone in [false, true]) {
    testWidgets('${phone ? 'phone' : 'desktop'} filtered and loaded windows', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = phone
          ? const Size(390, 844)
          : const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final (_, workspace) = (await tester.runAsync(() async {
        final fixture = activityFixture();
        await fixture.$1.login('fixture', 'fixture');
        return fixture;
      }))!;
      addTearDown(workspace.dispose);
      workspace
        ..loading = false
        ..section = 'activity';
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          home: withAppServices(
            WorkspaceView(
              controller: workspace,
              appearance: const RaftAppearance(),
              onAppearance: (_) async {},
              onLogout: () async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final dynamic state = tester.state(find.byType(ResourceView));
      final observations = <Map<String, dynamic>>[];
      void record(String phase) => observations.add({
        'phase': phase,
        'query': workspace.inboxQueries.last,
        'ids': [for (final Map row in state.rows) row['channelId']],
        'hasMore': state.hasMore,
        'totalUnread': state.totalUnreadCount,
        'loading': state.loading,
      });

      try {
        record('default');
        final firstRow = state.rows.first;
        await state.load(append: true);
        expect(state.rows, hasLength(60));
        expect(identical(state.rows.first, firstRow), isTrue);
        expect(workspace.inboxQueries.last['offset'], 30);
        expect(state.hasMore, isFalse);
        record('append');

        workspace.inbox[0] = {
          ...workspace.inbox[0],
          'lastMessagePreview': 'Revalidated first row',
        };
        await state.load(keep: true);
        expect(workspace.inboxQueries.last['limit'], 60);
        expect(state.rows, hasLength(60));
        expect(state.rows.first['lastMessagePreview'], 'Revalidated first row');
        expect(skeleton, findsNothing);
        record('loaded-revalidate');

        workspace.inbox = [channelRow(3, unread: 2), channelRow(9, unread: 4)];
        state.filter = 'unread';
        await state.load();
        expect(workspace.inboxQueries.last['filter'], 'unread');
        expect(state.rows, hasLength(2));
        record('unread');

        workspace.inbox = [channelRow(9, unread: 4)];
        state.advanced.channelId = 'ch9';
        state.advanced.direction = 'asc';
        state.query.text = 'Preview 9';
        await state.load();
        expect(state.rows.single['channelId'], 'ch9');
        expect(workspace.inboxQueries.last['channelId'], 'ch9');
        expect(workspace.inboxQueries.last['sort'], 'asc');
        expect(workspace.inboxQueries.last['q'], 'Preview 9');
        record('channel-query-ascending');
        // Machine-comparable fixture observations, identical on both refs.
        // ignore: avoid_print
        print('M2_WINDOW_${phone ? 'PHONE' : 'DESKTOP'} ${jsonEncode(observations)}');
      } finally {
        await tester.pumpWidget(const SizedBox());
      }
    });
  }
}
