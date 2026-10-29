import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_theme/recipes.dart';

// Spot values of the Raft recipe set (raft-ui 0.7.0, no `theme` axis). The
// frozen 0.5.52 values of the Elegant and Brutal looks are pinned in
// legacy_recipe_spot_test.dart and must not change.
void main() {
  group('Button recipe', () {
    RaftSlotStyle button({
      RaftButtonRecipeVariant? variant,
      RaftButtonRecipeSize? size,
      Set<String> states = const {},
    }) => RaftButtonRecipe.resolve(
      variant: variant,
      size: size,
      states: RaftRecipeStates(states),
    ).root;

    test('md metrics', () {
      final root = button(size: RaftButtonRecipeSize.md);
      expect(root.height, 32);
      expect(root.padding.horizontal, 24);
      expect(root.fontSize, 13);
      expect(root.fontWeight, FontWeight.w700);
      expect(root.borderRadius, BorderRadius.circular(8));
      expect(root.borderWidth, const EdgeInsets.all(1.5));
    });

    test('the default size is md', () {
      expect(button().height, 32);
    });

    test(
      'primary is a sticker: attention fill inside a sticker-ink border',
      () {
        final root = button(variant: RaftButtonRecipeVariant.primary);
        expect(root.backgroundColor?.tokenName, 'attention400');
        expect(root.borderColor?.tokenName, 'stickerInk');
      },
    );

    test('outline sits on the card layer with a strong line', () {
      final root = button(variant: RaftButtonRecipeVariant.outline);
      expect(root.backgroundColor?.tokenName, 'layerCard');
      expect(root.borderColor?.tokenName, 'lineStrong');
    });

    test('disabled swaps to the muted fill instead of fading', () {
      final root = button(
        variant: RaftButtonRecipeVariant.primary,
        states: {RaftRecipeStates.disabled},
      );
      expect(root.backgroundColor?.tokenName, 'fillMuted');
      expect(root.opacity, 1);
    });
  });

  test('Input: 8px radius, 1.5px strong line on the card layer', () {
    final root = RaftInputRecipe.resolve().root;
    expect(root.borderRadius, BorderRadius.circular(8));
    expect(root.borderWidth, const EdgeInsets.all(1.5));
    expect(root.borderColor?.tokenName, 'lineStrong');
    expect(root.backgroundColor?.tokenName, 'layerCard');
  });

  test('Card: 10px radius, hairline border, no shadow', () {
    final root = RaftCardRecipe.resolve().root;
    expect(root.borderRadius, BorderRadius.circular(10));
    expect(root.borderWidth, const EdgeInsets.all(1));
    expect(root.borderColor?.tokenName, 'lineHairline');
    expect(root.boxShadow, isEmpty);
  });

  test('Badge: 4px sticker, bold 12px', () {
    final root = RaftBadgeRecipe.resolve().root;
    expect(root.borderRadius, BorderRadius.circular(4));
    expect(root.fontSize, 12);
    expect(root.fontWeight, FontWeight.w700);
  });

  test('Switch: 50x30 track', () {
    final root = RaftSwitchRecipe.resolve().root;
    expect(root.width, 50);
    expect(root.height, 30);
  });

  test('every recipe resolves its default combination', () {
    for (final MapEntry(key: name, value: resolve) in raftRecipes.entries) {
      expect(resolve(const {}), isNotEmpty, reason: name);
    }
  });
}
