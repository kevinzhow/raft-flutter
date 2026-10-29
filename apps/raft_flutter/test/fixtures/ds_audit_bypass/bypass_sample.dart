// Fixture for tool/tests/test_ds_audit.py: pins what the bypass scan counts.
// Not a test itself (no _test suffix). Expected counts live in the Python test;
// update both together. Mentions in comments or strings never count:
// AlertDialog( showDialog( TextField( PopupMenuButton(
import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import 'lookalikes.dart' as fake;

const String mention = 'AlertDialog( showModalBottomSheet( OverlayEntry(';

Future<void> bypassSample(BuildContext context, VoidCallback onTap) async {
  Widget build(BuildContext _) => const SizedBox();
  // bypass.dialog x4: AlertDialog, SimpleDialog, Dialog.fullscreen, showDialog
  const AlertDialog(title: Text('raw'));
  const SimpleDialog();
  const Dialog.fullscreen(child: SizedBox());
  await showDialog<void>(context: context, builder: (_) => const SizedBox());
  // bypass.dialog tear-off x1 (a reference without a call)
  final host = showDialog;
  // bypass.bottom_sheet x1
  await showModalBottomSheet<void>(
    context: context,
    builder: (_) => const SizedBox(),
  );
  // bypass.menu x2: PopupMenuButton and its item
  PopupMenuButton<int>(
    itemBuilder: (_) => [const PopupMenuItem<int>(value: 1, child: Text('a'))],
  );
  // bypass.button x2 + bypass.icon_button x2 (the styleFrom calls count)
  TextButton(onPressed: onTap, child: const Text('go'));
  OutlinedButton.icon(
    onPressed: onTap,
    icon: const Icon(Icons.add),
    label: const Text('x'),
  );
  IconButton(onPressed: onTap, icon: const Icon(Icons.close));
  IconButton.styleFrom();
  // bypass.tooltip x1 (plus the extends below), bypass.toggle x2, bypass.chip x1, bypass.list_tile x1
  const Tooltip(message: 'raw', child: SizedBox());
  Checkbox(value: true, onChanged: (_) {});
  Switch(value: true, onChanged: (_) {});
  const Chip(label: Text('chip'));
  const ListTile(title: Text('row'));
  // bypass.progress x2, bypass.refresh x1, bypass.divider x1
  const CircularProgressIndicator();
  const LinearProgressIndicator();
  RefreshIndicator(onRefresh: () async {}, child: const SizedBox());
  const Divider();
  // bypass.select x2, bypass.text_field x2, bypass.picker x1
  DropdownButton<int>(
    items: const [DropdownMenuItem<int>(value: 1, child: Text('a'))],
    onChanged: (_) {},
  );
  const TextField();
  EditableText(
    controller: TextEditingController(),
    focusNode: FocusNode(),
    style: const TextStyle(),
    cursorColor: const Color(0xFF000000),
    backgroundCursorColor: const Color(0xFF000000),
  );
  await showDatePicker(
    context: context,
    firstDate: DateTime(2020),
    lastDate: DateTime(2030),
  );
  // bypass.overlay x2
  OverlayEntry(builder: (_) => const SizedBox());
  OverlayPortal(
    controller: OverlayPortalController(),
    overlayChildBuilder: (_) => const SizedBox(),
  );
  // bypass.dialog x1 allowed by an inline ds-allow, x1 by a ds-allow above
  await showDialog<void>(context: context, builder: build); // ds-allow: inline
  // ds-allow: fixture exercises the allowlist on the line above
  await showDialog<void>(context: context, builder: build);
  // Negatives: Raft components and same-named non-Material classes never count.
  RaftButton(label: 'ok', onPressed: onTap);
  const RaftTooltip(message: 'tip', child: SizedBox());
  const fake.AlertDialog(title: SizedBox());
  const fake.Tooltip(message: 'x');
  const fake.TextField();
  await fake.showDialog(context);
  host;
}

// bypass.tooltip x1: a class extending the raw Tooltip counts once.
class WrappedTooltip extends Tooltip {
  const WrappedTooltip({super.key, super.message});
}
