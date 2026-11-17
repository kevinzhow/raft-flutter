import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

/// Presentation for the existing non-anchored workspace chooser.
/// The host owns membership, browser availability, route results and authority.
Widget workspaceSwitcherDialog({
  required BuildContext context,
  required Iterable<RaftRecord> servers,
  required String? selectedServerId,
  required String Function(String) translate,
  required Widget Function(RaftRecord) browserAction,
  required ValueChanged<String> onSelected,
  required VoidCallback onClose,
  ValueChanged<RaftRecord>? onOpenInBrowser,
}) {
  return RaftChoiceDialog<String>(
    title: translate('Switch Server'),
    options: [
      for (final server in servers)
        RaftChoiceDialogOption(
          key: ValueKey('switch-server-choice-${server.id}'),
          value: server.id,
          label: server.name,
          selected: server.id == selectedServerId,
          onAuxiliary: onOpenInBrowser == null
              ? null
              : () => onOpenInBrowser(server),
          trailing: onOpenInBrowser == null ? null : browserAction(server),
        ),
      RaftChoiceDialogOption(
        value: 'create',
        label: translate('Create server'),
      ),
      RaftChoiceDialogOption(value: 'join', label: translate('Join server')),
    ],
    onSelected: onSelected,
    onClose: onClose,
  );
}
