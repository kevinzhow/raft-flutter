// The Raft set: checks every generated slot against the independent JS cascade oracle.
// The committed fixture is complete, so a standalone copy needs no repository
// build directory or raft_ui to verify source recipe values.
import 'package:raft_theme/recipes.dart';

import 'support/recipe_parity_support.dart';

// Full theme matrix on purpose (theme/token/recipe test): never sampled, see
// the independent theme engine.
void main() {
  registerRecipeParityTests(
    recipes: raftRecipes,
    fixturePaths: const ['test/recipes/recipe_parity_cases.g.json'],
  );
}
