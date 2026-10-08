import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    testWidgets('controlled initial desktop focus only once $family/$dark', (
      t,
    ) async {
      final elsewhere = FocusNode();
      addTearDown(elsewhere.dispose);
      Widget host(bool autofocus, {bool visible = true, bool allowed = true}) =>
          MaterialApp(
            theme: raftTheme(family, dark: dark),
            home: Scaffold(
              body: Column(
                children: [
                  TextField(focusNode: elsewhere),
                  const Spacer(),
                  Visibility(
                    visible: visible,
                    maintainState: true,
                    child: RaftComposer(
                      key: const ValueKey('thread-composer'),
                      hint: 'Message thread',
                      initialDraft: 'Public retained 中文',
                      autofocus: autofocus,
                      canAutofocus: () => allowed,
                      onSend: (_) async => true,
                    ),
                  ),
                ],
              ),
            ),
          );
      await t.pumpWidget(host(true));
      await t.pump();
      final composer = find.byType(RaftComposer);
      final state = t.state(composer);
      final editor = find.descendant(
        of: composer,
        matching: find.byType(TextField),
      );
      final node = t.widget<TextField>(editor).focusNode!;
      expect(node.hasFocus, isTrue);
      expect(
        t.widget<TextField>(editor).controller!.text,
        'Public retained 中文',
      );
      elsewhere.requestFocus();
      await t.pump();
      await t.pumpWidget(host(true));
      await t.pump();
      expect(t.state(composer), same(state));
      expect(elsewhere.hasFocus, isTrue);
      expect(node.hasFocus, isFalse);
      await t.pumpWidget(host(true, visible: false));
      await t.pump();
      await t.pumpWidget(host(true));
      await t.pump();
      expect(elsewhere.hasFocus, isTrue);
      expect(node.hasFocus, isFalse);
      expect(
        t.widget<TextField>(editor).controller!.text,
        'Public retained 中文',
      );
      expect(t.takeException(), isNull);
    });
    testWidgets(
      'touch and denied authority never request initial focus $family/$dark',
      (t) async {
        Future<void> mount({
          required bool autofocus,
          required bool allowed,
          required bool visible,
        }) async {
          await t.pumpWidget(
            MaterialApp(
              theme: raftTheme(family, dark: dark),
              home: Scaffold(
                body: Column(
                  children: [
                    const Spacer(),
                    Visibility(
                      visible: visible,
                      maintainState: true,
                      child: RaftComposer(
                        key: ValueKey('$autofocus/$allowed/$visible'),
                        autofocus: autofocus,
                        canAutofocus: () => allowed,
                        initialDraft: '未发送中文',
                        onSend: (_) async => true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
          await t.pump();
          final editor = find.descendant(
            of: find.byType(RaftComposer, skipOffstage: false),
            matching: find.byType(TextField, skipOffstage: false),
            skipOffstage: false,
          );
          expect(t.widget<TextField>(editor).focusNode!.hasFocus, isFalse);
          expect(t.widget<TextField>(editor).controller!.text, '未发送中文');
        }

        await mount(autofocus: false, allowed: true, visible: true);
        await mount(autofocus: true, allowed: false, visible: true);
        await mount(autofocus: true, allowed: true, visible: false);
        await t.pumpWidget(const SizedBox.shrink());
        await t.pump();
        expect(t.takeException(), isNull);
      },
    );
  }
}
