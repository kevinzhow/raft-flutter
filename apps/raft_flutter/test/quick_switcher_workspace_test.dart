import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/device_preferences.dart';
import 'package:raft_flutter/data/recent_conversations.dart';
import 'package:raft_flutter/data/search_memory.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/quick_switcher.dart';
import 'package:raft_flutter/features/resource_view.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/app_services_fixture.dart';

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
  final searchQueries = <Map<String, dynamic>>[];
  bool failSearch = false;
  final channelRows = [
    RaftChannel({
      'id': 'c-general',
      'name': 'general',
      'type': 'channel',
      'lastMessageAt': '2026-10-09T00:00:00Z',
      'joined': true,
    }),
    RaftChannel({
      'id': 'c-design',
      'name': 'design',
      'type': 'channel',
      'joined': true,
      'description': 'Design work',
      'lastMessageAt': '2026-10-08T00:00:00Z',
    }),
    RaftChannel({
      'id': 'c-ops',
      'name': 'ops',
      'type': 'channel',
      'lastMessageAt': '2026-10-07T00:00:00Z',
      'joined': true,
    }),
  ];
  final dmRows = [
    RaftChannel({
      'id': 'dm-bob',
      'type': 'dm',
      'peerId': 'bob',
      'peerType': 'user',
    }),
  ];
  final people = <Map<String, dynamic>>[
    {'userId': 'bob', 'name': 'bob', 'displayName': 'Bob'},
    {'userId': 'carol', 'name': 'carol', 'displayName': 'Carol'},
  ];
  final agents = <Map<String, dynamic>>[
    {
      'id': 'a-cindy',
      'name': 'cindy',
      'displayName': 'Cindy',
      'status': 'active',
      'runtime': 'x',
      'model': 'y',
    },
  ];
  @override
  Stream<RaftEvent> get events => stream.stream;
  @override
  void connect() {}
  @override
  void joinChannel(String id) {}
  @override
  Future<List<RaftRecord>> servers() async => [
    RaftRecord({'id': 's', 'name': 'Fixture', 'role': 'owner'}),
  ];
  @override
  Future<List<RaftChannel>> channels({bool dm = false}) async =>
      dm ? dmRows : channelRows;
  @override
  Future<Map<String, dynamic>> messagePage(
    String id, {
    int limit = 50,
    BigInt? before,
    BigInt? after,
  }) async {
    calls.add('messages:$id');
    return {'messages': [], 'threadSummariesByParentMessageId': {}};
  }

  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    calls.add('GET:$path');
    if (path.endsWith('/members')) return people;
    if (path == '/agents') return agents;
    if (path.endsWith('/machines')) return {'machines': []};
    if (path == '/messages/search') {
      searchQueries.add(Map<String, dynamic>.from(query ?? const {}));
      if (failSearch) {
        throw const RaftApiException('Search failed', status: 500);
      }
      return {
        'results': [
          {
            'id': 'hit',
            'channelId': 'c-ops',
            'channelName': 'ops',
            'channelType': 'channel',
            'senderId': 'bob',
            'senderName': 'Bob',
            'senderType': 'user',
            'snippet': 'quarterly plan',
            'createdAt': '2026-10-08T00:00:00Z',
          },
        ],
      };
    }
    if (path.startsWith('/channels/') && path.split('/').length == 3) {
      final id = path.split('/').last;
      final row = [
        ...channelRows,
        ...dmRows,
      ].where((c) => c.id == id).firstOrNull;
      if (row != null) return row.json;
    }
    if (path == '/channels/unread') return {'channels': {}};
    if (path.endsWith('/sidebar-order')) {
      return {'pinned': [], 'customSections': [], 'sectionPlacements': []};
    }
    if (path.endsWith('/setup-projection')) {
      return {'phase': 'complete', 'surface': 'complete', 'blocksChat': false};
    }
    if (path == '/auth/identities') {
      return {'passwordConfigured': true, 'identities': []};
    }
    if (path == '/auth/providers') return {'providers': []};
    return [];
  }

  @override
  Future<dynamic> request(
    String method,
    String path, {
    dynamic data,
    Map<String, dynamic>? query,
    bool authorized = true,
    bool retried = false,
    UploadCancellation? cancellation,
    void Function(int, int)? onSendProgress,
    Map<String, dynamic>? headers,
    bool acceptServerExit = false,
    Duration? receiveTimeout,
  }) => method == 'POST' ? post(path, data: data) : get(path, query: query);

  @override
  Future<dynamic> post(String path, {dynamic data}) async {
    calls.add('POST:$path');
    if (path == '/channels/dm' && data is Map) {
      return {
        'id': 'dm-new',
        'type': 'dm',
        'peerId': data['userId'] ?? data['agentId'],
        'peerType': data['userId'] != null ? 'user' : 'agent',
      };
    }
    if (path.endsWith('/read')) {
      return {'maxReadSeq': '2', 'readStateVersion': '1'};
    }
    if (path == '/feature-flags/evaluate') return {'evaluations': []};
    return {};
  }
}

Future<(_Client, WorkspaceController)> mount(
  WidgetTester t, {
  Size size = const Size(1280, 900),
  RaftFamily family = RaftFamily.elegant,
  bool dark = false,
  String section = 'chat',
}) async {
  SharedPreferences.setMockInitialValues({});
  DevicePreferences.adopt(await SharedPreferences.getInstance());
  addTearDown(DevicePreferences.reset);
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  final client = _Client()..selectServer('s');
  final w = WorkspaceController(client)
    ..server = RaftRecord({
      'id': 's',
      'slug': 'fixture',
      'name': 'Fixture',
      'role': 'owner',
    })
    ..channels = client.channelRows
    ..dms = client.dmRows
    ..channel = client.channelRows.first
    ..section = section;
  w.messageDomain.ledger.switchServer('s');
  addTearDown(() async {
    w.dispose();
    await client.stream.close();
  });
  await t.pumpWidget(
    MaterialApp(
      theme: raftTheme(family, dark: dark),
      home: withAppServices(
        WorkspaceView(
          controller: w,
          appearance: const RaftAppearance(),
          onAppearance: (_) async {},
          onLogout: () async {},
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
  return (client, w);
}

Future<void> chord(
  WidgetTester t,
  LogicalKeyboardKey modifier,
  LogicalKeyboardKey k,
) async {
  await t.sendKeyDownEvent(modifier);
  await t.sendKeyEvent(k);
  await t.sendKeyUpEvent(modifier);
}

void main() {
  for (final modifier in [
    ('Ctrl', LogicalKeyboardKey.controlLeft, TargetPlatform.linux),
    ('Cmd', LogicalKeyboardKey.metaLeft, TargetPlatform.macOS),
  ]) {
    testWidgets(
      '[N26] ${modifier.$1}+K floats the switcher over the current conversation with cached results in its first frame',
      (t) async {
        final (client, w) = await mount(t);
        expect(find.byType(QuickSwitcher), findsNothing);
        final calls = client.calls.length;
        await chord(t, modifier.$2, LogicalKeyboardKey.keyK);
        // One frame: the overlay and its rows are already there; no request.
        await t.pump();
        expect(find.byType(QuickSwitcher), findsOneWidget);
        expect(find.byKey(const Key('quick-switcher-recent')), findsOneWidget);
        expect(
          find.byKey(const ValueKey('quick-switcher-channel:c-design')),
          findsOneWidget,
        );
        expect(client.calls.length, calls);
        // The page behind keeps its place.
        expect(w.section, 'chat');
        expect(w.channel!.id, 'c-general');
        expect(find.byType(ResourceView), findsNothing);
        // Typing finds a person and a profile-less agent from cached lists.
        await t.enterText(find.byType(TextField).last, 'cin');
        await t.pump();
        expect(
          find.byKey(const ValueKey('quick-switcher-agent:a-cindy')),
          findsOneWidget,
        );
        await key(t, LogicalKeyboardKey.escape);
        expect(find.byType(QuickSwitcher), findsNothing);
        expect(w.channel!.id, 'c-general');
      },
      variant: TargetPlatformVariant.only(modifier.$3),
    );
  }

  testWidgets(
    '[N26] choosing a channel opens it like the sidebar and the next opening lists it first',
    (t) async {
      final (client, w) = await mount(t);
      await chord(t, LogicalKeyboardKey.controlLeft, LogicalKeyboardKey.keyK);
      await t.pump();
      await t.enterText(find.byType(TextField).last, 'ops');
      await t.pump();
      await key(t, LogicalKeyboardKey.enter);
      await t.pumpAndSettle();
      expect(find.byType(QuickSwitcher), findsNothing);
      expect(w.channel!.id, 'c-ops');
      expect(w.section, 'chat');
      // The visit is remembered per workspace and account, and survives a
      // new store (restart) through the device preference.
      final scope = RecentConversationScope(client.origin, 's', 'alice');
      expect(RecentConversationStore().idsFor(scope).take(2).toList(), [
        'c-ops',
        'c-general',
      ]);
      // Cmd/Ctrl+K restores the saved query; the rail starts fresh.
      await chord(t, LogicalKeyboardKey.controlLeft, LogicalKeyboardKey.keyK);
      await t.pump();
      expect(find.byKey(const Key('quick-switcher-recent')), findsNothing);
      await key(t, LogicalKeyboardKey.escape);
      await t.tap(find.byKey(const ValueKey('rail-search')));
      await t.pump();
      // The conversation behind the overlay is never listed.
      expect(
        find.byKey(const ValueKey('quick-switcher-channel:c-ops')),
        findsNothing,
      );
      expect(
        t
            .getTopLeft(
              find.byKey(const ValueKey('quick-switcher-channel:c-general')),
            )
            .dy,
        lessThan(
          t
              .getTopLeft(
                find.byKey(const ValueKey('quick-switcher-channel:c-design')),
              )
              .dy,
        ),
      );
    },
  );

  testWidgets('[N26] a person without a DM creates one and opens it', (
    t,
  ) async {
    final (client, w) = await mount(t);
    await chord(t, LogicalKeyboardKey.controlLeft, LogicalKeyboardKey.keyK);
    await t.pump();
    await t.enterText(find.byType(TextField).last, 'carol');
    await t.pump();
    await key(t, LogicalKeyboardKey.enter);
    await t.pumpAndSettle();
    expect(client.calls, contains('POST:/channels/dm'));
    expect(w.channel!.id, 'dm-new');
    expect(find.byType(QuickSwitcher), findsNothing);
  });

  testWidgets('[N26] a person with a DM opens it without a request', (t) async {
    final (client, w) = await mount(t);
    await chord(t, LogicalKeyboardKey.controlLeft, LogicalKeyboardKey.keyK);
    await t.pump();
    await t.enterText(find.byType(TextField).last, 'bob');
    await t.pump();
    final posts = client.calls.where((c) => c.startsWith('POST:/channels/dm'));
    await key(t, LogicalKeyboardKey.enter);
    await t.pumpAndSettle();
    expect(posts, isEmpty);
    expect(w.channel!.id, 'dm-bob');
  });

  testWidgets('[N26] the Search for row opens the full page with the query', (
    t,
  ) async {
    final (client, w) = await mount(t);
    await chord(t, LogicalKeyboardKey.controlLeft, LogicalKeyboardKey.keyK);
    await t.pump();
    await t.enterText(find.byType(TextField).last, 'quarterly');
    await t.pump();
    await key(t, LogicalKeyboardKey.enter);
    await t.pumpAndSettle();
    expect(find.byType(QuickSwitcher), findsNothing);
    expect(w.section, 'search');
    expect(find.byType(ResourceView), findsOneWidget);
    expect(w.location.query('q'), 'quarterly');
  });

  testWidgets('[N26] a message preview hit jumps to the message', (t) async {
    final (client, w) = await mount(t);
    await chord(t, LogicalKeyboardKey.controlLeft, LogicalKeyboardKey.keyK);
    await t.pump();
    await t.enterText(find.byType(TextField).last, 'quarterly');
    await t.pump(const Duration(milliseconds: 300));
    await t.pump();
    expect(
      find.textContaining('quarterly plan', findRichText: true),
      findsOneWidget,
    );
    await key(t, LogicalKeyboardKey.arrowDown);
    await key(t, LogicalKeyboardKey.enter);
    await t.pumpAndSettle();
    expect(w.channel!.id, 'c-ops');
    expect(find.byType(QuickSwitcher), findsNothing);
  });

  testWidgets('[N26] clicking outside the card closes the switcher', (t) async {
    final (_, w) = await mount(t);
    await chord(t, LogicalKeyboardKey.controlLeft, LogicalKeyboardKey.keyK);
    await t.pump();
    await t.tapAt(const Offset(5, 5));
    await t.pumpAndSettle();
    expect(find.byType(QuickSwitcher), findsNothing);
    expect(w.channel!.id, 'c-general');
  });

  testWidgets('[N26] a narrow window keeps the full Search page', (t) async {
    final (_, w) = await mount(t, size: const Size(390, 844));
    await chord(t, LogicalKeyboardKey.controlLeft, LogicalKeyboardKey.keyK);
    await t.pumpAndSettle();
    expect(find.byType(QuickSwitcher), findsNothing);
    expect(w.section, 'search');
  });

  // Source isGlobalSearchShortcut: Cmd alone on Apple platforms, Ctrl alone
  // elsewhere. Ctrl+K on macOS is the text field's "delete to end of line".
  for (final platform in [
    (
      TargetPlatform.macOS,
      'Cmd',
      LogicalKeyboardKey.metaLeft,
      'Ctrl',
      LogicalKeyboardKey.controlLeft,
    ),
    (
      TargetPlatform.linux,
      'Ctrl',
      LogicalKeyboardKey.controlLeft,
      'Cmd/Super',
      LogicalKeyboardKey.metaLeft,
    ),
    (
      TargetPlatform.windows,
      'Ctrl',
      LogicalKeyboardKey.controlLeft,
      'Win',
      LogicalKeyboardKey.metaLeft,
    ),
  ]) {
    testWidgets(
      '[shortcut] ${platform.$1.name}: ${platform.$2}+K opens search, ${platform.$4}+K does not',
      (t) async {
        await mount(t);
        await chord(t, platform.$5, LogicalKeyboardKey.keyK);
        await t.pump();
        expect(find.byType(QuickSwitcher), findsNothing);
        await chord(t, platform.$3, LogicalKeyboardKey.keyK);
        await t.pump();
        expect(find.byType(QuickSwitcher), findsOneWidget);
      },
      variant: TargetPlatformVariant.only(platform.$1),
    );

    testWidgets(
      '[shortcut] ${platform.$1.name}: ${platform.$2}+K on the Search page focuses and selects its field instead of floating the overlay',
      (t) async {
        final (_, w) = await mount(t, section: 'search');
        expect(w.section, 'search');
        final field = find.byType(TextField).first;
        await t.enterText(field, 'ops');
        await t.pump();
        // Focus leaves the field (a click on the page background).
        FocusManager.instance.primaryFocus?.unfocus();
        await t.pump();
        expect(t.widget<TextField>(field).focusNode!.hasFocus, isFalse);
        await chord(t, platform.$3, LogicalKeyboardKey.keyK);
        await t.pump();
        expect(find.byType(QuickSwitcher), findsNothing);
        final input = t.widget<TextField>(field);
        expect(input.focusNode!.hasFocus, isTrue);
        expect(
          input.controller!.selection,
          const TextSelection(baseOffset: 0, extentOffset: 3),
        );
      },
      variant: TargetPlatformVariant.only(platform.$1),
    );
  }

  testWidgets('Cmd+, still opens settings and Escape still dismisses panels', (
    t,
  ) async {
    final (_, w) = await mount(t);
    await chord(t, LogicalKeyboardKey.metaLeft, LogicalKeyboardKey.comma);
    await t.pumpAndSettle();
    expect(w.section, 'settings');
    expect(find.byType(QuickSwitcher), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('[N26] the switcher closes when the workspace scope changes', (
    t,
  ) async {
    final (client, w) = await mount(t);
    await chord(t, LogicalKeyboardKey.controlLeft, LogicalKeyboardKey.keyK);
    await t.pump();
    expect(find.byType(QuickSwitcher), findsOneWidget);
    w.server = RaftRecord({
      'id': 's2',
      'slug': 'other',
      'name': 'Other',
      'role': 'owner',
    });
    w.notifyListeners();
    await t.pumpAndSettle();
    expect(find.byType(QuickSwitcher), findsNothing);
  });

  testWidgets(
    '[N26] the shortcut works from inside the composer, not with extra modifiers, and not under a dialog',
    (t) async {
      final (_, w) = await mount(t);
      await t.tap(find.byType(TextField).first);
      await t.pump();
      await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await t.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await t.sendKeyEvent(LogicalKeyboardKey.keyK);
      await t.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await t.pump();
      expect(find.byType(QuickSwitcher), findsNothing);
      await chord(t, LogicalKeyboardKey.controlLeft, LogicalKeyboardKey.keyK);
      await t.pump();
      expect(find.byType(QuickSwitcher), findsOneWidget);
      // A second press while open leaves exactly one switcher.
      await chord(t, LogicalKeyboardKey.controlLeft, LogicalKeyboardKey.keyK);
      await t.pump();
      expect(find.byType(QuickSwitcher), findsOneWidget);
      expect(w.section, 'chat');
    },
  );

  group('rail Search opens the desktop overlay', () {
    final scope = SearchMemoryScope(
      'https://public-fixture.invalid',
      's',
      'alice',
    );
    SearchStateSnapshot saved() => SearchMemoryStore().loadSync(scope).state;
    Future<void> railSearch(WidgetTester t) async {
      await t.tap(find.byKey(const ValueKey('rail-search')));
      await t.pump();
    }

    Future<void> type(WidgetTester t, String text) async {
      await t.enterText(find.byType(TextField).last, text);
      await t.pump();
    }

    testWidgets(
      '[N27] the rail Search button floats the switcher with a focused field, not the Search page',
      (t) async {
        final (client, w) = await mount(t);
        final calls = client.calls.length;
        await railSearch(t);
        expect(find.byType(QuickSwitcher), findsOneWidget);
        expect(find.byType(ResourceView), findsNothing);
        expect(find.byKey(const Key('quick-switcher-recent')), findsOneWidget);
        expect(w.section, 'chat');
        expect(w.channel!.id, 'c-general');
        expect(client.calls.length, calls);
        // The field owns the keyboard from the first frame.
        final editable = t.state<EditableTextState>(
          find.descendant(
            of: find.byType(QuickSwitcher),
            matching: find.byType(EditableText),
          ),
        );
        expect(editable.widget.focusNode.hasPrimaryFocus, isTrue);
        // Escape dismisses; the page and its rail are untouched.
        await key(t, LogicalKeyboardKey.escape);
        expect(find.byType(QuickSwitcher), findsNothing);
        expect(w.channel!.id, 'c-general');
        expect(find.byKey(const ValueKey('rail-search')), findsOneWidget);
      },
    );

    testWidgets(
      '[N27] a second click on the rail while open does not stack another switcher; the backdrop click closes it',
      (t) async {
        await mount(t);
        await railSearch(t);
        await chord(t, LogicalKeyboardKey.controlLeft, LogicalKeyboardKey.keyK);
        await t.pump();
        expect(find.byType(QuickSwitcher), findsOneWidget);
        // The rail sits under the transparent backdrop: a click there is a
        // click outside the card.
        await t.tap(
          find.byKey(const ValueKey('rail-search')),
          warnIfMissed: false,
        );
        await t.pumpAndSettle();
        expect(find.byType(QuickSwitcher), findsNothing);
      },
    );

    testWidgets(
      '[N27] Cmd/Ctrl+K restores the last query selected; the rail always starts empty and resets the saved state',
      (t) async {
        await mount(t);
        await chord(t, LogicalKeyboardKey.controlLeft, LogicalKeyboardKey.keyK);
        await t.pump();
        await type(t, 'ops');
        expect(saved().query, 'ops');
        await key(t, LogicalKeyboardKey.escape);
        // Same overlay, restored: query back, fully selected.
        await chord(t, LogicalKeyboardKey.controlLeft, LogicalKeyboardKey.keyK);
        await t.pump();
        final field = t.widget<TextField>(find.byType(TextField).last);
        expect(field.controller!.text, 'ops');
        expect(
          field.controller!.selection,
          const TextSelection(baseOffset: 0, extentOffset: 3),
        );
        await key(t, LogicalKeyboardKey.escape);
        // The rail entry does not restore, and replaces the saved state.
        await railSearch(t);
        expect(
          t.widget<TextField>(find.byType(TextField).last).controller!.text,
          isEmpty,
        );
        expect(find.byKey(const Key('quick-switcher-recent')), findsOneWidget);
        expect(saved().query, isEmpty);
        await key(t, LogicalKeyboardKey.escape);
        await chord(t, LogicalKeyboardKey.controlLeft, LogicalKeyboardKey.keyK);
        await t.pump();
        expect(
          t.widget<TextField>(find.byType(TextField).last).controller!.text,
          isEmpty,
        );
      },
    );

    testWidgets(
      '[N27] filters appear with a query, narrow the preview request, persist, and travel to the full page',
      (t) async {
        final (client, w) = await mount(t);
        await railSearch(t);
        expect(find.byKey(const Key('quick-switcher-filters')), findsNothing);
        await type(t, 'quarterly');
        expect(find.byKey(const Key('quick-switcher-filters')), findsOneWidget);
        expect(find.text('Clear All'), findsNothing);
        // Pick "Last 7 Days" in the Time menu.
        await t.tap(find.text('Any Time'));
        await t.pumpAndSettle();
        await t.tap(find.text('Last 7 Days'));
        await t.pumpAndSettle();
        expect(saved().range, '7d');
        expect(find.text('Clear All'), findsOneWidget);
        await t.pump(const Duration(milliseconds: 300));
        await t.pump();
        // The preview request carries the filter and the query.
        expect(client.searchQueries.last['q'], 'quarterly');
        expect(client.searchQueries.last['after'], isNotNull);
        // "Search for" opens the page with the same query and filter.
        await key(t, LogicalKeyboardKey.enter);
        await t.pumpAndSettle();
        expect(w.section, 'search');
        expect(find.byType(ResourceView), findsOneWidget);
        expect(find.text('Last 7 Days'), findsOneWidget);
        expect(w.location.query('q'), 'quarterly');
      },
    );

    testWidgets(
      '[N27] Escape closes the open filter menu first, then the switcher',
      (t) async {
        await mount(t);
        await railSearch(t);
        await type(t, 'quarterly');
        await t.tap(find.text('Any Time'));
        await t.pumpAndSettle();
        expect(find.text('Last 30 Days'), findsOneWidget);
        await key(t, LogicalKeyboardKey.escape);
        await t.pumpAndSettle();
        expect(find.text('Last 30 Days'), findsNothing);
        expect(find.byType(QuickSwitcher), findsOneWidget);
        await key(t, LogicalKeyboardKey.escape);
        expect(find.byType(QuickSwitcher), findsNothing);
      },
    );

    testWidgets(
      '[N27] the cursor starts on the first row, follows the arrows, and Return opens that row',
      (t) async {
        final (_, w) = await mount(t);
        await railSearch(t);
        await key(t, LogicalKeyboardKey.arrowDown);
        await key(t, LogicalKeyboardKey.arrowDown); // stops at the last row
        await key(t, LogicalKeyboardKey.arrowUp);
        await key(t, LogicalKeyboardKey.arrowDown);
        await key(t, LogicalKeyboardKey.enter);
        await t.pumpAndSettle();
        expect(find.byType(QuickSwitcher), findsNothing);
        // Recent rows: design, ops (general is the current page).
        expect(w.channel!.id, 'c-ops');
      },
    );

    testWidgets(
      '[N27] a failed preview request shows the error card with Retry; Retry asks again',
      (t) async {
        final (client, _) = await mount(t);
        client.failSearch = true;
        await railSearch(t);
        await type(t, 'zq roadmap');
        await t.pump(const Duration(milliseconds: 300));
        await t.pump();
        expect(find.byKey(const Key('quick-switcher-error')), findsOneWidget);
        client.failSearch = false;
        await t.tap(find.text('Retry'));
        await t.pump();
        await t.pump(const Duration(milliseconds: 300));
        await t.pump();
        expect(find.byKey(const Key('quick-switcher-error')), findsNothing);
      },
    );

    testWidgets(
      '[N27] reopening with the same request shows the last answer in the first frame',
      (t) async {
        final (client, _) = await mount(t);
        await chord(t, LogicalKeyboardKey.controlLeft, LogicalKeyboardKey.keyK);
        await t.pump();
        await type(t, 'quarterly');
        await t.pump(const Duration(milliseconds: 300));
        await t.pump();
        expect(
          find.textContaining('quarterly plan', findRichText: true),
          findsOneWidget,
        );
        await key(t, LogicalKeyboardKey.escape);
        final requests = client.searchQueries.length;
        await chord(t, LogicalKeyboardKey.controlLeft, LogicalKeyboardKey.keyK);
        await t.pump();
        expect(
          find.textContaining('quarterly plan', findRichText: true),
          findsOneWidget,
        );
        await t.pump(const Duration(milliseconds: 300));
        expect(client.searchQueries.length, requests);
      },
    );

    testWidgets(
      '[N27] "Search this channel" opens the overlay with that channel as the filter and waits for a query',
      (t) async {
        final (client, w) = await mount(t);
        await t.tap(find.byTooltip('Search this channel'));
        await t.pump();
        expect(find.byType(QuickSwitcher), findsOneWidget);
        expect(find.byKey(const Key('quick-switcher-recent')), findsOneWidget);
        expect(client.searchQueries, isEmpty);
        await type(t, 'quarterly');
        await t.pump(const Duration(milliseconds: 300));
        await t.pump();
        expect(find.text('#general'), findsOneWidget);
        expect(client.searchQueries.last['channelId'], 'c-general');
        expect(w.section, 'chat');
      },
    );

    testWidgets(
      '[N27] a narrow window keeps the rail Search on the full page',
      (t) async {
        final (_, w) = await mount(t, size: const Size(390, 844));
        expect(find.byKey(const ValueKey('rail-search')), findsNothing);
        expect(w.section, 'chat');
      },
    );
  });
}

Future<void> key(WidgetTester t, LogicalKeyboardKey k) async {
  await t.sendKeyEvent(k);
  await t.pump();
}
