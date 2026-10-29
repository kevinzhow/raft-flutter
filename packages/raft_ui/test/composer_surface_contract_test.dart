import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_theme/raft_theme.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

void main() {
  for (final dark in [false, true]) {
    testWidgets('mounted composer uses Source card and focus ring/$dark', (
      tester,
    ) async {
      addTearDown(() => tester.pumpWidget(const SizedBox()));
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final theme = raftTheme(
        pack: packForThemeId(raftThemePackId),
        dark: dark,
      );
      final tokens = theme.extension<RaftTokens>()!;
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(body: RaftComposer(onSend: (_) async => false)),
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
      // v1.21.23 MessageInput mounts the 0.7.0 Composer without a surface
      // override: bg-layer-card border-[1.5px] focus-within:shadow-focus.
      expect(shell().color, tokens.colors['layer-card']);
      expect(
        shell().border,
        Border.all(color: tokens.colors['line-strong']!, width: 1),
      );
      await tester.tap(find.byType(TextField));
      await tester.pump();
      expect(shell().boxShadow, tokens.focusShadows);
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText))
            .focusNode
            .hasFocus,
        true,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  test('frozen composer keeps old surface, border and shadow paint order', () {
    for (final id in [elegantThemePackId, brutalThemePackId]) {
      for (final dark in [false, true]) {
        final tokens = raftTheme(
          pack: packForThemeId(id),
          dark: dark,
        ).extension<RaftTokens>()!;
        final recipe = RaftComposerRecipe(tokens, desktop: true);
        for (final focused in [false, true]) {
          final raised = id == brutalThemePackId && !dark;
          final shadow = raised
              ? tokens.shadows
              : dark
              ? [
                  if (focused)
                    BoxShadow(
                      color: tokens.colors['accent-400']!.withValues(alpha: .7),
                      spreadRadius: .5,
                    ),
                ]
              : [
                  ...tokens.shadows,
                  BoxShadow(
                    color: tokens.colors['line-composer']!,
                    spreadRadius: 1,
                  ),
                ];
          expect(
            recipe.shellDecoration(focused: focused),
            BoxDecoration(
              color: tokens.panel,
              borderRadius: BorderRadius.circular(recipe.shellRadius),
              border: raised
                  ? Border.all(color: tokens.colors['line-composer']!, width: 2)
                  : null,
              boxShadow: shadow,
            ),
            reason: '$id/$dark/$focused',
          );
          expect(recipe.hostDecoration.color, tokens.panel);
        }
      }
    }
  }, skip: raftLookSkip(raftLookElegant, raftLookBrutal));
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
