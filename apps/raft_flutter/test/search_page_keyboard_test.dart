import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/resource_view.dart';
import 'package:raft_flutter/features/search_filter_bar.dart';
import 'package:raft_ui/raft_ui.dart';

/// Search page keyboard contract (Source MessageSearchPage `handleRailKeyDown`,
/// `focusSearchInput`, `isSearchKeyboardComposing`) and its thread-group and
/// zh rendering.
class _Workspace extends WorkspaceController {
  _Workspace(super.client);
  Object? search;
  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) async {
    if (path == '/messages/search') return search;
    if (path.endsWith('/members') || path == '/agents') return [];
    if (path.endsWith('/machines')) return [];
    return {};
  }
}

Map<String, dynamic> hit(
  String id, {
  String? thread,
  String text = 'ops note',
  String sender = 'Cindy',
}) => {
  'id': id,
  'channelId': thread == null ? 'c' : 'thread-$thread',
  'threadId': thread,
  'parentMessageId': thread == null ? null : 'parent-$thread',
  'parentMessageContent': thread == null ? null : 'Parent of $thread',
  'parentChannelId': 'c',
  'parentChannelName': 'ops',
  'parentChannelType': 'channel',
  'channelType': thread == null ? 'channel' : 'thread',
  'channelName': 'ops',
  'senderId': 'owner',
  'senderType': 'user',
  'senderName': sender,
  'snippet': text,
  'content': text,
  'createdAt': '2026-06-19T10:00:00.000Z',
};

void main() {
  late RaftClient client;
  late _Workspace w;
  var backs = 0;
  setUp(() {
    backs = 0;
    client = RaftClient(
      origin: 'https://fixture.invalid',
      sessionStore: MemorySessionStore(),
    )..user = RaftRecord({'id': 'owner', 'name': 'Owner'});
    client.selectServer('s');
    w = _Workspace(client)
      ..server = RaftRecord({'id': 's', 'role': 'owner'})
      ..channels = [
        RaftChannel({'id': 'c', 'name': 'ops', 'joined': true}),
      ]
      ..search = {
        'results': [hit('m1'), hit('m2'), hit('m3')],
        'hasMore': false,
      };
  });
  tearDown(() async {
    w.dispose();
    await client.dispose();
  });

  Future<void> mount(
    WidgetTester t, {
    Size size = const Size(1280, 800),
    String query = 'note',
    Locale locale = const Locale('en'),
    TargetPlatform platform = TargetPlatform.linux,
  }) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(
      MaterialApp(
        locale: locale,
        supportedLocales: const [Locale('en'), Locale('zh')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: raftTheme().copyWith(platform: platform),
        home: Scaffold(
          body: ResourceView(
            controller: w,
            section: 'search',
            initialQuery: query,
            restoreSearchState: false,
            onBack: () => backs++,
            onMessage: (_, _) async {},
          ),
        ),
      ),
    );
    await t.pump(const Duration(milliseconds: 400));
    await t.pumpAndSettle();
  }

  bool selected(WidgetTester t, String id) => t
      .widget<RaftQuickSwitcherHit>(find.byKey(ValueKey('search-message:$id')))
      .selected;

  Future<void> press(WidgetTester t, LogicalKeyboardKey key) async {
    await t.sendKeyEvent(key);
    await t.pump();
  }

  testWidgets('a desktop Search page focuses its field on mount', (t) async {
    await mount(t);
    final field = t.widget<TextField>(find.byType(TextField).first);
    expect(field.focusNode!.hasFocus, isTrue);
  });

  testWidgets('a phone keeps the keyboard down until a tap', (t) async {
    await mount(
      t,
      size: const Size(390, 844),
      platform: TargetPlatform.android,
    );
    final field = t.widget<TextField>(find.byType(TextField).first);
    expect(field.focusNode!.hasFocus, isFalse);
  });

  // The keyboard follows the input, not the width: an unfolded foldable is as
  // wide as a desktop window and a narrow desktop window as narrow as a phone.
  testWidgets('an unfolded foldable keeps the keyboard down until a tap', (
    t,
  ) async {
    for (final size in const [Size(856, 944), Size(944, 856)]) {
      await mount(t, size: size, platform: TargetPlatform.android);
      final field = t.widget<TextField>(find.byType(TextField).first);
      expect(field.focusNode!.hasFocus, isFalse, reason: '$size');
      await t.pumpWidget(const SizedBox());
    }
  });

  testWidgets('a narrow desktop window focuses its field on mount', (t) async {
    await mount(t, size: const Size(390, 844));
    final field = t.widget<TextField>(find.byType(TextField).first);
    expect(field.focusNode!.hasFocus, isTrue);
  });

  testWidgets('the first result is the selected one before any key', (t) async {
    await mount(t);
    expect(selected(t, 'm1'), isTrue);
    expect(selected(t, 'm2'), isFalse);
  });

  testWidgets('Up and Down move the cursor and stop at the ends', (t) async {
    await mount(t);
    await press(t, LogicalKeyboardKey.arrowUp);
    expect(selected(t, 'm1'), isTrue);
    await press(t, LogicalKeyboardKey.arrowDown);
    await press(t, LogicalKeyboardKey.arrowDown);
    await press(t, LogicalKeyboardKey.arrowDown);
    expect(selected(t, 'm3'), isTrue);
    await press(t, LogicalKeyboardKey.arrowUp);
    expect(selected(t, 'm2'), isTrue);
  });

  testWidgets(
    'Escape leaves Search while focus is on a filter chip, not only in the field',
    (t) async {
      await mount(t);
      // Focus leaves the field for a filter chip.
      final chipFocus = find
          .descendant(
            of: find.byType(SearchFilterBar),
            matching: find.byType(Focus),
          )
          .evaluate()
          .map((e) {
            // The node of this Focus widget: ask from its first child.
            late final Element child;
            e.visitChildren((c) => child = c);
            return Focus.maybeOf(child, createDependency: false)!;
          })
          .firstWhere((node) => node.canRequestFocus && !node.skipTraversal);
      chipFocus.requestFocus();
      await t.pump();
      final field = t.widget<TextField>(find.byType(TextField).first);
      expect(field.focusNode!.hasFocus, isFalse);
      await press(t, LogicalKeyboardKey.escape);
      expect(backs, 1);
    },
  );

  testWidgets('Escape in the field leaves Search once', (t) async {
    await mount(t);
    await press(t, LogicalKeyboardKey.escape);
    expect(backs, 1);
  });

  testWidgets('IME composition owns Escape and the arrows', (t) async {
    await mount(t);
    await t.showKeyboard(find.byType(TextField).first);
    final field = t.widget<TextField>(find.byType(TextField).first);
    expect(field.focusNode!.hasFocus, isTrue);
    // Pinyin in progress: "zi" is composing text.
    t.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'note',
        selection: TextSelection.collapsed(offset: 4),
        composing: TextRange(start: 0, end: 4),
      ),
    );
    await t.pump();
    await press(t, LogicalKeyboardKey.arrowDown);
    expect(selected(t, 'm1'), isTrue);
    await press(t, LogicalKeyboardKey.escape);
    expect(backs, 0);
    // The composition commits: the keys work again.
    t.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'note',
        selection: TextSelection.collapsed(offset: 4),
      ),
    );
    await t.pump();
    await press(t, LogicalKeyboardKey.escape);
    expect(backs, 1);
  });

  testWidgets(
    'a thread with one hit still shares a titled card; other hits stay single',
    (t) async {
      w.search = {
        'results': [
          hit('t1', thread: 'a', text: 'note one'),
          hit('t2', thread: 'a', text: 'note two'),
          hit('t3', thread: 'b', text: 'note three'),
          hit('m1'),
          // A thread channel without a threadId is not grouped (Source).
          {...hit('t4', thread: 'c'), 'threadId': null},
        ],
        'hasMore': false,
      };
      await mount(t);
      expect(find.byType(RaftQuickSwitcherThreadGroup), findsNWidgets(2));
      expect(find.text('Parent of a'), findsOneWidget);
      expect(find.text('Parent of b'), findsOneWidget);
      expect(find.text('2 hits'), findsOneWidget);
      expect(find.text('1 hit'), findsOneWidget);
      // The first hit is selected, so its group is the selected card.
      expect(selected(t, 't1'), isTrue);
    },
  );

  testWidgets('filter chips and empty states are Chinese in zh', (t) async {
    w.search = {'results': [], 'hasMore': false};
    await mount(t, locale: const Locale('zh'), query: '自动更新');
    expect(find.text('不限时间'), findsOneWidget);
    expect(find.text('相关度'), findsOneWidget);
    expect(find.text('Any Time'), findsNothing);
    expect(find.text('Relevant'), findsNothing);
    expect(find.text('没有找到“自动更新”的结果'), findsOneWidget);
    expect(find.text('试试其他关键词或更短的短语。'), findsOneWidget);
  });

  testWidgets('the recent sort reads 最新 in zh (Web search.sortRecent)', (
    t,
  ) async {
    await mount(t, locale: const Locale('zh'), query: '自动更新');
    await t.tap(find.text('相关度'));
    await t.pumpAndSettle();
    expect(find.text('最新'), findsOneWidget);
    expect(find.text('最近'), findsNothing);
  });

  for (final platform in [
    (TargetPlatform.macOS, '⌘K'),
    (TargetPlatform.linux, 'Ctrl+K'),
    (TargetPlatform.windows, 'Ctrl+K'),
  ]) {
    testWidgets('the field hint shows ${platform.$2} on ${platform.$1.name}', (
      t,
    ) async {
      await mount(t);
      final field = t.widget<TextField>(find.byType(TextField).first);
      expect(field.decoration!.hintText, endsWith(platform.$2));
    }, variant: TargetPlatformVariant.only(platform.$1));
  }
}
