import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/activity_find_scope.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/app_services_fixture.dart';

// Activity find (Cmd+F on Apple platforms, Ctrl+F elsewhere) on the mounted
// 1200x800 desktop WorkspaceView with activity_sidebar_inbox_v0 enabled, with
// real key events. Web ThreadsInbox: Activity owns the chord while the last
// pointer-down / focus was inside its panel, and leaves an opened
// conversation panel to its own finder.
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
  Map<String, dynamic> row(
    String id,
    String name, {
    int unread = 0,
    String? preview,
  }) => {
    'kind': 'channel',
    'channelId': id,
    'channelName': name,
    'lastMessagePreview': preview ?? 'Preview $name',
    'unreadCount': unread,
    'firstUnreadMessageId': unread > 0 ? 'first-$id' : null,
    'lastMessageId': 'last-$id',
  };
  late List<Map<String, dynamic>> inbox = [
    row('c', 'design', unread: 1),
    row('c2', 'random'),
  ];
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
        'items': [for (final row in inbox) Map<String, dynamic>.of(row)],
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
    if (path == '/feature-flags/evaluate') {
      return {
        'evaluations': [
          {'key': 'activity_sidebar_inbox_v0', 'enabled': true},
        ],
      };
    }
    return {};
  }
}

Future<(WorkspaceController, _Client)> _mount(WidgetTester t, bool dark) async {
  SharedPreferences.setMockInitialValues({});
  t.view.physicalSize = const Size(1200, 800);
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
  w.messageDomain.ledger.switchServer('s');
  addTearDown(() async {
    w.dispose();
    await client.stream.close();
  });
  final workspace = withAppServices(
    WorkspaceView(
      controller: w,
      appearance: RaftAppearance(mode: dark ? ThemeMode.dark : ThemeMode.light),
      onAppearance: (_) async {},
      onLogout: () async {},
    ),
  );
  await t.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: raftTheme(dark: dark),
      supportedLocales: const [Locale('en'), Locale('zh')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: workspace,
    ),
  );
  await t.pumpAndSettle();
  return (w, client);
}

Future<void> _rail(WidgetTester t, String id) async {
  await t.tap(find.byKey(Key('rail-$id')));
  await t.pumpAndSettle();
}

/// The platform's primary chord: Cmd+F on macOS, Ctrl+F on Linux / Windows.
Future<void> _find(WidgetTester t) async {
  final apple = defaultTargetPlatform == TargetPlatform.macOS;
  final modifier = apple
      ? LogicalKeyboardKey.metaLeft
      : LogicalKeyboardKey.controlLeft;
  await t.sendKeyDownEvent(modifier);
  await t.sendKeyEvent(LogicalKeyboardKey.keyF);
  await t.sendKeyUpEvent(modifier);
  await t.pump();
  await t.pump();
}

final _field = find.byType(RaftActivitySearchInput);
bool _opened() => _field.evaluate().isNotEmpty;

/// The query field has keyboard focus.
bool _focused(WidgetTester t) =>
    t.widget<RaftActivitySearchInput>(_field).focusNode.hasPrimaryFocus;

Future<(WorkspaceController, _Client)> _activity(WidgetTester t) async {
  final (w, client) = await _mount(t, false);
  w.setForeground(true);
  await _rail(t, 'activity');
  // 1200x800 with the flag evaluated: the master-detail Activity sidebar.
  expect(find.byType(RaftConversationCard), findsWidgets);
  return (w, client);
}

void main() {
  for (final platform in [
    TargetPlatform.macOS,
    TargetPlatform.linux,
    TargetPlatform.windows,
  ]) {
    final variant = TargetPlatformVariant.only(platform);
    final chord = platform == TargetPlatform.macOS ? 'Cmd+F' : 'Ctrl+F';

    testWidgets(
      '$chord on a freshly opened Activity opens find ($platform)',
      (t) async {
        await _activity(t);
        expect(_opened(), isFalse);
        await _find(t);
        expect(_opened(), isTrue);
        expect(_focused(t), isTrue);
        await t.pumpWidget(const SizedBox());
      },
      variant: variant,
    );

    testWidgets('$chord after a click on empty panel space ($platform)', (
      t,
    ) async {
      await _activity(t);
      // Below the last row: nothing focusable under the pointer.
      await t.tapAt(
        Offset(t.getCenter(find.byType(RaftConversationCard).first).dx, 780),
      );
      await t.pumpAndSettle();
      await _find(t);
      expect(_opened(), isTrue);
      expect(_focused(t), isTrue);
      await t.pumpWidget(const SizedBox());
    }, variant: variant);

    testWidgets('$chord after a real click on an Activity row ($platform)', (
      t,
    ) async {
      final (w, _) = await _activity(t);
      await t.tap(find.byKey(const ValueKey('activity-channel-c')));
      await t.pumpAndSettle();
      expect(w.location.content?.id, 'c');
      await _find(t);
      expect(_opened(), isTrue);
      expect(_focused(t), isTrue);
      await t.pumpWidget(const SizedBox());
    }, variant: variant);

    testWidgets('$chord with focus traversed into the panel ($platform)', (
      t,
    ) async {
      await _activity(t);
      final scope = FocusManager.instance.primaryFocus;
      // Walk focus until a control inside the Activity list holds it.
      final row = find.byType(RaftConversationCard).first;
      var inside = false;
      for (var i = 0; i < 40 && !inside; i++) {
        await t.sendKeyEvent(LogicalKeyboardKey.tab);
        await t.pump();
        final focus = FocusManager.instance.primaryFocus;
        inside =
            focus != null &&
            focus != scope &&
            find
                .ancestor(
                  of: find.byWidget(focus.context!.widget),
                  matching: row,
                )
                .evaluate()
                .isNotEmpty;
        if (!inside && focus?.context != null) {
          inside =
              focus!.context!
                  .findAncestorWidgetOfExactType<RaftConversationCard>() !=
              null;
        }
      }
      expect(inside, isTrue, reason: 'tab never reached an Activity row');
      await _find(t);
      expect(_opened(), isTrue);
      expect(_focused(t), isTrue);
      await t.pumpWidget(const SizedBox());
    }, variant: variant);

    testWidgets(
      'IME commit in the find field keeps the list and reloads once ($platform)',
      (t) async {
        final (_, client) = await _activity(t);
        await _find(t);
        expect(_focused(t), isTrue);
        final loads = client.calls
            .where((c) => c == 'GET:/channels/inbox')
            .length;
        // Pinyin: "a", "ab", "abc" compose, then the candidate commits.
        for (final text in ['a', 'ab', 'abc']) {
          t.testTextInput.updateEditingValue(
            TextEditingValue(
              text: text,
              selection: TextSelection.collapsed(offset: text.length),
              composing: TextRange(start: 0, end: text.length),
            ),
          );
          await t.pump(const Duration(milliseconds: 40));
        }
        await t.pump(const Duration(milliseconds: 300));
        t.testTextInput.updateEditingValue(
          const TextEditingValue(
            text: 'abc',
            selection: TextSelection.collapsed(offset: 3),
          ),
        );
        await t.pump();
        // The composition commit is the Search page's rule (it drops its
        // results and re-queries); Activity find only filters, so the list
        // stays painted and no second request is queued for it.
        expect(find.byType(RaftConversationCard), findsWidgets);
        await t.pump(const Duration(milliseconds: 400));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        expect(find.byType(RaftConversationCard), findsWidgets);
        expect(
          client.calls.where((c) => c == 'GET:/channels/inbox').length,
          loads + 1,
          reason: 'one reload for the typed text, none for the commit',
        );
        await t.pumpWidget(const SizedBox());
      },
      variant: variant,
    );

    testWidgets(
      '$chord with focus traversed out to the sidebar stays out ($platform)',
      (t) async {
        await _activity(t);
        // Web focusin outside the Activity panel ends its find scope:
        // Shift+Tab out to a rail control leaves Cmd/Ctrl+F to that surface.
        bool inPanel() =>
            FocusManager.instance.primaryFocus!.context!
                .findAncestorWidgetOfExactType<ActivityFindScope>() !=
            null;
        for (var i = 0; i < 40 && inPanel(); i++) {
          await t.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
          await t.sendKeyEvent(LogicalKeyboardKey.tab);
          await t.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
          await t.pump();
        }
        expect(inPanel(), isFalse, reason: 'shift+tab never left the panel');
        await _find(t);
        expect(_opened(), isFalse);
        await t.pumpWidget(const SizedBox());
      },
      variant: variant,
    );

    testWidgets('$chord selects the previous query on open ($platform)', (
      t,
    ) async {
      await _activity(t);
      await _find(t);
      await t.enterText(
        find.descendant(of: _field, matching: find.byType(EditableText)),
        'abc',
      );
      await t.pump();
      // Click away inside the panel (the field blurs), then find again.
      await t.tapAt(
        Offset(t.getCenter(find.byType(RaftConversationCard).first).dx, 780),
      );
      await t.pumpAndSettle();
      await _find(t);
      expect(_focused(t), isTrue);
      final input = t.widget<EditableText>(
        find.descendant(of: _field, matching: find.byType(EditableText)),
      );
      expect(
        input.controller.selection,
        const TextSelection(baseOffset: 0, extentOffset: 3),
      );
      await t.pumpWidget(const SizedBox());
    }, variant: variant);

    for (final (label, target) in [
      ('a non-focusable spot', find.text('Beginning of messages')),
      ('its composer', find.text('Message #design')),
    ]) {
      testWidgets(
        '$chord after a click on the conversation panel ($label) stays out ($platform)',
        (t) async {
          final (w, _) = await _activity(t);
          await t.tap(find.byKey(const ValueKey('activity-channel-c')));
          await t.pumpAndSettle();
          expect(w.location.content?.id, 'c');
          // The row click made Activity the keyboard scope; a click in the
          // preview hands it to the conversation, which keeps its own finder.
          await t.tap(target);
          await t.pumpAndSettle();
          await _find(t);
          expect(_opened(), isFalse);
          // Back in the Activity list the scope returns.
          await t.tapAt(
            Offset(
              t.getCenter(find.byType(RaftConversationCard).first).dx,
              780,
            ),
          );
          await t.pumpAndSettle();
          await _find(t);
          expect(_opened(), isTrue);
          await t.pumpWidget(const SizedBox());
        },
        variant: variant,
      );
    }
  }
}
