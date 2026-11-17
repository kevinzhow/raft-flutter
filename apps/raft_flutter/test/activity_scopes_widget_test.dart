import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/activity_filter_choice.dart';
import 'package:raft_flutter/data/device_preferences.dart';
import 'package:raft_flutter/features/resource_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'activity_incremental_refresh_test.dart'
    show ActivityClient, ActivityWorkspace, activityFixture, channelRow;

/// The scoped answers of a server: empty Pinned, a failing Saved.
class ScopeWorkspace extends ActivityWorkspace {
  ScopeWorkspace(super.client);
  bool failScope = false;
  List<Map<String, dynamic>> objects = const [];

  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) async {
    if (path == '/channels/inbox' && query?['scope'] != null) {
      inboxQueries.add({...?query});
      if (failScope) throw const RaftApiException('Server error', status: 500);
      return {
        'items': query?['scope'] == 'artifacts' ? objects : [],
        'hasMore': false,
        'totalCount': 0,
        'totalUnreadCount': 0,
        'activeUnreadCount': 0,
      };
    }
    return super.query(path, query: query);
  }
}

void main() {
  late ActivityClient client;
  late ScopeWorkspace w;

  Future<dynamic> mount(WidgetTester t) async {
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: ResourceView(
            controller: w,
            section: 'activity',
            onMessage: (_, _) async {},
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    return t.state(find.byType(ResourceView));
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    DevicePreferences.adopt(await SharedPreferences.getInstance());
    final (c, base) = activityFixture();
    client = c;
    w = ScopeWorkspace(c)
      ..server = base.server
      ..channels = base.channels
      ..inbox = [for (var i = 0; i < 4; i++) channelRow(i, unread: i == 1 ? 2 : 0)];
  });
  tearDown(() async {
    w.dispose();
    await client.dispose();
    DevicePreferences.reset();
  });

  testWidgets('a scope asks Web exact query: filter all, its scope, sort desc, 50', (t) async {
    final dynamic state = await mount(t);
    expect(w.inboxQueries.first['limit'], 50);
    expect(w.inboxQueries.first['filter'], 'all');
    expect(w.inboxQueries.first.containsKey('scope'), isFalse);
    state.chooseActivityFilter(ActivityFilterChoice.pinned);
    await t.pumpAndSettle();
    final scoped = w.inboxQueries.where((q) => q['scope'] == 'pinned').first;
    expect(scoped['filter'], 'all');
    expect(scoped['sort'], 'desc');
    expect(scoped['limit'], 50);
    expect(w.inboxQueries.where((q) => q['scope'] == 'pinned').length, 1);
  });

  testWidgets('the choice is kept per server and read on the first frame', (t) async {
    final dynamic state = await mount(t);
    state.chooseActivityFilter(ActivityFilterChoice.saved);
    await t.pumpAndSettle();
    expect(ActivityFilterPreference.read('s1'), ActivityFilterChoice.saved);
    await t.pumpWidget(const SizedBox());
    final dynamic reopened = await mount(t);
    expect(reopened.filter, 'saved');
    expect(w.inboxQueries.last['scope'], 'saved');
  });

  testWidgets('an empty scope shows its own copy, never the default', (t) async {
    final dynamic state = await mount(t);
    state.chooseActivityFilter(ActivityFilterChoice.artifacts);
    await t.pumpAndSettle();
    expect(find.text('No Artifacts here'), findsOneWidget);
    expect(find.text('No conversations'), findsNothing);
  });

  testWidgets('no rows and a failed load show the banner, Retry resolves it', (t) async {
    final dynamic state = await mount(t);
    w.failScope = true;
    state.chooseActivityFilter(ActivityFilterChoice.pinned);
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('inbox-load-failed')), findsOneWidget);
    expect(find.text("Couldn't load Activity."), findsOneWidget);
    expect(find.text('No pinned conversations'), findsNothing);
    w.failScope = false;
    await t.tap(find.text('Retry'));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('inbox-load-failed')), findsNothing);
    expect(find.text('No pinned conversations'), findsOneWidget);
  });

  testWidgets('the banner is absent while rows are listed', (t) async {
    await mount(t);
    expect(find.byKey(const ValueKey('inbox-load-failed')), findsNothing);
  });

  testWidgets('an object row is keyed by its object and does not crash the list', (t) async {
    w.objects = [
      {
        'kind': 'object',
        'objectKind': 'artifact',
        'objectId': 'o1',
        'lastActivityAt': '2026-10-10T00:00:00Z',
        'unreadCount': 1,
        'hasMention': false,
        'doneFrontierSeq': '9',
      },
    ];
    final dynamic state = await mount(t);
    state.chooseActivityFilter(ActivityFilterChoice.artifacts);
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(state.rows, hasLength(1));
    expect(state.rowKey(state.rows.single), 'object:artifact:o1');
    expect(state.activityObjects.objectCount, 0);
  });

  testWidgets('Pinned reloads when the sidebar pins change', (t) async {
    final dynamic state = await mount(t);
    state.chooseActivityFilter(ActivityFilterChoice.pinned);
    await t.pumpAndSettle();
    final before = w.inboxQueries.where((q) => q['scope'] == 'pinned').length;
    w.sidebarOrder = {
      ...w.sidebarOrder,
      'pinned': [
        {'kind': 'channel', 'id': 'ch1'},
      ],
    };
    w.notifyListeners();
    await t.pumpAndSettle();
    expect(w.inboxQueries.where((q) => q['scope'] == 'pinned').length, before + 1);
  });

  testWidgets('Saved reloads when savedRevision changes', (t) async {
    final dynamic state = await mount(t);
    state.chooseActivityFilter(ActivityFilterChoice.saved);
    await t.pumpAndSettle();
    final before = w.inboxQueries.where((q) => q['scope'] == 'saved').length;
    w.savedRevision++;
    w.notifyListeners();
    await t.pumpAndSettle();
    expect(w.inboxQueries.where((q) => q['scope'] == 'saved').length, before + 1);
  });

  testWidgets('the counts line says in progress / unread and keeps the settled values', (t) async {
    final dynamic state = await mount(t);
    expect(find.text('4 in progress · 2 unread'), findsOneWidget);
    final hold = Completer<void>();
    w.hold = hold;
    state.chooseActivityFilter(ActivityFilterChoice.unread);
    await t.pump();
    expect(find.text('4 in progress · 2 unread'), findsOneWidget);
    hold.complete();
    w.hold = null;
    await t.pumpAndSettle();
  });
}
