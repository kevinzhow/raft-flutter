import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/thread_agent_followers_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'message_presentation_test.dart' show MessageAdapter, fixture;

Map<String, dynamic> follower(
  String id,
  String name, {
  bool canRemove = true,
  bool current = true,
}) => {
  'id': id,
  'name': name,
  'displayName': name,
  'status': 'active',
  'avatarUrl': 'pixel:robot',
  'isCurrentServer': current,
  'canRemove': canRemove,
  if (!current) 'serverName': 'Acme',
};

/// The store's requests run in the test's fake-async zone: let them finish.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<MessageAdapter> mount(
    WidgetTester tester, {
    required Map<String, dynamic> Function() roster,
    List<String>? opened,
  }) async {
    tester.view.physicalSize = const Size(600, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final (w, api) = (await tester.runAsync(() => fixture('owner')))!;
    addTearDown(w.dispose);
    api.routes['GET /channels/threads/followers'] = (_) => roster();
    api.routes['GET /agents'] = (_) => [];
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topRight,
            child: ThreadAgentFollowersView(
              controller: w,
              threadChannelId: 't1',
              onOpenAgent: opened?.add,
            ),
          ),
        ),
      ),
    );
    await settle(tester);
    return api;
  }

  testWidgets(
    'count trigger and follower rows; a manager can remove and undo',
    (tester) async {
      var removed = false;
      final opened = <String>[];
      final api = await mount(
        tester,
        opened: opened,
        roster: () => {
          'threads': [
            {
              'threadChannelId': 't1',
              'canManage': true,
              'agents': [
                follower('a1', 'Cindy'),
                if (!removed) follower('a2', 'Product UX'),
              ],
            },
          ],
        },
      );
      api.routes['DELETE /channels/threads/t1/followers/agents/a2'] = (_) {
        removed = true;
        return {'removed': true, 'undoToken': 'undo-1'};
      };
      Map<String, dynamic>? restoreBody;
      api.routes['POST /channels/threads/t1/followers/agents/a2/restore'] =
          (o) {
            restoreBody = Map<String, dynamic>.from(o.data as Map);
            removed = false;
            return {'restored': true};
          };

      final trigger = find.byKey(const Key('thread-followers-header-trigger'));
      expect(trigger, findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      await tester.tap(trigger);
      await tester.pumpAndSettle();
      expect(find.text('Following Agents'), findsOneWidget);
      expect(find.text('Cindy'), findsOneWidget);
      expect(find.text('Product UX'), findsOneWidget);
      // Fallback activity line from the follower status.
      expect(find.text('Online'), findsNWidgets(2));

      await tester.tap(find.text('Cindy'));
      await tester.pump();
      expect(opened, ['a1']);

      await tester.tap(find.byKey(const Key('thread-follower-remove')).last);
      await tester.pumpAndSettle();
      expect(
        find.text("Removed Product UX from this thread's followers."),
        findsOneWidget,
      );
      expect(find.text('Product UX'), findsNothing);
      expect(find.text('1'), findsOneWidget);

      await tester.tap(find.byKey(const Key('toast-action')));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
      expect(restoreBody, {'undoToken': 'undo-1'});
      expect(find.text('Restored Product UX as a follower.'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 6));
    },
  );

  testWidgets('a failed removal shows the error toast and keeps the row', (
    tester,
  ) async {
    final api = await mount(
      tester,
      roster: () => {
        'threads': [
          {
            'threadChannelId': 't1',
            'canManage': true,
            'agents': [follower('a1', 'Cindy')],
          },
        ],
      },
    );
    api.routes['DELETE /channels/threads/t1/followers/agents/a1'] = (_) =>
        throw StateError('boom');
    await tester.tap(find.byKey(const Key('thread-followers-header-trigger')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('thread-follower-remove')));
    await tester.pump();
    await settle(tester);
    await tester.pumpAndSettle();
    expect(find.text("Couldn't remove this follower."), findsOneWidget);
    expect(find.text('Cindy'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('a peer-server follower cannot be removed here', (tester) async {
    await mount(
      tester,
      roster: () => {
        'threads': [
          {
            'threadChannelId': 't1',
            'canManage': true,
            'agents': [
              follower('a1', 'Cindy', canRemove: false, current: false),
            ],
          },
        ],
      },
    );
    await tester.tap(find.byKey(const Key('thread-followers-header-trigger')));
    await tester.pumpAndSettle();
    expect(find.text('Acme'), findsOneWidget);
    final remove = tester.widget<RaftIconButton>(
      find.byKey(const Key('thread-follower-remove')),
    );
    expect(remove.onPressed, isNull);
    expect(
      remove.tooltip,
      'Cindy follows from Acme. Switch to that server to remove them.',
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('non-managers see no remove button; empty roster hides it', (
    tester,
  ) async {
    await mount(
      tester,
      roster: () => {
        'threads': [
          {
            'threadChannelId': 't1',
            'canManage': false,
            'agents': [follower('a1', 'Cindy')],
          },
        ],
      },
    );
    await tester.tap(find.byKey(const Key('thread-followers-header-trigger')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('thread-follower-remove')), findsNothing);
    await tester.pumpWidget(const SizedBox());

    await mount(
      tester,
      roster: () => {
        'threads': [
          {'threadChannelId': 't1', 'canManage': true, 'agents': []},
        ],
      },
    );
    expect(
      find.byKey(const Key('thread-followers-header-trigger')),
      findsNothing,
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a failed load shows the error trigger and Retry reloads', (
    tester,
  ) async {
    var fail = true;
    await mount(
      tester,
      roster: () {
        if (fail) throw StateError('down');
        return {
          'threads': [
            {
              'threadChannelId': 't1',
              'canManage': true,
              'agents': [follower('a1', 'Cindy')],
            },
          ],
        };
      },
    );
    await tester.tap(find.byKey(const Key('thread-followers-header-trigger')));
    await tester.pumpAndSettle();
    expect(find.text("Followers couldn't be loaded."), findsOneWidget);
    fail = false;
    await tester.tap(find.text('Retry'));
    await tester.pump();
    await settle(tester);
    await tester.pumpAndSettle();
    expect(find.text('Cindy'), findsOneWidget);
    expect(find.text("Followers couldn't be loaded."), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  test('follower status words normalize like Web', () {
    expect(followerAgentStatus('online'), 'active');
    expect(followerAgentStatus('active'), 'active');
    expect(followerAgentStatus('stopped'), 'stopped');
    expect(followerAgentStatus('whatever'), 'inactive');
    expect(followerAgentStatus(null), 'inactive');
  });
}
