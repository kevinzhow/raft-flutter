part of 'fit_toolbar.dart';

class RaftFitSplitButton extends RaftFitItem {
  const RaftFitSplitButton({
    required this.label,
    required this.menuLabel,
    required this.glyph,
    required this.onPressed,
    required this.entries,
    this.mainKey,
    this.menuKey,
    super.plusOrder,
  });

  final String label, menuLabel;
  final RaftGlyph glyph;
  final VoidCallback onPressed;
  final List<RaftMenuEntry> entries;
  final Key? mainKey, menuKey;

  @override
  bool get hasPlusForm => true;

  @override
  Widget buildForm(
    BuildContext context,
    RaftFitForm form, {
    required bool probe,
    List<RaftMenuEntry> moreEntries = const [],
  }) {
    final tokens = RaftTokens.of(context);
    final states = tokens.recipeStates(
      responsive: true,
      extra: ['data-sticker-edge'],
    );
    final recipeTokens = tokens.recipeTokens;
    final root = RaftButtonSplitRecipe.resolve(
      states: states,
      tokens: recipeTokens,
    ).base;
    final main = RaftButtonSplitMainRecipe.resolve(
      states: states,
      tokens: recipeTokens,
    ).base;
    final menu = RaftButtonSplitMenuRecipe.resolve(
      variant: RaftButtonSplitMenuRecipeVariant.primary,
      size: RaftButtonSplitMenuRecipeSize.md,
      states: states,
      tokens: recipeTokens,
    ).base;
    final full = form == RaftFitForm.full;
    final fit = _fitStyle(context, extra: ['ancestor:data-fit-plus']).splitMain;
    Widget menuButton(FocusNode? focus, VoidCallback? press) => RaftButton(
      uiVariant: RaftButtonVariant.primary,
      uiSize: RaftButtonSize.md,
      glyph: RaftGlyph.chevronDown,
      semanticLabel: menuLabel,
      tooltip: probe ? null : menuLabel,
      focusNode: focus,
      visualWidth: menu.length('width'),
      onPressed: press,
      styleBuilder: (_, _, style) =>
          style.copyWith(properties: {...style.properties, ...menu.properties}),
    );
    return Semantics(
      container: !probe,
      child: RaftRecipeBox(
        style: root,
        tokens: recipeTokens,
        applyText: false,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            RaftButton(
              key: probe ? null : mainKey,
              label: full ? label : '',
              glyph: full ? glyph : RaftGlyph.plus,
              semanticLabel: full ? null : label,
              tooltip: full || probe ? null : label,
              uiVariant: RaftButtonVariant.primary,
              uiSize: RaftButtonSize.md,
              visualWidth: full ? null : fit.length('width'),
              onPressed: onPressed,
              styleBuilder: (_, _, style) => style.copyWith(
                properties: {
                  ...style.properties,
                  ...main.properties,
                  if (!full)
                    for (final side in ['left', 'right'])
                      if (fit['padding-$side'] case final value?)
                        'padding-$side': value,
                },
              ),
            ),
            if (probe)
              menuButton(null, () {})
            else
              RaftDropdownMenu(
                key: menuKey,
                label: menuLabel,
                align: RaftDropdownAlign.end,
                sideOffset: 4,
                width: 220,
                entries: entries,
                triggerBuilder: (_, focus, press) => menuButton(focus, press),
              ),
          ],
        ),
      ),
    );
  }
}
