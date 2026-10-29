import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

enum _Target { attach, send }

void main() {
  for (final direction in [TextDirection.ltr, TextDirection.rtl]) {
    for (final target in _Target.values) {
      testWidgets('actual composer $direction $target keeps nearby gap', (
        t,
      ) async {
        t.view.physicalSize = const Size(390, 844);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        addTearDown(() async {
          await t.pumpWidget(const SizedBox.shrink());
          await t.pumpAndSettle();
        });
        var attached = 0;
        var sent = 0;
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(platform: TargetPlatform.android),
            builder: (context, child) =>
                Directionality(textDirection: direction, child: child!),
            home: Scaffold(
              body: Align(
                alignment: Alignment.bottomCenter,
                child: RaftComposer(
                  initialDraft: 'review draft',
                  onAttach: () => attached++,
                  onSend: (_) async {
                    sent++;
                    // Preserve the draft so both pointer probes stay enabled.
                    return false;
                  },
                ),
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        final action = find.byWidgetPredicate(
          (w) =>
              w is RaftComposerAction &&
              w.tooltip == (target == _Target.attach ? 'Attach File' : 'Send'),
        );
        expect(action, findsOneWidget);
        final a = t.getRect(action);
        final shell = t.getRect(
          find.byKey(const ValueKey('composer-shell-slot')),
        );
        // Use the side facing the middle of the toolbar, safely inside the
        // shell and outside the actual action face. The point is only 2dp
        // beyond the face, within the documented 48dp touch target.
        final gap = Offset(
          a.center.dx < shell.center.dx ? a.right + 2 : a.left - 2,
          a.center.dy,
        );
        expect(a.contains(gap), isFalse);
        expect(shell.contains(gap), isTrue);
        expect(
          t.hitTestOnBinding(gap).path.any((e) => e.target is RenderEditable),
          isFalse,
          reason: 'The action gap must not be a direct editor hit',
        );
        final editor = t.widget<EditableText>(find.byType(EditableText));
        expect(editor.focusNode.hasFocus, isFalse);
        await t.tapAt(gap);
        await t.pumpAndSettle();
        expect(
          [attached, sent],
          target == _Target.attach ? [1, 0] : [0, 1],
          reason: 'The shell focus listener must yield to the nearby action',
        );
        expect(editor.focusNode.hasFocus, isFalse);
        expect(editor.controller.text, 'review draft');

        // The actual child action remains active with its ordinary hit path.
        await t.tapAt(a.center);
        await t.pumpAndSettle();
        expect([attached, sent], target == _Target.attach ? [2, 0] : [0, 2]);
        expect(editor.focusNode.hasFocus, isFalse);

        // The background still focuses the editor where no nearby action or
        // actual editable box owns the point.
        final field = t.getRect(find.byType(TextField));
        final blank = Offset(
          shell.center.dx,
          (field.bottom + shell.bottom) / 2,
        );
        expect(
          t.hitTestOnBinding(blank).path.any((e) => e.target is RenderEditable),
          isFalse,
        );
        await t.tapAt(blank);
        await t.pumpAndSettle();
        expect(editor.focusNode.hasFocus, isTrue);
        expect(editor.controller.text, 'review draft');
        expect([attached, sent], target == _Target.attach ? [2, 0] : [0, 2]);
        expect(t.takeException(), isNull);
      });
    }
  }
}
