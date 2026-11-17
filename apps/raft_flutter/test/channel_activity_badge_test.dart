import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/workspace_channel_header.dart';
import 'package:raft_ui/raft_ui.dart';

import 'message_presentation_test.dart' show fixture;

void main() {
  for (final dark in [false, true]) {
    testWidgets(
      'header activity suffix preserves title and actions dark=$dark',
      (t) async {
        final semantics = t.ensureSemantics();
        final (w, api) = (await t.runAsync(() => fixture('owner')))!;
        addTearDown(w.dispose);
        addTearDown(() => t.pumpWidget(const SizedBox()));
        w.channel = RaftChannel({
          'id': 'c1',
          'type': 'channel',
          'name': 'Forum',
          'threadSort': 'activity',
          'activityMuted': true,
          'archivedAt': '2026-11-01T00:00:00Z',
        });
        w.channels = [w.channel!];
        api.routes['POST /feature-flags/evaluate'] = (_) => {
          'evaluations': [
            {'key': 'channel_thread_sort_v0', 'enabled': true},
          ],
        };
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(dark: dark),
            home: Scaffold(
              body: WorkspaceChannelHeader(
                headerKey: const ValueKey('channel-header'),
                controller: w,
                channel: w.channel!,
                backLabel: 'Back',
                onSearch: () {},
                onSettings: () {},
              ),
            ),
          ),
        );
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await t.pumpAndSettle();
        final badge = find.byKey(const ValueKey('channel-forum-order-badge'));
        expect(badge, findsOneWidget);
        expect(
          find.bySemanticsLabel('Sorted by latest activity'),
          findsOneWidget,
        );
        expect(t.widget<RaftIcon>(badge).size, 14);
        expect(
          find.byKey(const ValueKey('channel-topbar-search')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('channel-overflow-trigger')),
          findsOneWidget,
        );
        final header = t.widget<RaftChannelHeader>(
          find.byKey(const ValueKey('channel-header')),
        );
        expect(header.name, 'Forum');
        expect(header.titleSuffix, isNotNull);
        expect(t.takeException(), isNull);
        semantics.dispose();
      },
    );
  }
}
