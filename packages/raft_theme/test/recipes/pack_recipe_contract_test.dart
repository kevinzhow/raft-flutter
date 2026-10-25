import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_theme/raft_theme.dart';
import 'package:raft_theme/recipes.dart';

Directory _themePackage() {
  var ancestor = Directory.current;
  while (true) {
    for (final candidate in [
      ancestor,
      Directory.fromUri(ancestor.uri.resolve('packages/raft_theme/')),
    ]) {
      final pubspec = File.fromUri(candidate.uri.resolve('pubspec.yaml'));
      if (pubspec.existsSync() &&
          RegExp(
            r'^name: raft_theme$',
            multiLine: true,
          ).hasMatch(pubspec.readAsStringSync())) {
        return candidate;
      }
    }
    final parent = ancestor.parent;
    if (parent.path == ancestor.path) {
      throw StateError(
        'Cannot locate the raft_theme package from ${Directory.current.path}',
      );
    }
    ancestor = parent;
  }
}

void main() {
  test('the independent package has no application or raft_ui dependency', () {
    final package = _themePackage().uri;
    final pubspec = File.fromUri(package.resolve('pubspec.yaml'))
        .readAsStringSync();
    expect(pubspec, matches(RegExp(r'^name: raft_theme$', multiLine: true)));
    expect(pubspec, isNot(matches(RegExp(r'^\s+raft_ui:', multiLine: true))));
    for (final file in Directory.fromUri(
      package.resolve('lib/'),
    ).listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      expect(
        file.readAsStringSync(),
        isNot(
          matches(
            RegExp(
              r'''(?:import|export)\s+['"](?:package:raft_ui/|.*apps/raft_flutter)''',
            ),
          ),
        ),
        reason: file.path,
      );
    }
  });

  test(
    'each generated slot retains source identity independently of raft_ui',
    () {
      expect(raftRecipes, hasLength(121));
      for (final recipe in raftRecipes.entries) {
        for (final theme in ['elegant', 'brutal']) {
          final props = {'theme': theme};
          final slots = recipe.value(props);
          expect(slots, isNotEmpty, reason: recipe.key);
          for (final slot in slots.entries) {
            expect(slot.value.context!.recipe, recipe.key);
            expect(slot.value.context!.slot, slot.key);
          }
        }
      }
    },
  );

  test(
    'three packs resolve colors, font metrics and shadows without a UI adapter',
    () {
      for (final pack in builtInThemes.values) {
        for (final dark in [false, true]) {
          final values = pack.resolve(dark: dark, base: builtInRaftTheme);
          final tokens = RaftThemeRecipeTokens(values);
          expect(tokens.color('foreground'), values.colors['foreground']);
          expect(
            tokens.number('fieldFontSize'),
            values.geometry['type.field.size'],
          );
          expect(tokens.fontFamily('sansFont'), values.fonts['sans']!.family);
          final source = RaftInputRecipe.resolve(
            theme: RaftRecipeTheme.elegant,
            tokens: RaftThemeRecipeTokens(values, bindComponents: false),
          ).root;
          final bound = RaftInputRecipe.resolve(
            theme: RaftRecipeTheme.elegant,
            tokens: tokens,
          ).root;
          expect(
            bound.borderRadius!.topLeft.x,
            values.geometry['radius.control'],
          );
          expect(bound.padding, source.padding);
          final shadow = tokens.shadow('themeShadowLg');
          final expected = values.shadows['lg']!
              .where((s) => !s.inset)
              .toList()
              .reversed;
          expect(shadow.map((s) => s.offset), expected.map((s) => s.offset));
          for (final recipe in raftRecipes.entries) {
            for (final style in recipe.value({
              'theme': 'elegant',
            }, tokens: tokens).values) {
              style.backgroundColor?.resolve(tokens);
              style.color?.resolve(tokens);
              style.textStyle(tokens);
              style.border(tokens);
              style.decoration(tokens);
            }
          }
        }
      }
    },
  );
}
