import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

Widget host(
  Widget child,
  RaftFamily family,
  bool dark, {
  double width = 390,
  double inset = 0,
  RaftDensity density = RaftDensity.desktop,
}) => MaterialApp(
  theme: raftTheme(family, dark: dark),
  home: MediaQuery(
    data: MediaQueryData(
      size: Size(width, 700),
      padding: EdgeInsets.only(bottom: inset),
    ),
    child: Scaffold(
      body: RaftDensityScope(
        density: density,
        child: Column(children: [const Spacer(), child]),
      ),
    ),
  ),
);

void main() {
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    testWidgets(
      'touch actions keep source flow, disjoint edge hits and editor focus: $family/$dark',
      (tester) async {
        var images = 0, files = 0, sends = 0;
        await tester.pumpWidget(
          host(
            RaftComposer(
              initialDraft: 'Draft 中文',
              onImagePick: () => images++,
              onAttach: () => files++,
              onSend: (_) async {
                sends++;
                return false;
              },
            ),
            family,
            dark,
            density: RaftDensity.touch,
          ),
        );
        await tester.pump(const Duration(milliseconds: 250));
        Finder action(String label) => find.ancestor(
          of: find.byTooltip(label),
          matching: find.byType(RaftComposerAction),
        );
        final image = tester.getRect(action('Attach image'));
        final file = tester.getRect(action('Attach file'));
        final send = tester.getRect(action('Send message (Ctrl+Enter)'));
        final size = family == RaftFamily.brutal ? 26.0 : 28.0;
        expect(image.size, Size.square(size));
        expect(file.size, Size.square(size));
        expect(send.size, const Size.square(28));
        expect(file.left - image.right, family == RaftFamily.brutal ? 8 : 6);
        expect(
          tester
              .getSize(find.byKey(const ValueKey('composer-toolbar-slot')))
              .height,
          family == RaftFamily.brutal ? 28 : 42,
        );
        await tester.tap(find.byType(TextField));
        await tester.tapAt(Offset(image.left + 1, image.center.dy));
        await tester.pump();
        await tester.tapAt(Offset(file.right - 1, file.center.dy));
        await tester.pump();
        expect((images, files, sends), (1, 1, 0));
        final gesture = await tester.startGesture(send.center);
        await gesture.cancel();
        await tester.pump();
        expect(sends, 0);
        await tester.tapAt(
          Offset(image.right + (file.left - image.right) / 2, image.center.dy),
        );
        await tester.pump();
        expect((images, files, sends), (1, 1, 0));
        expect(
          tester
              .widget<EditableText>(find.byType(EditableText))
              .focusNode
              .hasFocus,
          true,
        );
        expect(
          tester
              .widget<EditableText>(find.byType(EditableText))
              .controller
              .text,
          'Draft 中文',
        );
        await tester.tapAt(Offset(send.center.dx, send.bottom - 1));
        await tester.pump();
        expect(sends, 1);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      },
    );

    testWidgets(
      'mounted host/editor bounds, safe inset counted once: $family/$dark',
      (tester) async {
        await tester.pumpWidget(
          host(
            RaftComposer(bottomSafeInset: 7, onSend: (_) async => false),
            family,
            dark,
            inset: 29,
          ),
        );
        final context = tester.element(find.byType(RaftComposer));
        final recipe = RaftComposerRecipe(
          RaftTokens.of(context),
          desktop: false,
          bottomSafeInset: 7,
        );
        expect(recipe.hostInset, const EdgeInsets.fromLTRB(12, 12, 12, 23));
        expect(recipe.editorMinimum, 20);
        expect(recipe.editorMaximum, 128);
        expect(recipe.shellRadius, family == RaftFamily.brutal ? 0 : 8);
        final actualHost = tester.widget<Container>(
          find.byKey(const ValueKey('composer-host-slot')),
        );
        expect(
          actualHost.padding,
          recipe.hostInset,
        ); // Not 23 + MediaQuery's29.
        expect(actualHost.decoration, recipe.hostDecoration);
        final text = tester.widget<TextField>(find.byType(TextField));
        expect(text.style!.fontSize, 16);
        expect(text.style!.height, 20 / 16);
        final decoration =
            tester
                    .widget<Container>(
                      find.byKey(const ValueKey('composer-shell-slot')),
                    )
                    .decoration!
                as BoxDecoration;
        expect(
          decoration.border,
          family == RaftFamily.brutal
              ? Border.all(color: Colors.black, width: 2)
              : null,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      },
    );

    testWidgets(
      'empty disabled, pointer focus, late ACK preserves changed draft: $family/$dark',
      (tester) async {
        final delivered = Completer<bool>();
        var sends = 0;
        await tester.pumpWidget(
          host(
            RaftComposer(
              onSend: (_) {
                sends++;
                return delivered.future;
              },
            ),
            family,
            dark,
          ),
        );
        final send = tester.widget<RaftComposerAction>(
          find.ancestor(
            of: find.byTooltip('Send message (Ctrl+Enter)'),
            matching: find.byType(RaftComposerAction),
          ),
        );
        expect(send.onPressed, isNull);
        await tester.enterText(find.byType(TextField), 'First draft 日本語');
        await tester.pump();
        await tester.tap(find.byTooltip('Send message (Ctrl+Enter)'));
        await tester.pump();
        expect(sends, 1);
        expect(
          tester
              .widget<EditableText>(find.byType(EditableText))
              .focusNode
              .hasFocus,
          isTrue,
        );
        await tester.enterText(find.byType(TextField), 'New draft 中文');
        delivered.complete(true);
        await tester.pump();
        expect(
          tester
              .widget<EditableText>(find.byType(EditableText))
              .controller
              .text,
          'New draft 中文',
        );
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      },
    );

    testWidgets(
      'popup outside shell keeps card height; real option tap retains editor focus: $family/$dark',
      (tester) async {
        await tester.pumpWidget(
          host(
            RaftComposer(
              onSend: (_) async => false,
              suggestions: const [
                RaftComposerSuggestion(type: 'user', id: 'one', name: 'Alice'),
              ],
            ),
            family,
            dark,
          ),
        );
        await tester.enterText(find.byType(TextField), '@al');
        await tester.pump();
        await tester.pump();
        final shell = tester.getRect(
          find.byKey(const ValueKey('composer-shell-slot')),
        );
        final popup = tester.getRect(
          find.byKey(const ValueKey('composer-suggestions-slot')),
        );
        expect(
          popup.bottom,
          lessThan(
            tester
                .getRect(find.byKey(const ValueKey('composer-host-slot')))
                .top,
          ),
        );
        final option = find.byKey(
          const ValueKey('composer-suggestion-user-one'),
        );
        expect(option.hitTestable(), findsOneWidget);
        await tester.tap(option);
        await tester.pump();
        await tester.pump();
        expect(
          tester
              .widget<EditableText>(find.byType(EditableText))
              .controller
              .text,
          '@Alice ',
        );
        expect(
          tester
              .widget<EditableText>(find.byType(EditableText))
              .focusNode
              .hasFocus,
          isTrue,
        );
        expect(
          tester
              .getRect(find.byKey(const ValueKey('composer-shell-slot')))
              .height,
          shell.height,
        );
        expect(
          find.byKey(const ValueKey('composer-suggestions-slot')),
          findsNothing,
        );
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      },
    );
  }

  testWidgets(
    'image/file are independent; controlled task action cannot send; pending upload busy blocks shortcuts',
    (tester) async {
      var images = 0, files = 0, tasks = 0, sends = 0;
      final task = TextButton(
        onPressed: () => tasks++,
        child: const Text('As task'),
      );
      await tester.pumpWidget(
        host(
          RaftComposer(
            initialDraft: 'Draft',
            onImagePick: () => images++,
            onAttach: () => files++,
            taskAction: task,
            onSend: (_) async {
              sends++;
              return false;
            },
          ),
          RaftFamily.elegant,
          false,
        ),
      );
      await tester.tap(find.byType(TextField));
      await tester.tap(find.byTooltip('Attach image'));
      expect(images, 1);
      expect(files, 0);
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText))
            .focusNode
            .hasFocus,
        isTrue,
      );
      await tester.tap(find.byTooltip('Attach file'));
      expect(files, 1);
      await tester.tap(find.text('As task'));
      expect(tasks, 1);
      expect(sends, 0);
      await tester.pumpWidget(
        host(
          RaftComposer(
            initialDraft: 'Draft',
            submitBusy: true,
            canSend: false,
            onSend: (_) async {
              sends++;
              return true;
            },
          ),
          RaftFamily.elegant,
          false,
        ),
      );
      await tester.tap(find.byType(TextField));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(sends, 0);
      expect(find.byType(RaftSpinner), findsOneWidget);
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).controller.text,
        'Draft',
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );

  testWidgets(
    'compact host removes normal spacing/actions and desktop editor follows actual product40 override',
    (tester) async {
      await tester.pumpWidget(
        host(
          RaftComposer(
            variant: RaftComposerVariant.compact,
            onAttach: () {},
            onSend: (_) async => false,
          ),
          RaftFamily.elegant,
          false,
          width: 900,
        ),
      );
      final actual = tester.widget<Container>(
        find.byKey(const ValueKey('composer-host-slot')),
      );
      expect(actual.padding, EdgeInsets.zero);
      expect((actual.decoration! as BoxDecoration).border, isNull);
      expect(find.byTooltip('Attach file'), findsNothing);
      final editor = tester.widget<ConstrainedBox>(
        find.byKey(const ValueKey('composer-editor-slot')),
      );
      expect(editor.constraints.minHeight, 40);
      expect(
        tester.widget<TextField>(find.byType(TextField)).style!.fontSize,
        14,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
}
