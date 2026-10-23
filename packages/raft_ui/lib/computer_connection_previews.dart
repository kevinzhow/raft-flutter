import 'package:flutter/material.dart';

import 'previews.dart';
import 'raft_ui.dart';

@RaftPreviews('Confirm the connected computer', size: Size(390, 844))
Widget computerConnectionConfirmationPreview() => const _ConnectionPreview();

@RaftPreviews('Loading connected computer details', size: Size(390, 844))
Widget computerConnectionLoadingPreview() =>
    const _ConnectionPreview(loading: true);

class _ConnectionPreview extends StatelessWidget {
  const _ConnectionPreview({this.loading = false});
  final bool loading;

  Widget dialog(BuildContext context) => RaftAddComputerDialog(
    commandsFor: (_) => null,
    register: () async {},
    cancel: () async {},
    done: (_) async {},
    connected: RaftAddComputerConnection(
      hostname: loading ? '' : 'My development computer',
      os: loading ? null : 'macOS',
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
