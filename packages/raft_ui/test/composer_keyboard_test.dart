import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

/// Web `MessageInput.handleKeyDown` parity on every desktop platform, and the
/// mobile exception (Enter stays a newline; the Send button submits).
Widget _host(Widget child) => MaterialApp(
  theme: raftTheme(dark: false),
  home: Scaffold(body: Column(children: [const Spacer(), child])),
);

void _onPlatform(
  TargetPlatform platform,
  String description,
  Future<void> Function(WidgetTester) body,
) => testWidgets(description, (tester) async {
  debugDefaultTargetPlatformOverride = platform;
  try {
    await body(tester);
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
});

class _Rig {
  final sent = <String>[];
  final tasks = <String>[];
  Widget composer({
    List<RaftComposerSuggestion> suggestions = const [],
    String draft = '',
  }) => RaftComposer(
    initialDraft: draft,
    suggestions: suggestions,
    onSend: (text) async {
      sent.add(text);
      return true;
    },
    onForceTaskSendWithMentions: (text, _) async {
      tasks.add(text);
      return true;
    },
  );
}

String _text(WidgetTester tester) =>
    tester.widget<EditableText>(find.byType(EditableText)).controller.text;

Future<void> _focus(WidgetTester tester, Widget composer) async {
  await tester.pumpWidget(_host(composer));
  await tester.tap(find.byType(TextField));
  await tester.pump();
}

Future<void> _chord(
  WidgetTester tester,
  LogicalKeyboardKey key, {
  bool shift = false,
  bool meta = false,
  bool control = false,
  bool alt = false,
}) async {
  final mods = [
    if (shift) LogicalKeyboardKey.shiftLeft,
    if (meta) LogicalKeyboardKey.metaLeft,
    if (control) LogicalKeyboardKey.controlLeft,
    if (alt) LogicalKeyboardKey.altLeft,
  ];
  for (final m in mods) {
    await tester.sendKeyDownEvent(m);
  }
  await tester.sendKeyEvent(key);
  for (final m in mods.reversed) {
    await tester.sendKeyUpEvent(m);
  }
  await tester.pump();
  await tester.pump();
}

void main() {
  for (final platform in [
    TargetPlatform.macOS,
    TargetPlatform.windows,
    TargetPlatform.linux,
  ]) {
    group('$platform', () {
      void testWidgets(
        String description,
        Future<void> Function(WidgetTester) body,
      ) => _onPlatform(platform, description, body);

      testWidgets('Return sends the trimmed draft and clears the editor', (
        tester,
      ) async {
        final rig = _Rig();
        await _focus(tester, rig.composer());
        await tester.enterText(find.byType(TextField), '  hello  ');
        await _chord(tester, LogicalKeyboardKey.enter);
        expect(rig.sent, ['hello']);
        expect(_text(tester), '');
      });

      testWidgets('keypad Enter and Alt+Enter send like Web', (tester) async {
        final rig = _Rig();
        await _focus(tester, rig.composer());
        await tester.enterText(find.byType(TextField), 'one');
        // flutter_test has no Windows keycode for the keypad Enter.
        await _chord(
          tester,
          platform == TargetPlatform.windows
              ? LogicalKeyboardKey.enter
              : LogicalKeyboardKey.numpadEnter,
        );
        await tester.enterText(find.byType(TextField), 'two');
        await _chord(tester, LogicalKeyboardKey.enter, alt: true);
        expect(rig.sent, ['one', 'two']);
      });

      testWidgets('Shift+Return inserts a newline at the caret, no send', (
        tester,
      ) async {
        final rig = _Rig();
        await _focus(tester, rig.composer());
        await tester.enterText(find.byType(TextField), 'ab');
        tester.testTextInput.updateEditingValue(
          const TextEditingValue(
            text: 'ab',
            selection: TextSelection.collapsed(offset: 1),
          ),
        );
        await tester.pump();
        await _chord(tester, LogicalKeyboardKey.enter, shift: true);
        expect(_text(tester), 'a\nb');
        expect(rig.sent, isEmpty);
        await _chord(tester, LogicalKeyboardKey.enter, shift: true);
        expect(_text(tester), 'a\n\nb');
      });

      testWidgets('empty draft Return neither sends nor inserts', (
        tester,
      ) async {
        final rig = _Rig();
        await _focus(tester, rig.composer());
        await _chord(tester, LogicalKeyboardKey.enter);
        expect(rig.sent, isEmpty);
        expect(_text(tester), '');
      });

      testWidgets('Cmd/Ctrl+Enter sends; with Shift sends as task', (
        tester,
      ) async {
        final rig = _Rig();
        await _focus(tester, rig.composer());
        final meta = platform == TargetPlatform.macOS;
        await tester.enterText(find.byType(TextField), 'plain');
        await _chord(
          tester,
          LogicalKeyboardKey.enter,
          meta: meta,
          control: !meta,
        );
        await tester.enterText(find.byType(TextField), 'task');
        await _chord(
          tester,
          LogicalKeyboardKey.enter,
          shift: true,
          meta: meta,
          control: !meta,
        );
        expect(rig.sent, ['plain']);
        expect(rig.tasks, ['task']);
      });

      testWidgets('open suggestion popover: Return selects, never sends', (
        tester,
      ) async {
        final rig = _Rig();
        await _focus(
          tester,
          rig.composer(
            suggestions: const [
              RaftComposerSuggestion(type: 'user', id: 'a', name: 'Alice'),
            ],
          ),
        );
        await tester.enterText(find.byType(TextField), '@al');
        await tester.pump();
        await tester.pump();
        await _chord(tester, LogicalKeyboardKey.enter);
        expect(_text(tester), '@Alice ');
        expect(rig.sent, isEmpty);
        await _chord(tester, LogicalKeyboardKey.enter);
        expect(rig.sent, ['@Alice']);
      });

      testWidgets('Shift+Return with a popover open inserts a newline', (
        tester,
      ) async {
        final rig = _Rig();
        await _focus(
          tester,
          rig.composer(
            suggestions: const [
              RaftComposerSuggestion(type: 'user', id: 'a', name: 'Alice'),
            ],
          ),
        );
        await tester.enterText(find.byType(TextField), '@al');
        await tester.pump();
        await tester.pump();
        await _chord(tester, LogicalKeyboardKey.enter, shift: true);
        expect(_text(tester), '@al\n');
        expect(rig.sent, isEmpty);
      });

      testWidgets('IME composition: Return commits, never sends or breaks', (
        tester,
      ) async {
        final rig = _Rig();
        await _focus(tester, rig.composer());
        tester.testTextInput.updateEditingValue(
          const TextEditingValue(
            text: 'nihao',
            selection: TextSelection.collapsed(offset: 5),
            composing: TextRange(start: 0, end: 5),
          ),
        );
        await tester.pump();
        await _chord(tester, LogicalKeyboardKey.enter);
        await _chord(tester, LogicalKeyboardKey.enter, shift: true);
        await _chord(tester, LogicalKeyboardKey.enter, meta: true);
        expect(rig.sent, isEmpty);
        expect(_text(tester), 'nihao');
        // The IME commits; the next Return now sends.
        tester.testTextInput.updateEditingValue(
          const TextEditingValue(
            text: '你好',
            selection: TextSelection.collapsed(offset: 2),
          ),
        );
        await tester.pump();
        await _chord(tester, LogicalKeyboardKey.enter);
        expect(rig.sent, ['你好']);
      });

      testWidgets('text-input newline action is not a send', (tester) async {
        final rig = _Rig();
        await _focus(tester, rig.composer());
        await tester.enterText(find.byType(TextField), 'draft');
        await tester.testTextInput.receiveAction(TextInputAction.newline);
        await tester.pump();
        expect(rig.sent, isEmpty);
        expect(_text(tester), 'draft');
      });
    });
  }

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    group('$platform', () {
      void testWidgets(
        String description,
        Future<void> Function(WidgetTester) body,
      ) => _onPlatform(platform, description, body);

      testWidgets('Return never sends (Send button does)', (tester) async {
        final rig = _Rig();
        await _focus(tester, rig.composer());
        await tester.enterText(find.byType(TextField), 'draft');
        await _chord(tester, LogicalKeyboardKey.enter);
        expect(rig.sent, isEmpty);
        await tester.tap(find.byTooltip('Send'));
        await tester.pump();
        expect(rig.sent, ['draft']);
      });
    });
  }
}
