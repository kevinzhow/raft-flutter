import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/recipes.dart';
void main() {
  test('p', () {
    for (final th in RaftRecipeTheme.values)
    for (final v in RaftMessageReferenceRecipeVariant.values) {
      final s = RaftMessageReferenceRecipe.resolve(theme: th, variant: v);
      print('$th $v ${s.root}');
      print('   classes ${s.root.classes}');
    }
    for (final th in RaftRecipeTheme.values) {
      final c = RaftTaskChipRecipe.resolveProps({'theme': th.name, 'variant': 'inline', 'status': 'in-progress'});
      for (final e in c.entries) print('$th TASKCHIP ${e.key} ${e.value} ${e.value.classes}');
    }
  });
}
