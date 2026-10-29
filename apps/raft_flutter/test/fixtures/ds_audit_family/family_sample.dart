// Fixture for tool/tests/test_ds_audit.py: pins what the family scan counts.
// Expected counts live in the Python test; update both together. Mentions in
// comments or strings never count: OldButton( showOldModal(
// A doc reference does not count either: [OldButton].
import 'package:flutter/widgets.dart';

import 'lookalike.dart' as other;
import 'new_widgets.dart';
import 'old_widgets.dart' show OldBanner, OldButton, showOldModal;

const String mention = 'OldButton( OldBanner( showOldModal(';

// duplicate.button x2: a field type and the parameter type.
OldButton? lastButton;

class Holder {
  const Holder(this.button);
  final OldButton button;
}

// duplicate.button x1: extends counts once.
class Sub extends OldButton {
  const Sub({super.key});
}

Future<void> familySample(BuildContext context) async {
  // duplicate.button x4: const call, named constructor, static member, is-check
  const OldButton();
  const OldButton.icon();
  OldButton.kind;
  if (lastButton is OldButton) {}
  // duplicate.banner x1
  const OldBanner();
  // duplicate.dialog x2: a call and a tear-off
  await showOldModal(context);
  final reopen = showOldModal;
  // Negatives: canonical components and a same-named class elsewhere.
  const NewButton();
  const other.OldButton();
  reopen;
}
