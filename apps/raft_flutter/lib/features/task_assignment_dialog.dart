import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

/// Display-only task assignee choices. The host owns membership loading,
/// permission checks, route authority and the eventual typed mutation.
Widget taskAssignmentDialog({
  required BuildContext context,
  required List<Map<String, dynamic>> choices,
  required ValueChanged<Map<String, dynamic>> onSelected,
  required VoidCallback onClose,
  Object? claimedById,
  Object? claimedByType,
}) {
  if (RaftTokens.of(context).isRaftLook) {
    return RaftChoiceDialog<Map<String, dynamic>>(
      title: raftText(context, 'Assign task'),
      options: [
        RaftChoiceDialogOption(
          key: const Key('assign-task-unassign'),
          value: <String, dynamic>{},
          label: raftText(context, 'Unassign'),
          selected: claimedById == null,
        ),
        for (final person in choices)
          RaftChoiceDialogOption(
            key: ValueKey(
              'assign-task-${person['actorType']}-${person['userId'] ?? person['id']}',
            ),
            value: person,
            label:
                '${person['displayName'] ?? person['name']} · ${person['actorType'] ?? person['type']}',
            selected:
                person['actorType'] == claimedByType &&
                (person['userId'] ?? person['id']) == claimedById,
          ),
      ],
      onSelected: onSelected,
      onClose: onClose,
    );
  }
  return buildFrozenChoiceDialog(
    title: Text(raftText(context, 'Assign task')),
    options: [
      RaftFrozenChoiceDialogOption(
        onPressed: () => onSelected(<String, dynamic>{}),
        child: Text(raftText(context, 'Unassign')),
      ),
      for (final person in choices)
        RaftFrozenChoiceDialogOption(
          onPressed: () => onSelected(person),
          child: Text(
            '${person['displayName'] ?? person['name']} · ${person['actorType'] ?? person['type']}',
          ),
        ),
    ],
  );
}
