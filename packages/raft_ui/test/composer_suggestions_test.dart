import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

const choices = [
  RaftComposerSuggestion(
    type: 'user',
    id: 'human-id',
    name: 'same',
    title: 'Human Same',
  ),
  RaftComposerSuggestion(
    type: 'agent',
    id: 'agent-id',
    name: 'same',
    title: 'Agent Same',
  ),
  RaftComposerSuggestion(type: 'channel', id: 'channel-id', name: 'design'),
];
void main() {
  test('structured identity appears only in visible exact handle, including adjacent Chinese text', () {
    expect(raftStructuredMentionAppears('草案@Mona', 'Mona'), isTrue);
    expect(raftStructuredMentionAppears('draft@Mona', 'Mona'), isTrue);
    expect(raftStructuredMentionAppears('草案@Mona继续', 'Mona'), isFalse);
    expect(raftStructuredMentionAppears('`@Mona`', 'Mona'), isFalse);
    expect(raftStructuredMentionAppears('```\n@Mona\n```', 'Mona'), isFalse);
    expect(
      raftStructuredMentionAppears('[@Mona](<app:system.test>)', 'Mona'),
      isFalse,
    );
  });
  for (final dark in raftThemeMatrix([false, true])) {
    testWidgets(
      'keyboard binds selected duplicate handle identity and failed retry retains it: ${dark ? 'dark' : 'light'}',
      (tester) async {
        final sends = <List<Map<String, dynamic>>>[];
        var success = false;
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(dark: dark),
            home: Scaffold(
              body: Column(
                children: [
                  const Spacer(),
                  RaftComposer(
                    suggestions: choices,
                    onSend: (_) async => false,
                    onSendWithMentions: (_, mentions) async {
                      sends.add(mentions);
                      return success;
                    },
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.enterText(find.byType(TextField), '@sa');
        await tester.pump();
        expect(
          find.byKey(const ValueKey('composer-suggestion-user-human-id')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('composer-suggestion-agent-agent-id')),
          findsOneWidget,
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        expect(
          tester
              .widget<EditableText>(find.byType(EditableText))
              .controller
              .text,
          '@same ',
        );
        expect(sends, isEmpty); // Enter accepts completion rather than sending.
        await tester.tap(find.byTooltip('Send'));
        await tester.pump();
        expect(sends.single, [
          {'type': 'agent', 'id': 'agent-id', 'name': 'same'},
        ]);
        success = true;
        await tester.tap(find.byTooltip('Send'));
        await tester.pump();
        expect(sends.last, sends.first);
        expect(
          tester
              .widget<EditableText>(find.byType(EditableText))
              .controller
              .text,
          isEmpty,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  Future<String> pick(
    WidgetTester tester,
    List<RaftComposerSuggestion> suggestions,
    String typed,
    List<LogicalKeyboardKey> keys,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: Column(
            children: [
              const Spacer(),
              RaftComposer(suggestions: suggestions, onSend: (_) async => true),
            ],
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), typed);
    await tester.pump();
    for (final key in keys) {
      await tester.sendKeyEvent(key);
      await tester.pump();
    }
    return tester.widget<EditableText>(find.byType(EditableText)).controller.text;
  }

  List<RaftComposerSuggestion> people(int count, {int? Function(int)? rank}) => [
    for (var i = 0; i < count; i++)
      RaftComposerSuggestion(
        type: 'agent',
        id: 'a$i',
        name: 'agent$i',
        threadRank: rank?.call(i),
      ),
  ];

  // Web rankComposerSuggestions: a blank query lists every candidate and a
  // typed query keeps the 30 best; the popup is a scroll list, so a roster
  // longer than ten is reachable (ArrowUp wraps to the last option).
  testWidgets('blank @ lists the whole roster, not the first ten', (t) async {
    expect(
      await pick(t, people(25), '@', [
        LogicalKeyboardKey.arrowUp,
        LogicalKeyboardKey.enter,
      ]),
      '@agent24 ',
    );
  });
  testWidgets('typed @ query keeps the 30 best matches', (t) async {
    expect(
      await pick(t, people(40), '@agent', [
        LogicalKeyboardKey.arrowUp,
        LogicalKeyboardKey.enter,
      ]),
      '@agent29 ',
    );
  });
  testWidgets('thread recency leads each group, in-channel first', (t) async {
    final list = [
      ...people(4, rank: (i) => i == 2 ? 1 : (i == 3 ? 0 : null)),
      const RaftComposerSuggestion(
        type: 'agent',
        id: 'out',
        name: 'outsider',
        inChannel: false,
        threadRank: 0,
      ),
    ];
    // Recent speakers first (agent3, agent2), then roster order; a
    // not-in-channel speaker stays in its own later group.
    expect(
      await pick(t, list, '@', [LogicalKeyboardKey.enter]),
      '@agent3 ',
    );
    expect(
      await pick(t, list, '@', [
        LogicalKeyboardKey.arrowDown,
        LogicalKeyboardKey.enter,
      ]),
      '@agent2 ',
    );
    expect(
      await pick(t, list, '@', [
        LogicalKeyboardKey.arrowUp,
        LogicalKeyboardKey.enter,
      ]),
      '@outsider ',
    );
  });
  testWidgets(
    'channel name keeps intrinsic basis and description receives remaining width',
    (t) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          home: Scaffold(
            body: Column(
              children: [
                const Spacer(),
                RaftComposer(
                  suggestions: const [
                    RaftComposerSuggestion(
                      type: 'channel',
                      id: 'design',
                      name: 'design',
                      detail: 'Product and UI decisions',
                    ),
                  ],
                  onSend: (_) async => true,
                ),
              ],
            ),
          ),
        ),
      );
      await t.enterText(find.byType(TextField), '#');
      await t.pump();
      final title = find.text('design'),
          meta = find.text('Product and UI decisions');
      expect(t.getTopLeft(meta).dx - t.getTopRight(title).dx, closeTo(6, .01));
      final option = find.byKey(
        const ValueKey('composer-suggestion-channel-design'),
      );
      expect(
        t.getTopRight(meta).dx,
        greaterThan(t.getTopRight(option).dx - 20),
      );
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.pump();
      expect(
        t.widget<EditableText>(find.byType(EditableText)).controller.text,
        '#design ',
      );
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'channel Tab inserts text; Escape and IME keep draft intact; edited code does not send bound mention',
    (tester) async {
      String? sent;
      List<Map<String, dynamic>>? payload;
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          home: Scaffold(
            body: Column(
              children: [
                const Spacer(),
                RaftComposer(
                  suggestions: choices,
                  onSend: (_) async => false,
                  onSendWithMentions: (text, mentions) async {
                    sent = text;
                    payload = mentions;
                    return false;
                  },
                ),
              ],
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), '#des');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final field = tester.widget<EditableText>(find.byType(EditableText));
      expect(field.controller.text, '#design ');
      await tester.enterText(find.byType(TextField), '@sa');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(field.controller.text, '@sa');
      expect(find.byType(ListTile), findsNothing);
      field.controller.value = const TextEditingValue(
        text: '@sa日本',
        selection: TextSelection.collapsed(offset: 5),
        composing: TextRange(start: 3, end: 5),
      );
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(sent, isNull);
      expect(field.controller.text, '@sa日本');
      await tester.enterText(find.byType(TextField), '@sa');
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey('composer-suggestion-user-human-id')),
      );
      await tester.pump();
      await tester.enterText(find.byType(TextField), '`@same`');
      await tester.tap(find.byTooltip('Send'));
      await tester.pump();
      expect(sent, '`@same`');
      expect(payload, isEmpty);
    },
  );

  testWidgets('suggestion popover adds no safe-area gap above its first row', (
    tester,
  ) async {
    // Edge-to-edge phone: the status bar inset reaches the popover.
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(412, 915);
    tester.view.padding = const FakeViewPadding(top: 40, bottom: 24);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: Column(
            children: [
              const Spacer(),
              RaftComposer(suggestions: choices, onSend: (_) async => false),
            ],
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), '@sa');
    await tester.pump();
    final list = tester.getRect(
      find.ancestor(
        of: find.byKey(const ValueKey('composer-suggestion-user-human-id')),
        matching: find.byType(ListView),
      ),
    );
    final firstRow = tester.getRect(
      find.byKey(const ValueKey('composer-suggestion-user-human-id')),
    );
    // Rows (and their group label) start at the list's top, not 40dp lower.
    expect(firstRow.top - list.top, lessThan(40));
    expect(tester.takeException(), isNull);
  });
}
