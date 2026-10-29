import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

/// The expandable composer: the expand button on the inline composer and the
/// expanded editor, tested through the real [RaftComposer].
const _three = 'one\ntwo\nthree';

class _Rig {
  final sent = <String>[];
  final tasks = <String>[];
  final mentions = <List<Map<String, dynamic>>>[];
  final drafts = <String>[];
  Widget composer({
    String draft = '',
    List<RaftComposerSuggestion> suggestions = const [],
    Widget Function(BuildContext, String)? previewBuilder,
    VoidCallback? onAttach,
  }) => RaftComposer(
    initialDraft: draft,
    suggestions: suggestions,
    onAttach: onAttach,
    onImagePick: onAttach,
    previewBuilder: previewBuilder,
    onDraftChanged: drafts.add,
    onSend: (text) async {
      sent.add(text);
      return true;
    },
    onSendWithMentions: (text, picked) async {
      sent.add(text);
      mentions.add(picked);
      return true;
    },
    onForceTaskSendWithMentions: (text, _) async {
      tasks.add(text);
      return true;
    },
  );
}

Widget _host(
  Widget child, {
  bool dark = false,
  double scale = 1,
  double keyboard = 0,
}) => MaterialApp(
  theme: raftTheme(dark: dark),
  builder: (context, home) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      textScaler: TextScaler.linear(scale),
      viewInsets: EdgeInsets.only(bottom: keyboard),
    ),
    child: home!,
  ),
  home: Scaffold(body: Column(children: [const Spacer(), child])),
);

void _size(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

const _desktop = Size(1000, 800), _phone = Size(412, 915);

final _expandButton = find.byKey(const ValueKey('composer-expand'));
final _expandedView = find.byType(RaftComposerExpandedView);

Finder _tool(String tooltip) => find.byWidgetPredicate(
  (w) => w is RaftComposerToolButton && w.tooltip == tooltip,
);

/// The inline text field is first in the tree; the expanded one is last.
Finder get _fields => find.byType(TextField);
TextField _inline(WidgetTester t) => t.widget<TextField>(_fields.first);
TextField _expandedField(WidgetTester t) => t.widget<TextField>(_fields.last);

TextEditingController _controller(WidgetTester t) => _inline(t).controller!;

Future<void> _open(WidgetTester tester) async {
  await tester.tap(_expandButton);
  await tester.pumpAndSettle();
  expect(_expandedView, findsOneWidget);
}

Future<void> _chord(
  WidgetTester tester,
  LogicalKeyboardKey key, {
  bool shift = false,
  bool meta = false,
  bool control = false,
}) async {
  final mods = [
    if (shift) LogicalKeyboardKey.shiftLeft,
    if (meta) LogicalKeyboardKey.metaLeft,
    if (control) LogicalKeyboardKey.controlLeft,
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

void _setValue(WidgetTester tester, String text, int base, [int? extent]) {
  _controller(tester).value = TextEditingValue(
    text: text,
    selection: TextSelection(baseOffset: base, extentOffset: extent ?? base),
  );
}

void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    group('expand button ${dark ? 'dark' : 'light'}', () {
      testWidgets('appears from 3 lines, not at 1 or 2', (tester) async {
        _size(tester, _desktop);
        final rig = _Rig();
        for (final (text, shown) in [
          ('', false),
          ('one line', false),
          ('one\ntwo', false),
          ('one\ntwo\nthree', true),
          ('one\ntwo\nthree\nfour\nfive\nsix\nseven\neight', true),
        ]) {
          await tester.pumpWidget(
            _host(
              KeyedSubtree(
                key: ValueKey(text),
                child: rig.composer(draft: text),
              ),
              dark: dark,
            ),
          );
          expect(
            _expandButton,
            shown ? findsOneWidget : findsNothing,
            reason: text,
          );
        }
      });

      testWidgets('a wrapped paragraph counts its visual lines', (
        tester,
      ) async {
        _size(tester, const Size(500, 800));
        final rig = _Rig();
        final long = List.filled(60, 'word').join(' ');
        await tester.pumpWidget(_host(rig.composer(draft: long), dark: dark));
        expect(_expandButton, findsOneWidget);
        await tester.pumpWidget(
          _host(
            KeyedSubtree(
              key: const ValueKey('short'),
              child: rig.composer(draft: 'short'),
            ),
            dark: dark,
          ),
        );
        expect(_expandButton, findsNothing);
      });

      testWidgets('typing never flickers the button at the threshold', (
        tester,
      ) async {
        _size(tester, const Size(520, 800));
        final rig = _Rig();
        await tester.pumpWidget(_host(rig.composer(), dark: dark));
        await tester.tap(_fields.first);
        await tester.pump();
        // Grow the draft one word at a time through the 2 -> 3 line threshold.
        // The button may switch on once and must stay on, and wherever it is
        // on the field really shows 3+ lines (so it never shows early) while
        // it is off whenever the field shows 2 lines or fewer.
        var wasShown = false;
        final line = tester.getSize(_fields.first).height;
        for (var words = 1; words <= 80; words++) {
          await tester.enterText(
            _fields.first,
            List.filled(words, 'wordy').join(' '),
          );
          await tester.pump();
          final shown = _expandButton.evaluate().isNotEmpty;
          expect(
            !wasShown || shown,
            isTrue,
            reason: '$words words: shown then hidden',
          );
          wasShown = wasShown || shown;
          final lines =
              (tester.getSize(find.byType(EditableText).first).height / 20)
                  .round();
          if (shown)
            expect(lines, greaterThanOrEqualTo(3), reason: '$words words');
          if (lines <= 2) expect(shown, isFalse, reason: '$words words');
        }
        expect(wasShown, isTrue);
        expect(line, greaterThan(0));
      });

      testWidgets(
        'keeps the editor focused and its text across the threshold',
        (tester) async {
          _size(tester, _desktop);
          final rig = _Rig();
          await tester.pumpWidget(
            _host(rig.composer(draft: 'a\nb'), dark: dark),
          );
          await tester.tap(_fields.first);
          await tester.pump();
          expect(_inline(tester).focusNode!.hasFocus, isTrue);
          await tester.enterText(_fields.first, 'a\nb\nc');
          await tester.pump();
          expect(_expandButton, findsOneWidget);
          expect(_inline(tester).focusNode!.hasFocus, isTrue);
          expect(_controller(tester).text, 'a\nb\nc');
        },
      );

      testWidgets('is not offered while an IME composition is active', (
        tester,
      ) async {
        _size(tester, _desktop);
        final rig = _Rig();
        await tester.pumpWidget(_host(rig.composer(draft: _three), dark: dark));
        await tester.tap(_fields.first);
        await tester.pump();
        _controller(tester).value = const TextEditingValue(
          text: _three,
          selection: TextSelection.collapsed(offset: 13),
          composing: TextRange(start: 8, end: 13),
        );
        await tester.pump();
        await tester.tap(_expandButton);
        await tester.pumpAndSettle();
        expect(_expandedView, findsNothing);
      });
    });
  }

  group('expanded editor shares the draft', () {
    testWidgets('same draft, selection and undo history both ways', (
      tester,
    ) async {
      _size(tester, _desktop);
      final rig = _Rig();
      await tester.pumpWidget(_host(rig.composer(draft: _three)));
      _setValue(tester, _three, 4, 7);
      final inline = _inline(tester);
      await _open(tester);
      // Only the expanded field is attached to the draft now; it is the
      // composer's own controller and undo controller.
      expect(_fields, findsOneWidget);
      final expanded = _expandedField(tester);
      expect(expanded.controller, same(inline.controller));
      expect(expanded.undoController, same(inline.undoController));
      expect(expanded.focusNode, isNot(same(inline.focusNode)));
      expect(expanded.focusNode!.hasFocus, isTrue);
      expect(
        _controller(tester).selection,
        const TextSelection(baseOffset: 4, extentOffset: 7),
      );
      // Edit in the expanded view; the inline composer's draft follows.
      await tester.enterText(_fields.last, '$_three\nfour');
      await tester.pump();
      expect(_controller(tester).text, '$_three\nfour');
      expect(rig.drafts.last, '$_three\nfour');
      // Collapse with Escape: the draft survives, focus is back inline.
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(_expandedView, findsNothing);
      expect(_controller(tester).text, '$_three\nfour');
      expect(_inline(tester).focusNode!.hasFocus, isTrue);
      expect(rig.sent, isEmpty);
    });

    testWidgets('collapse button keeps the draft too', (tester) async {
      _size(tester, _desktop);
      final rig = _Rig();
      await tester.pumpWidget(_host(rig.composer(draft: _three)));
      await _open(tester);
      await tester.tap(find.byKey(const ValueKey('composer-collapse')));
      await tester.pumpAndSettle();
      expect(_expandedView, findsNothing);
      expect(_controller(tester).text, _three);
    });

    testWidgets('mentions picked in the expanded editor are sent', (
      tester,
    ) async {
      _size(tester, _desktop);
      final rig = _Rig();
      await tester.pumpWidget(
        _host(
          rig.composer(
            draft: 'a\nb\nc ',
            suggestions: const [
              RaftComposerSuggestion(type: 'user', id: 'u1', name: 'cindy'),
            ],
          ),
        ),
      );
      _setValue(tester, 'a\nb\nc ', 6);
      await _open(tester);
      await tester.enterText(_fields.last, 'a\nb\nc @ci');
      await tester.pump();
      expect(
        find.byKey(const ValueKey('composer-suggestion-user-u1')),
        findsOneWidget,
      );
      // The suggestion list is not hidden under the dialog: tap it.
      await tester.tap(
        find.byKey(const ValueKey('composer-suggestion-user-u1')),
      );
      await tester.pumpAndSettle();
      expect(_controller(tester).text, 'a\nb\nc @cindy ');
      await _chord(tester, LogicalKeyboardKey.enter, control: true);
      await tester.pumpAndSettle();
      expect(rig.sent, ['a\nb\nc @cindy']);
      expect(rig.mentions.single.single['id'], 'u1');
      // Sending closes the editor.
      expect(_expandedView, findsNothing);
    });

    testWidgets('mentions picked inline stay bound when sent from the editor', (
      tester,
    ) async {
      _size(tester, _desktop);
      final rig = _Rig();
      await tester.pumpWidget(
        _host(
          rig.composer(
            suggestions: const [
              RaftComposerSuggestion(type: 'user', id: 'u1', name: 'cindy'),
            ],
          ),
        ),
      );
      await tester.tap(_fields.first);
      await tester.enterText(_fields.first, '@ci');
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey('composer-suggestion-user-u1')),
      );
      await tester.pump();
      await tester.enterText(_fields.first, '@cindy x\ny\nz');
      await tester.pump();
      await _open(tester);
      await tester.tap(find.byKey(const ValueKey('composer-submit')).last);
      await tester.pumpAndSettle();
      expect(rig.mentions.single.single['name'], 'cindy');
    });

    testWidgets('Escape closes the suggestion list first, then the editor', (
      tester,
    ) async {
      _size(tester, _desktop);
      final rig = _Rig();
      await tester.pumpWidget(
        _host(
          rig.composer(
            draft: _three,
            suggestions: const [
              RaftComposerSuggestion(type: 'user', id: 'u1', name: 'cindy'),
            ],
          ),
        ),
      );
      await _open(tester);
      await tester.enterText(_fields.last, '$_three @ci');
      await tester.pump();
      expect(
        find.byKey(const ValueKey('composer-suggestion-user-u1')),
        findsOneWidget,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('composer-suggestion-user-u1')),
        findsNothing,
      );
      expect(_expandedView, findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(_expandedView, findsNothing);
      expect(_controller(tester).text, '$_three @ci');
    });
  });

  for (final platform in [
    TargetPlatform.macOS,
    TargetPlatform.windows,
    TargetPlatform.linux,
  ]) {
    group('keys on $platform', () {
      final meta = platform == TargetPlatform.macOS;
      void keyTest(String name, Future<void> Function(WidgetTester) body) =>
          testWidgets(name, (tester) async {
            debugDefaultTargetPlatformOverride = platform;
            try {
              _size(tester, _desktop);
              await body(tester);
            } finally {
              debugDefaultTargetPlatformOverride = null;
            }
          });

      keyTest('Enter adds a line in the expanded editor, never sends', (
        tester,
      ) async {
        final rig = _Rig();
        await tester.pumpWidget(_host(rig.composer(draft: _three)));
        await _open(tester);
        _controller(tester).selection = const TextSelection.collapsed(
          offset: 3,
        );
        await _chord(tester, LogicalKeyboardKey.enter);
        expect(_controller(tester).text, 'one\n\ntwo\nthree');
        await _chord(tester, LogicalKeyboardKey.enter, shift: true);
        expect(_controller(tester).text, 'one\n\n\ntwo\nthree');
        expect(rig.sent, isEmpty);
      });

      keyTest('Cmd/Ctrl+Enter sends; Shift adds the task', (tester) async {
        final rig = _Rig();
        await tester.pumpWidget(_host(rig.composer(draft: _three)));
        await _open(tester);
        await _chord(
          tester,
          LogicalKeyboardKey.enter,
          meta: meta,
          control: !meta,
        );
        await tester.pumpAndSettle();
        expect(rig.sent, [_three]);
        expect(_expandedView, findsNothing);
        await tester.enterText(_fields.first, 'x\ny\nz');
        await tester.pump();
        await _open(tester);
        await _chord(
          tester,
          LogicalKeyboardKey.enter,
          shift: true,
          meta: meta,
          control: !meta,
        );
        await tester.pumpAndSettle();
        expect(rig.tasks, ['x\ny\nz']);
      });

      keyTest('Cmd/Ctrl+Shift+E expands and collapses', (tester) async {
        final rig = _Rig();
        await tester.pumpWidget(_host(rig.composer(draft: 'short')));
        await tester.tap(_fields.first);
        await tester.pump();
        await _chord(
          tester,
          LogicalKeyboardKey.keyE,
          shift: true,
          meta: meta,
          control: !meta,
        );
        await tester.pumpAndSettle();
        expect(_expandedView, findsOneWidget);
        await _chord(
          tester,
          LogicalKeyboardKey.keyE,
          shift: true,
          meta: meta,
          control: !meta,
        );
        await tester.pumpAndSettle();
        expect(_expandedView, findsNothing);
        expect(_controller(tester).text, 'short');
      });

      keyTest('the inline composer is unchanged: Enter sends', (tester) async {
        final rig = _Rig();
        await tester.pumpWidget(_host(rig.composer()));
        await tester.tap(_fields.first);
        await tester.enterText(_fields.first, 'hi');
        await _chord(tester, LogicalKeyboardKey.enter);
        expect(rig.sent, ['hi']);
      });

      keyTest('format shortcuts edit the draft in the expanded editor', (
        tester,
      ) async {
        final rig = _Rig();
        await tester.pumpWidget(_host(rig.composer(draft: 'a b\nc\nd')));
        await _open(tester);
        _controller(tester).selection = const TextSelection(
          baseOffset: 2,
          extentOffset: 3,
        );
        await _chord(
          tester,
          LogicalKeyboardKey.keyB,
          meta: meta,
          control: !meta,
        );
        expect(_controller(tester).text, 'a **b**\nc\nd');
        await _chord(
          tester,
          LogicalKeyboardKey.keyB,
          meta: meta,
          control: !meta,
        );
        expect(_controller(tester).text, 'a b\nc\nd');
        await _chord(
          tester,
          LogicalKeyboardKey.keyI,
          meta: meta,
          control: !meta,
        );
        expect(_controller(tester).text, 'a *b*\nc\nd');
      });
    });
  }

  group('toolbar', () {
    Future<void> press(WidgetTester tester, String tooltip) async {
      await tester.tap(_tool(tooltip));
      await tester.pump();
    }

    testWidgets('inline marks wrap the selection and toggle off', (
      tester,
    ) async {
      _size(tester, _desktop);
      await tester.pumpWidget(
        _host(_Rig().composer(draft: 'say hi now\nb\nc')),
      );
      await _open(tester);
      for (final (tip, mark) in [
        ('Bold', '**'),
        ('Italic', '*'),
        ('Strikethrough', '~~'),
        ('Inline Code', '`'),
      ]) {
        _setValue(tester, 'say hi now\nb\nc', 4, 6);
        await press(tester, tip);
        expect(
          _controller(tester).text,
          'say ${mark}hi$mark now\nb\nc',
          reason: tip,
        );
        expect(
          _controller(tester).selection,
          TextSelection(
            baseOffset: 4 + mark.length,
            extentOffset: 6 + mark.length,
          ),
        );
        await press(tester, tip);
        expect(
          _controller(tester).text,
          'say hi now\nb\nc',
          reason: '$tip off',
        );
      }
      // The editor keeps focus while the toolbar is used.
      expect(_expandedField(tester).focusNode!.hasFocus, isTrue);
    });

    testWidgets('an empty selection inserts a placeholder that is selected', (
      tester,
    ) async {
      _size(tester, _desktop);
      await tester.pumpWidget(_host(_Rig().composer(draft: 'a\nb\nc')));
      await _open(tester);
      _setValue(tester, 'a\nb\nc', 5);
      await press(tester, 'Bold');
      expect(_controller(tester).text, 'a\nb\nc**text**');
      expect(
        _controller(tester).selection,
        const TextSelection(baseOffset: 7, extentOffset: 11),
      );
    });

    testWidgets('italic inside bold adds italic, and bold toggles off alone', (
      tester,
    ) async {
      _size(tester, _desktop);
      await tester.pumpWidget(_host(_Rig().composer(draft: '**hi**\nb\nc')));
      await _open(tester);
      _setValue(tester, '**hi**\nb\nc', 2, 4);
      await press(tester, 'Italic');
      expect(_controller(tester).text, '***hi***\nb\nc');
      _setValue(tester, '***hi***\nb\nc', 3, 5);
      await press(tester, 'Bold');
      expect(_controller(tester).text, '*hi*\nb\nc');
    });

    testWidgets('block styles prefix every selected line and toggle off', (
      tester,
    ) async {
      _size(tester, _desktop);
      await tester.pumpWidget(_host(_Rig().composer(draft: 'a\nb\nc\nd')));
      await _open(tester);
      for (final (tip, expected) in [
        ('Quote', '> a\n> b\nc\nd'),
        ('Bulleted List', '- a\n- b\nc\nd'),
        ('Numbered List', '1. a\n2. b\nc\nd'),
        ('Task List', '- [ ] a\n- [ ] b\nc\nd'),
      ]) {
        _setValue(tester, 'a\nb\nc\nd', 0, 3);
        await press(tester, tip);
        expect(_controller(tester).text, expected, reason: tip);
        // The edit keeps both lines selected, so pressing again removes it.
        await press(tester, tip);
        expect(_controller(tester).text, 'a\nb\nc\nd', reason: '$tip off');
      }
    });

    testWidgets('heading cycles ## then ### then none', (tester) async {
      _size(tester, _desktop);
      await tester.pumpWidget(_host(_Rig().composer(draft: 'title\nb\nc')));
      await _open(tester);
      _setValue(tester, 'title\nb\nc', 2);
      await press(tester, 'Heading');
      expect(_controller(tester).text, '## title\nb\nc');
      await press(tester, 'Heading');
      expect(_controller(tester).text, '### title\nb\nc');
      await press(tester, 'Heading');
      expect(_controller(tester).text, 'title\nb\nc');
    });

    testWidgets('code block, link, table, divider, mention and channel', (
      tester,
    ) async {
      _size(tester, _desktop);
      await tester.pumpWidget(_host(_Rig().composer(draft: 'a\nb\nc')));
      await _open(tester);
      _setValue(tester, 'a\nb\nc', 2, 3);
      await press(tester, 'Code Block');
      expect(_controller(tester).text, 'a\n```\nb\n```\n\nc');
      _setValue(tester, 'see docs', 4, 8);
      await press(tester, 'Link');
      expect(_controller(tester).text, 'see [docs](https://)');
      expect(
        _controller(tester).selection,
        const TextSelection(baseOffset: 11, extentOffset: 19),
      );
      _setValue(tester, 'x', 1);
      await press(tester, 'Table');
      expect(
        _controller(tester).text,
        startsWith('x\n| Column | Column |\n| --- | --- |'),
      );
      _setValue(tester, 'x', 1);
      await press(tester, 'Divider');
      expect(_controller(tester).text, 'x\n\n---\n\n');
      _setValue(tester, 'hi', 2);
      await press(tester, 'Mention');
      expect(_controller(tester).text, 'hi @');
      _setValue(tester, 'hi ', 3);
      await press(tester, 'Channel or Task');
      expect(_controller(tester).text, 'hi #');
    });

    testWidgets('every toolbar button names itself for assistive tech', (
      tester,
    ) async {
      _size(tester, _desktop);
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(_host(_Rig().composer(draft: _three)));
      await _open(tester);
      for (final tip in [
        'Bold',
        'Italic',
        'Strikethrough',
        'Heading',
        'Quote',
        'Bulleted List',
        'Numbered List',
        'Task List',
        'Inline Code',
        'Code Block',
        'Link',
        'Table',
        'Divider',
        'Mention',
        'Channel or Task',
        'Hide Preview',
        'Collapse Editor',
      ]) {
        expect(find.bySemanticsLabel(tip), findsWidgets, reason: tip);
      }
      semantics.dispose();
    });
  });

  group('markdown editing controller', () {
    Future<TextSpan> span(
      WidgetTester tester,
      RaftMarkdownEditingController c,
    ) async {
      late TextSpan out;
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          home: Builder(
            builder: (context) {
              out = c.buildTextSpan(
                context: context,
                style: const TextStyle(fontSize: 14),
                withComposing: true,
              );
              return const SizedBox();
            },
          ),
        ),
      );
      return out;
    }

    const sample =
        '## Title\n**bold** *it* _it_ ~~gone~~ `code` [a](http://x) @cindy #general\n'
        '- item\n1. one\n> quote\n```dart\nvoid main() {}\n```\n中文 **粗体**';

    testWidgets('styling never changes the characters', (tester) async {
      final c = RaftMarkdownEditingController(text: sample)..styled = true;
      addTearDown(c.dispose);
      expect((await span(tester, c)).toPlainText(), sample);
      for (final cut in [0, 1, 5, 12, 40, sample.length]) {
        c.text = sample.substring(0, cut);
        expect((await span(tester, c)).toPlainText(), sample.substring(0, cut));
      }
    });

    testWidgets('styling is off until the expanded editor turns it on', (
      tester,
    ) async {
      final c = RaftMarkdownEditingController(text: '**bold**');
      addTearDown(c.dispose);
      bool anyBold(TextSpan s) =>
          s.style?.fontWeight == FontWeight.w700 ||
          (s.children ?? []).any((x) => x is TextSpan && anyBold(x));
      expect(anyBold(await span(tester, c)), isFalse);
      c.styled = true;
      expect(anyBold(await span(tester, c)), isTrue);
      c.styled = false;
      expect(anyBold(await span(tester, c)), isFalse);
    });

    testWidgets('no styling while an IME composition is active', (
      tester,
    ) async {
      final c = RaftMarkdownEditingController()..styled = true;
      addTearDown(c.dispose);
      c.value = const TextEditingValue(
        text: '**bold** 中文',
        selection: TextSelection.collapsed(offset: 11),
        composing: TextRange(start: 9, end: 11),
      );
      final s = await span(tester, c);
      expect(s.toPlainText(), '**bold** 中文');
      bool anyStyled(TextSpan s) =>
          s.style?.fontWeight == FontWeight.w700 ||
          s.style?.fontFamily == RaftTokens.theme().monoFont ||
          (s.children ?? []).any((x) => x is TextSpan && anyStyled(x));
      expect(anyStyled(s), isFalse);
    });
  });

  group('preview equals what is sent', () {
    testWidgets(
      'default preview renders the trimmed draft with RaftMessageBody',
      (tester) async {
        _size(tester, _desktop);
        final rig = _Rig();
        const draft = '  # Plan\n\n- **a**\n- b\n\n  ';
        await tester.pumpWidget(_host(rig.composer(draft: draft)));
        await _open(tester);
        final body = tester.widget<RaftMessageBody>(
          find.byType(RaftMessageBody),
        );
        expect(body.content, '# Plan\n\n- **a**\n- b');
        await tester.tap(find.byKey(const ValueKey('composer-submit')).last);
        await tester.pumpAndSettle();
        expect(rig.sent, [body.content]);
      },
    );

    testWidgets('the preview follows edits and a host preview builder', (
      tester,
    ) async {
      _size(tester, _desktop);
      final shown = <String>[];
      final rig = _Rig();
      await tester.pumpWidget(
        _host(
          rig.composer(
            draft: _three,
            previewBuilder: (context, content) {
              shown.add(content);
              return Text('host:$content');
            },
          ),
        ),
      );
      await _open(tester);
      expect(find.text('host:$_three'), findsOneWidget);
      await tester.enterText(_fields.last, '$_three!');
      await tester.pump();
      expect(shown.last, '$_three!');
      expect(find.byType(RaftMessageBody), findsNothing);
    });

    testWidgets('the eye button hides and shows the preview', (tester) async {
      _size(tester, _desktop);
      await tester.pumpWidget(_host(_Rig().composer(draft: _three)));
      await _open(tester);
      expect(find.byKey(const ValueKey('composer-preview')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('composer-preview-toggle')));
      await tester.pump();
      expect(find.byKey(const ValueKey('composer-preview')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('composer-preview-toggle')));
      await tester.pump();
      expect(find.byKey(const ValueKey('composer-preview')), findsOneWidget);
    });
  });

  group('surfaces', () {
    testWidgets('desktop: a dialog that traps focus and returns it', (
      tester,
    ) async {
      _size(tester, _desktop);
      await tester.pumpWidget(_host(_Rig().composer(draft: _three)));
      await tester.tap(_fields.first);
      await tester.pump();
      await _open(tester);
      expect(
        find.byKey(const ValueKey('composer-preview-toggle')),
        findsOneWidget,
      );
      // Tab many times: focus never leaves the dialog.
      for (var i = 0; i < 40; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        final focused = FocusManager.instance.primaryFocus?.context;
        expect(focused, isNotNull);
        expect(
          focused!.findAncestorWidgetOfExactType<RaftComposerExpandedView>(),
          isNotNull,
          reason: 'tab $i left the dialog',
        );
      }
      await tester.tap(find.byKey(const ValueKey('composer-collapse')));
      await tester.pumpAndSettle();
      expect(_inline(tester).focusNode!.hasFocus, isTrue);
    });

    testWidgets('a tap on the scrim collapses and keeps the draft', (
      tester,
    ) async {
      _size(tester, _desktop);
      await tester.pumpWidget(_host(_Rig().composer(draft: _three)));
      await _open(tester);
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
      expect(_expandedView, findsNothing);
      expect(_controller(tester).text, _three);
    });

    testWidgets(
      'phone: a bottom sheet, write/preview switch, toolbar over the keyboard',
      (tester) async {
        _size(tester, _phone);
        final rig = _Rig();
        await tester.pumpWidget(
          _host(rig.composer(draft: _three), keyboard: 300),
        );
        await _open(tester);
        // A bottom sheet: full width, tall, with a drag handle.
        expect(tester.getSize(find.byType(BottomSheet)).width, _phone.width);
        expect(find.byKey(const ValueKey('raft-sheet-handle')), findsOneWidget);
        // No preview toggle button on the phone; the Write | Preview switch is there.
        expect(
          find.byKey(const ValueKey('composer-preview-toggle')),
          findsNothing,
        );
        expect(find.byType(RaftSegmentedControl<bool>), findsOneWidget);
        // Write mode: the field, the toolbar and the action row sit above the keyboard.
        final above = _phone.height - 300;
        expect(
          tester
              .getBottomLeft(find.byKey(const ValueKey('composer-submit')).last)
              .dy,
          lessThanOrEqualTo(above),
        );
        expect(
          tester.getBottomLeft(_tool('Bold')).dy,
          lessThanOrEqualTo(above),
        );
        expect(
          tester.getTopLeft(_tool('Bold')).dy,
          greaterThan(tester.getTopLeft(_fields.last).dy),
        );
        expect(tester.takeException(), isNull);
        // Switch to Preview: the page shows the rendered message, no toolbar.
        final switcher = tester.widget<RaftSegmentedControl<bool>>(
          find.byType(RaftSegmentedControl<bool>),
        );
        switcher.onChanged!(true);
        await tester.pump();
        expect(find.byType(RaftMessageBody), findsOneWidget);
        expect(_tool('Bold'), findsNothing);
        // Collapse returns to the inline composer with the draft.
        await tester.tap(find.byKey(const ValueKey('composer-collapse')));
        await tester.pumpAndSettle();
        expect(_expandedView, findsNothing);
        expect(_controller(tester).text, _three);
      },
    );

    testWidgets('closing the page the composer lives in closes the editor', (
      tester,
    ) async {
      _size(tester, _desktop);
      final rig = _Rig();
      await tester.pumpWidget(_host(rig.composer(draft: _three)));
      await _open(tester);
      await tester.pumpWidget(_host(const SizedBox()));
      await tester.pumpAndSettle();
      expect(_expandedView, findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('large text', () {
    for (final scale in [1.3, 2.0, 3.1]) {
      for (final size in [_desktop, _phone]) {
        testWidgets('no overflow at ${scale}x on ${size.width.toInt()}', (
          tester,
        ) async {
          _size(tester, size);
          await tester.pumpWidget(
            _host(_Rig().composer(draft: _three), scale: scale),
          );
          expect(tester.takeException(), isNull, reason: 'inline');
          await tester.tap(_expandButton);
          await tester.pumpAndSettle();
          expect(_expandedView, findsOneWidget);
          expect(tester.takeException(), isNull, reason: 'expanded');
          await tester.tap(find.byKey(const ValueKey('composer-collapse')));
          await tester.pumpAndSettle();
          expect(_expandedView, findsNothing);
        });
      }
    }
  });
}
