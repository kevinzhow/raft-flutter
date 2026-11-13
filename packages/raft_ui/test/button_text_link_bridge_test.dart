import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  test('retired Button axes resolve TextLink metrics without a Button box', () {
    final tokens = RaftTokens.theme();
    for (final (size, variant) in [
      (RaftButtonSize.inline, RaftButtonVariant.standard),
      (RaftButtonSize.md, RaftButtonVariant.link),
      (RaftButtonSize.inline, RaftButtonVariant.link),
    ]) {
      final metrics = RaftButtonMetrics.of(size, variant, tokens);
      expect(metrics.height, 0);
      expect(metrics.paddingX, 0);
      expect(metrics.text.fontWeight, 500);
    }
  });

  for (final dark in [false, true]) {
    testWidgets('retired Button link uses TextLink states and input/$dark', (
      tester,
    ) async {
      var activated = 0, disabled = false, busy = false;
      late StateSetter update;
      final focus = FocusNode();
      TestGesture? mouse;
      addTearDown(() async {
        await mouse?.removePointer();
        await tester.pumpWidget(const SizedBox());
        focus.dispose();
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(dark: dark).copyWith(platform: TargetPlatform.linux),
          home: Scaffold(
            body: Center(
              child: DefaultTextStyle.merge(
                style: const TextStyle(fontSize: 19, height: 2),
                child: StatefulBuilder(
                  builder: (context, setState) {
                    update = setState;
                    return RaftButton(
                      label: 'Read more',
                      // Keep the old generated API working until its callers
                      // migrate to the TextLink family.
                      tone: RaftButtonRecipeVariant.link,
                      size: RaftButtonRecipeSize.inline,
                      physicalHeight: 60,
                      focusNode: focus,
                      disabled: disabled,
                      busy: busy,
                      onPressed: () => activated++,
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final button = find.byType(RaftButton);
      final box = find.descendant(
        of: button,
        matching: find.byType(RaftRecipeBox),
      );
      RaftRecipeBox surface() => tester.widget<RaftRecipeBox>(box);
      final tokens = RaftTokens.of(tester.element(button));
      final idle = tester.getRect(button);
      expect(
        idle.height,
        38,
        reason: 'TextLink inherits its ambient line box.',
      );
      expect(surface().style.padding, EdgeInsets.zero);
      expect(surface().style.borderRadius, BorderRadius.circular(2));
      expect(
        surface().style.text(tokens.recipeTokens).fontWeight,
        FontWeight.w500,
      );
      expect(
        surface().style.text(tokens.recipeTokens).color,
        tokens.colors['foreground-muted'],
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(focus.hasFocus, isTrue);
      expect(surface().style['box-shadow'], isNotNull);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(activated, 1);
      mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: idle.center);
      await tester.pumpAndSettle();
      expect(surface().style['text-decoration-line'].toString(), 'underline');
      expect(
        surface().style.text(tokens.recipeTokens).color,
        tokens.colors['foreground'],
      );
      expect(tester.getRect(button), idle);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(activated, 2);

      update(() => disabled = true);
      await tester.pumpAndSettle();
      expect(
        surface().style.text(tokens.recipeTokens).color,
        tokens.colors['foreground-disabled'],
      );
      expect(
        surface().style['text-decoration-line']?.toString(),
        isNot('underline'),
      );
      await tester.tap(button);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(activated, 2);
      update(() {
        disabled = false;
        busy = true;
      });
      await tester.pump();
      await tester.tap(button);
      await tester.pump();
      expect(activated, 2);
      expect(tester.getRect(button), idle);
      expect(tester.takeException(), isNull);
    });
  }
}
