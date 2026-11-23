import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/resource_view.dart';
import 'package:raft_flutter/features/saved_sidebar_entry.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../integration_test/perf_lab/fixtures.dart' show LabAdapter, LabClient;

void main() {
  for (final (section, trigger) in [
    ('search', 'plan'),
    ('saved', 'plan'),
    ('saved', 'save'),
    ('badge', 'plan'),
  ]) {
    testWidgets('$section revalidates its mounted projection after $trigger', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final api = LabAdapter();
      final client = LabClient(api)
        ..user = RaftRecord({'id': 'alice'})
        ..selectServer('s1');
      final channel = RaftChannel({
        'id': 'room',
        'name': 'Room',
        'type': 'channel',
        'joined': true,
      });
      final workspace = WorkspaceController(client)
        ..server = RaftRecord({'id': 's1', 'role': 'owner', 'plan': 'free'})
        ..channels = [channel];
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        workspace.dispose();
      });
      final searching = section == 'search';
      final badge = section == 'badge';
      final endpoint = searching ? '/messages/search' : '/channels/saved';
      final field = searching ? 'results' : 'saved';
      final hits = 'GET $endpoint';
      Map<String, dynamic> row(String id) => {
        'id': id,
        'messageId': id,
        'channelId': channel.id,
        'channelName': channel.name,
        'senderType': 'user',
        'senderId': 'alice',
        'senderName': 'Alice',
        'content': 'Matching $id',
        'createdAt': '2026-10-10T10:00:00Z',
      };
      var rows = [row('current')];
      Completer<void>? response;
      api.routes[hits] = (_) async {
        await response?.future;
        return {field: rows, 'total': rows.length, 'hasMore': false};
      };
      api.routes['POST /channels/saved'] = (_) => {};
      Finder painted(String id) => badge
          ? find.byWidgetPredicate(
              (widget) =>
                  widget is RaftNavItem &&
                  widget.count == (id == 'current' ? 1 : 2),
            )
          : find
                .byKey(ValueKey(searching ? 'search-message:$id' : 'saved-$id'))
                .hitTestable();
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          home: Scaffold(
            body: badge
                ? SavedSidebarEntry(controller: workspace, onTap: () {})
                : ResourceView(
                    controller: workspace,
                    section: section,
                    initialQuery: searching ? 'Matching' : null,
                    onMessage: (_, _) async {},
                  ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(painted('current'), findsOneWidget);
      final queries = api.hits[hits]!;
      client.emit('server:plan-updated', {'serverId': 'other', 'plan': 'pro'});
      await tester.pumpAndSettle();
      expect(api.hits[hits], queries);

      response = Completer<void>();
      addTearDown(() {
        if (response?.isCompleted == false) response!.complete();
      });
      rows = [row('restored'), ...rows];
      if (trigger == 'plan') {
        client.emit('server:plan-updated', {'serverId': 's1', 'plan': 'pro'});
        expect(workspace.server?.string('plan'), 'pro');
      } else {
        final saving = SavedCountStore.of(workspace).setSaved('restored', true);
        await tester.pumpAndSettle();
        await saving;
        expect(api.hits['POST /channels/saved'], 1);
      }
      await tester.pumpAndSettle();
      expect(painted('current'), findsOneWidget);
      expect(api.hits[hits], queries + 1);
      response.complete();
      await tester.pumpAndSettle();
      expect(painted('restored'), findsOneWidget);
    });
  }
}
