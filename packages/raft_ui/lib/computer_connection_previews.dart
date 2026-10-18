import 'package:flutter/material.dart';

import 'previews.dart';
import 'raft_ui.dart';

@RaftPreviews('Confirm the connected computer', size: Size(390, 844))
Widget computerConnectionConfirmationPreview() => const _ConnectionPreview();

class _ConnectionPreview extends StatelessWidget {
  const _ConnectionPreview();

  Widget dialog(BuildContext context) => RaftAddComputerDialog(
    commandsFor: (_) => null,
    register: () async {},
    cancel: () async {},
    done: (_) async {},
    connected: const RaftAddComputerConnection(
      hostname: 'My development computer',
      os: 'macOS',
      requiresConfirmation: true,
    ),
  );

  Widget launcher(BuildContext context) => Center(
    child: RaftButton(
      label: 'Add Computer',
      onPressed: () => RaftAddComputerDialog.show(context, dialog),
    ),
  );

  @override
  Widget build(BuildContext context) => Navigator(
    onGenerateInitialRoutes: (_, _) => [
      MaterialPageRoute<void>(builder: launcher),
      DialogRoute<void>(context: context, builder: dialog),
    ],
    onGenerateRoute: (_) => MaterialPageRoute<void>(builder: launcher),
  );
}
