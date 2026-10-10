import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/resource_view.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'message_presentation_test.dart' show fixture;
import 'activity_follow_ack_test.dart' show thread;

const activeRow = <String, dynamic>{
  'kind': 'channel',
  'channelId': 'c1',
  'channelName': 'general',
  'lastMessagePreview': 'Accepted active result',
  'lastMessageId': 'm-active',
  'unreadCount': 2,
  'latestActivitySeq': '8',
};
const facets = [
  {
    'channelId': 'c1',
    'channelName': 'general',
    'channelType': 'channel',
    'count': 4,
  },
  {'channelId': 'd1', 'channelName': 'Alice', 'channelType': 'dm', 'count': 1},
];
Map<String, dynamic> flag(bool enabled) => {
  'evaluations': [
    {'key': 'activity_sidebar_inbox_v0', 'enabled': enabled},
  ],
};

void main() {
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    testWidgets(
      '[N24h] $family/$dark flag-enabled ACK survives Saved facets and cached All return',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = const Size(1440, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final (w, api) = (await tester.runAsync(() => fixture('owner')))!;
        addTearDown(w.dispose);
        w.loading = false;
        w.section = 'activity';
        final row = {...thread(), 'parentChannelId': 'c1'};
        api.routes['POST /feature-flags/evaluate'] = (_) => flag(true);
        api.routes['POST /channels/threads/unfollow'] = (_) => {};
        api.routes['GET /channels/inbox'] = (_) => {
          'items': [row],
          'groups': facets,
          'totalCount': 1,
          'totalUnreadCount': 3,
        };
        api.routes['GET /channels/saved'] = (_) => {
          'saved': [],
          'globalTotal': 0,
        };
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
        await tester.tap(
          find.byType(RaftConversationCard),
          buttons: kSecondaryMouseButton,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(RaftMenuItem, 'Unfollow'));
        await tester.pumpAndSettle();
        final dynamic state = tester.state(find.byType(ResourceView));
        expect((state.rows.single as Map)['isFollowing'], false);
        Future<void> choose(String view) async {
          await tester.tap(
            find.byKey(const ValueKey('activity-scope-switcher')),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(ValueKey('activity-switcher-nav-$view')));
          await tester.pumpAndSettle();
        }

        await choose('saved');
        expect(state.rows, isEmpty);
        expect(
          state.totalUnreadCount,
          0,
          reason: 'Stale active facets retain the acknowledged unread change.',
        );
        await choose('all');
        expect((state.rows.single as Map)['isFollowing'], false);
        expect((state.rows.single as Map)['unreadCount'], 0);
        expect(state.totalUnreadCount, 0);
        expect(tester.takeException(), isNull);
      },
      variant: const TargetPlatformVariant({TargetPlatform.linux}),
    );
    testWidgets(
      '[N24h] $family/$dark late selected-server evaluation cannot enable the new server page',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = const Size(1440, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final (w, api) = (await tester.runAsync(() => fixture('owner')))!;
        addTearDown(w.dispose);
        w.loading = false;
        w.section = 'activity';
        final old = Completer<Map<String, dynamic>>();
        api.routes['POST /feature-flags/evaluate'] = (request) =>
            (request.data as Map)['keys'].contains(
                  'activity_sidebar_inbox_v0',
                ) &&
                (request.data as Map)['serverId'] == 's1'
            ? old.future
            : flag(false);
        api.routes['GET /channels/inbox'] = (_) => {'items': [], 'groups': []};
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
        w.client.selectServer('s2');
        w.server = RaftRecord({'id': 's2', 'slug': 'two', 'role': 'member'});
        w.section = 'activity';
        w.notifyListeners();
        await tester.pumpAndSettle();
        expect(
          api.calls.where(
            (c) =>
                c.path == '/feature-flags/evaluate' &&
                (c.data as Map)['keys'].contains('activity_sidebar_inbox_v0') &&
                (c.data as Map)['serverId'] == 's2',
          ),
          hasLength(1),
        );
        old.complete(flag(true));
        await tester.pumpAndSettle();
        expect(w.server!.id, 's2');
        expect(find.byType(RaftActivityScopeToolbar), findsNothing);
        expect(find.byType(RaftSegmentedControl<String>), findsOneWidget);
      },
      variant: const TargetPlatformVariant({TargetPlatform.linux}),
    );
    testWidgets(
      '[N24h] $family/$dark late Saved and active facet windows cannot replace the selected Done page',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = const Size(1440, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final (w, api) = (await tester.runAsync(() => fixture('owner')))!;
        addTearDown(w.dispose);
        w.loading = false;
        w.section = 'activity';
        final saved = Completer<Map<String, dynamic>>();
        final oldFacet = Completer<Map<String, dynamic>>();
        var holdFacets = false;
        api.routes['POST /feature-flags/evaluate'] = (_) => flag(true);
        api.routes['GET /channels/inbox'] = (_) {
          if (holdFacets) return oldFacet.future;
          return {
            'items': [activeRow],
            'groups': facets,
            'totalCount': 5,
            'totalUnreadCount': 2,
          };
        };
        api.routes['GET /channels/saved'] = (_) => saved.future;
        api.routes['GET /channels/inbox/done'] = (_) => {
          'items': [
            {...activeRow, 'channelName': 'Current Done'},
          ],
        };
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
        holdFacets = true;
        await tester.tap(find.byKey(const ValueKey('activity-scope-switcher')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('activity-switcher-nav-saved')),
        );
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(RaftActivityLoadingList), findsOneWidget);
        expect(find.byKey(const ValueKey('activity-channel-c1')), findsNothing);
        await tester.tap(find.byKey(const ValueKey('activity-scope-switcher')));
        await tester.pump(const Duration(milliseconds: 300));
        holdFacets = false;
        await tester.tap(
          find.byKey(const ValueKey('activity-switcher-nav-done')),
        );
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Current Done', findRichText: true),
          findsOneWidget,
        );
        saved.complete({
          'saved': [
            {
              'messageId': 'late',
              'channelId': 'c1',
              'channelName': 'Late Saved',
              'content': 'Late Saved',
            },
          ],
          'globalTotal': 99,
        });
        if (!oldFacet.isCompleted) {
          oldFacet.complete({
            'items': [],
            'groups': [
              {
                'channelId': 'late-forbidden',
                'channelName': 'Late forbidden facet',
              },
            ],
            'totalCount': 99,
          });
        }
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Current Done', findRichText: true),
          findsOneWidget,
        );
        expect(
          find.textContaining('Late Saved', findRichText: true),
          findsNothing,
        );
        await tester.tap(find.byKey(const ValueKey('activity-scope-switcher')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('activity-switcher-group-late-forbidden')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('activity-switcher-group-c1')),
          findsOneWidget,
        );
        await tester.tap(find.byType(RaftCloseButton));
        await tester.pumpAndSettle();
      },
      variant: const TargetPlatformVariant({TargetPlatform.linux}),
    );

    for (final enabled in [false, true]) {
      for (final width in [1440.0, 390.0]) {
        testWidgets(
          '[N24h] $family/$dark ${enabled ? 'flag-enabled' : 'flag-disabled'} ${width == 390 ? 'mobile' : 'desktop'} actual Activity sources',
          (tester) async {
            SharedPreferences.setMockInitialValues({});
            tester.view.physicalSize = Size(width, 900);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            final (w, api) = (await tester.runAsync(() => fixture('owner')))!;
            addTearDown(w.dispose);
            w.loading = false;
            w.section = 'activity';
            w.dms = [
              RaftChannel({
                'id': 'd1',
                'name': 'Alice',
                'type': 'dm',
                'joined': true,
              }),
            ];
            final evaluation = Completer<Map<String, dynamic>>();
            api.routes['POST /feature-flags/evaluate'] = (_) =>
                evaluation.future;
            api.routes['GET /channels/inbox'] = (_) => {
              'items': [activeRow],
              'groups': facets,
              'totalCount': 5,
              'totalUnreadCount': 2,
            };
            api.routes['GET /channels/inbox/done'] = (_) => {
              'items': [
                {
                  ...activeRow,
                  'channelId': 'done-channel',
                  'channelName': 'done result',
                  'unreadCount': 0,
                },
              ],
              'groups': [
                {
                  'channelId': 'must-not-replace',
                  'channelName': 'Wrong result facet',
                },
              ],
              'totalCount': 900,
              'totalUnreadCount': 800,
            };
            api.routes['GET /channels/saved'] = (_) => {
              'saved': [
                {
                  'messageId': 'saved-message',
                  'channelId': 'c1',
                  'channelName': 'general',
                  'channelType': 'channel',
                  'content': 'Accepted saved result',
                  'senderType': 'user',
                  'senderId': 'alice',
                  'createdAt': '2026-10-10T00:00:00Z',
                },
              ],
              'total': 1,
              'globalTotal': 3,
            };
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
            expect(
              find.byType(RaftSegmentedControl<String>),
              findsOneWidget,
              reason: 'Unknown evaluation must keep Source classic branch.',
            );
            final request = api.calls.singleWhere(
              (c) =>
                  c.path == '/feature-flags/evaluate' &&
                  (c.data as Map)['keys'].contains('activity_sidebar_inbox_v0'),
            );
            expect(request.data, {
              'keys': ['activity_sidebar_inbox_v0'],
              'serverId': 's1',
              'platform': width == 390 ? 'mobile' : 'web',
            });
            evaluation.complete(flag(enabled));
            await tester.pumpAndSettle();
            expect(find.byTooltip('Filters'), findsNothing);
            expect(find.text('Unfollowed threads'), findsNothing);
            if (!enabled) {
              expect(find.byType(RaftActivityScopeToolbar), findsNothing);
              expect(find.byType(RaftSegmentedControl<String>), findsOneWidget);
              expect(
                api.calls.where((c) => c.path == '/channels/inbox/done'),
                isEmpty,
              );
              // Source loads the first Saved page on connect (saved ids and
              // the badge); the disabled Activity page adds no read of its own.
              expect(
                api.calls
                    .where((c) => c.path == '/channels/saved')
                    .map((c) => c.queryParameters),
                [
                  {'limit': 20, 'offset': 0, 'sort': 'desc'},
                ],
              );
              return;
            }
            expect(
              find.byType(RaftActivityScopeToolbar),
              findsOneWidget,
              reason:
                  'The accepted server flag must mount Source enabled controls.',
            );
            final toolbar = tester.widget<RaftActivityScopeToolbar>(
              find.byType(RaftActivityScopeToolbar),
            );
            expect(toolbar.compact, width >= 768);
            expect(
              tester
                  .getSize(
                    find.byKey(const ValueKey('activity-enabled-toolbar')),
                  )
                  .height,
              width >= 768 ? (family == RaftFamily.brutal ? 90 : 89) : 54,
            );
            expect(find.byType(RaftSegmentedControl<String>), findsNothing);
            Future<void> select(String view) async {
              if (width >= 768) {
                await tester.tap(
                  find.byKey(const ValueKey('activity-scope-switcher')),
                );
                await tester.pumpAndSettle();
                expect(
                  find.byKey(const ValueKey('activity-switcher-group-c1')),
                  findsOneWidget,
                );
                expect(
                  find.byKey(const ValueKey('activity-switcher-group-d1')),
                  findsOneWidget,
                );
                await tester.tap(
                  find.byKey(ValueKey('activity-switcher-nav-$view')),
                );
              } else {
                await tester.ensureVisible(
                  find.byKey(ValueKey('activity-view-$view')),
                );
                await tester.tap(find.byKey(ValueKey('activity-view-$view')));
              }
              await tester.pumpAndSettle();
            }

            await select('done');
            expect(
              find.byKey(const ValueKey('activity-channel-done-channel')),
              findsOneWidget,
            );
            expect(find.byTooltip('Restore conversation'), findsOneWidget);
            expect(find.text('5 active · 2 unread'), findsOneWidget);
            expect(
              find.byKey(const ValueKey('activity-switcher-dialog')),
              findsNothing,
            );
            final done = api.calls.lastWhere(
              (c) => c.path == '/channels/inbox/done',
            );
            expect(done.queryParameters, {
              'limit': 30,
              'offset': 0,
              'sort': 'desc',
            });
            await select('saved');
            expect(find.text('Accepted saved result'), findsOneWidget);
            expect(
              find.byTooltip('Mark conversation done'),
              findsNothing,
              reason: 'Source Saved activity rows have doneAction=none.',
            );
            final saved = api.calls.lastWhere(
              (c) => c.path == '/channels/saved',
            );
            expect(saved.queryParameters, {
              'limit': 20,
              'offset': 0,
              'sort': 'desc',
            });
            if (width >= 768) {
              await tester.tap(
                find.byKey(const ValueKey('activity-scope-switcher')),
              );
              await tester.pumpAndSettle();
              expect(
                find.byKey(
                  const ValueKey('activity-switcher-group-must-not-replace'),
                ),
                findsNothing,
              );
              await tester.tap(
                find.byKey(const ValueKey('activity-switcher-group-c1')),
              );
              await tester.pumpAndSettle();
              expect(
                api.calls
                    .lastWhere((c) => c.path == '/channels/saved')
                    .queryParameters['channelId'],
                'c1',
              );
              expect(
                api.calls
                    .lastWhere((c) => c.path == '/channels/inbox')
                    .queryParameters['channelId'],
                'c1',
              );
            }
            await select('unread');
            expect(
              api.calls
                  .lastWhere((c) => c.path == '/channels/inbox')
                  .queryParameters['filter'],
              'unread',
            );
            expect(find.byType(ResourceView), findsOneWidget);
          },
          variant: TargetPlatformVariant({
            width == 390 ? TargetPlatform.android : TargetPlatform.linux,
          }),
        );
      }
    }
  }
}
