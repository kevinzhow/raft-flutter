import 'dart:ui' show SemanticsAction;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

void main() {
  for (final id in raftThemeMatrix([
    raftThemePackId,
    elegantThemePackId,
    brutalThemePackId,
  ], look: raftLookOf)) {
    for (final dark in [false, true]) {
      for (final device in [
        (TargetPlatform.linux, const Size(390, 844)),
        (TargetPlatform.android, const Size(856, 944)),
        (TargetPlatform.android, const Size(944, 856)),
      ]) {
        testWidgets('button inputs $id/$dark/${device.$1}/${device.$2}', (
          t,
        ) async {
          t.view.physicalSize = device.$2;
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.reset);
          final focus = FocusNode();
          final semantics = t.ensureSemantics();
          TestGesture? mouse;
          addTearDown(() async {
            if (mouse != null) await mouse.removePointer();
            await t.pumpWidget(const SizedBox());
            focus.dispose();
          });
          try {
            var count = 0, disabled = false, busy = false;
            late StateSetter update;
            await t.pumpWidget(
              MaterialApp(
                theme: raftTheme(
                  pack: packForThemeId(id),
                  dark: dark,
                ).copyWith(platform: device.$1),
                home: MediaQuery(
                  data: MediaQueryData(
                    size: device.$2,
                    disableAnimations: true,
                  ),
                  child: Scaffold(
                    body: Center(
                      child: StatefulBuilder(
                        builder: (context, setState) {
                          update = setState;
                          return RaftButton(
                            label: 'Apply',
                            focusNode: focus,
                            size: RaftButtonRecipeSize.xs,
                            busy: busy,
                            onPressed: disabled ? null : () => count++,
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            );
            await t.pumpAndSettle();
            final button = find.byType(RaftButton);
            final before = t.getRect(button);
            expect(
              RaftInteraction.of(t.element(button)).touch,
              device.$1 == TargetPlatform.android,
            );
            expect(
              t.getSemantics(button),
              matchesSemantics(
                label: 'Apply',
                isButton: true,
                hasEnabledState: true,
                isEnabled: true,
                isFocusable: true,
                hasTapAction: true,
                hasFocusAction: true,
              ),
            );
            await t.tap(button);
            await t.pumpAndSettle();
            expect(count, 1);
            mouse = await t.createGesture(kind: PointerDeviceKind.mouse);
            await mouse.addPointer(location: before.center);
            await mouse.down(before.center);
            await t.pump(const Duration(milliseconds: 200));
            expect(count, 1, reason: 'Press paints before release activates.');
            await mouse.up();
            await t.pumpAndSettle();
            expect(count, 2);
            await mouse.moveTo(const Offset(1, 1));
            await t.sendKeyEvent(LogicalKeyboardKey.tab);
            focus.requestFocus();
            await t.pumpAndSettle();
            expect(focus.hasFocus, isTrue);
            await t.sendKeyEvent(LogicalKeyboardKey.enter);
            await t.sendKeyEvent(LogicalKeyboardKey.space);
            await t.pumpAndSettle();
            expect(count, 4);
            expect(
              t.getRect(button),
              before,
              reason: 'Input never changes layout.',
            );
            for (final loading in [false, true]) {
              update(() {
                disabled = !loading;
                busy = loading;
              });
              await t.pumpAndSettle();
              await t.tap(button);
              await t.sendKeyEvent(LogicalKeyboardKey.enter);
              await t.sendKeyEvent(LogicalKeyboardKey.space);
              await t.pumpAndSettle();
              expect(count, 4, reason: 'Disabled and busy reject activation.');
              expect(
                t
                    .getSemantics(button)
                    .getSemanticsData()
                    .hasAction(SemanticsAction.tap),
                isFalse,
              );
              expect(t.getRect(button), before);
            }
            expect(t.takeException(), isNull);
          } finally {
            semantics.dispose();
          }
        });
      }
    }
  }
}
