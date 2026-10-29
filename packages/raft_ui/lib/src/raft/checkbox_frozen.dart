// The frozen Elegant and Brutal paint of the checkbox family: the hand-painted indicator and checkbox (token colours,
// exactly as before the Raft look moved onto the generated recipes) and the two call shapes that used Material
// controls: the sign-up terms box and the checkbox list rows. The Raft look never reaches this file. Delete it with the legacy looks; do not add
// to it.
part of 'checkbox.dart';

Widget _frozenIndicator(BuildContext context, RaftCheckboxIndicator indicator) {
  final RaftCheckboxIndicator(
    :checked,
    :disabled,
    :previewOnHover,
    :hovered,
    :shape,
    :mark,
    :size,
    :style,
  ) = indicator;
  final t = RaftTokens.of(context);
  final ui = t.ui;
  final Color fill, border, ink;
  // Translucent tokens are blended the way Blink does, over the box they sit on (the border over its own fill).
  if (checked) {
    final disabledFill = raftChromeBlend(ui.foregroundDisabled, ui.layerCanvas);
    fill = disabled ? disabledFill : ui.foreground;
    border = disabled
        ? raftChromeBlend(ui.foregroundDisabled, disabledFill)
        : ui.foreground;
    ink = disabled ? ui.layerCard : ui['foreground-inverse'];
  } else {
    fill = disabled ? ui.fillMuted : ui.layerCard;
    border = disabled
        ? raftChromeBlend(ui.foregroundDisabled, ui.fillMuted)
        : ui.lineStrong;
    ink = previewOnHover && hovered
        ? ui.foreground.withValues(alpha: ui.foreground.a * .2)
        : const Color(0x00000000);
  }
  final showMark = checked || previewOnHover;
  return ExcludeSemantics(
    child: RaftCssBox(
      // The square form is the theme's sticker corner; the circle form is a true
      // circle at any size, which is why the official `rounded-full` stays
      // `size / 2` rather than becoming a token.
      radius:
          style?.radius ??
          (shape == RaftCheckboxShape.circle
              ? size / 2
              : t.size('radius.sticker', fallback: 4)),
      fill: style?.fill ?? fill,
      borderWidth: style?.borderWidth ?? raftControlBorderPx(context, 1.5),
      borderColor: style?.borderColor ?? border,
      width: size,
      height: size,
      alignment: Alignment.center,
      child: showMark
          ? RaftIcon(
              mark == RaftCheckboxMark.minus
                  ? RaftGlyph.minus
                  : RaftGlyph.check,
              size: style?.markSize ?? size * .7,
              strokeWidth: style?.markStrokeWidth ?? 2,
              color: style?.markColor ?? ink,
            )
          : null,
    ),
  );
}

Widget _frozenCheckbox(BuildContext context, RaftCheckbox box) {
  final RaftCheckbox(
    :value,
    :onChanged,
    :indeterminate,
    :shape,
    :semanticLabel,
    :focusNode,
    :size,
  ) = box;
  final t = RaftTokens.of(context);
  final ui = t.ui;
  final disabled = onChanged == null;
  return RaftInteractive(
    onPressed: disabled ? null : () => onChanged(indeterminate ? true : !value),
    button: false,
    checked: indeterminate ? null : value,
    focusNode: focusNode,
    semanticLabel: semanticLabel,
    builder: (context, st) => Semantics(
      mixed: indeterminate,
      child: RaftCssBox(
        // `rounded-sticker` on the root, also for the circle shape: the official
        // root keeps the sticker corner and the inner indicator draws the circle.
        radius: t.size('radius.sticker', fallback: 4),
        rings: [
          if (st.focusVisible)
            for (final layer in ui.focusRing.layers)
              RaftRing(layer.spread, layer.color),
        ],
        width: size,
        height: size,
        child: ExcludeSemantics(
          child: RaftCheckboxIndicator(
            checked: value || indeterminate,
            mark: indeterminate
                ? RaftCheckboxMark.minus
                : RaftCheckboxMark.check,
            shape: shape,
            disabled: disabled,
            size: size,
          ),
        ),
      ),
    ),
  );
}

Widget _frozenMaterialCheckbox(BuildContext context, RaftCheckbox box) {
  final size = RaftCheckboxRecipe.resolve(
    theme: RaftRecipeTheme.elegant,
    size: RaftCheckboxRecipeSize.md,
    tokens: RaftTokens.of(context).recipeTokens,
  ).root.width!;
  return SizedBox.square(
    dimension: size,
    child: Checkbox(
      key: box.key,
      value: box.value,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      onChanged: box.onChanged == null
          ? null
          : (v) => box.onChanged!(v == true),
    ),
  );
}

Widget _frozenCheckboxRow(BuildContext context, RaftCheckboxRow row) =>
    CheckboxListTile(
      dense: row.dense,
      title: Text(row.title),
      subtitle: row.description == null ? null : Text(row.description!),
      value: row.value,
      onChanged: row.onChanged == null
          ? null
          : (v) => row.onChanged!(v == true),
    );
