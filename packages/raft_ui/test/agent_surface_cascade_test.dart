import 'dart:ui' show SemanticsRole;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/agent_surface_previews.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

import 'selection_popover_surface_test.dart' as selection;

Future<void> loadFonts(WidgetTester tester) async {
  await selection.loadFonts(tester);
  await tester.runAsync(() async {
    ByteData bytes;
    try {
      bytes = await rootBundle.load(
        'packages/raft_ui/assets/fonts/SpaceGrotesk.ttf',
      );
    } on FlutterError {
      bytes = await rootBundle.load('assets/fonts/SpaceGrotesk.ttf');
    }
    await (FontLoader(
      'packages/raft_ui/SpaceGrotesk',
    )..addFont(Future.value(bytes))).load();
  });
}

Widget host(ThemeData theme, Widget child) => MaterialApp(
  theme: theme,
  home: Scaffold(body: child),
);

void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    testWidgets(
      '${dark ? 'dark' : 'light'} legacy Elegant portal font and label cascade',
      (tester) async {
        await loadFonts(tester);
        final theme = raftTheme(
              pack: packForThemeId(elegantThemePackId),
              dark: dark,
            ),
            tokens = theme.extension<RaftTokens>()!,
            controller = TextEditingController(text: 'Product');
        await tester.pumpWidget(
          host(
            theme,
            RaftAgentDialogCard(
              title: 'Create Agent',
              onClose: () {},
              children: [
                RaftStableField(
                  label: 'Name',
                  child: RaftAgentTextInput(controller: controller),
                ),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          DefaultTextStyle.of(tester.element(find.byType(RaftStableField)))
              .style
              .fontFamily,
          tokens.bodyFont,
        );
        expect(
          tester.widget<Text>(find.text('Name')).style!.color,
          dark ? tokens.colors['foreground-hint'] : tokens.strong,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        controller.dispose();
      },
      skip: raftLookSkip(raftLookElegant),
    );
    testWidgets(
      '${dark ? 'dark' : 'light'} form repaint keeps real IME, selection and input hit',
      (tester) async {
        await loadFonts(tester);
        final controller = TextEditingController(text: 'draft');
        late StateSetter update;
        var invalid = false;
        var currentTheme = raftTheme(dark: dark);
        await tester.pumpWidget(
          StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return host(
                currentTheme,
                Center(
                  child: SizedBox(
                    width: 300,
                    child: RaftAgentTextInput(
                      controller: controller,
                      invalid: invalid,
                      semanticLabel: 'Name',
                    ),
                  ),
                ),
              );
            },
          ),
        );
        await tester.pumpAndSettle();
        await tester.tapAt(
          tester.getRect(find.byType(RaftAgentTextInput)).center,
        );
        await tester.pump();
        final editable = tester.state<EditableTextState>(
          find.byType(EditableText),
        );
        expect(editable.widget.focusNode.hasFocus, true);
        tester.testTextInput.updateEditingValue(
          const TextEditingValue(
            text: '日本語 input',
            selection: TextSelection(baseOffset: 1, extentOffset: 3),
            composing: TextRange(start: 0, end: 3),
          ),
        );
        await tester.pump();
        final value = controller.value;
        update(() {
          invalid = true;
          currentTheme = raftTheme(dark: !dark);
        });
        await tester.pumpAndSettle();
        expect(tester.state(find.byType(EditableText)), same(editable));
        expect(controller.value, value);
        expect(editable.widget.focusNode.hasFocus, true);
        expect(tester.testTextInput.hasAnyClients, true);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump();
        expect(controller.selection.isCollapsed, true);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        controller.dispose();
      },
    );
    testWidgets(
      '${dark ? 'dark' : 'light'} default warning and capacity caller stay distinct',
      (tester) async {
        await loadFonts(tester);
        final theme = raftTheme(dark: dark),
            tokens = theme.extension<RaftTokens>()!;
        Widget warning(bool caller) => host(
          theme,
          Center(
            child: SizedBox(
              width: 280,
              child: RaftAgentBanner(
                status: RaftAgentBannerStatus.warning,
                description: 'Capacity',
                action: 'Upgrade',
                onAction: () {},
                foregroundColor: caller && dark
                    ? tokens.colors['warning-strong']
                    : null,
                actionForeground: caller && dark
                    ? tokens.colors['warning-strong']
                    : null,
                backgroundColor: caller && dark
                    ? tokens.colors['warning-soft']
                    : null,
              ),
            ),
          ),
        );
        await tester.pumpWidget(warning(false));
        await tester.pumpAndSettle();
        final ordinary = tester.widget<RaftAgentInlineText>(
          find.byType(RaftAgentInlineText),
        );
        expect(ordinary.style!.color, isNot(tokens.muted));
        // raft-ui 0.7.0's banner no longer recolours its description button, so
        // the inline action keeps the link colour instead of inheriting the text.
        expect(ordinary.actionForeground, isNull);
        await tester.pumpWidget(warning(true));
        await tester.pumpAndSettle();
        final explicit = tester.widget<RaftAgentInlineText>(
          find.byType(RaftAgentInlineText),
        );
        expect(
          explicit.style!.color,
          dark ? tokens.colors['warning-strong'] : ordinary.style!.color,
        );
        expect(
          explicit.actionForeground,
          dark ? tokens.colors['warning-strong'] : ordinary.actionForeground,
        );
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets(
      '${dark ? 'dark' : 'light'} message menu paint retains keyboard and pointer semantics',
      (tester) async {
        final semantics = tester.ensureSemantics();
        var selected = 0, dismissed = 0;
        await tester.pumpWidget(
          host(
            raftTheme(dark: dark),
            Center(
              child: RaftMessageContextMenu(
                onDismiss: () => dismissed++,
                sections: [
                  [
                    RaftMessageContextMenuItem(
                      label: 'Copy',
                      icon: const RaftIcon(RaftGlyph.copy),
                      onPressed: () => selected++,
                    ),
                  ],
                  [
                    const RaftMessageContextMenuItem(
                      label: 'Unavailable',
                      icon: RaftIcon(RaftGlyph.x),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final box = tester.widget<RaftRecipeBox>(
          find.byType(RaftRecipeBox).first,
        );
        // elevation-float has outer layers only, in light and dark.
        expect(box.style.cssShadows(box.tokens).where((s) => s.inset), isEmpty);
        expect(
          find.byWidgetPredicate(
            (w) => w is Semantics && w.properties.role == SemanticsRole.menu,
          ),
          findsOneWidget,
        );
        final control = find.byType(RaftMenuButtonItem).first;
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: tester.getCenter(control));
        await mouse.down(tester.getCenter(control));
        await mouse.up();
        await tester.pumpAndSettle();
        expect(selected, 1);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(selected, 2);
        await tester.tap(find.text('Unavailable'));
        await tester.pump();
        expect(selected, 2);
        await tester.tap(control);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pump();
        expect(dismissed, 1);
        await mouse.removePointer();
        expect(tester.takeException(), isNull);
        semantics.dispose();
      },
    );
    testWidgets(
      '${dark ? 'dark' : 'light'} explicit primary text caller preserves generic accent and disabled action',
      (tester) async {
        var calls = 0;
        final theme = raftTheme(dark: dark),
            tokens = theme.extension<RaftTokens>()!;
        Widget buttons(bool override) => host(
          theme,
          Center(
            child: RaftAgentDialogButton(
              label: 'Create',
              primary: true,
              foreground: override && dark
                  ? tokens.colors['foreground-inverse']
                  : null,
            ),
          ),
        );
        await tester.pumpWidget(buttons(false));
        await tester.pumpAndSettle();
        final before = DefaultTextStyle.of(tester.element(find.text('Create')))
            .style
            .color;
        await tester.pumpWidget(buttons(true));
        await tester.pumpAndSettle();
        expect(
          DefaultTextStyle.of(tester.element(find.text('Create'))).style.color,
          dark ? tokens.colors['foreground-inverse'] : before,
        );
        await tester.tap(find.text('Create'));
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        expect(calls, 0);
        await tester.pumpWidget(
          host(
            theme,
            Center(
              child: RaftAgentDialogButton(
                label: 'Create',
                primary: true,
                onPressed: () => calls++,
                foreground: dark ? tokens.colors['foreground-inverse'] : null,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Create'));
        await tester.pump();
        expect(calls, 1);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        expect(calls, 2);
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets(
      '${dark ? 'dark' : 'light'} interactive form preview edits, selects and submits',
      (tester) async {
        await loadFonts(tester);
        await tester.binding.setSurfaceSize(const Size(440, 560));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          host(raftTheme(dark: dark), const AgentSurfacePreview()),
        );
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'Product-QA');
        await tester.pump();
        await tester.tap(find.text('Select...'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Laptop'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Use Capacity Caller'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Create'));
        await tester.pumpAndSettle();
        expect(find.text('Created'), findsOneWidget);
        await tester.tap(find.byType(RaftDialogClose));
        await tester.pump();
        expect(find.text('Closed'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
