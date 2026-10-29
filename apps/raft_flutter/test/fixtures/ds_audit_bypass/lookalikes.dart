// Fixture for tool/tests/test_ds_audit.py: same-named classes and functions
// that are not Material and must never count as bypasses.
import 'package:flutter/widgets.dart';

class AlertDialog extends StatelessWidget {
  const AlertDialog({super.key, this.title});
  final Widget? title;
  @override
  Widget build(BuildContext context) => title ?? const SizedBox.shrink();
}

class Tooltip extends StatelessWidget {
  const Tooltip({super.key, this.message});
  final String? message;
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class TextField extends StatelessWidget {
  const TextField({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

Future<void> showDialog(BuildContext context) async {}
