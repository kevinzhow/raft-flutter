import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

Future<void> _motion(WidgetTester t) async {
  await t.pump();
  await t.pump(const Duration(milliseconds: 240));
}

Future<RaftToastController> _mount(WidgetTester t, {bool dark = false}) async {
  final controller = RaftToastController();
  addTearDown(controller.dispose);
  await t.pumpWidget(
    MaterialApp(
      theme: raftTheme(dark: dark),
      home: Scaffold(body: RaftToastPortal(controller: controller)),
    ),
  );
  return controller;
}

void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    final mode = dark ? 'dark' : 'light';
    testWidgets('$mode onClose reports action once, after onAction', (t) async {
      final c = await _mount(t, dark: dark);
      final log = <String>[];
      c.show(
        'Marked as done',
        actionLabel: 'Undo',
        onAction: () => log.add('action'),
        onClose: (r) => log.add('close:${r.name}'),
      );
      await _motion(t);
      await t.tap(find.byKey(const Key('toast-action')));
      await _motion(t);
      expect(log, ['close:action', 'action']);
      c.clear();
      expect(log, hasLength(2));
    });

    testWidgets('$mode onClose reports timeout after 8s', (t) async {
      final c = await _mount(t, dark: dark);
      final log = <RaftToastCloseReason>[];
      c.show('Done', actionLabel: 'Undo', onAction: () {}, onClose: log.add);
      await t.pump(const Duration(seconds: 7));
      expect(log, isEmpty);
      await t.pump(const Duration(seconds: 1, milliseconds: 100));
      expect(log, [RaftToastCloseReason.timeout]);
    });

    testWidgets('$mode close button and clear report dismissed', (t) async {
      final c = await _mount(t, dark: dark);
      final log = <RaftToastCloseReason>[];
      c.show('One', dismissible: true, onClose: log.add);
      await _motion(t);
      await t.tap(find.byKey(const Key('toast-close')));
      await _motion(t);
      expect(log, [RaftToastCloseReason.dismissed]);
      c.show('Two', onClose: log.add);
      c.clear();
      expect(log, [
        RaftToastCloseReason.dismissed,
        RaftToastCloseReason.dismissed,
      ]);
    });
  }

  testWidgets('a newer toast closes the old one as replaced', (t) async {
    final c = await _mount(t);
    final log = <String>[];
    c.show('A', onClose: (r) => log.add('a:${r.name}'));
    c.show('B', onClose: (r) => log.add('b:${r.name}'));
    expect(log, ['a:replaced']);
    c.clear();
    expect(log, ['a:replaced', 'b:dismissed']);
  });

  testWidgets('handle.dismiss closes its own toast early, once', (t) async {
    final c = await _mount(t);
    final log = <RaftToastCloseReason>[];
    final h = c.show('A', actionLabel: 'Undo', onClose: log.add);
    expect(h.isShown, isTrue);
    h.dismiss();
    expect(h.isShown, isFalse);
    expect(log, [RaftToastCloseReason.dismissed]);
    h.dismiss();
    expect(log, hasLength(1));
    expect(c.title, isNull);
  });

  testWidgets('a stale handle never closes a newer toast', (t) async {
    final c = await _mount(t);
    final h = c.show('A');
    c.show('B');
    h.dismiss();
    expect(c.title, 'B');
    expect(h.isShown, isFalse);
    c.clear();
  });

  testWidgets('paused toast does not time out until resumed', (t) async {
    final c = await _mount(t);
    final log = <RaftToastCloseReason>[];
    c.show('A', actionLabel: 'Undo', onClose: log.add);
    c.pause(true);
    await t.pump(const Duration(seconds: 20));
    expect(log, isEmpty);
    c.pause(false);
    await t.pump(const Duration(seconds: 9));
    expect(log, [RaftToastCloseReason.timeout]);
  });

  testWidgets('showRaftToastHandle passes onClose and returns a handle', (
    t,
  ) async {
    final log = <RaftToastCloseReason>[];
    late RaftToastHandle? handle;
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(dark: false),
        home: RaftToastHost(
          child: Builder(
            builder: (context) => TextButton(
              onPressed: () => handle = showRaftToastHandle(
                context,
                'Marked as done',
                tone: RaftToastRecipeTone.success,
                actionLabel: 'Undo',
                onAction: () {},
                onClose: log.add,
              ),
              child: const Text('go'),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('go'));
    expect(handle, isNotNull);
    handle!.dismiss();
    expect(log, [RaftToastCloseReason.dismissed]);
  });
}
