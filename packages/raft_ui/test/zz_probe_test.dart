import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/recipes.dart';
void main() {
  test('p', () {
    for (final th in RaftRecipeTheme.values) {
      final s = RaftInputRecipe.resolve(theme: th);
      for (final e in s.slots.entries) print('$th ${e.key} ${e.value}');
      final f = RaftInputRecipe.resolve(theme: th, states: const RaftRecipeStates({RaftRecipeStates.focusVisible, RaftRecipeStates.focus}));
      print('$th FOCUS ${f.slots.values.first}');
    }
  });
}
