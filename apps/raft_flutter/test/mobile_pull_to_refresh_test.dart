import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/desktop_directory_view.dart';
import 'package:raft_flutter/features/resource_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'activity_incremental_refresh_test.dart'
    show activityFixture, channelRow, shown;
import 'mounted_message_navigation_test.dart' show mountPage;

class _RefreshClient extends RaftClient {
  _RefreshClient()
    : super(
        origin: 'https://refresh-fixture.invalid',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'alice'});
    selectServer('s');
  }
  final reads = <String>[];
  final routes = <String, FutureOr<dynamic> Function()>{};
  Completer<void>? hold;
  bool empty = false, fail = false;
  String name = 'Held';

  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    reads.add(path);
    final route = routes[path];
    if (route != null) return await route();
    final label = name, noRows = empty, failed = fail, gate = hold;
    if (gate != null) await gate.future;
    if (failed) throw StateError('Offline fixture');
    if (noRows) return [];
    if (path == '/agents') {
      return [
        {'id': 'agent', 'name': '$label agent'},
      ];
    }
    if (path.endsWith('/members')) {
      return [
        {'userId': 'human', 'name': '$label human'},
      ];
    }
    if (path.endsWith('/machines')) {
      return [
        {'id': 'machine', 'name': '$label computer'},
      ];
    }
    return [];
  }

  @override
  Future<dynamic> getForServer(
    String server,
    String path, {
    Map<String, dynamic>? query,
  }) => get(path, query: query);

  @override
  Future<dynamic> post(String path, {dynamic data}) async => {};

  @override
  Future<List<RaftRecord>> accountServers() async => [];
}

void mobile(WidgetTester t) {
  t.view.physicalSize = const Size(390, 844);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

Future<void> pull(WidgetTester t) async {
  await t.drag(find.byType(RefreshIndicator), const Offset(0, 360));
  await t.pump();
  await t.pump(const Duration(milliseconds: 500));
}

void main() {
  for (final (family, dark) in raftThemeMatrix([
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ])) {
    testWidgets(
      '$family/$dark Home pull refreshes channels, DMs and unread without bootstrap or losing drafts',
      (t) async {
        SharedPreferences.setMockInitialValues({});
        final api = _RefreshClient()..selectServer('s1');
        final w = WorkspaceController(api)
          ..server = RaftRecord({'id': 's1', 'role': 'owner'})
          ..channel = RaftChannel({'id': 'c1', 'name': 'test', 'joined': true})
          ..loading = false;
        w.channels = [w.channel!];
        w.messageDomain.ledger.switchServer('s1');
        addTearDown(() async {
          w.dispose();
          await api.dispose();
        });
        w.setSection('home');
        w.drafts['c1'] = 'Unsent draft';
        final gate = Completer<void>();
        api.routes['/channels'] = () async {
          await gate.future;
          return [
            {'id': 'c1', 'name': 'Updated channel', 'joined': true},
          ];
        };
        api.routes['/channels/dm'] = () async {
          await gate.future;
          return [];
        };
        api.routes['/channels/unread'] = () async {
          await gate.future;
          return {
            'channels': {'c1': 3},
          };
        };
        api.routes['/announcements/active'] = () => {'announcements': []};
        api.routes['/servers/s1/sidebar-order'] = () => {};
        await mountPage(t, w, family, dark, width: 390);
        expect(find.byType(RefreshIndicator), findsOneWidget);
        final before = api.reads.length;
        final location = w.location.uri;
        final held = find.byKey(const ValueKey('sidebar-channel-c1'));
        final heldElement = t.element(held);
        await pull(t);
        for (final path in ['/channels', '/channels/dm', '/channels/unread']) {
          expect(
            api.reads.skip(before).where((r) => r == path),
            hasLength(1),
            reason: path,
          );
        }
        expect(t.element(held), same(heldElement));
        expect(find.text('test'), findsOneWidget);
        expect(w.drafts['c1'], 'Unsent draft');
        expect(w.location.uri, location);
        expect(w.loading, isFalse);
        gate.complete();
        await t.pumpAndSettle();
        expect(find.text('Updated channel'), findsOneWidget);
        expect(w.unread['c1'], 3);
        expect(w.drafts['c1'], 'Unsent draft');
        expect(w.location.uri, location);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
      },
      variant: TargetPlatformVariant({TargetPlatform.android}),
    );

    for (final empty in [false, true]) {
      testWidgets(
        '$family/$dark Members empty=$empty refreshes shared directory in place and survives failure',
        (t) async {
          mobile(t);
          final client = _RefreshClient()..empty = empty;
          final w = WorkspaceController(client)
            ..server = RaftRecord({'id': 's', 'role': 'owner'});
          addTearDown(() async {
            w.dispose();
            await client.dispose();
          });
          await t.pumpWidget(
            MaterialApp(
              theme: raftTheme(
                family,
                dark: dark,
              ).copyWith(platform: TargetPlatform.android),
              home: Scaffold(
                body: DesktopDirectoryView(
                  controller: w,
                  mobileRoot: true,
                  onSelected: (_) {},
                ),
              ),
            ),
          );
          await t.pumpAndSettle();
          final reads = client.reads.length;
          final row = find.byKey(
            const ValueKey('desktop-directory-agent-agent'),
          );
          final held = empty ? null : t.element(row);
          final position = t
              .state<ScrollableState>(
                find.descendant(
                  of: find.byKey(const Key('desktop-directory-list')),
                  matching: find.byType(Scrollable),
                ),
              )
              .position;
          client.hold = Completer<void>();
          client.empty = false;
          client.name = 'Updated';
          await pull(t);
          expect(client.reads.length, reads + 3);
          if (!empty) {
            expect(t.element(row), same(held));
            expect(find.text('Held human'), findsOneWidget);
            expect(find.byType(RaftSidebarRowsSkeleton), findsNothing);
          }
          client.hold!.complete();
          await t.pumpAndSettle();
          client.hold = null;
          expect(find.text('Updated agent'), findsOneWidget);
          expect(find.text('Updated human'), findsOneWidget);
          expect(
            t
                .state<ScrollableState>(
                  find.descendant(
                    of: find.byKey(const Key('desktop-directory-list')),
                    matching: find.byType(Scrollable),
                  ),
                )
                .position,
            same(position),
          );
          client.fail = true;
          await pull(t);
          await t.pumpAndSettle();
          expect(find.text('Updated human'), findsOneWidget);
          expect(find.byType(RefreshProgressIndicator), findsNothing);
          client.fail = false;
          client.name = 'Recovered';
          await pull(t);
          await t.pumpAndSettle();
          expect(find.text('Recovered human'), findsOneWidget);
          expect(t.takeException(), isNull);
          await t.pumpWidget(const SizedBox());
        },
      );
    }

    for (final enabled in [false, true]) {
      testWidgets(
        '$family/$dark Activity enabled=$enabled refreshes populated and empty pager sections',
        (t) async {
          mobile(t);
          final (client, w) = activityFixture();
          addTearDown(() async {
            w.dispose();
            await client.dispose();
          });
          w.inbox = [
            {...channelRow(3, unread: 2), 'channelName': 'Held conversation'},
          ];
          await t.pumpWidget(
            MaterialApp(
              theme: raftTheme(
                family,
                dark: dark,
              ).copyWith(platform: TargetPlatform.android),
              home: Scaffold(
                body: ResourceView(
                  controller: w,
                  section: 'activity',
                  activitySidebarEnabled: enabled,
                  onMessage: (_, _) async {},
                ),
              ),
            ),
          );
          await t.pumpAndSettle();
          expect(shown('Held conversation'), findsOneWidget);
          final reads = w.inboxQueries.length;
          w.hold = Completer<void>();
          w.inbox = [
            {
              ...channelRow(3, unread: 2),
              'channelName': 'Updated conversation',
            },
          ];
          await pull(t);
          expect(w.inboxQueries.length, reads + 1);
          expect(shown('Held conversation'), findsOneWidget);
          expect(
            find.descendant(
              of: find.byType(RefreshIndicator),
              matching: find.byType(RaftActivityLoadingList),
            ),
            findsNothing,
          );
          w.hold!.complete();
          await t.pumpAndSettle();
          w.hold = null;
          expect(shown('Updated conversation'), findsOneWidget);
          // The horizontal gesture changes the section; it never arms refresh.
          await t.drag(
            find.byType(RaftSectionPager<String>),
            const Offset(-340, 0),
          );
          await t.pumpAndSettle();
          expect(find.byType(RefreshProgressIndicator), findsNothing);
          expect(
            t
                .widget<RaftSectionPager<String>>(
                  find.byType(RaftSectionPager<String>),
                )
                .value,
            'unread',
          );
          w.inbox.clear();
          await pull(t);
          await t.pumpAndSettle();
          expect(shown('Updated conversation'), findsNothing);
          final emptyReads = w.inboxQueries.length;
          w.inbox = [
            {
              ...channelRow(3, unread: 2),
              'channelName': 'Recovered conversation',
            },
          ];
          await pull(t);
          await t.pumpAndSettle();
          expect(w.inboxQueries.length, emptyReads + 1);
          expect(shown('Recovered conversation'), findsOneWidget);
          expect(
            t
                .widget<RaftSectionPager<String>>(
                  find.byType(RaftSectionPager<String>),
                )
                .value,
            'unread',
          );
          expect(t.takeException(), isNull);
          await t.pumpWidget(const SizedBox());
        },
      );
    }
  }
}
