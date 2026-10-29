import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_theme/raft_theme.dart';
import 'package:raft_theme/recipes.dart';

void main() {
  for (final dark in [false, true]) {
    final tokens = RaftThemeRecipeTokens(builtInRaftTheme.resolve(dark: dark));
    final flags = <String>{if (dark) 'dark'};
    RaftRecipeStates states({
      bool hover = false,
      bool focus = false,
      bool disabled = false,
      double height = 800,
    }) => RaftRecipeStates(
      {
        ...flags,
        if (hover) 'hover',
        if (focus) 'focus-visible',
        if (disabled) 'disabled' else 'enabled',
      },
      1280,
      height,
    );

    test(
      'Web action $dark keeps source typography and compact viewport density',
      () {
        final normal = RaftWebMenuActionRecipe.resolve(
          tokens: tokens,
          states: states(),
        ).root;
        final compact = RaftWebMenuActionRecipe.resolve(
          tokens: tokens,
          states: states(height: 600),
        ).root;
        expect(normal.minHeight, 36);
        expect(normal.fontSize, 14);
        expect(normal.fontWeight, FontWeight.w500);
        expect(
          normal.padding,
          const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        );
        expect(compact.minHeight, 32);
        expect(
          compact.padding,
          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        );
      },
    );

    test(
      'Web action $dark highlights keyboard focus and never disabled hover',
      () {
        final hover = RaftWebMenuActionRecipe.resolve(
          tokens: tokens,
          states: states(hover: true),
        ).root;
        final focus = RaftWebMenuActionRecipe.resolve(
          tokens: tokens,
          states: states(focus: true),
        ).root;
        final disabled = RaftWebMenuActionRecipe.resolve(
          tokens: tokens,
          states: states(hover: true, disabled: true),
        ).root;
        expect(
          hover.backgroundColor!.resolve(tokens),
          tokens.color('brandSoft'),
        );
        expect(
          focus.backgroundColor!.resolve(tokens),
          tokens.color('brandSoft'),
        );
        expect(disabled.backgroundColor, isNull);
        expect(
          disabled.color!.resolve(tokens),
          tokens.color('foregroundDisabled'),
        );
      },
    );

    test(
      'Web selection $dark retains its distinct gap, leading slot and check',
      () {
        final normal = RaftWebSelectionRowRecipe.resolve(
          tokens: tokens,
          states: states(),
        );
        final checked = RaftWebSelectionRowRecipe.resolve(
          tokens: tokens,
          checked: true,
          states: states(),
        );
        final sentinel = RaftWebSelectionRowRecipe.resolve(
          tokens: tokens,
          italic: true,
          states: states(),
        );
        expect(normal.root.height, 36);
        expect(normal.root.columnGap, 8);
        expect(normal.root.fontSize, 14);
        expect(normal.root.fontWeight, FontWeight.w500);
        expect(checked.root.fontWeight, FontWeight.w700);
        expect(normal.leading.width, 20);
        expect(normal.indicator.width, 16);
        expect(
          sentinel.label.color!.resolve(tokens),
          tokens.color('foregroundMuted'),
        );
        expect(
          sentinel.label.properties['font-style'],
          isNull,
          reason: 'The source explicitly describes sentinel labels as muted, without italic type.',
        );
      },
    );

    test('span badge $dark does not match button-only enabled hover', () {
      final span = RaftBadgeRecipe.resolve(
        appearance: RaftBadgeRecipeAppearance.soft,
        tokens: tokens,
        states: RaftRecipeStates({...flags, 'hover'}),
      ).root;
      final button = RaftBadgeRecipe.resolve(
        appearance: RaftBadgeRecipeAppearance.soft,
        tokens: tokens,
        states: RaftRecipeStates({...flags, 'hover', 'enabled'}),
      ).root;
      expect(span['background-image'], isNull);
      expect(button['background-image'], isNotNull);
    });

    test(
      'Web selection panel $dark reads source surface and search geometry',
      () {
        final panel = RaftWebSelectionPanelRecipe.resolve(
          tokens: tokens,
          states: states(),
        );
        expect(
          panel.root.backgroundColor!.resolve(tokens),
          tokens.color('layerPopover'),
        );
        expect(panel.header.padding, const EdgeInsets.fromLTRB(16, 10, 16, 4));
        expect(panel.search.height, 40);
        expect(panel.searchIcon.width, 16);
        expect(panel.list.maxHeight, 256);
        expect(panel.list.padding, const EdgeInsets.all(6));
      },
    );
  }
}
