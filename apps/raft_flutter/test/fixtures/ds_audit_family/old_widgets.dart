// Fixture for tool/tests/test_ds_audit.py: stands in for the file that
// declares the deprecated duplicates. References in this file never count.
import 'package:flutter/widgets.dart';

class OldButton extends StatelessWidget {
  const OldButton({super.key});
  const OldButton.icon({super.key});
  static const String kind = 'old';
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class OldBanner extends StatelessWidget {
  const OldBanner({super.key});
  @override
  Widget build(BuildContext context) => const OldButton();
}

Future<void> showOldModal(BuildContext context) async {}

Future<void> reopen(BuildContext context) => showOldModal(context);
