import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

Future<void> pumpLarge(
  WidgetTester t,
  Widget child, {
  double scale = 3.1,
  Size view = const Size(390, 500),
}) async {
  t.view.physicalSize = view;
  t.view.devicePixelRatio = 1;
  t.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(t.view.reset);
  addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
  addTearDown(() => t.pumpWidget(const SizedBox.shrink()));
  await t.pumpWidget(
    MaterialApp(
      theme: raftTheme(),
      builder: (context, child) => RaftTextScaling(child: child!),
      home: Scaffold(body: child),
    ),
  );
  await t.pumpAndSettle();
}

Finder closeIn(Finder card) => find.descendant(
  of: card,
  matching: find.byWidgetPredicate(
    (w) => w is RaftCloseButton || w is RaftDialogClose,
  ),
);

void main() {
  for (final withFooter in [false, true]) {
    testWidgets(
      'large card keeps close usable after body drag: footer=$withFooter',
      (t) async {
        var closed = false;
        await pumpLarge(
          t,
          RaftModalBackdrop(
            child: RaftDialogCard(
              title: 'Details',
              onClose: () => closed = true,
              child: const SizedBox(height: 1100, child: Text('Long content')),
              footer: withFooter
                  ? RaftButton(label: 'Go', onPressed: () {})
                  : null,
            ),
          ),
        );
        expect(t.takeException(), isNull);
        final close = closeIn(find.byType(RaftDialogCard));
        final body = find.text('Long content');
        final before = t.getTopLeft(body).dy;
        expect(close.hitTestable(), findsOneWidget);
        await t.dragFrom(const Offset(195, 300), const Offset(0, -250));
        await t.pumpAndSettle();
        expect(t.getTopLeft(body).dy, lessThan(before - 100));
        expect(close.hitTestable(), findsOneWidget);
        await t.tap(close);
        await t.pump();
        expect(closed, isTrue);
        expect(t.takeException(), isNull);
      },
    );
  }

  testWidgets('large form keeps close and save usable after body drag', (
    t,
  ) async {
    await pumpLarge(
      t,
      Builder(
        builder: (context) => RaftButton(
          label: 'Open form',
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => RaftFormDialog(
              title: 'Rename channel',
              description: 'Pick a name teammates will recognise.',
              fields: const [
                RaftFormField('name', 'Name', initial: 'release'),
                RaftFormField('topic', 'Topic', multiline: true),
              ],
              onSubmit: (_) async {},
            ),
          ),
        ),
      ),
      view: const Size(390, 600),
    );
    await t.tap(find.text('Open form'));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    final form = find.byType(RaftFormDialog);
    final close = closeIn(form);
    final scroll = find.descendant(
      of: form,
      matching: find.byType(SingleChildScrollView),
    );
    expect(scroll, findsOneWidget);
    final description = find.text('Pick a name teammates will recognise.');
    final before = t.getTopLeft(description).dy;
    await t.drag(scroll, const Offset(0, -120));
    await t.pumpAndSettle();
    expect(t.getTopLeft(description).dy, lessThan(before - 10));
    expect(close.hitTestable(), findsOneWidget);
    expect(find.text('Save').hitTestable(), findsOneWidget);
    await t.tap(close);
    await t.pumpAndSettle();
    expect(form, findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('large create-task form keeps close usable after body drag', (
    t,
  ) async {
    var closed = false;
    final titles = List.generate(
      1,
      (i) => TextEditingController(text: 'Task $i'),
    );
    addTearDown(() {
      for (final controller in titles) {
        controller.dispose();
      }
    });
    await pumpLarge(
      t,
      RaftCreateTaskDialogView(
        titles: titles,
        filledCount: titles.length,
        onClose: () => closed = true,
        onSubmit: () {},
        onAddRow: () {},
        onRemoveRow: (_) {},
      ),
      scale: 1.01,
      view: const Size(1280, 220),
    );
    expect(t.takeException(), isNull);
    final card = find.byKey(const ValueKey('create-task-dialog'));
    final close = closeIn(card);
    final first = find.byKey(const ValueKey('create-task-title-0'));
    final before = t.getTopLeft(first).dy;
    expect(close.hitTestable(), findsOneWidget);
    await t.dragFrom(const Offset(640, 130), const Offset(0, -150));
    await t.pumpAndSettle();
    expect(t.getTopLeft(first).dy, lessThan(before - 10));
    expect(close.hitTestable(), findsOneWidget);
    await t.tap(close);
    await t.pump();
    expect(closed, isTrue);
    expect(t.takeException(), isNull);
  });
}
