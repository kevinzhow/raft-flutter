import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/user_activity.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/page_layout.dart';
import 'package:raft_flutter/features/resource_view.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Activity/Search channel preview contract: one location owns the detail
// title, rail highlight, master list, detail body and Back, and read admission
// follows that visible location. Driven through the mounted WorkspaceView with
// real rail, sidebar, search, activity, Escape and Close controls.
class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://public-fixture.invalid',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'alice', 'displayName': 'Alice'});
  }
  final stream = StreamController<RaftEvent>.broadcast(sync: true);
  final calls = <String>[];
  final channelRows = [
    RaftChannel({
      'id': 'c',
      'serverId': 's',
      'name': 'design',
      'type': 'channel',
      'joined': true,
    }),
    RaftChannel({
      'id': 'c2',
      'serverId': 's',
      'name': 'random',
      'type': 'channel',
      'joined': true,
    }),
  ];
  @override
  Stream<RaftEvent> get events => stream.stream;
  @override
  void connect() {}
  @override
  void joinChannel(String id) {}
  @override
  Future<List<RaftRecord>> servers() async => [
    RaftRecord({'id': 's', 'slug': 'fixture', 'name': 'Fixture'}),
  ];
  @override
  Future<List<RaftChannel>> channels({bool dm = false}) async =>
      dm ? [] : channelRows;
  @override
  Future<Map<String, dynamic>> messagePage(
    String id, {
    int limit = 50,
    BigInt? before,
    BigInt? after,
  }) async {
    calls.add('messages:$id');
    return {
      'messages': [message('$id-tail', id, 1)],
      'threadSummariesByParentMessageId': {},
    };
  }

  Map<String, dynamic> message(String id, String channel, int seq) => {
    'id': id,
    'channelId': channel,
    'serverId': 's',
    'seq': '$seq',
    'content': 'Public $id',
    'senderId': 'other',
    'senderType': 'user',
    'createdAt': '2026-10-08T00:00:00Z',
  };

  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    calls.add('GET:$path');
    if (path == '/messages/search') {
      return {
        'results': [
          {
            ...message('hit', 'c', 1),
            'content': 'Selected public hit',
            'channelName': 'design',
            'senderName': 'Public sender',
          },
          {
            ...message('hit2', 'c2', 1),
            'content': 'Other public hit',
            'channelName': 'random',
            'senderName': 'Public sender',
          },
        ],
        'hasMore': false,
      };
    }
    if (path == '/channels/inbox') {
      return {
        'items': [
          {
            'kind': 'channel',
            'channelId': 'c',
            'channelName': 'design',
            'lastMessagePreview': 'Activity preview row',
            'unreadCount': 1,
            'firstUnreadMessageId': 'act',
            'lastMessageId': 'act',
          },
        ],
      };
    }
    for (final row in channelRows) {
      if (path == '/channels/${row.id}') return row.json;
    }
    if (path.startsWith('/messages/context/')) {
      final id = path.split('/').last;
      return {
        'messages': [message(id, '${query?['channelId'] ?? 'c'}', 1)],
      };
    }
    if (path == '/channels/threads/followed') return {'threads': []};
    if (path == '/channels/unread') return {'channels': {}};
    if (path.endsWith('/sidebar-order')) {
      return {'pinned': [], 'customSections': [], 'sectionPlacements': []};
    }
    if (path.endsWith('/setup-projection')) {
      return {'phase': 'complete', 'surface': 'complete', 'blocksChat': false};
    }
    return [];
  }

  @override
  Future<dynamic> post(String path, {dynamic data}) async {
    calls.add('POST:$path');
    if (path.endsWith('/read')) {
      return {'maxReadSeq': '1', 'readStateVersion': '1'};
    }
    if (path == '/feature-flags/evaluate') return {'evaluations': []};
    return {};
  }
}

Future<(WorkspaceController, _Client)> _mount(
  WidgetTester t,
  RaftFamily family,
  bool dark,
) async {
  SharedPreferences.setMockInitialValues({});
  t.view.physicalSize = const Size(1440, 900);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final client = _Client()..selectServer('s');
  final w = WorkspaceController(client)
    ..server = RaftRecord({
      'id': 's',
      'slug': 'fixture',
      'name': 'Fixture',
      'role': 'owner',
    })
    ..channels = client.channelRows
    ..channel = client.channelRows.first
    ..section = 'chat';
  w.ledger.switchServer('s');
  addTearDown(() async {
    w.dispose();
    await client.stream.close();
  });
  await t.pumpWidget(
    MaterialApp(
      theme: raftTheme(family, dark: dark),
      home: WorkspaceView(
        controller: w,
        appearance: RaftAppearance(
          mode: dark ? ThemeMode.dark : ThemeMode.light,
          light: family,
        ),
        onAppearance: (_) async {},
        onLogout: () async {},
      ),
    ),
  );
  await t.pumpAndSettle();
  return (w, client);
}

String _selectedRail(WidgetTester t) =>
    t.widget<RaftWorkspaceRail>(find.byType(RaftWorkspaceRail)).selected;

Future<void> _rail(WidgetTester t, String id) async {
  await t.tap(find.byKey(Key('rail-$id')));
  await t.pumpAndSettle();
}

void main() {
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    testWidgets(
      '[N27] $family/$dark Activity/Search channel preview: title, rail, master, detail and Back follow one location; hidden channel stays unread',
      (t) async {
        final semantics = t.ensureSemantics();
        final (w, client) = await _mount(t, family, dark);
        w.setForeground(true);
        await t.tap(
          find.descendant(
            of: find.byKey(const Key('workspace-sidebar-panel')),
            matching: find.text('random'),
          ),
        );
        await t.pumpAndSettle();
        expect(w.location.toString(), '/s/fixture/channel/c2');
        int reads(String id) =>
            client.calls.where((c) => c == 'POST:/channels/$id/read').length;
        Future<void> live(String id, String channel, int seq) async {
          RaftUserActivity.mark();
          client.stream.add(
            RaftEvent('message:new', client.message(id, channel, seq)),
          );
          await t.pumpAndSettle();
        }

        // Control: the visible chat conversation does accept a live read.
        final visibleReads = reads('c2');
        await live('live-visible', 'c2', 2);
        expect(reads('c2'), greaterThan(visibleReads));

        String? headerTitle() =>
            find
                .descendant(
                  of: find.byKey(const Key('desktop-content-detail')),
                  matching: find.byType(RaftPageHeader),
                )
                .evaluate()
                .isEmpty
            ? null
            : t
                  .widget<RaftPageHeader>(
                    find.descendant(
                      of: find.byKey(const Key('desktop-content-detail')),
                      matching: find.byType(RaftPageHeader),
                    ),
                  )
                  .title;
        void expectPreview(String surface, String? channelId, String? name) {
          expect(w.location.route.name, surface);
          expect(w.location.content?.id, channelId);
          expect(w.section, surface);
          // Rail highlight and sidebar follow the location's surface.
          expect(_selectedRail(t), surface);
          expect(
            t.getSemantics(find.byKey(Key('rail-$surface'))),
            isSemantics(isSelected: true),
          );
          expect(
            find.byKey(const Key('workspace-sidebar-panel')),
            findsNothing,
          );
          // The master list stays mounted alongside the detail.
          expect(find.byType(ResourceView), findsOneWidget);
          expect(headerTitle(), name);
          if (channelId == null) {
            expect(
              find.byKey(const Key('desktop-content-detail')),
              findsNothing,
            );
          } else {
            expect(w.channel?.id, channelId);
            expect(
              find.descendant(
                of: find.byKey(const Key('desktop-content-detail')),
                matching: find.text('Public ${w.location.messageId}'),
              ),
              findsWidgets,
            );
          }
        }

        // Search: open one result, retarget to another, then Back.
        await _rail(t, 'search');
        expectPreview('search', null, null);
        await t.enterText(find.byType(TextField).first, 'public');
        await t.pump(const Duration(milliseconds: 500));
        await t.pumpAndSettle();
        final master = t.state(find.byType(ResourceView));
        await t.tap(find.text('Selected public hit'));
        await t.pumpAndSettle();
        expectPreview('search', 'c', 'design');
        expect(w.location.messageId, 'hit');
        expect(t.state(find.byType(ResourceView)), same(master));
        await t.tap(find.text('Other public hit'));
        await t.pumpAndSettle();
        expectPreview('search', 'c2', 'random');
        expect(w.location.messageId, 'hit2');
        expect(w.location.query('q'), 'public');
        expect(t.state(find.byType(ResourceView)), same(master));
        // Desktop Back (Escape) closes only the preview slot; query and
        // master remain.
        await t.sendKeyEvent(LogicalKeyboardKey.escape);
        await t.pumpAndSettle();
        expectPreview('search', null, null);
        expect(w.location.query('q'), 'public');
        expect(t.state(find.byType(ResourceView)), same(master));
        // The closed preview is hidden: a live arrival is not marked read.
        final hiddenSearch = reads('c2');
        await live('live-hidden-search', 'c2', 3);
        expect(reads('c2'), hiddenSearch);

        // Activity: open the row, close via its real Close control.
        await _rail(t, 'activity');
        expectPreview('activity', null, null);
        final hiddenMain = reads('c2');
        await live('live-hidden-activity', 'c2', 4);
        expect(reads('c2'), hiddenMain);
        await t.tap(find.byKey(const ValueKey('activity-channel-c')));
        // The mounted Activity consumer owns Source's 220 ms single-open wait.
        await t.pump(const Duration(milliseconds: 250));
        await t.pumpAndSettle();
        expectPreview('activity', 'c', 'design');
        expect(w.location.messageId, 'act');
        // Control: the visible preview does accept a live read.
        final visiblePreview = reads('c');
        await live('live-visible-preview', 'c', 5);
        expect(reads('c'), greaterThan(visiblePreview));
        await t.tap(find.byTooltip('Close detail'));
        await t.pumpAndSettle();
        expectPreview('activity', null, null);
        final hiddenActivity = reads('c');
        await live('live-hidden-preview', 'c', 6);
        expect(reads('c'), hiddenActivity);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
        semantics.dispose();
      },
    );
  }
}
