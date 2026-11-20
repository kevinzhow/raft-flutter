import 'dart:convert';
import 'dart:ui' show SemanticsAction;

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_theme/raft_theme.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  for (final dark in [false, true]) {
    testWidgets('mounted composer rings for keyboard navigation/$dark', (
      tester,
    ) async {
      addTearDown(() => tester.pumpWidget(const SizedBox()));
      tester.view.physicalSize = dark
          ? const Size(856, 944)
          : const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final theme = raftTheme(pack: packForThemeId(raftThemePackId), dark: dark)
          .copyWith(
            platform: dark ? TargetPlatform.android : TargetPlatform.linux,
          );
      final tokens = theme.extension<RaftTokens>()!;
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: RaftComposer(
              autofocus: true,
              onAttach: () {},
              onSend: (_) async => false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      BoxDecoration shell() =>
          tester
                  .widget<Container>(
                    find.byKey(const ValueKey('composer-shell-slot')),
                  )
                  .decoration
              as BoxDecoration;
      expect(shell().color, tokens.colors['layer-card']);
      expect(
        shell().border,
        Border.all(color: tokens.colors['line-strong']!, width: 1),
      );
      final editor = find.byType(EditableText);
      final focus = tester.widget<EditableText>(editor).focusNode;
      final pointer = dark ? PointerDeviceKind.touch : PointerDeviceKind.mouse;
      expect(focus.hasPrimaryFocus, isTrue);
      expect(shell().boxShadow, tokens.focusShadows);

      await tester.tap(editor, kind: pointer);
      await tester.pump();
      expect(focus.hasPrimaryFocus, isTrue);
      expect(shell().boxShadow, isEmpty);

      const draft = 'Unsent draft';
      await tester.enterText(editor, draft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.pump();
      expect(focus.hasPrimaryFocus, isTrue);
      expect(shell().boxShadow, isEmpty);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(focus.hasPrimaryFocus, isFalse);
      expect(shell().boxShadow, tokens.focusShadows);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      expect(focus.hasPrimaryFocus, isTrue);
      expect(shell().boxShadow, tokens.focusShadows);

      await tester.tap(editor, kind: pointer);
      focus.unfocus();
      await tester.pumpAndSettle();
      expect(focus.hasPrimaryFocus, isFalse);
      expect(shell().boxShadow, isEmpty);

      focus.requestFocus();
      await tester.pumpAndSettle();
      expect(focus.hasPrimaryFocus, isTrue);
      expect(shell().boxShadow, isEmpty);

      focus.unfocus();
      await tester.pump(const Duration(milliseconds: 1100));
      expect(focus.hasPrimaryFocus, isFalse);
      focus.requestFocus();
      await tester.pumpAndSettle();
      expect(focus.hasPrimaryFocus, isTrue);
      expect(shell().boxShadow, tokens.focusShadows);

      await tester.tap(editor, kind: pointer);
      focus.unfocus();
      await tester.pump(const Duration(milliseconds: 1100));
      await tester.pumpAndSettle();
      expect(focus.hasPrimaryFocus, isFalse);
      expect(shell().boxShadow, isEmpty);
      final semantics = tester.ensureSemantics();
      try {
        await tester.pump();
        final node = tester.getSemantics(find.byType(TextField));
        expect(
          node.getSemanticsData().hasAction(SemanticsAction.focus),
          isTrue,
        );
        node.owner!.performAction(node.id, SemanticsAction.focus);
      } finally {
        semantics.dispose();
      }
      await tester.pumpAndSettle();
      expect(focus.hasPrimaryFocus, isTrue);
      expect(shell().boxShadow, tokens.focusShadows);
      expect(tester.widget<EditableText>(editor).controller.text, draft);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('pointer-opened composer autofocus keeps the idle shell', (
    tester,
  ) async {
    var open = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme().copyWith(platform: TargetPlatform.linux),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => Column(
              children: [
                RaftButton(
                  label: 'Open discussion',
                  onPressed: () => setState(() => open = true),
                ),
                if (open)
                  RaftComposer(autofocus: true, onSend: (_) async => false),
              ],
            ),
          ),
        ),
      ),
    );
    expect(find.byType(RaftComposer), findsNothing);
    await tester.tap(
      find.text('Open discussion'),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<EditableText>(find.byType(EditableText))
          .focusNode
          .hasPrimaryFocus,
      isTrue,
    );
    final shell = tester.widget<Container>(
      find.byKey(const ValueKey('composer-shell-slot')),
    );
    expect((shell.decoration! as BoxDecoration).boxShadow, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('user pack independently controls composer surface and shadows', (
    tester,
  ) async {
    final pack = RaftThemePack.parse(
      jsonEncode({
        'format': raftThemePackFormat,
        'id': 'user:composer-surface',
        'name': {'en': 'Composer surface'},
        'version': '1.0.0',
        'extends': 'raft',
        'modes': {
          'light': {
            'colors': {
              'layer-composer-shell': '#123456',
              'layer-composer-host': '#abcdef',
            },
            'geometry': {'stroke.composerShell': 3},
            'shadows': {
              'shadow.composerIdle': '1px 2px 3px 4px #123456',
              'shadow.composerFocus': '4px 3px 2px 1px #654321',
            },
          },
          'dark': {},
        },
      }),
    );
    late RaftComposerRecipe recipe;
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(pack: pack),
        home: Builder(
          builder: (context) {
            recipe = RaftComposerRecipe(RaftTokens.of(context), desktop: true);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(recipe.hostDecoration.color, const Color(0xffabcdef));
    expect(
      recipe.shellDecoration(focused: false).color,
      const Color(0xff123456),
    );
    expect(
      (recipe.shellDecoration(focused: false).border as Border).top.width,
      3,
    );
    expect(recipe.shellDecoration(focused: false).boxShadow, const [
      BoxShadow(
        color: Color(0xff123456),
        offset: Offset(1, 2),
        blurRadius: 3,
        spreadRadius: 4,
      ),
    ]);
    expect(recipe.shellDecoration(focused: true).boxShadow, const [
      BoxShadow(
        color: Color(0xff654321),
        offset: Offset(4, 3),
        blurRadius: 2,
        spreadRadius: 1,
      ),
    ]);
    await tester.pumpWidget(const SizedBox());
  });
}
