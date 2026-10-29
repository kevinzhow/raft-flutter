import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_theme/raft_theme.dart';
import 'package:raft_theme/recipes.dart' show RaftRecipeSet;
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/src/recipes/recipe_router.dart';

/// Every place that composes utility class names by hand, in the Raft look.
///
/// A routed recipe's `classes` come from the Raft set there, whose utility table
/// does not compile the 0.5.52 names those lists add. Mixing the two used to
/// throw a RangeError (index -1); each site now builds a list of one set.
RaftThemePack _userPack(Map<String, String> options) => RaftThemePack.parse('''
{
  "format": "raft-theme/1",
  "id": "test-user",
  "name": {"en": "User"},
  "version": "1.0.0",
  "extends": "raft",
  "modes": {
    "light": {"options": ${_json(options)}},
    "dark": {"options": ${_json(options)}}
  }
}
''');

String _json(Map<String, String> m) =>
    '{${m.entries.map((e) => '"${e.key}": "${e.value}"').join(',')}}';

Widget _host(ThemeData theme, Widget child) => MaterialApp(
  theme: theme,
  home: Scaffold(
    body: Center(child: SizedBox(width: 320, child: child)),
  ),
);

void main() {
  test('the user pack really opts out of the raft styles', () {
    final t = RaftTokens.theme(
      pack: _userPack({
        'surfaceItem.style': 'recipe',
        'selectionPopover.style': 'recipe',
      }),
    );
    expect(t.recipeSet, RaftRecipeSet.raft);
    expect(t.option('surfaceItem.style', or: 'x'), 'recipe');
    expect(t.option('selectionPopover.style', or: 'x'), 'recipe');
  });

  for (final dark in [false, true]) {
    final mode = dark ? 'dark' : 'light';
    final raftTheme_ = raftTheme(dark: dark);
    final recipeOptions = _userPack({
      'surfaceItem.style': 'recipe',
      'selectionPopover.style': 'recipe',
    });

    testWidgets('$mode Raft: RaftPanel legacyCard (authored list)', (t) async {
      await t.pumpWidget(
        _host(raftTheme_, const RaftPanel(shadow: true, child: Text('panel'))),
      );
      expect(find.text('panel'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('$mode Raft: RaftTextInput legacy chrome (authored list)', (
      t,
    ) async {
      await t.pumpWidget(
        _host(raftTheme_, const RaftTextInput(chrome: RaftInputChrome.legacy)),
      );
      await t.tap(find.byType(TextField));
      await t.pump();
      expect(t.takeException(), isNull);
    });

    for (final selected in [false, true]) {
      testWidgets(
        '$mode Raft: surface list item on the recipe style, selected=$selected',
        (t) async {
          await t.pumpWidget(
            _host(
              raftTheme(dark: dark, pack: recipeOptions),
              RaftCard.item(
                selected: selected,
                onTap: () {},
                child: const Text('row'),
              ),
            ),
          );
          final gesture = await t.createGesture(kind: PointerDeviceKind.mouse);
          await gesture.addPointer(location: t.getCenter(find.text('row')));
          await t.pump();
          expect(find.text('row'), findsOneWidget);
          expect(t.takeException(), isNull);
        },
      );
    }

    testWidgets('$mode Raft: selection popover on the recipe style', (t) async {
      await t.pumpWidget(
        _host(
          raftTheme(dark: dark, pack: recipeOptions),
          RaftSelectionPopover(
            title: 'Pick',
            options: [
              RaftSelectionOption(label: 'One', checked: true, onTap: () {}),
            ],
          ),
        ),
      );
      expect(find.text('One'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    test('$mode Raft: assignee surface uses the 0.7.0 popover treatment', () {
      final t = RaftTokens.theme(dark: dark);
      final classes = taskAssigneeSurface(t).classes;
      expect(
        classes,
        containsAll(['bg-layer-popover', 'shadow-float', 'ring-1']),
      );
      expect(classes, isNot(contains('bg-layer-card')));
      expect(classes.any((c) => c.contains('raft-md')), isFalse);
    });

    for (final pack in [builtInElegantTheme, builtInBrutalTheme]) {
      test('$mode ${pack.id}: assignee surface keeps the frozen classes', () {
        final t = RaftTokens.theme(dark: dark, pack: pack);
        final classes = taskAssigneeSurface(t).classes;
        expect(classes, containsAll(['bg-layer-popover', 'shadow-raft-md']));
      });
    }
  }

  test('unknown class names fail loudly instead of a RangeError', () {
    final t = RaftTokens.theme();
    expect(
      () => resolveAuthoredClasses(
        const ['border', 'bg-layer-card-not-a-class'],
        t.recipeStates(),
        t.recipeTokens,
      ),
      throwsA(
        isA<AssertionError>().having(
          (e) => e.message,
          'message',
          contains('bg-layer-card-not-a-class'),
        ),
      ),
    );
    expect(
      () => resolveRecipeClasses(
        const ['bg-layer-panel'],
        t.recipeStates(),
        t.recipeTokens,
      ),
      throwsA(
        isA<AssertionError>().having(
          (e) => e.message,
          'message',
          contains('bg-layer-panel'),
        ),
      ),
    );
  });
}
