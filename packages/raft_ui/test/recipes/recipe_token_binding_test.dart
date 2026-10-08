import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/recipes.dart';

// Every foundation token referenced by the generated recipes must resolve
// against the generated token set in all three themes.
const _colors = [
  'accent200',
  'accent400',
  'accent500',
  'accent700',
  'accent950',
  'accentHover',
  'accentSoft',
  'accentStrong',
  'colorBrutalLime100',
  'colorBrutalOrange100',
  'colorBrutalYellow100',
  'danger',
  'dangerForeground',
  'dangerHover',
  'dangerMuted',
  'dangerSoft',
  'dangerStrong',
  'fillMuted',
  'fillStrong',
  'foreground',
  'foregroundActive',
  'foregroundDisabled',
  'foregroundHint',
  'foregroundHover',
  'foregroundIcon',
  'foregroundInverse',
  'foregroundMuted',
  'foregroundPlaceholder',
  'foregroundStrong',
  'inactive',
  'inactiveForeground',
  'info',
  'infoHover',
  'infoMuted',
  'infoSoft',
  'infoStrong',
  'ink',
  'ink10',
  'ink16',
  'ink2',
  'ink20',
  'ink30',
  'ink4',
  'ink40',
  'ink6',
  'ink8',
  'layerBackdrop',
  'layerCanvasMuted',
  'layerCard',
  'layerHud',
  'layerHudForeground',
  'layerInset',
  'layerPanel',
  'layerPopover',
  'line',
  'lineField',
  'lineFieldHover',
  'lineHairline',
  'lineMuted',
  'lineStrong',
  'primary100',
  'primary200',
  'primary400',
  'primary50',
  'primary500',
  'primary600',
  'primary700',
  'primary800',
  'primary900',
  'primary950',
  'primaryActive',
  'primaryEdge',
  'primaryGlow',
  'primaryHover',
  'primarySoft',
  'primaryStrong',
  'secondary100',
  'secondary200',
  'secondary300',
  'secondary400',
  'secondary500',
  'secondary800',
  'secondary900',
  'secondary950',
  'success',
  'successForeground',
  'successMuted',
  'successSoft',
  'successStrong',
  'warning',
  'warningForeground',
  'warningHover',
  'warningMuted',
  'warningSoft',
  'warningStrong',
];
const _shadows = [
  'themeShadowLg',
  'themeShadowMd',
  'themeShadowSm',
  'themeShadowXl',
  'themeShadowXs',
];
const _numbers = [
  'cardTitleFontSize',
  'cardTitleFontWeight',
  'cardTitleLineHeight',
  'fieldFontSize',
  'fieldFontWeight',
  'fieldLineHeight',
];
const _fonts = ['headingFont', 'monoFont', 'sansFont'];

void main() {
  final themes = {
    'brutal': RaftTokens.theme(RaftFamily.brutal),
    'elegant-light': RaftTokens.theme(RaftFamily.elegant),
    'elegant-dark': RaftTokens.theme(RaftFamily.elegant, dark: true),
  };
  for (final MapEntry(key: id, value: tokens) in themes.entries) {
    test('recipe tokens resolve in $id', () {
      final r = RaftRecipeTokens(tokens);
      for (final n in _colors) {
        expect(() => r.color(n), returnsNormally, reason: n);
      }
      for (final n in _shadows) {
        expect(r.shadow(n), isNotEmpty, reason: n);
      }
      for (final n in _numbers) {
        expect(r.number(n), isNotNull, reason: n);
      }
      for (final n in _fonts) {
        expect(r.fontFamily(n), isNotNull, reason: n);
      }
    });
  }

  test('brutal md primary button resolves to source values', () {
    final tokens = RaftRecipeTokens(RaftTokens.theme(RaftFamily.brutal));
    final s = RaftButtonRecipe.resolve(
      theme: RaftRecipeTheme.brutal,
      variant: RaftButtonRecipeVariant.primary,
      size: RaftButtonRecipeSize.md,
      states: const RaftRecipeStates({}),
      tokens: tokens,
    );
    expect(s.root.height, 32);
  });
}
