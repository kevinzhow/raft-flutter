import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

import 'flutter_test_config.dart' show leakDebt;

// The form scaffolds follow the window width through one presented route: a
// bottom sheet below 768, a centered dialog from 768, with the same state.

const _opener = ValueKey('open');

Widget _app({
  required WidgetBuilder form,
  double keyboard = 0,
  void Function(Object? result)? onResult,
}) => MaterialApp(
  theme: raftTheme(),
  builder: (context, home) => MediaQuery(
    data: MediaQuery.of(context)
        .copyWith(viewInsets: EdgeInsets.only(bottom: keyboard)),
    child: home!,
  ),
  home: Builder(
    builder: (context) => Scaffold(
      body: Center(
        child: TextButton(
          key: _opener,
          onPressed: () async {
            final result = await showRaftForm<bool>(context, builder: form);
            onResult?.call(result);
          },
          child: const Text('open'),
        ),
      ),
    ),
  ),
);

void _size(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.byKey(_opener));
  await tester.pumpAndSettle();
}

FocusNode? _focused() => FocusManager.instance.primaryFocus;

void main() {
  leakDebt(const ['CurvedAnimation']);
  Widget formDialog(BuildContext context, {int fields = 2}) => RaftFormDialog(
    title: 'Rename channel',
    submitLabel: 'Rename',
    fields: [
      for (var i = 0; i < fields; i++)
        RaftFormField('f$i', 'Field $i', required: i == 0),
    ],
    onSubmit: (_) async {},
  );

  group('RaftFormDialog', () {
    testWidgets('is a bottom sheet on a phone and a dialog from 768', (
      tester,
    ) async {
      for (final (width, sheet) in [
        (390.0, true),
        (767.0, true),
        (768.0, false),
        (1000.0, false),
      ]) {
        _size(tester, Size(width, 800));
        await tester.pumpWidget(_app(form: formDialog));
        await _open(tester);
        expect(find.byType(RaftSheet), sheet ? findsOneWidget : findsNothing);
        expect(
          find.byWidgetPredicate((w) => w is AlertDialog || w is RaftDialog),
          sheet ? findsNothing : findsOneWidget,
        );
        expect(find.text('Rename channel'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('keeps the text, the focus and the window across 768', (
      tester,
    ) async {
      _size(tester, const Size(1000, 800));
      await tester.pumpWidget(_app(form: formDialog));
      await _open(tester);
      final second = find.byKey(const ValueKey('field-f1'));
      await tester.enterText(second, 'typed here');
      await tester.pump();
      final focus = _focused();
      expect(focus, isNotNull);
      for (final width in [390.0, 1000.0, 600.0]) {
        tester.view.physicalSize = Size(width, 800);
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('field-f1')), findsOneWidget);
        expect(find.text('typed here'), findsOneWidget, reason: '$width');
        expect(_focused(), same(focus), reason: '$width focus');
        expect(find.byType(RaftFormDialog), findsOneWidget);
      }
    });

    testWidgets('submit returns true', (tester) async {
      _size(tester, const Size(390, 800));
      Object? result;
      await tester.pumpWidget(
        _app(form: formDialog, onResult: (r) => result = r),
      );
      await _open(tester);
      await tester.enterText(find.byKey(const ValueKey('field-f0')), 'abc');
      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();
      expect(result, true);
      expect(find.byType(RaftFormDialog), findsNothing);
    });

    testWidgets('the sheet scrolls and keeps a focused field above the '
        'keyboard', (tester) async {
      _size(tester, const Size(390, 800));
      await tester.pumpWidget(
        _app(form: (c) => formDialog(c, fields: 14), keyboard: 300),
      );
      await _open(tester);
      final scroll = find.byType(CustomScrollView);
      final last = find.byKey(const ValueKey('field-f13'));
      await tester.dragUntilVisible(
        last.hitTestable(),
        scroll,
        const Offset(0, -200),
      );
      await tester.tap(last);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<EditableText>(
              find.descendant(of: last, matching: find.byType(EditableText)),
            )
            .focusNode
            .hasFocus,
        isTrue,
      );
      expect(tester.getRect(last).bottom, lessThanOrEqualTo(800 - 300));
      expect(find.text('Rename'), findsOneWidget);
      expect(
        tester.getRect(find.text('Rename')).bottom,
        lessThanOrEqualTo(800 - 300),
      );
    });

    group('unsaved input', () {
      final asked = find.byType(RaftAvatarDiscardConfirmation);
      final handle = find.byKey(const ValueKey('raft-sheet-handle'));
      Future<void> phoneForm(WidgetTester tester) async {
        _size(tester, const Size(390, 800));
        await tester.pumpWidget(_app(form: formDialog));
        await _open(tester);
      }

      testWidgets('a drag on a changed form asks, Keep Editing keeps it, '
          'Discard Changes closes it', (tester) async {
        await phoneForm(tester);
        await tester.enterText(find.byKey(const ValueKey('field-f1')), 'mine');
        await tester.fling(handle, const Offset(0, 700), 2500);
        await tester.pumpAndSettle();
        expect(asked, findsOneWidget);
        await tester.tap(find.text('Keep Editing'));
        await tester.pumpAndSettle();
        expect(find.text('mine'), findsOneWidget);
        expect(find.byType(RaftSheet), findsOneWidget);
        await tester.fling(handle, const Offset(0, 700), 2500);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Discard Changes'));
        await tester.pumpAndSettle();
        expect(find.byType(RaftFormDialog), findsNothing);
      });

      testWidgets('an untouched form closes by drag and by the scrim without '
          'asking', (tester) async {
        await phoneForm(tester);
        await tester.fling(handle, const Offset(0, 700), 2500);
        await tester.pumpAndSettle();
        expect(asked, findsNothing);
        expect(find.byType(RaftFormDialog), findsNothing);
        await tester.pumpWidget(const SizedBox());
        await phoneForm(tester);
        await tester.tapAt(const Offset(200, 6));
        await tester.pumpAndSettle();
        expect(asked, findsNothing);
        expect(find.byType(RaftFormDialog), findsNothing);
      });

      testWidgets('the X asks on a changed form; Cancel never asks', (
        tester,
      ) async {
        await phoneForm(tester);
        await tester.enterText(find.byKey(const ValueKey('field-f1')), 'mine');
        await tester.tap(find.byType(RaftCloseButton));
        await tester.pumpAndSettle();
        expect(asked, findsOneWidget);
        await tester.tap(find.text('Keep Editing'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(asked, findsNothing);
        expect(find.byType(RaftFormDialog), findsNothing);
      });

      testWidgets('a changed choice counts as unsaved', (tester) async {
        _size(tester, const Size(390, 800));
        await tester.pumpWidget(
          _app(
            form: (context) => RaftFormDialog(
              title: 'Language',
              fields: const [
                RaftFormField(
                  'lang',
                  'Language',
                  initial: 'en',
                  choices: {'en': 'English', 'de': 'Deutsch'},
                ),
              ],
              onSubmit: (_) async {},
            ),
          ),
        );
        await _open(tester);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(asked, findsNothing, reason: 'nothing changed: just closes');
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(
          _app(
            form: (context) => RaftFormDialog(
              title: 'Language',
              fields: const [
                RaftFormField(
                  'lang',
                  'Language',
                  initial: 'en',
                  choices: {'en': 'English', 'de': 'Deutsch'},
                ),
              ],
              onSubmit: (_) async {},
            ),
          ),
        );
        await _open(tester);
        await tester.tap(find.byType(DropdownButtonFormField<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Deutsch').last);
        await tester.pumpAndSettle();
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(asked, findsOneWidget);
      });
    });
  });
}
