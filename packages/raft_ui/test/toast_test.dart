import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/src/recipes/toast_styles.g.dart';

void main() {
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    testWidgets('$family/$dark title-only source recipe and bounded portal', (
      t,
    ) async {
      t.view.physicalSize = const Size(320, 720);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final controller = RaftToastController();
      addTearDown(controller.dispose);
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(family, dark: dark),
          home: Scaffold(
            body: Column(
              children: [
                TextField(focusNode: focus),
                RaftToastPortal(controller: controller),
              ],
            ),
          ),
        ),
      );
      focus.requestFocus();
      await t.pump();
      controller.show('Copied');
      await t.pump();
      expect(
        focus.hasFocus,
        isTrue,
        reason: 'Feedback must not capture input focus.',
      );
      final toast = find.byType(RaftToast);
      expect(toast, findsOneWidget);
      final title = t.widget<Text>(find.text('Copied'));
      expect(title.style!.fontSize, 14);
      expect(title.style!.height, 20 / 14);
      expect(title.style!.fontWeight, FontWeight.w400);
      final tokens = RaftTokens.theme(family, dark: dark);
      final root = t.widget<RaftRecipeBox>(
        find.descendant(of: toast, matching: find.byType(RaftRecipeBox)).first,
      );
      final expected = RaftToastRecipe.resolve(
        theme: tokens.recipeTheme,
        layout: RaftToastRecipeLayout.inline,
        tone: RaftToastRecipeTone.success,
        tokens: tokens.recipeTokens,
        states: tokens.recipeStates(),
      );
      expect(root.style.classes, expected.root.classes);
      expect(root.style.borderWidth.top, family == RaftFamily.brutal ? 2 : 0);
      expect(t.getRect(toast).left, greaterThanOrEqualTo(16));
      expect(t.getRect(toast).right, lessThanOrEqualTo(304));
      expect(t.getRect(toast).bottom, 704);
      final live = t.widget<Semantics>(
        find.descendant(of: toast, matching: find.byType(Semantics)).first,
      );
      expect(live.properties.liveRegion, isTrue);
      await t.pump(const Duration(milliseconds: 4999));
      expect(toast, findsOneWidget);
      await t.pump(const Duration(milliseconds: 1));
      expect(toast, findsNothing);
      expect(t.takeException(), isNull);
    });
  }

  testWidgets(
    'hover pause, replacement and owner removal retain no stale overlay',
    (t) async {
      final controller = RaftToastController();
      addTearDown(controller.dispose);
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(body: RaftToastPortal(controller: controller)),
        ),
      );
      controller.show('First');
      await t.pump();
      final mouse = await t.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(t.getCenter(find.byType(RaftToast)));
      await t.pump();
      await t.pump(const Duration(seconds: 6));
      expect(find.text('First'), findsOneWidget);
      controller.show('Latest');
      await t.pump();
      expect(find.text('First'), findsNothing);
      await mouse.moveTo(Offset.zero);
      await t.pump(const Duration(seconds: 4));
      expect(find.text('Latest'), findsOneWidget);
      await t.pump(const Duration(seconds: 1));
      expect(find.byType(RaftToast), findsNothing);
      controller.show('Scope feedback');
      await t.pump();
      await t.pumpWidget(const MaterialApp(home: SizedBox()));
      expect(find.text('Scope feedback'), findsNothing);
      controller.clear();
      await t.pump();
      expect(t.takeException(), isNull);
      await mouse.removePointer();
    },
  );
}
