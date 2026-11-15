import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

import 'flutter_test_config.dart' show leakDebt;

// `dismissible: false` with `dragDismissible: false` is Web
// `disablePointerDismissal` for content a stray touch must not lose: no
// pointer closes the window. A press on the scrim does nothing; on a phone a
// drag down (slow or flung, by the handle or the content) moves the sheet and
// it slides back. Esc, Back and the close button still close it.
// `dismissible: false` alone keeps the approved phone drag of form sheets
// (docs/close-affordances.md, e.g. computer-bulk-model).

const _opener = ValueKey('open');
final _handle = find.byKey(const ValueKey('raft-sheet-handle'));

Widget _app(Future<void> Function(BuildContext context) open) => MaterialApp(
  theme: raftTheme(),
  home: Builder(
    builder: (context) => Scaffold(
      body: Center(
        child: TextButton(
          key: _opener,
          onPressed: () => open(context),
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

Widget _form(BuildContext context) => RaftFormDialog(
  title: 'New backup codes',
  submitLabel: 'Done',
  fields: const [RaftFormField('code', 'Code')],
  onSubmit: (_) async {},
);

Future<void> _openForm(
  WidgetTester tester, {
  required bool dismissible,
  bool? dragDismissible,
}) async {
  await tester.pumpWidget(
    _app(
      (context) => showRaftForm<bool>(
        context,
        dismissible: dismissible,
        dragDismissible: dragDismissible ?? dismissible,
        guardUnsaved: false,
        builder: _form,
      ),
    ),
  );
  await tester.tap(find.byKey(_opener));
  await tester.pumpAndSettle();
}

Future<void> _pressOutside(WidgetTester tester) async {
  await tester.tapAt(const Offset(200, 6));
  await tester.pumpAndSettle();
}

void main() {
  leakDebt(const ['CurvedAnimation']);

  testWidgets('a dialog that may not be dismissed by a pointer ignores the '
      'scrim; Esc closes it', (tester) async {
    _size(tester, const Size(1280, 900));
    await _openForm(tester, dismissible: false);
    await _pressOutside(tester);
    expect(find.byType(RaftFormDialog), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(RaftFormDialog), findsNothing);
  });

  testWidgets('such a sheet ignores the scrim, a slow drag and a fling down, '
      'and comes back to its opening size; Back closes it', (tester) async {
    _size(tester, const Size(390, 800));
    await _openForm(tester, dismissible: false);
    expect(find.byType(RaftFormSheet), findsOneWidget);
    final top = tester.getTopLeft(_handle).dy;

    await _pressOutside(tester);
    expect(find.byType(RaftFormSheet), findsOneWidget);

    await tester.drag(_handle, const Offset(0, 600));
    await tester.pumpAndSettle();
    expect(find.byType(RaftFormSheet), findsOneWidget);
    expect(tester.getTopLeft(_handle).dy, moreOrLessEquals(top, epsilon: 1));

    await tester.fling(_handle, const Offset(0, 700), 2500);
    await tester.pumpAndSettle();
    expect(find.byType(RaftFormSheet), findsOneWidget);
    expect(tester.getTopLeft(_handle).dy, moreOrLessEquals(top, epsilon: 1));

    // A pull down on the content (not the handle) is the same drag.
    await tester.fling(find.text('Code'), const Offset(0, 700), 2500);
    await tester.pumpAndSettle();
    expect(find.byType(RaftFormSheet), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(RaftFormSheet), findsNothing);
  });

  testWidgets('a dismissible sheet still closes by a fling down', (
    tester,
  ) async {
    _size(tester, const Size(390, 800));
    await _openForm(tester, dismissible: true);
    await tester.fling(_handle, const Offset(0, 700), 2500);
    await tester.pumpAndSettle();
    expect(find.byType(RaftFormSheet), findsNothing);
  });

  testWidgets('without a scrim close the sheet still closes by a drag', (
    tester,
  ) async {
    _size(tester, const Size(390, 800));
    await _openForm(tester, dismissible: false, dragDismissible: true);
    await _pressOutside(tester);
    expect(find.byType(RaftFormSheet), findsOneWidget);
    await tester.fling(_handle, const Offset(0, 700), 2500);
    await tester.pumpAndSettle();
    expect(find.byType(RaftFormSheet), findsNothing);
  });

  testWidgets('a fixed-height sheet that may not be dismissed by a pointer '
      'is not dragged closed either', (tester) async {
    _size(tester, const Size(390, 800));
    await tester.pumpWidget(
      _app(
        (context) => showRaftPresented<void>(
          context,
          policy: RaftPresentationPolicy.form,
          dismissible: false,
          dragDismissible: false,
          sheetFillsHeight: true,
          content: (context, form) => const SizedBox.expand(
            key: ValueKey('fixed-content'),
            child: Text('fixed'),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(_opener));
    await tester.pumpAndSettle();
    await tester.fling(find.text('fixed'), const Offset(0, 700), 2500);
    await tester.pumpAndSettle();
    expect(find.text('fixed'), findsOneWidget);
  });
}
