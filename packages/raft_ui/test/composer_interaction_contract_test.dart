import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

import 'flutter_test_config.dart' show leakDebt;

// The expandable composer's interaction contract. One group per event; every
// rule says what happens to the draft, the selection, an IME composition, undo
// and focus. The host here behaves like the app: it saves every draft change,
// echoes it back as `initialDraft` + `draftRevision`, and disables the composer
// while its page is covered by another route (the chat page does exactly that).

class _Store {
  final text = <String, String>{};
  final revision = <String, int>{};
  final saved = <String, List<String>>{};
  final changes = ValueNotifier<int>(0);
  final channel = ValueNotifier<String>('general');
  final enabled = ValueNotifier<bool>(true);
  final sent = <String>[];
  bool acceptSends = true;

  String draft([String? ch]) => text[ch ?? channel.value] ?? '';
  void save(String ch, String value) {
    if (draft(ch) == value) return;
    text[ch] = value;
    revision[ch] = (revision[ch] ?? 0) + 1;
    (saved[ch] ??= []).add(value);
    changes.value++;
  }

  /// A draft that arrives from elsewhere (another window, a share).
  void incoming(String value, {String? ch}) {
    final key = ch ?? channel.value;
    text[key] = value;
    revision[key] = (revision[key] ?? 0) + 1;
    changes.value++;
  }

  void dispose() {
    changes.dispose();
    channel.dispose();
    enabled.dispose();
  }
}

_Store _store(WidgetTester tester, {String draft = ''}) {
  final s = _Store();
  if (draft.isNotEmpty) s.text['general'] = draft;
  addTearDown(s.dispose);
  return s;
}

Widget _app(
  _Store s, {
  bool dark = false,
  TargetPlatform platform = TargetPlatform.macOS,
  bool clearOnSubmit = false,
  double keyboard = 0,
}) => MaterialApp(
  theme: raftTheme(dark: dark).copyWith(platform: platform),
  builder: (context, home) => MediaQuery(
    data: MediaQuery.of(context)
        .copyWith(viewInsets: EdgeInsets.only(bottom: keyboard)),
    child: home!,
  ),
  home: Scaffold(
    body: Column(
      children: [
        const Spacer(),
        ListenableBuilder(
          listenable: Listenable.merge([s.changes, s.channel, s.enabled]),
          builder: (context, _) {
            final ch = s.channel.value;
            // The chat page's own rule: a page that is covered, hidden or has
            // its tickers off is not presented, so its composer is disabled.
            final presented =
                Visibility.of(context) && TickerMode.valuesOf(context).enabled;
            return RaftComposer(
              key: ValueKey('compose-$ch'),
              enabled: presented && s.enabled.value,
              clearOnSubmit: clearOnSubmit,
              initialDraft: s.draft(ch),
              draftRevision: s.revision[ch] ?? 0,
              onDraftChanged: (t) => s.save(ch, t),
              onAttach: () {},
              onImagePick: () {},
              onSend: (t) async {
                s.sent.add(t);
                return s.acceptSends;
              },
            );
          },
        ),
      ],
    ),
  ),
);

void _size(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

const _desktop = Size(1000, 800), _narrow = Size(412, 915);
const _three = 'one\ntwo\nthree';

final _expandButton = find.byKey(const ValueKey('composer-expand'));
final _view = find.byType(RaftComposerExpandedView);
final _collapse = find.byKey(const ValueKey('composer-collapse'));
final _handle = find.byType(RaftSheetHandle);
final _sheet = find.byType(BottomSheet);

/// Every EditableText in the tree, offstage ones included.
Finder get _everyEditable => find.byType(EditableText, skipOffstage: false);
EditableTextState _live(WidgetTester t) =>
    t.state<EditableTextState>(find.byType(EditableText).last);
TextEditingController _ctl(WidgetTester t) => _live(t).widget.controller;
TextEditingValue _value(WidgetTester t) => _ctl(t).value;

Future<void> _open(WidgetTester tester) async {
  await tester.tap(_expandButton);
  await tester.pumpAndSettle();
  expect(_view, findsOneWidget);
}

Future<void> _chord(
  WidgetTester tester,
  LogicalKeyboardKey key, {
  bool shift = false,
  bool meta = false,
}) async {
  if (meta) await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
  if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyEvent(key);
  if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  if (meta) await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
  await tester.pump();
  await tester.pump();
}

/// The platform input method reports [text] with [composing] marked.
void _ime(
  WidgetTester t,
  String text, {
  required int from,
  int? to,
  int? caret,
}) => t.testTextInput.updateEditingValue(
  TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: caret ?? to ?? text.length),
    composing: from < 0
        ? TextRange.empty
        : TextRange(start: from, end: to ?? text.length),
  ),
);

const _composingEnd = TextRange(start: 13, end: 18);

/// Types the pinyin "nihao" after [_three] with the input method.
Future<void> _compose(WidgetTester tester) async {
  for (var i = 1; i <= 5; i++) {
    _ime(tester, _three + 'nihao'.substring(0, i), from: 13);
    await tester.pump();
  }
  expect(_value(tester).composing, _composingEnd);
}

List<String> _echoes(WidgetTester t) => [
  for (final call in t.testTextInput.log)
    if (call.method == 'TextInput.setEditingState') call.method,
];

void main() {
  // Flutter 3.47.6: a modal bottom sheet closed by a drag rebinds its animation
  // to a CurvedAnimation (`_ModalBottomSheetState.handleDragEnd`) that nothing
  // disposes.
  leakDebt(const ['CurvedAnimation']);
  group('one editor at a time', () {
    for (final size in [_desktop, _narrow]) {
      testWidgets('exactly one EditableText on the draft at ${size.width}', (
        tester,
      ) async {
        _size(tester, size);
        final s = _store(tester, draft: _three);
        await tester.pumpWidget(_app(s));
        expect(_everyEditable, findsOneWidget);
        await _open(tester);
        expect(
          _everyEditable,
          findsOneWidget,
          reason: 'the hidden inline field must not stay attached',
        );
        await tester.tap(_collapse);
        await tester.pumpAndSettle();
        expect(_view, findsNothing);
        expect(_everyEditable, findsOneWidget);
      });
    }

    testWidgets(
      'focus churn of the hidden inline field cannot wipe a composition',
      (tester) async {
        _size(tester, _desktop);
        final s = _store(tester, draft: _three);
        await tester.pumpWidget(_app(s));
        final inlineFocus = tester
            .widget<TextField>(find.byType(TextField))
            .focusNode!;
        await _open(tester);
        await _compose(tester);
        // Any focus re-evaluation of the covered inline field (a route scope
        // changing, a window regaining focus) notifies its focus node.
        inlineFocus.canRequestFocus = false;
        await tester.pump();
        inlineFocus.canRequestFocus = true;
        await tester.pump();
        expect(_value(tester).composing, _composingEnd);
        expect(_value(tester).text, '${_three}nihao');
      },
    );
  });

  group('IME composition', () {
    for (final expanded in [false, true]) {
      testWidgets(
        '${expanded ? 'expanded' : 'inline'}: pinyin stays composing through '
        'draft saves and host echoes, then commits the characters',
        (tester) async {
          _size(tester, _desktop);
          final s = _store(tester, draft: _three);
          await tester.pumpWidget(_app(s));
          await tester.tap(find.byType(TextField));
          await tester.pump();
          if (expanded) await _open(tester);
          tester.testTextInput.log.clear();
          for (var i = 1; i <= 5; i++) {
            _ime(tester, _three + 'nihao'.substring(0, i), from: 13);
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 50));
            expect(_value(tester).composing, TextRange(start: 13, end: 13 + i));
          }
          expect(
            _echoes(tester),
            isEmpty,
            reason: 'the framework must not write back into the IME',
          );
          _ime(tester, '$_three你好', from: -1);
          await tester.pump();
          expect(_value(tester).text, '$_three你好');
          expect(_value(tester).composing, TextRange.empty);
          expect(s.draft(), '$_three你好');
          expect(s.saved['general']!.last, '$_three你好');
        },
      );
    }

    testWidgets('an incoming draft waits for the composition, then merges', (
      tester,
    ) async {
      _size(tester, _desktop);
      final s = _store(tester, draft: _three);
      await tester.pumpWidget(_app(s));
      await _open(tester);
      await _compose(tester);
      final before = _value(tester);
      s.incoming('from another window');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(_value(tester), before, reason: 'nothing may touch a composition');
      _ime(tester, '$_three你好', from: -1);
      await tester.pump();
      await tester.pump();
      expect(_value(tester).text, contains('你好'));
      expect(_value(tester).text, contains('from another window'));
    });

    testWidgets('Escape while composing is the input method\'s, not ours', (
      tester,
    ) async {
      _size(tester, _desktop);
      final s = _store(tester, draft: _three);
      await tester.pumpWidget(_app(s));
      await _open(tester);
      await _compose(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(_view, findsOneWidget, reason: 'Esc must not collapse');
      expect(_value(tester).composing, _composingEnd);
    });

    testWidgets('format shortcuts and the expand toggle wait for the IME', (
      tester,
    ) async {
      _size(tester, _desktop);
      final s = _store(tester, draft: _three);
      await tester.pumpWidget(_app(s));
      await _open(tester);
      await _compose(tester);
      final before = _value(tester);
      await _chord(tester, LogicalKeyboardKey.keyB, meta: true);
      expect(_value(tester), before, reason: 'Cmd+B writes the controller');
      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is RaftComposerToolButton && w.tooltip == 'Bold',
        ),
      );
      await tester.pump();
      expect(_value(tester), before, reason: 'the Bold button writes it too');
      await _chord(tester, LogicalKeyboardKey.keyE, meta: true, shift: true);
      expect(_view, findsOneWidget, reason: 'the toggle must not collapse');
      expect(_value(tester).composing, _composingEnd);
    });

    // A real mouse click on desktop: pointer down outside a text field's tap
    // region unfocuses it, and the platform commits the marked text before
    // onPressed runs. The toolbar and the card belong to the field.
    for (final place in ['Bold', 'blank']) {
      testWidgets(
        'macOS mouse click on $place keeps the composition and the focus',
        (tester) async {
          _size(tester, _desktop);
          final s = _store(tester, draft: _three);
          await tester.pumpWidget(_app(s));
          await _open(tester);
          await _compose(tester);
          final before = _value(tester);
          final field = _live(tester).widget.focusNode;
          final target = place == 'Bold'
              ? tester.getCenter(
                  find.byWidgetPredicate(
                    (w) => w is RaftComposerToolButton && w.tooltip == 'Bold',
                  ),
                )
              // The editor's padding, left of the text.
              : tester.getCenter(find.byWidget(_live(tester).widget)) -
                    Offset(
                      tester
                                  .getSize(find.byWidget(_live(tester).widget))
                                  .width /
                              2 +
                          RaftSpace.x1_5,
                      0,
                    );
          await tester.tapAt(target, kind: PointerDeviceKind.mouse);
          await tester.pump();
          expect(field.hasFocus, isTrue, reason: 'the click took the focus');
          expect(_value(tester), before);
        },
        variant: TargetPlatformVariant.only(TargetPlatform.macOS),
      );
    }

    testWidgets('expanding is refused while composing, inline', (tester) async {
      _size(tester, _desktop);
      final s = _store(tester, draft: _three);
      await tester.pumpWidget(_app(s));
      await tester.tap(find.byType(TextField));
      await tester.pump();
      await _compose(tester);
      await _chord(tester, LogicalKeyboardKey.keyE, meta: true, shift: true);
      await tester.pumpAndSettle();
      expect(_view, findsNothing);
      expect(_value(tester).composing, _composingEnd);
    });
  });

  group('narrow window: expansion does not depend on the layout', () {
    for (final platform in [TargetPlatform.macOS, TargetPlatform.android]) {
      testWidgets('$platform at phone width: expand opens and stays open', (
        tester,
      ) async {
        _size(tester, _narrow);
        final s = _store(tester, draft: _three);
        await tester.pumpWidget(_app(s, platform: platform));
        await _open(tester);
        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();
        expect(_view, findsOneWidget, reason: 'it must not close itself');
        expect(_sheet, findsOneWidget, reason: 'a phone gets a bottom sheet');
        expect(_handle, findsOneWidget);
        // And it is editable: the composer was not disabled by its own page
        // being covered.
        expect(_live(tester).widget.readOnly, isFalse);
        await tester.enterText(find.byType(EditableText), '$_three\nfour');
        await tester.pump();
        expect(s.draft(), '$_three\nfour');
      });
    }

    testWidgets('a real disable still collapses it', (tester) async {
      _size(tester, _desktop);
      final s = _store(tester, draft: _three);
      await tester.pumpWidget(_app(s));
      await _open(tester);
      s.enabled.value = false;
      await tester.pumpAndSettle();
      expect(_view, findsNothing);
      expect(s.draft(), _three);
    });
  });

  group('the phone sheet: every way out keeps the draft', () {
    for (final exit in ['drag the handle', 'scrim', 'Back', 'Esc', 'button']) {
      testWidgets(exit, (tester) async {
        _size(tester, _narrow);
        final s = _store(tester, draft: _three);
        await tester.pumpWidget(_app(s));
        await _open(tester);
        expect(_sheet, findsOneWidget);
        // The sheet is the framework's modal bottom sheet route.
        expect(
          ModalRoute.of(tester.element(_view)),
          isA<ModalBottomSheetRoute<void>>(),
        );
        switch (exit) {
          case 'drag the handle':
            await tester.fling(_handle, const Offset(0, 600), 2500);
          case 'scrim':
            await tester.tapAt(const Offset(200, 10));
          case 'Back':
            await tester.binding.handlePopRoute();
          case 'Esc':
            await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          default:
            await tester.tap(_collapse);
        }
        await tester.pumpAndSettle();
        expect(_view, findsNothing, reason: exit);
        expect(_value(tester).text, _three);
        expect(s.draft(), _three);
        expect(_everyEditable, findsOneWidget);
      });
    }

    testWidgets('typing in the sheet, then closing, loses nothing', (
      tester,
    ) async {
      _size(tester, _narrow);
      final s = _store(tester, draft: _three);
      await tester.pumpWidget(_app(s));
      await _open(tester);
      await tester.enterText(find.byType(EditableText), '$_three\nfour');
      await tester.pump();
      await tester.fling(_handle, const Offset(0, 600), 2500);
      await tester.pumpAndSettle();
      expect(_value(tester).text, '$_three\nfour');
      expect(s.draft(), '$_three\nfour');
    });
  });

  group('window resize across the breakpoint', () {
    testWidgets('dialog to sheet and back: same editor, nothing lost', (
      tester,
    ) async {
      _size(tester, _desktop);
      final s = _store(tester, draft: _three);
      await tester.pumpWidget(_app(s));
      await _open(tester);
      expect(_sheet, findsNothing);
      await _compose(tester);
      final state = _live(tester);
      final before = _value(tester);
      final focus = state.widget.focusNode;
      expect(focus.hasFocus, isTrue);

      tester.view.physicalSize = _narrow;
      await tester.pumpAndSettle();
      expect(_view, findsOneWidget, reason: 'stays expanded');
      expect(_sheet, findsOneWidget, reason: 'now a bottom sheet');
      expect(identical(_live(tester), state), isTrue, reason: 'same editor');
      expect(_value(tester), before, reason: 'draft, caret and composition');
      expect(focus.hasFocus, isTrue);

      tester.view.physicalSize = _desktop;
      await tester.pumpAndSettle();
      expect(_view, findsOneWidget);
      expect(_sheet, findsNothing, reason: 'back to the dialog');
      expect(identical(_live(tester), state), isTrue);
      expect(_value(tester), before);
      expect(focus.hasFocus, isTrue);
      expect(tester.takeException(), isNull);
    });

    // Mac, task #155 step 10: opened as a sheet in a 390-wide window, then
    // the window is dragged straight to 1200.
    testWidgets('opened as a sheet, widened to 1200: stays, caret kept', (
      tester,
    ) async {
      _size(tester, const Size(390, 844));
      final s = _store(tester, draft: _three);
      await tester.pumpWidget(_app(s));
      await _open(tester);
      expect(_sheet, findsOneWidget);
      _ctl(tester).selection = const TextSelection.collapsed(offset: 6);
      await tester.pump();
      final state = _live(tester);
      final before = _value(tester);

      for (final w in [600.0, 900.0, 1200.0]) {
        tester.view.physicalSize = Size(w, 800);
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(_view, findsOneWidget, reason: 'stays expanded');
      expect(_sheet, findsNothing, reason: 'now a dialog');
      expect(identical(_live(tester), state), isTrue, reason: 'same editor');
      expect(_value(tester), before, reason: 'draft and caret');
      expect(state.widget.focusNode.hasFocus, isTrue);
      expect(tester.takeException(), isNull);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('the cut is 768: 767 is a sheet, 768 a dialog', (tester) async {
      final s = _store(tester, draft: _three);
      _size(tester, const Size(767, 900));
      await tester.pumpWidget(_app(s));
      await _open(tester);
      expect(_sheet, findsOneWidget);
      tester.view.physicalSize = const Size(768, 900);
      await tester.pumpAndSettle();
      expect(_sheet, findsNothing);
      expect(_view, findsOneWidget);
    });
  });

  group('interaction contract', () {
    testWidgets('expand: draft, selection, undo and focus follow', (
      tester,
    ) async {
      _size(tester, _desktop);
      final s = _store(tester, draft: _three);
      await tester.pumpWidget(_app(s));
      await tester.tap(find.byType(TextField));
      await tester.pump();
      final inline = _live(tester);
      inline.widget.controller.selection = const TextSelection(
        baseOffset: 4,
        extentOffset: 7,
      );
      await tester.pump();
      final undo = inline.widget.undoController;
      await _open(tester);
      final expanded = _live(tester);
      expect(expanded.widget.controller.text, _three);
      expect(
        expanded.widget.controller.selection,
        const TextSelection(baseOffset: 4, extentOffset: 7),
      );
      expect(expanded.widget.undoController, same(undo));
      expect(expanded.widget.focusNode.hasFocus, isTrue);
    });

    testWidgets('collapse: draft and selection stay, focus returns inline, '
        'a composition is closed rather than left stuck', (tester) async {
      _size(tester, _desktop);
      final s = _store(tester, draft: _three);
      await tester.pumpWidget(_app(s));
      await _open(tester);
      await _compose(tester);
      await tester.tap(_collapse);
      await tester.pumpAndSettle();
      expect(_view, findsNothing);
      expect(_everyEditable, findsOneWidget);
      expect(_live(tester).widget.focusNode.hasFocus, isTrue);
      expect(_value(tester).text, '${_three}nihao');
      expect(
        _value(tester).composing,
        TextRange.empty,
        reason: 'a stale composing range would disable Send and expand',
      );
    });

    testWidgets('undo: one controller serves whichever field is showing; '
        'collapsing leaves the draft as typed', (tester) async {
      _size(tester, _desktop);
      final s = _store(tester, draft: _three);
      await tester.pumpWidget(_app(s));
      final undo = _live(tester).widget.undoController!;
      await _open(tester);
      expect(_live(tester).widget.undoController, same(undo));
      await tester.enterText(find.byType(EditableText), '$_three\nfour');
      await tester.pump(const Duration(milliseconds: 600));
      await tester.tap(_collapse);
      await tester.pumpAndSettle();
      // The history itself belongs to the live field and starts afresh with it
      // (the framework keeps the stack in the field's state); the controller
      // and the text are what carry over.
      expect(_live(tester).widget.undoController, same(undo));
      expect(_value(tester).text, '$_three\nfour');
      undo.undo();
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.takeException(), isNull);
    });

    testWidgets('Esc collapses and returns focus inline', (tester) async {
      _size(tester, _desktop);
      final s = _store(tester, draft: _three);
      await tester.pumpWidget(_app(s));
      await _open(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(_view, findsNothing);
      expect(_value(tester).text, _three);
      expect(_live(tester).widget.focusNode.hasFocus, isTrue);
    });

    testWidgets('switching channel while expanded closes it; each draft '
        'stays with its own channel', (tester) async {
      _size(tester, _desktop);
      final s = _store(tester, draft: _three);
      s.text['random'] = 'elsewhere';
      await tester.pumpWidget(_app(s));
      await _open(tester);
      await tester.enterText(find.byType(EditableText), '$_three\nfour');
      await tester.pump();
      s.channel.value = 'random';
      await tester.pumpAndSettle();
      expect(_view, findsNothing);
      expect(tester.takeException(), isNull);
      expect(_everyEditable, findsOneWidget);
      expect(_value(tester).text, 'elsewhere');
      expect(s.draft('general'), '$_three\nfour');
    });

    testWidgets('focus loss keeps it expanded with the draft and caret', (
      tester,
    ) async {
      _size(tester, _desktop);
      final s = _store(tester, draft: _three);
      await tester.pumpWidget(_app(s));
      await _open(tester);
      _ctl(tester).selection = const TextSelection.collapsed(offset: 5);
      await tester.pump();
      _live(tester).widget.focusNode.unfocus();
      await tester.pumpAndSettle();
      expect(_view, findsOneWidget);
      expect(_value(tester).text, _three);
      expect(
        _value(tester).selection,
        const TextSelection.collapsed(offset: 5),
      );
      await tester.tap(find.byType(EditableText));
      await tester.pump();
      expect(_live(tester).widget.focusNode.hasFocus, isTrue);
      expect(s.draft(), _three);
    });

    testWidgets('app backgrounding keeps it expanded, draft and caret intact, '
        'and a composition untouched', (tester) async {
      _size(tester, _desktop);
      final s = _store(tester, draft: _three);
      await tester.pumpWidget(_app(s));
      await _open(tester);
      await _compose(tester);
      final before = _value(tester);
      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(_view, findsOneWidget);
      expect(_value(tester), before);
    });

    testWidgets('send (Cmd+Enter): sends once, collapses, clears the draft', (
      tester,
    ) async {
      _size(tester, _desktop);
      final s = _store(tester, draft: _three);
      await tester.pumpWidget(_app(s));
      await _open(tester);
      await _chord(tester, LogicalKeyboardKey.enter, meta: true);
      await tester.pumpAndSettle();
      expect(s.sent, [_three]);
      expect(_view, findsNothing);
      expect(_value(tester).text, isEmpty);
    });

    testWidgets('send is refused while composing', (tester) async {
      _size(tester, _desktop);
      final s = _store(tester, draft: _three);
      await tester.pumpWidget(_app(s));
      await _open(tester);
      await _compose(tester);
      await _chord(tester, LogicalKeyboardKey.enter, meta: true);
      await tester.pumpAndSettle();
      expect(s.sent, isEmpty);
      expect(_view, findsOneWidget);
      expect(_value(tester).composing, _composingEnd);
    });

    testWidgets('a rejected send stays expanded with the draft', (
      tester,
    ) async {
      _size(tester, _desktop);
      final s = _store(tester, draft: _three)..acceptSends = false;
      await tester.pumpWidget(_app(s));
      await _open(tester);
      await _chord(tester, LogicalKeyboardKey.enter, meta: true);
      await tester.pumpAndSettle();
      expect(s.sent, [_three]);
      expect(_view, findsOneWidget);
      expect(_value(tester).text, _three);
    });

    testWidgets('a rejected hand-off restores the draft, collapsed', (
      tester,
    ) async {
      _size(tester, _desktop);
      final s = _store(tester, draft: _three)..acceptSends = false;
      await tester.pumpWidget(_app(s, clearOnSubmit: true));
      await _open(tester);
      await _chord(tester, LogicalKeyboardKey.enter, meta: true);
      await tester.pumpAndSettle();
      expect(_view, findsNothing);
      expect(_value(tester).text, _three);
    });

    testWidgets('an incoming draft replaces the text, keeps it expanded and '
        'focused, and never adds a second editor', (tester) async {
      _size(tester, _desktop);
      final s = _store(tester, draft: _three);
      await tester.pumpWidget(_app(s));
      await _open(tester);
      s.incoming('from another window');
      await tester.pumpAndSettle();
      expect(_view, findsOneWidget);
      expect(_value(tester).text, 'from another window');
      expect(_live(tester).widget.focusNode.hasFocus, isTrue);
      expect(_everyEditable, findsOneWidget);
    });
  });
}
