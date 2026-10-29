@Tags(['look-elegant'])
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/src/recipes/toast_styles.g.dart';
import 'package:raft_ui/test_themes.dart';

void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        '${dark ? 'dark' : 'light'}/$scale action precedes trailing close',
        (t) async {
          t.view
            ..physicalSize = const Size(390, 900)
            ..devicePixelRatio = 1;
          addTearDown(t.view.reset);
          final controller = RaftToastController();
          addTearDown(controller.dispose);
          var copied = 0;
          await t.pumpWidget(
            MaterialApp(
              theme: raftTheme(
                pack: packForThemeId(elegantThemePackId),
                dark: dark,
              ),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: Scaffold(body: RaftToastPortal(controller: controller)),
            ),
          );
          void show() => controller.show(
            'Local save failed',
            actionLabel: 'Copy',
            onAction: () => copied++,
          );
          show();
          await t.pump();
          final action = find.byKey(const Key('toast-action'));
          final close = find.byKey(const Key('toast-close'));
          expect(t.getRect(close).left, greaterThan(t.getRect(action).right));
          expect(t.takeException(), isNull);
          await t.tap(action);
          await t.pump();
          expect(copied, 1);
          expect(find.byType(RaftToast), findsNothing);
          show();
          await t.pump();
          await t.tap(close);
          await t.pump();
          expect(copied, 1);
          expect(find.byType(RaftToast), findsNothing);
        },
      );
    }
    testWidgets(
      '${dark ? 'dark' : 'light'} title-only source recipe and bounded portal',
      (t) async {
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
            theme: raftTheme(
              pack: packForThemeId(elegantThemePackId),
              dark: dark,
            ),
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
        controller.show('Copied', dismissible: false);
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
        // The app theme above is Elegant, so the recipe set is Elegant's too.
        final tokens = RaftTokens.theme(
          dark: dark,
          pack: packForThemeId(elegantThemePackId),
        );
        final root = t.widget<RaftRecipeBox>(
          find
              .descendant(of: toast, matching: find.byType(RaftRecipeBox))
              .first,
        );
        final expected = RaftToastRecipe.resolve(
          theme: tokens.recipeTheme,
          layout: RaftToastRecipeLayout.inline,
          tone: RaftToastRecipeTone.success,
          tokens: tokens.recipeTokens,
          states: tokens.recipeStates(),
        );
        expect(root.style.classes, expected.root.classes);
        expect(root.style.borderWidth.top, 0);
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
      },
    );
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
      controller.show('Clear hovered notice');
      await t.pump();
      await mouse.moveTo(t.getCenter(find.byType(RaftToast)));
      await t.pump();
      controller.clear();
      await t.pump();
      await mouse.moveTo(Offset.zero);
      await t.pump();
      controller.show('New scope notice');
      await t.pump();
      await t.pump(const Duration(seconds: 5));
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

  testWidgets('a dismissible toast shows the icon and a close that clears it', (
    t,
  ) async {
    t.view.physicalSize = const Size(320, 720);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final controller = RaftToastController();
    addTearDown(controller.dispose);
    var undone = 0;
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(pack: packForThemeId(elegantThemePackId)),
        home: Scaffold(body: RaftToastPortal(controller: controller)),
      ),
    );
    controller.show('Removed', actionLabel: 'Undo', onAction: () => undone++);
    await t.pump();
    expect(find.byKey(const Key('toast-close')), findsOneWidget);
    expect(find.byKey(const Key('toast-action')), findsOneWidget);
    expect(t.getRect(find.byType(RaftToast)).right, lessThanOrEqualTo(304));
    await t.tap(find.byKey(const Key('toast-action')));
    await t.pump();
    expect(undone, 1);
    expect(find.byType(RaftToast), findsNothing);
    controller.show('Saved');
    await t.pump();
    await t.tap(find.byKey(const Key('toast-close')));
    await t.pump();
    expect(find.byType(RaftToast), findsNothing);
    controller.show('Copied', dismissible: false);
    await t.pump();
    expect(find.byKey(const Key('toast-close')), findsNothing);
    controller.clear();
  });

  testWidgets(
    'a toast from the root host renders without the debug underline',
    (t) async {
      // The host sits in MaterialApp.builder, above the Navigator: its overlay
      // has no Material or Scaffold ancestor, so an unstyled Text would get the
      // WidgetsApp fallback (yellow double underline, monospace).
      final controller = RaftToastController();
      addTearDown(controller.dispose);
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(pack: packForThemeId(elegantThemePackId)),
          builder: (context, child) =>
              RaftToastHost(controller: controller, child: child!),
          home: const Scaffold(body: SizedBox.expand()),
        ),
      );
      controller.show('Could not complete that. Try again.', dismissible: true);
      await t.pump();
      final title = find.text('Could not complete that. Try again.');
      expect(title, findsOneWidget);
      final style = DefaultTextStyle.of(t.element(title)).style
          .merge(t.widget<Text>(title).style);
      expect(style.decoration, anyOf(isNull, TextDecoration.none));
      expect(style.decorationColor, isNull);
      expect(style.fontFamily, isNot('monospace'));
      expect(style.fontSize, 14);
      // The action label and close button inherit the same base.
      controller.show(
        'Removed',
        dismissible: true,
        actionLabel: 'Undo',
        onAction: () {},
      );
      await t.pump();
      for (final text in t.widgetList<Text>(
        find.descendant(
          of: find.byType(RaftToast),
          matching: find.byType(Text),
        ),
      )) {
        final merged = DefaultTextStyle.of(t.element(find.byWidget(text))).style
            .merge(text.style);
        expect(
          merged.decoration,
          anyOf(isNull, TextDecoration.none),
          reason: '"${text.data}"',
        );
      }
      controller.clear();
    },
  );

  group('toast against the composer', () {
    Future<void> mount(
      WidgetTester t,
      Size size, {
      double keyboard = 0,
      bool strip = false,
    }) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      t.view.viewInsets = FakeViewPadding(bottom: keyboard);
      addTearDown(t.view.reset);
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(pack: packForThemeId(elegantThemePackId)),
          builder: (context, child) => RaftToastHost(child: child!),
          home: Scaffold(
            body: Column(
              children: [
                const Expanded(child: SizedBox.expand()),
                RaftComposer(
                  onSend: (_) async => true,
                  hasAttachments: strip,
                  attachments: strip
                      ? const SizedBox(key: Key('strip'), height: 72)
                      : null,
                ),
              ],
            ),
          ),
        ),
      );
      await t.pump();
    }

    Future<void> toast(WidgetTester t) async {
      final context = t.element(find.byType(RaftComposer));
      showRaftToast(context, 'Channel ID and content are required');
      await t.pump();
      await t.pump();
    }

    final send = find.byKey(const ValueKey('composer-submit'));
    for (final (name, size, keyboard, strip) in [
      ('phone', const Size(390, 844), 0.0, false),
      ('phone with an attachment strip', const Size(390, 844), 0.0, true),
      ('phone with the keyboard open', const Size(390, 844), 300.0, false),
      ('narrow window', const Size(700, 700), 0.0, false),
    ]) {
      testWidgets('$name: the toast clears the composer', (t) async {
        await mount(t, size, keyboard: keyboard, strip: strip);
        await toast(t);
        final toastRect = t.getRect(find.byType(RaftToast));
        final composer = t.getRect(find.byType(RaftComposer));
        expect(toastRect.overlaps(composer), isFalse);
        expect(toastRect.overlaps(t.getRect(send)), isFalse);
        expect(
          toastRect.overlaps(
            t.getRect(
              find.descendant(
                of: find.byType(RaftComposer),
                matching: find.byType(TextField),
              ),
            ),
          ),
          isFalse,
        );
        expect(toastRect.bottom, lessThanOrEqualTo(size.height - keyboard));
      });
    }

    testWidgets('a wide layout keeps the bottom-center placement', (t) async {
      await mount(t, const Size(1280, 800));
      await toast(t);
      expect(t.getRect(find.byType(RaftToast)).bottom, 800 - 16);
    });

    testWidgets('a composer on a covered route does not lift the toast', (
      t,
    ) async {
      await mount(t, const Size(390, 844));
      final context = t.element(find.byType(RaftComposer));
      Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => const Scaffold()));
      await t.pumpAndSettle();
      showRaftToast(t.element(find.byType(Scaffold).last), 'Saved');
      await t.pump();
      await t.pump();
      expect(t.getRect(find.byType(RaftToast)).bottom, 844 - 16);
    });
  });
}
