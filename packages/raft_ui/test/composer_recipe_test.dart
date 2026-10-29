import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

Widget host(
  Widget child,
  bool dark, {
  double width = 390,
  double inset = 0,
  RaftDensity density = RaftDensity.desktop,
}) => MaterialApp(
  theme: raftTheme(dark: dark),
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
  for (final (dark) in raftThemeMatrix([(false), (true)], full: true)) {
    testWidgets(
      'touch actions keep source flow, disjoint edge hits and editor focus: ${dark ? 'dark' : 'light'}',
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
            dark,
            density: RaftDensity.touch,
          ),
        );
        await tester.pump(const Duration(milliseconds: 250));
        Finder action(String label) => find.ancestor(
          of: find.byTooltip(label),
          matching: find.byType(RaftComposerAction),
        );
        final image = tester.getRect(action('Attach Media'));
        final file = tester.getRect(action('Attach File'));
        final send = tester.getRect(action('Send'));
        final size = 32.0;
        expect(image.size, Size.square(size));
        expect(file.size, Size.square(size));
        expect(send.size, const Size.square(32));
        expect(file.left - image.right, 8);
        expect(
          tester
              .getSize(find.byKey(const ValueKey('composer-toolbar-slot')))
              .height,
          32,
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
        // Touch slop: the gap between the two small buttons is split between
        // them (nearest button wins), it is not dead space.
        await tester.tapAt(Offset(image.right + 1, image.center.dy));
        await tester.pump();
        expect((images, files, sends), (2, 1, 0));
        await tester.tapAt(Offset(file.left - 1, file.center.dy));
        await tester.pump();
        expect((images, files, sends), (2, 2, 0));
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
        // Source 32dp Send keeps its visual box but accepts a 48dp touch target.
        // The inside probe stays one pixel within the 8px added on each edge.
        await tester.tapAt(Offset(send.right + 7, send.center.dy));
        await tester.pump();
        expect(sends, 2);
        await tester.tapAt(Offset(send.center.dx, send.top - 7));
        await tester.pump();
        expect(sends, 3);
        await tester.tapAt(Offset(send.left - 7, send.center.dy));
        await tester.pump();
        expect(sends, 4);
        // Beyond 48dp nothing reroutes to it.
        await tester.tapAt(Offset(send.center.dx, send.top - 14));
        await tester.pump();
        expect(sends, 4);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      },
    );

    testWidgets(
      'mounted host/editor bounds, safe inset counted once: ${dark ? 'dark' : 'light'}',
      (tester) async {
        await tester.pumpWidget(
          host(
            RaftComposer(bottomSafeInset: 7, onSend: (_) async => false),
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
        expect(recipe.hostInset, const EdgeInsets.fromLTRB(20, 8, 20, 23));
        expect(recipe.editorMinimum, 24);
        expect(recipe.editorMaximum, 128);
        expect(recipe.shellRadius, 10);
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
        expect(text.style!.height, 24 / 16);
        final decoration =
            tester
                    .widget<Container>(
                      find.byKey(const ValueKey('composer-shell-slot')),
                    )
                    .decoration!
                as BoxDecoration;
        expect(decoration.border!.top.width, 1);
        expect(
          decoration.border!.top.color,
          dark ? const Color(0xffe5e5e2) : const Color(0xff141111),
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      },
    );

    testWidgets(
      'Send tap keeps an unfocused composer unfocused: ${dark ? 'dark' : 'light'}',
      (tester) async {
        // Source MessageInput only prevents the Send pointer-down blur; it never
        // focuses the textarea after a send, so no keyboard pops on Android.
        var sends = 0;
        await tester.pumpWidget(
          host(
            RaftComposer(
              initialDraft: 'Restored draft',
              onSend: (_) async {
                sends++;
                return true;
              },
            ),
            dark,
          ),
        );
        await tester.tap(find.byTooltip('Send'));
        await tester.pump();
        expect(sends, 1);
        expect(
          tester
              .widget<EditableText>(find.byType(EditableText))
              .focusNode
              .hasFocus,
          isFalse,
        );
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      },
    );

    testWidgets(
      'empty disabled, pointer focus, late ACK preserves changed draft: ${dark ? 'dark' : 'light'}',
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
            dark,
          ),
        );
        final send = tester.widget<RaftComposerAction>(
          find.ancestor(
            of: find.byTooltip('Send'),
            matching: find.byType(RaftComposerAction),
          ),
        );
        expect(send.onPressed, isNull);
        await tester.enterText(find.byType(TextField), 'First draft 日本語');
        await tester.pump();
        await tester.tap(find.byTooltip('Send'));
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
      'popup outside shell keeps card height; real option tap retains editor focus: ${dark ? 'dark' : 'light'}',
      (tester) async {
        await tester.pumpWidget(
          host(
            RaftComposer(
              onSend: (_) async => false,
              suggestions: const [
                RaftComposerSuggestion(type: 'user', id: 'one', name: 'Alice'),
              ],
            ),
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
    testWidgets(
      'long mention label shrinks beside badge and handle without changing keyboard insertion: ${dark ? 'dark' : 'light'}',
      (tester) async {
        const name = 'Android-Developer-4-with-a-long-handle';
        await tester.pumpWidget(
          host(
            SizedBox(
              width: 342,
              child: RaftComposer(
                onSend: (_) async => false,
                suggestions: const [
                  RaftComposerSuggestion(
                    type: 'agent',
                    id: 'long-agent',
                    name: name,
                    title: 'Android Developer with a long display name',
                    detail: 'Implements shared Android and desktop fixes.',
                  ),
                ],
              ),
            ),
            dark,
          ),
        );
        await tester.enterText(find.byType(TextField), '@');
        await tester.pump();
        await tester.pump();
        expect(
          find.byKey(const ValueKey('composer-suggestion-agent-long-agent')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        expect(
          tester
              .widget<EditableText>(find.byType(EditableText))
              .controller
              .text,
          '@$name ',
        );
        expect(
          find.byKey(const ValueKey('composer-suggestions-slot')),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'image/file are independent; controlled task action cannot send; pending upload busy blocks shortcuts',
    (tester) async {
      var images = 0, files = 0, tasks = 0, sends = 0;
      final task = TextButton(
        onPressed: () => tasks++,
        child: const Text('As Task'),
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
          false,
        ),
      );
      await tester.tap(find.byType(TextField));
      await tester.tap(find.byTooltip('Attach Media'));
      expect(images, 1);
      expect(files, 0);
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText))
            .focusNode
            .hasFocus,
        isTrue,
      );
      await tester.tap(find.byTooltip('Attach File'));
      expect(files, 1);
      await tester.tap(find.text('As Task'));
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
    'compact host removes normal spacing/actions and desktop editor keeps its minimum and current Web body type',
    (tester) async {
      await tester.pumpWidget(
        host(
          RaftComposer(
            variant: RaftComposerVariant.compact,
            onAttach: () {},
            onSend: (_) async => false,
          ),
          false,
          width: 900,
        ),
      );
      final actual = tester.widget<Container>(
        find.byKey(const ValueKey('composer-host-slot')),
      );
      expect(actual.padding, EdgeInsets.zero);
      expect((actual.decoration! as BoxDecoration).border, isNull);
      expect(find.byTooltip('Attach File'), findsNothing);
      final editor = tester.widget<ConstrainedBox>(
        find.byKey(const ValueKey('composer-editor-slot')),
      );
      expect(editor.constraints.minHeight, 24);
      expect(
        tester.widget<TextField>(find.byType(TextField)).style!.fontSize,
        16,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
}
