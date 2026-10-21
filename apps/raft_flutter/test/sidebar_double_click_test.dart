import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/activity_first_unread.dart';
import 'package:raft_flutter/features/desktop_directory_view.dart';
import 'package:raft_flutter/features/desktop_navigation_policy.dart';
import 'package:raft_flutter/features/page_layout.dart' show RaftPageHeader;
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:raft_flutter/features/resource_list_updates.dart';
import 'package:raft_ui/raft_ui.dart';

import 'activity_incremental_refresh_test.dart'
    show ActivityClient, ActivityWorkspace, activityFixture, channelRow, shown;
import 'message_presentation_test.dart' show fixture;
import 'support/app_services_fixture.dart';
import 'mounted_message_navigation_test.dart' show pageFixture, mountPage;

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://fixture.test',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'alice'});
    selectServer('s');
  }
  final stream = StreamController<RaftEvent>.broadcast(sync: true);
  @override
  Stream<RaftEvent> get events => stream.stream;
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async =>
      <dynamic>[];
}

class _Workspace extends WorkspaceController {
  _Workspace(super.client);
  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) async =>
      switch (path) {
        '/agents' => [
          {
            'id': 'a',
            'name': 'Source Agent',
            'status': 'active',
            'runtime': 'codex',
            'machineId': 'c',
          },
        ],
        '/servers/s/machines' => {
          'machines': [
            {'id': 'c', 'name': 'Source Computer', 'status': 'online'},
          ],
        },
        '/servers/s/members' => [
          {'userId': 'u', 'name': 'Source Human', 'role': 'member'},
        ],
        _ => <dynamic>[],
      };
}

/// Mouse double-click only: Source `MemberHumanRow` / `MemberAgentRow` open a
/// DM, the Activity entries jump to the first unread row.
void main() {
  var clock = Duration.zero;
  Future<void> click(
    WidgetTester t,
    Finder at, {
    PointerDeviceKind kind = PointerDeviceKind.mouse,
  }) async {
    final position = t.getCenter(at);
    final pointer = TestPointer(1, kind);
    for (var i = 0; i < 2; i++) {
      await t.sendEventToBinding(pointer.down(position, timeStamp: clock));
      await t.sendEventToBinding(pointer.up(timeStamp: clock));
      clock += const Duration(milliseconds: 80);
      await t.pump(const Duration(milliseconds: 80));
    }
    await t.pump();
  }

  group('Members column', () {
    for (final (name, kind) in [
      ('Source Human', DesktopContentKind.human),
      ('Source Agent', DesktopContentKind.agent),
    ]) {
      testWidgets('double-clicking $name opens a DM, touch does not', (
        t,
      ) async {
        final client = _Client();
        final w = _Workspace(client)
          ..server = RaftRecord({'id': 's', 'role': 'owner'});
        addTearDown(() async {
          w.dispose();
          await client.stream.close();
          await client.dispose();
        });
        await w.entityDirectory.preload();
        final selected = <DesktopContentTarget>[],
            dms = <DesktopContentTarget>[];
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(RaftFamily.elegant),
            home: Scaffold(
              body: SizedBox(
                width: 320,
                child: DesktopDirectoryView(
                  controller: w,
                  onSelected: selected.add,
                  onOpenDm: (target) async => dms.add(target),
                ),
              ),
            ),
          ),
        );
        final row = find.text(name);
        await click(t, row, kind: PointerDeviceKind.touch);
        expect(dms, isEmpty);
        expect(selected, hasLength(2));
        await click(t, row);
        expect(dms.map((e) => e.kind), [kind]);
        expect(dms.single.id, kind == DesktopContentKind.human ? 'u' : 'a');
        // Each click still selects the row, as before.
        expect(selected, hasLength(4));
        await t.pumpWidget(const SizedBox());
      });
    }

    testWidgets('a failing DM request leaves the column alone', (t) async {
      final client = _Client();
      final w = _Workspace(client)
        ..server = RaftRecord({'id': 's', 'role': 'owner'});
      addTearDown(() async {
        w.dispose();
        await client.stream.close();
        await client.dispose();
      });
      await w.entityDirectory.preload();
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.elegant),
          home: Scaffold(
            body: SizedBox(
              width: 320,
              child: DesktopDirectoryView(
                controller: w,
                onSelected: (_) {},
                onOpenDm: (_) async => throw StateError('offline'),
              ),
            ),
          ),
        ),
      );
      await click(t, find.text('Source Human'));
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    });
  });

  group('Activity entry', () {
    late ActivityClient client;
    late ActivityWorkspace w;
    setUp(() => (client, w) = activityFixture());
    tearDown(() async {
      w.dispose();
      await client.dispose();
    });

    testWidgets('the rail item arms the first-unread jump for the mouse only', (
      t,
    ) async {
      final (w, api) = await pageFixture(t);
      api.routes['GET /activity'] = (_) => {'items': []};
      await mountPage(t, w, RaftFamily.elegant, false);
      final activity = find.byKey(const ValueKey('rail-activity'));
      expect(activity, findsOneWidget);
      await click(t, activity, kind: PointerDeviceKind.touch);
      expect(ActivityFirstUnread.of(w).pending, isFalse);
      await click(t, activity);
      expect(ActivityFirstUnread.of(w).pending, isTrue);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('the first unread row is marked and scrolled into view once '
        'rows are there; read rows keep the intent pending', (t) async {
      final (w, _) = (await t.runAsync(() => fixture('owner')))!;
      addTearDown(w.dispose);
      final focus = ActivityFirstUnread.of(w);
      var unreadFrom = 99;
      final rows = [
        for (var i = 0; i < 60; i++)
          {'id': 'r$i', 'unreadCount': i >= unreadFrom ? 1 : 0},
      ];
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      late StateSetter rebuild;
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                focus.observe(rows, (r) => '${r['id']}', scroll, context);
                return ListView.builder(
                  controller: scroll,
                  itemCount: rows.length,
                  itemBuilder: (_, i) => KeyedSubtree(
                    key: ResourceRowListKey('r$i'),
                    child: SizedBox(height: 80, child: Text('row $i')),
                  ),
                );
              },
            ),
          ),
        ),
      );
      focus.request(w);
      rebuild(() {});
      await t.pumpAndSettle();
      // Nothing unread: the intent waits, nothing is marked.
      expect(focus.pending, isTrue);
      expect(focus.highlights('r40'), isFalse);
      expect(scroll.offset, 0);

      unreadFrom = 40;
      rows
        ..clear()
        ..addAll([
          for (var i = 0; i < 60; i++)
            {'id': 'r$i', 'unreadCount': i >= unreadFrom ? 1 : 0},
        ]);
      rebuild(() {});
      await t.pumpAndSettle();
      expect(focus.pending, isFalse);
      expect(focus.highlights('r40'), isTrue);
      expect(focus.highlights('r41'), isFalse);
      expect(scroll.offset, greaterThan(0));
      final top = t.getTopLeft(find.text('row 40')).dy;
      expect(top, inInclusiveRange(0, 600));
    });

    testWidgets('a double-click on the rail Activity item marks the first '
        'unread conversation of the open page', (t) async {
      SharedPreferences.setMockInitialValues({});
      t.view.physicalSize = const Size(1440, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.runAsync(() => client.login('fixture', 'fixture'));
      client.selectServer('s1');
      w.activityUnread.start();
      w.loading = false;
      w.section = 'chat';
      w.inbox = [
        channelRow(0),
        channelRow(1, unread: 2),
        channelRow(2, unread: 1),
        channelRow(3),
      ];
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
      await t.pump(const Duration(seconds: 3));
      for (var i = 0; i < 20; i++) {
        await t.pump(const Duration(milliseconds: 50));
      }
      await click(t, find.byKey(const ValueKey('rail-activity')));
      for (var i = 0; i < 20; i++) {
        await t.pump(const Duration(milliseconds: 50));
      }
      expect(shown('Channel 1'), findsOneWidget);
      bool marked(int i) => t
          .widget<RaftConversationCard>(
            find.byKey(ValueKey('activity-channel-ch$i')),
          )
          .selected;
      expect(
        [for (var i = 0; i < 4; i++) marked(i)],
        [false, true, false, false],
      );
      // A double-click on the page header moves the mark to the next unread
      // row, and round to the first again.
      for (final next in [2, 1]) {
        await click(t, find.byType(RaftPageHeader));
        for (var i = 0; i < 5; i++) {
          await t.pump(const Duration(milliseconds: 50));
        }
        expect(
          [for (var i = 0; i < 4; i++) marked(i)],
          [for (var i = 0; i < 4; i++) i == next],
        );
      }
      // Nothing was opened: the first unread conversation is only marked.
      expect(w.section, 'activity');
      await t.pumpWidget(const SizedBox());
    });
  });
}
