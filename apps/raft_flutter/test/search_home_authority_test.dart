import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_flutter/data/search_memory.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/resource_view.dart';
import 'package:raft_flutter/features/search_home.dart';
import 'package:raft_flutter/features/resource_search.dart';

class _Storage implements SearchMemoryStorage {
  final pending = <String, Completer<String?>>{};
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => pending[key]?.future ?? values[key];
  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}

class _Workspace extends WorkspaceController {
  _Workspace(super.client);
  final queries = <String>[];
  final requests = <Map<String, dynamic>>[];
  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) async {
    if (path == '/messages/search') {
      queries.add(query!['q'] as String);
      requests.add(Map.of(query));
      return {'results': [], 'hasMore': false};
    }
    return [];
  }
}

void main() {
  late RaftClient client;
  late _Workspace w;
  late _Storage storage;
  late SearchMemoryStore memory;
  final now = DateTime.utc(2026, 10, 8);
  const scope = SearchMemoryScope('https://fixture.invalid', 's', 'owner');
  setUp(() {
    client = RaftClient(
      origin: scope.origin,
      sessionStore: MemorySessionStore(),
    )..user = RaftRecord({'id': 'owner'});
    client.selectServer('s');
    w = _Workspace(client)
      ..server = RaftRecord({'id': 's', 'role': 'owner'})
      ..channels = [
        RaftChannel({
          'id': 'private',
          'name': 'Private discussions',
          'joined': true,
        }),
      ];
    storage = _Storage();
    memory = SearchMemoryStore(storage: storage, clock: () => now);
  });
  tearDown(() async {
    w.dispose();
    await client.dispose();
  });
  Future<void> mount(
    WidgetTester t, {
    String? initialQuery,
    bool restore = true,
    Future<void> Function(String, String?)? onMessage,
  }) async {
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(RaftFamily.elegant),
        home: Scaffold(
          body: ResourceView(
            controller: w,
            section: 'search',
            searchMemory: memory,
            clock: () => now,
            initialQuery: initialQuery,
            restoreSearchState: restore,
            onMessage: onMessage ?? (_, _) async {},
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  testWidgets('late storage restoration cannot replace a current typed query', (
    t,
  ) async {
    storage.pending[scope.key] = Completer<String?>();
    await mount(t);
    await t.enterText(find.byType(TextField), 'Current input');
    await t.pump(const Duration(milliseconds: 210));
    storage.pending[scope.key]!.complete(
      jsonEncode({
        'state': {'q': 'Old restored query'},
      }),
    );
    await t.pumpAndSettle();
    expect(
      t.widget<TextField>(find.byType(TextField)).controller!.text,
      'Current input',
    );
    expect(w.queries, isNot(contains('Old restored query')));
    expect(memory.current(scope).state.query, 'Current input');
  });
  testWidgets(
    'history activation searches; removal/clear actually update scoped storage',
    (t) async {
      memory.rememberQuery(scope, 'Android');
      memory.rememberQuery(scope, 'Other');
      await mount(t, initialQuery: '');
      await t.tap(find.bySemanticsLabel('Search history: Android'));
      await t.pump(const Duration(milliseconds: 210));
      expect(w.queries.last, 'Android');
      final field = t.widget<TextField>(find.byType(TextField));
      await t.enterText(find.byType(TextField), '');
      await t.pump(const Duration(milliseconds: 210));
      expect(field.controller!.text, '');
      final mouse = await t.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(
        t.getCenter(find.bySemanticsLabel('Search history: Other')),
      );
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Remove history: Other'));
      await mouse.removePointer();
      await t.pumpAndSettle();
      expect(memory.current(scope).history, ['Android']);
      await t.tap(find.text('Clear history'));
      await t.pumpAndSettle();
      expect(memory.current(scope).history, isEmpty);
      await memory.flush();
      expect(
        SearchMemoryData.decode(storage.values[scope.key], now).history,
        isEmpty,
      );
    },
  );
  testWidgets(
    'role revocation removes frequent private rows and retained callback cannot navigate',
    (t) async {
      memory.recordOpen(scope, 'channel:private');
      final opened = <String>[];
      await mount(
        t,
        initialQuery: '',
        onMessage: (id, _) async {
          opened.add(id);
        },
      );
      expect(find.text('Private discussions'), findsOneWidget);
      final home = t.widget<ResourceSearchHome>(
        find.byType(ResourceSearchHome),
      );
      final private = home.frequent.single;
      w.server = RaftRecord({'id': 's', 'role': 'guest'});
      w.channels = [];
      w.notifyListeners();
      await t.pumpAndSettle();
      expect(find.text('Private discussions'), findsNothing);
      home.onEntity(private);
      await t.pumpAndSettle();
      expect(opened, isEmpty);
      expect(
        storage.values.values.join(),
        isNot(contains('Private discussions')),
      );
    },
  );
  testWidgets(
    'old principal late read cannot show history or state in the next principal',
    (t) async {
      storage.pending[scope.key] = Completer<String?>();
      await mount(t);
      client.user = RaftRecord({'id': 'next'});
      w.notifyListeners();
      await t.pumpAndSettle();
      storage.pending[scope.key]!.complete(
        jsonEncode({
          'history': ['Old personal history'],
          'state': {'q': 'Old private query'},
          'usage': {
            'channel:private': [now.millisecondsSinceEpoch],
          },
        }),
      );
      await t.pumpAndSettle();
      expect(find.text('Old personal history'), findsNothing);
      expect(t.widget<TextField>(find.byType(TextField)).controller!.text, '');
      expect(find.text('Private discussions'), findsNothing);
      expect(w.queries, isNot(contains('Old private query')));
    },
  );
  testWidgets('restoration drops unavailable channel and sender identifiers', (
    t,
  ) async {
    memory.saveState(
      scope,
      const SearchStateSnapshot(
        query: 'Android',
        channelId: 'revoked',
        senderKey: 'user:removed',
        scopes: ['humans'],
        range: '7d',
        sort: 'recent',
      ),
    );
    await mount(t);
    expect(
      t.widget<TextField>(find.byType(TextField)).controller!.text,
      'Android',
    );
    expect(w.requests.last['channelId'], isNull);
    expect(w.requests.last['senderId'], isNull);
    expect(memory.current(scope).state.channelId, isNull);
    expect(memory.current(scope).state.senderKey, isNull);
    expect(memory.current(scope).state.scopes, ['humans']);
    expect(memory.current(scope).state.sort, 'recent');
  });
  testWidgets('fresh rail entry skips saved state but keeps personal history', (
    t,
  ) async {
    memory.saveState(
      scope,
      const SearchStateSnapshot(query: 'Old query', channelId: 'private'),
    );
    memory.rememberQuery(scope, 'Android');
    await mount(t, restore: false);
    expect(t.widget<TextField>(find.byType(TextField)).controller!.text, '');
    expect(find.bySemanticsLabel('Search history: Android'), findsOneWidget);
    expect(w.queries, isNot(contains('Old query')));
  });
  testWidgets('blank sort is disabled; committed query enables it', (t) async {
    await mount(t, initialQuery: '');
    RaftDropdownMenu sort() => t
        .widgetList<RaftDropdownMenu>(find.byType(RaftDropdownMenu))
        .firstWhere((menu) => menu.glyph == RaftGlyph.arrowDownUp);
    expect(sort().enabled, isFalse);
    await t.enterText(find.byType(TextField), 'Android');
    await t.pump(const Duration(milliseconds: 210));
    expect(sort().enabled, isTrue);
  });
  testWidgets(
    'touch history removes only in edit mode and exits edit when emptied',
    (t) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      memory.rememberQuery(scope, 'Android');
      await mount(t, initialQuery: '');
      expect(find.byTooltip('Remove history: Android'), findsNothing);
      await t.tap(find.text('Edit'));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Remove history: Android'));
      await t.pumpAndSettle();
      expect(memory.current(scope).history, isEmpty);
      expect(find.text('Done'), findsNothing);
    },
  );
  testWidgets(
    'accepted navigation persists usage before the page is disposed',
    (t) async {
      memory.recordOpen(scope, 'channel:private');
      var recordedBeforeNavigation = false;
      await mount(
        t,
        initialQuery: '',
        onMessage: (_, _) async {
          recordedBeforeNavigation =
              memory.current(scope).history.contains('Private') &&
              memory.current(scope).usage.containsKey('channel:private');
        },
      );
      await t.enterText(find.byType(TextField), 'Private');
      await t.pump(const Duration(milliseconds: 210));
      await t.pumpAndSettle();
      final tile = t.widget<ResourceSearchResults>(
        find.byType(ResourceSearchResults),
      );
      tile.onEntity(tile.entities.single);
      await t.pumpAndSettle();
      expect(recordedBeforeNavigation, isTrue);
      await t.pumpWidget(const SizedBox());
      await t.pump();
      expect(memory.current(scope).history, ['Private']);
      expect(
        memory.current(scope).usage.containsKey('channel:private'),
        isTrue,
      );
    },
  );
}
