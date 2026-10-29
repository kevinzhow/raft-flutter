// Fixture for tool/tests/test_ds_audit.py: a same-named class declared in a
// different file than the registry names; it must never count.
import 'package:flutter/widgets.dart';

class OldButton extends StatelessWidget {
  const OldButton({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
