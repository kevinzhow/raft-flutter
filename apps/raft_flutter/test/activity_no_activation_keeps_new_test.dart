import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/features/resource_view.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'activity_open_clears_new_test.dart' show activityRow;
import 'message_presentation_test.dart' show fixture;

void main() {
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, true),
  ]) {
    for (final width in [1440.0, 390.0]) {
      testWidgets(
        '[Activity no activation] $family/$dark ${width.toInt()}px unread indicators stay without a tap, through auto paths and a revisit',
        (tester) async {
          SharedPreferences.setMockInitialValues({});
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final (w, api) = (await tester.runAsync(() => fixture('owner')))!;
          addTearDown(w.dispose);
          w.loading = false;
          w.ledger.switchServer('s1');
          // The retained main channel is also an Activity row.
          w.dms = [
            RaftChannel({
              'id': 'd1',
              'name': 'Bob',
              'type': 'dm',
              'joined': true,
            }),
          ];
          w.section = 'activity';
          api.routes['GET /channels/inbox'] = (_) => {
            'items': [
              activityRow('thread'),
              activityRow('channel'),
              activityRow('dm'),
            ],
            'totalCount': 3,
            'totalUnreadCount': 6,
            'hasMore': false,
          };
          api.routes['GET /channels/threads/followed'] = (_) => {'threads': []};
          api.routes['GET /messages/channel/c1'] = (_) => {
            'messages': [
              {
                'id': 'm5',
                'channelId': 'c1',
                'seq': '5',
                'senderId': 'bob',
                'senderType': 'user',
                'content': 'tail',
              },
            ],
          };
          api.routes['POST /feature-flags/evaluate'] = (_) => {
            'evaluations': [],
          };
          api.routes['GET /servers/s1/setup-projection'] = (_) => {
            'phase': 'complete',
            'surface': 'complete',
            'blocksChat': false,
          };
          for (final id in ['thread-1', 'c1', 'd1']) {
            api.routes['POST /channels/$id/read-all'] = (_) => {
              'maxReadSeq': 5,
              'readStateVersion': 7,
            };
            api.routes['POST /channels/$id/read'] = (_) => {
              'maxReadSeq': 5,
              'readStateVersion': 8,
            };
          }
          Future<void> watch(String when) async {
            for (var i = 0; i < 50; i++) {
              expect(find.text('2 new'), findsNWidgets(3), reason: '$when $i');
              await tester.pump(const Duration(milliseconds: 100));
            }
          }

          await tester.pumpWidget(
            MaterialApp(
              theme: raftTheme(family, dark: dark),
              home: WorkspaceView(
                controller: w,
                appearance: RaftAppearance(light: family),
                onAppearance: (_) async {},
                onLogout: () async {},
              ),
            ),
          );
          await tester.pumpAndSettle();
          await watch('mount');
          expect(w.section, 'activity');
          // Away and back.
          w.setSection('home');
          await tester.pumpAndSettle();
          w.setSection('activity');
          await tester.pumpAndSettle();
          await watch('revisit');
          expect(
            api.calls.where(
              (r) => r.method == 'POST' && r.path.contains('/read'),
            ),
            isEmpty,
            reason: 'no read write without a user activation',
          );
        },
      );
    }
  }

  testWidgets(
    '[Activity live message] a new message adds to the indicator and nothing clears it',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final (w, api) = (await tester.runAsync(() => fixture('owner')))!;
      addTearDown(w.dispose);
      w.loading = false;
      w.ledger.switchServer('s1');
      w.dms = [
        RaftChannel({'id': 'd1', 'name': 'Bob', 'type': 'dm', 'joined': true}),
      ];
      w.section = 'activity';
      var seq = '5', unread = 2;
      api.routes['GET /channels/inbox'] = (_) => {
        'items': [
          activityRow('thread', seq: seq, unread: unread),
          activityRow('channel', seq: seq, unread: unread),
          activityRow('dm', seq: seq, unread: unread),
        ],
        'totalCount': 3,
        'totalUnreadCount': 3 * unread,
        'hasMore': false,
      };
      api.routes['GET /channels/threads/followed'] = (_) => {'threads': []};
      api.routes['GET /channels/unread'] = (_) => {'channels': <String, int>{}};
      api.routes['POST /feature-flags/evaluate'] = (_) => {'evaluations': []};
      api.routes['GET /servers/s1/setup-projection'] = (_) => {
        'phase': 'complete',
        'surface': 'complete',
        'blocksChat': false,
      };
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.elegant),
          home: Scaffold(
            body: ResourceView(
              controller: w,
              section: 'activity',
              onMessage: (_, _) async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('2 new'), findsNWidgets(3));
      final dynamic state = tester.state(find.byType(ResourceView));
      seq = '6';
      unread = 3;
      for (final id in ['c1', 'd1', 'thread-1']) {
        state.patchActivity(
          RaftEvent('message:new', {
            'id': 'm6-$id',
            'channelId': id,
            'seq': 6,
            'content': 'Live',
            'senderId': 'bob',
            'senderType': 'user',
            'senderName': 'Bob',
            'createdAt': '2026-10-10T01:00:00Z',
          }),
        );
      }
      unawaited(state.reconcile());
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (i > 5) {
          expect(find.text('3 new'), findsNWidgets(3), reason: 'frame $i');
        }
      }
    },
  );

  testWidgets(
    '[Activity activation scope] opening one row never clears another',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final (w, api) = (await tester.runAsync(() => fixture('owner')))!;
      addTearDown(w.dispose);
      w.loading = false;
      w.ledger.switchServer('s1');
      w.dms = [
        RaftChannel({'id': 'd1', 'name': 'Bob', 'type': 'dm', 'joined': true}),
      ];
      w.section = 'activity';
      api.routes['GET /channels/inbox'] = (_) => {
        'items': [
          activityRow('thread'),
          activityRow('channel'),
          activityRow('dm'),
        ],
        'totalCount': 3,
        'totalUnreadCount': 6,
        'hasMore': false,
      };
      api.routes['GET /channels/threads/followed'] = (_) => {'threads': []};
      api.routes['GET /messages/channel/d1'] = (_) => {'messages': []};
      api.routes['GET /messages/channel/c1'] = (_) => {'messages': []};
      api.routes['POST /feature-flags/evaluate'] = (_) => {'evaluations': []};
      api.routes['GET /servers/s1/setup-projection'] = (_) => {
        'phase': 'complete',
        'surface': 'complete',
        'blocksChat': false,
      };
      for (final id in ['thread-1', 'c1', 'd1']) {
        api.routes['POST /channels/$id/read-all'] = (_) => {
          'maxReadSeq': 5,
          'readStateVersion': 7,
        };
        api.routes['POST /channels/$id/read'] = (_) => {
          'maxReadSeq': 5,
          'readStateVersion': 8,
        };
      }
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.elegant),
          home: WorkspaceView(
            controller: w,
            appearance: RaftAppearance(light: RaftFamily.elegant),
            onAppearance: (_) async {},
            onLogout: () async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('2 new'), findsNWidgets(3));
      await tester.tap(find.byKey(const ValueKey('activity-dm-d1')));
      await tester.pump(const Duration(milliseconds: 220));
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        final shown = find.text('2 new').evaluate().length;
        expect(shown, 2, reason: 'frame $i');
      }
      // Leave and return with the opened conversation still selected: the two
      // rows nobody opened keep their indicator on every frame.
      w.setSection('home');
      await tester.pumpAndSettle();
      w.setSection('activity');
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (find.byKey(const ValueKey('activity-dm-d1')).evaluate().isEmpty) {
          continue;
        }
        expect(find.text('2 new').evaluate().length, 2, reason: 'revisit $i');
      }
      expect(
        find.byKey(const ValueKey('activity-thread-thread-1')),
        findsOneWidget,
      );
      expect(find.text('2 new'), findsNWidgets(2));
    },
  );

  testWidgets(
    '[Activity restored location] a restored content slot never clears other rows',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final (w, api) = (await tester.runAsync(() => fixture('owner')))!;
      addTearDown(w.dispose);
      w.loading = false;
      w.ledger.switchServer('s1');
      w.dms = [
        RaftChannel({'id': 'd1', 'name': 'Bob', 'type': 'dm', 'joined': true}),
      ];
      w.section = 'activity';
      w.navigation.navigate(RaftLocation.parse('/s/s1/activity?open=dm:d1'));
      api.routes['GET /channels/inbox'] = (_) => {
        'items': [
          activityRow('thread'),
          activityRow('channel'),
          activityRow('dm'),
        ],
        'totalCount': 3,
        'totalUnreadCount': 6,
        'hasMore': false,
      };
      api.routes['GET /channels/threads/followed'] = (_) => {'threads': []};
      api.routes['GET /messages/channel/d1'] = (_) => {'messages': []};
      api.routes['GET /messages/channel/c1'] = (_) => {'messages': []};
      api.routes['POST /feature-flags/evaluate'] = (_) => {'evaluations': []};
      api.routes['GET /servers/s1/setup-projection'] = (_) => {
        'phase': 'complete',
        'surface': 'complete',
        'blocksChat': false,
      };
      for (final id in ['thread-1', 'c1', 'd1']) {
        api.routes['POST /channels/$id/read-all'] = (_) => {
          'maxReadSeq': 5,
          'readStateVersion': 7,
        };
        api.routes['POST /channels/$id/read'] = (_) => {
          'maxReadSeq': 5,
          'readStateVersion': 8,
        };
      }
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.elegant),
          home: WorkspaceView(
            controller: w,
            appearance: RaftAppearance(light: RaftFamily.elegant),
            onAppearance: (_) async {},
            onLogout: () async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('2 new'), findsNWidgets(3));
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        expect(
          find.text('2 new').evaluate().length,
          greaterThanOrEqualTo(2),
          reason: 'frame $i',
        );
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('activity-thread-thread-1')),
            matching: find.text('2 new'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('activity-channel-c1')),
            matching: find.text('2 new'),
          ),
          findsOneWidget,
        );
      }
    },
  );
}
