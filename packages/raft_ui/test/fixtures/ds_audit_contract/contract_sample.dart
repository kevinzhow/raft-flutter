// Fixture for tool/tests/test_ds_audit.py: pins what tool/ds-audit counts under
// the theme contract (docs/ds-migration.md, "Contract rules"). Not a test itself
// (no _test.dart suffix). Expected counts live in the Python test; update both
// together. Mentions in comments or strings never count:
// Color(0xFF000000) Colors.red BorderRadius.circular(8) fontSize: 14 isElegant
// ignore_for_file: unused_local_variable, unused_element, unnecessary_statements
import 'package:flutter/material.dart';
import 'package:raft_ui/recipes.dart' show RaftRecipeTheme;

const String mention = 'Colors.red Radius.circular(4) RaftRecipeTheme.elegant';

/// Stand-ins for the theme types the rules key on by name. Their own uses
/// count too; the totals in the Python test include them.
enum RaftFamily { brutal, elegant }

class RaftTheme {
  const RaftTheme(this.id, this.family);
  final String id;
  final RaftFamily family;
  bool get isElegant => family == RaftFamily.elegant;
  bool get isBrutal => !isElegant; // not counted: reads another getter
}

const String raftThemePackId = 'raft';

void contractSample(RaftTheme theme, double radius, double border) {
  // contract.color_literal x5 enforced (the malformed allow still counts) and 2
  // allowlisted; Colors.transparent and a non-literal Color(...) do not count
  const a = Color(0xFF112233);
  const b = Color.fromARGB(255, 1, 2, 3);
  final c = Color.fromRGBO(1, 2, 3, 0.5);
  final d = Colors.white;
  const e = Colors.transparent;
  final f = Color(radius.toInt());
  // ds-allow: media chrome keeps its own scrim
  const allowed = Colors.black;
  // ds-allow:
  const malformed = Colors.black12;
  const sameLine = Colors.black26; // ds-allow: brand artwork

  // contract.font_size_literal x2 (a variable and `/ 2` arithmetic do not)
  final s1 = const TextStyle(fontSize: 14);
  final s2 = s1.copyWith(fontSize: 12.5);
  final s3 = s1.copyWith(fontSize: radius);
  final s4 = s1.copyWith(fontSize: radius / 2);

  // contract.radius_literal x3 (`radius - 1`, `radius / 2` and variables do not)
  final r1 = BorderRadius.circular(8);
  final r2 = BorderRadius.all(Radius.circular(4));
  final r3 = Radius.elliptical(radius, 6);
  final r4 = BorderRadius.circular(radius - 1);
  final r5 = BorderRadius.circular(radius / 2);
  final r6 = BorderRadius.all(Radius.circular(radius));
  final r7 = BorderRadius.zero;

  // contract.stroke_width_literal x5 (BorderSide, Border.all, copyWith, `..strokeWidth =`,
  // `strokeWidth:`); variables do not count
  const w1 = BorderSide(width: 2);
  final w2 = Border.all(width: 1.5);
  final w3 = BorderSide(width: border);
  final w4 = w3.copyWith(width: 3);
  final p = Paint()..strokeWidth = 2;
  final q = Paint()..strokeWidth = border;
  final progress = CircularProgressIndicator(strokeWidth: 4);
  final other = CircularProgressIndicator(strokeWidth: border);

  // contract.theme_name_branch (12 in the file with the stand-ins above):
  // RaftFamily type + member, isElegant, `theme.id ==`, `raftThemePackId !=`,
  // a switch on the family and its two case members
  final RaftFamily family = RaftFamily.brutal;
  if (theme.isElegant) {}
  if (theme.id == 'elegant') {}
  if (theme.id.isEmpty) {}
  if (raftThemePackId != 'other') {}
  switch (theme.family) {
    case RaftFamily.brutal:
      break;
    case RaftFamily.elegant:
      break;
  }

  // contract.legacy_recipe_theme x2 enforced + 1 allowlisted (the adapter
  // function below and `.values` do not count)
  const l1 = RaftRecipeTheme.elegant;
  final l2 = radius > 0 ? RaftRecipeTheme.brutal : RaftRecipeTheme.values.first;
  // ds-allow: legacy recipe table not yet regenerated
  const l3 = RaftRecipeTheme.elegant;
  final l4 = RaftRecipeTheme.values;

  a == b;
}

RaftRecipeTheme raftRecipeTheme(double radius) =>
    radius > 0 ? RaftRecipeTheme.elegant : RaftRecipeTheme.brutal;
