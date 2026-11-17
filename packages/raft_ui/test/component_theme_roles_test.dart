import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_theme/raft_theme.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  testWidgets('tooltip elevation can be changed by a user pack', (
    tester,
  ) async {
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
    final pack = RaftThemePack.parse(
      jsonEncode({
        'format': raftThemePackFormat,
        'id': 'user:component-roles',
        'name': {'en': 'Component roles'},
        'version': '1.0.0',
        'extends': 'raft',
        'modes': {
          'light': {
            'shadows': {'shadow.tooltip': '2px 3px 4px 5px #123456'},
          },
          'dark': {},
        },
      }),
    );
    late RaftTooltipRecipe recipe;
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(pack: pack),
        home: Builder(
          builder: (context) {
            recipe = RaftTooltipRecipe(RaftTokens.of(context));
            return const SizedBox();
          },
        ),
      ),
    );
    expect(recipe.shadows, const [
      BoxShadow(
        color: Color(0xff123456),
        offset: Offset(2, 3),
        blurRadius: 4,
        spreadRadius: 5,
      ),
    ]);
  });
  testWidgets(
    'a user pack controls message toolbar padding without a style branch',
    (tester) async {
      final pack = RaftThemePack.parse(
        jsonEncode({
          'format': raftThemePackFormat,
          'id': 'user:toolbar-padding',
          'name': {'en': 'Toolbar padding'},
          'version': '1.0.0',
          'extends': 'raft',
          'modes': {
            'light': {
              'geometry': {
                'space.messageToolbarInline': 10,
                'space.messageToolbarBlock': 8,
              },
            },
            'dark': {},
          },
        }),
      );
      late EdgeInsets padding;
      addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(pack: pack),
          home: Builder(
            builder: (context) {
              padding = RaftMessageRowRecipe(
                RaftTokens.of(context),
                viewportWidth: 1280,
              ).toolbarPadding;
              return const SizedBox();
            },
          ),
        ),
      );
      expect(padding, const EdgeInsets.symmetric(horizontal: 10, vertical: 8));
    },
  );
}
