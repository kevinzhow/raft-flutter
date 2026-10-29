import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/src/recipes/message_text_selection_toolbar.g.dart';

void main() {
  testWidgets('Android input Copy uses Raft menu typography and copies text', (
    tester,
  ) async {
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
    var clipboard = '';
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboard = (call.arguments as Map)['text'] as String;
        }
        if (call.method == 'Clipboard.hasStrings') return {'value': false};
        return null;
      },
    );
    final controller = TextEditingController(text: 'Raft selection');
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme().copyWith(platform: TargetPlatform.android),
        home: Scaffold(
          body: Center(child: RaftTextInput(controller: controller)),
        ),
      ),
    );
    await tester.tap(find.byType(TextField));
    controller.selection = const TextSelection(baseOffset: 0, extentOffset: 4);
    final editor = tester.state<EditableTextState>(find.byType(EditableText));
    editor.showToolbar();
    await tester.pumpAndSettle();
    final copy = find.text('Copy');
    expect(copy, findsOneWidget);
    expect(
      DefaultTextStyle.of(tester.element(copy)).style.fontWeight,
      // raft-ui 0.7.0 menu rows are bold 13px (0.6 sets them to w700).
      FontWeight.w700,
    );
    await tester.tap(copy);
    await tester.pumpAndSettle();
    expect(clipboard, 'Raft');
    expect(find.text('Copy'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  for (final (dark) in [(false), (true)]) {
    for (final scale in [1.0, 1.3, 2.0, 3.1]) {
      testWidgets(
        '${dark ? 'dark' : 'light'}/$scale overflow keeps labels and actions',
        (tester) async {
          addTearDown(() async {
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pump();
          });
          tester.view.physicalSize = const Size(320, 640);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final theme = raftTheme(dark: dark)
              .copyWith(platform: TargetPlatform.android);
          final tokens = theme.extension<RaftTokens>()!;
          final recipe = RaftMessageTextSelectionToolbarRecipe.resolve(
            theme: tokens.recipeTheme,
            states: tokens.recipeStates(),
            tokens: tokens.recipeTokens,
          );
          final actions = <int>[];
          const labels = [
            'Copy',
            'Cut',
            'Paste',
            'Select all',
            'Share selected text',
          ];
          await tester.pumpWidget(
            MaterialApp(
              theme: theme,
              home: Scaffold(
                body: MediaQuery(
                  data: MediaQueryData(
                    size: const Size(320, 640),
                    textScaler: TextScaler.linear(scale),
                    viewInsets: const EdgeInsets.only(bottom: 160),
                  ),
                  child: RaftTextSelectionToolbar.buttonItems(
                    anchors: const TextSelectionToolbarAnchors(
                      primaryAnchor: Offset(160, 260),
                      secondaryAnchor: Offset(160, 300),
                    ),
                    buttonItems: [
                      for (var i = 0; i < labels.length; i++)
                        ContextMenuButtonItem(
                          label: labels[i],
                          onPressed: () => actions.add(i),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final menu = find.byType(RaftTextSelectionToolbar);
          var copy = find.text('Copy');
          expect(copy, findsOneWidget);
          final style = DefaultTextStyle.of(tester.element(copy)).style;
          expect(
            style.fontWeight,
            recipe.toolbar.textStyle(tokens.recipeTokens).fontWeight,
          );
          expect(style.fontFamily, tokens.bodyFont);
          expect(
            MediaQuery.textScalerOf(tester.element(copy))
                    .scale(style.fontSize!) *
                (tester
                            .renderObject<RenderBox>(copy)
                            .localToGlobal(const Offset(1, 0)) -
                        tester
                            .renderObject<RenderBox>(copy)
                            .localToGlobal(Offset.zero))
                    .distance,
            closeTo(style.fontSize! * scale, .01),
          );
          await tester.tap(copy);
          expect(actions, [0]);
          final more = find.byWidgetPredicate(
            (w) =>
                w is IconButton &&
                w.tooltip ==
                    MaterialLocalizations.of(tester.element(menu))
                        .moreButtonTooltip,
          );
          expect(more, findsOneWidget);
          await tester.tap(more);
          await tester.pumpAndSettle();
          final share = find.text('Share selected text');
          await tester.ensureVisible(share);
          await tester.pumpAndSettle();
          expect(share.hitTestable(), findsOneWidget);
          final paragraph = tester.renderObject<RenderParagraph>(
            find.descendant(of: share, matching: find.byType(RichText)),
          );
          expect(paragraph.didExceedMaxLines, isFalse);
          final rect = tester.getRect(share);
          expect(rect.left, greaterThanOrEqualTo(8));
          expect(rect.right, lessThanOrEqualTo(312));
          expect(
            rect.bottom,
            lessThanOrEqualTo(473),
          ); // 13px rows in raft-ui 0.7.0
          await tester.tap(share);
          expect(actions, [0, 4]);
          expect(
            find.descendant(
              of: menu,
              matching: find.byType(TextSelectionToolbar),
            ),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      '${dark ? 'dark' : 'light'} message long-press Copy reaches clipboard and clears',
      (tester) async {
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
        });
        var copied = '';
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'Clipboard.setData')
              copied = (call.arguments as Map)['text'] as String;
            return null;
          },
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(dark: dark)
                .copyWith(platform: TargetPlatform.android),
            home: const Scaffold(
              body: Center(
                child: RaftDensityScope(
                  density: RaftDensity.touch,
                  child: RaftSelectionArea(
                    contextMenuBuilder: RaftSelectionArea.touchToolbarOnly,
                    child: Text('selection'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.longPress(find.text('selection'));
        await tester.pumpAndSettle();
        expect(find.byType(RaftTextSelectionToolbar), findsOneWidget);
        await tester.tap(find.text('Copy'));
        await tester.pumpAndSettle();
        expect(copied, 'selection');
        expect(find.text('Copy'), findsNothing);
        final region = tester.state<SelectableRegionState>(
          find.byType(SelectableRegion),
        );
        expect(
          region.contextMenuButtonItems.any(
            (item) => item.type == ContextMenuButtonType.copy,
          ),
          isFalse,
        );
      },
    );
  }

  for (final takesAttachments in [true, false]) {
    testWidgets(
      'Android menu Paste preserves host-first attachment path ($takesAttachments)',
      (tester) async {
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
        });
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'Clipboard.hasStrings') return {'value': true};
            if (call.method == 'Clipboard.getData')
              return {'text': 'clipboard text'};
            return null;
          },
        );
        var calls = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme().copyWith(platform: TargetPlatform.android),
            home: Scaffold(
              body: RaftComposer(
                onSend: (_) async => false,
                onPasteAttachments: () async {
                  calls++;
                  return takesAttachments;
                },
              ),
            ),
          ),
        );
        await tester.longPress(find.byType(TextField));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Paste'));
        await tester.pumpAndSettle();
        expect(calls, 1);
        expect(
          tester
              .widget<EditableText>(find.byType(EditableText))
              .controller
              .text,
          takesAttachments ? '' : 'clipboard text',
        );
        expect(find.text('Paste'), findsNothing);
      },
    );
  }

  testWidgets(
    'Android cut, select all and paste preserve the actual selection',
    (tester) async {
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      });
      var clipboard = 'replacement';
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.hasStrings') return {'value': true};
          if (call.method == 'Clipboard.getData') return {'text': clipboard};
          if (call.method == 'Clipboard.setData')
            clipboard = (call.arguments as Map)['text'] as String;
          return null;
        },
      );
      final controller = TextEditingController(text: 'alpha beta');
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme().copyWith(platform: TargetPlatform.android),
          home: Scaffold(
            body: Center(child: RaftTextInput(controller: controller)),
          ),
        ),
      );
      await tester.tap(find.byType(TextField));
      final editor = tester.state<EditableTextState>(find.byType(EditableText));
      controller.selection = const TextSelection.collapsed(offset: 2);
      editor.showToolbar();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Select all'));
      await tester.pumpAndSettle();
      expect(
        controller.selection,
        const TextSelection(baseOffset: 0, extentOffset: 10),
      );
      // Select all deliberately hides Android's toolbar; a new long press reopens it.
      editor.showToolbar();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cut'));
      await tester.pumpAndSettle();
      expect(controller.text, '');
      expect(clipboard, 'alpha beta');
      editor.showToolbar();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Paste'));
      await tester.pumpAndSettle();
      expect(controller.text, 'alpha beta');
    },
  );
  testWidgets(
    'Android menu exposes enabled actions to accessibility and keyboard',
    (tester) async {
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      });
      final semantics = tester.ensureSemantics();
      var copies = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme().copyWith(platform: TargetPlatform.android),
          home: Scaffold(
            body: RaftTextSelectionToolbar.buttonItems(
              anchors: const TextSelectionToolbarAnchors(
                primaryAnchor: Offset(300, 300),
              ),
              buttonItems: [
                ContextMenuButtonItem(
                  label: 'Copy selection',
                  onPressed: () => copies++,
                ),
                const ContextMenuButtonItem(
                  label: 'Unavailable',
                  onPressed: null,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final copy = tester.getSemantics(find.text('Copy selection'));
      expect(copy.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      final disabled = tester.getSemantics(find.text('Unavailable'));
      expect(
        disabled.getSemanticsData().hasAction(SemanticsAction.tap),
        isFalse,
      );
      final focus = tester
          .widget<FocusableActionDetector>(
            find
                .ancestor(
                  of: find.text('Copy selection'),
                  matching: find.byType(FocusableActionDetector),
                )
                .first,
          )
          .focusNode!;
      focus.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(copies, 1);
      semantics.dispose();
    },
  );

  for (final platform in [
    TargetPlatform.linux,
    TargetPlatform.windows,
    TargetPlatform.macOS,
    TargetPlatform.iOS,
  ]) {
    testWidgets('$platform keeps the adaptive toolbar', (tester) async {
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      });
      var copies = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme().copyWith(platform: platform),
          home: Scaffold(
            body: RaftTextSelectionToolbar.buttonItems(
              anchors: const TextSelectionToolbarAnchors(
                primaryAnchor: Offset(300, 300),
              ),
              buttonItems: [
                ContextMenuButtonItem(
                  type: ContextMenuButtonType.copy,
                  onPressed: () => copies++,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AdaptiveTextSelectionToolbar), findsOneWidget);
      expect(find.byType(RaftRecipeBox), findsNothing);
      await tester.tap(find.text('Copy'));
      expect(copies, 1);
    });
  }
  testWidgets(
    'Android menu does not inherit selected content decoration or font',
    (tester) async {
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      });
      final theme = raftTheme().copyWith(platform: TargetPlatform.android);
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: DefaultTextStyle(
              style: const TextStyle(
                fontFamily: 'monospace',
                decoration: TextDecoration.underline,
                fontSize: 40,
              ),
              child: RaftTextSelectionToolbar.buttonItems(
                anchors: const TextSelectionToolbarAnchors(
                  primaryAnchor: Offset(300, 300),
                ),
                buttonItems: [
                  ContextMenuButtonItem(
                    type: ContextMenuButtonType.copy,
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final style = DefaultTextStyle.of(tester.element(find.text('Copy')))
          .style;
      expect(style.decoration, TextDecoration.none);
      expect(style.fontFamily, theme.extension<RaftTokens>()!.bodyFont);
      expect(style.fontSize, 13); // raft-ui 0.7.0 menu rows
    },
  );
  testWidgets(
    'overflow keeps the original narrow panel and start-aligned labels',
    (tester) async {
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      });
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme().copyWith(platform: TargetPlatform.android),
          home: Scaffold(
            body: RaftTextSelectionToolbar.buttonItems(
              anchors: const TextSelectionToolbarAnchors(
                primaryAnchor: Offset(160, 300),
              ),
              buttonItems: [
                for (final label in [
                  'Cut',
                  'Copy',
                  'Paste',
                  'Select all',
                  'Ask Gemini',
                ])
                  ContextMenuButtonItem(label: label, onPressed: () {}),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final surface = find.byType(RaftRecipeBox).first;
      final closed = tester.getRect(surface);
      final more = find.byWidgetPredicate(
        (w) =>
            (w is RaftInteractive && w.tooltip == 'Show menu') ||
            (w is IconButton && w.tooltip == 'Show menu') ||
            (w is RaftInteractive && w.tooltip == 'More') ||
            (w is IconButton && w.tooltip == 'More'),
      );
      await tester.tap(more);
      await tester.pumpAndSettle();
      final expanded = tester.getRect(surface);
      expect(expanded.width, lessThan(closed.width - 40));
      expect(
        tester.getRect(find.text('Ask Gemini')).left - expanded.left,
        lessThan(24),
      );
    },
  );
}
