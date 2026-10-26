// The frozen Elegant and Brutal paint of the two checkbox call shapes that used Material controls: the sign-up terms
// box and the checkbox list rows. The Raft look never reaches this file. Delete it with the legacy looks; do not add
// to it.
part of 'checkbox.dart';

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
