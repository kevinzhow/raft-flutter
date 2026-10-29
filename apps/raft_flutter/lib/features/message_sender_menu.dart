import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:raft_client/raft_client.dart' show RaftMessage;
import 'package:raft_ui/raft_ui.dart';

import 'message_presentation.dart' show messageSenderIdentityKind;
import 'message_reference_directory.dart';

/// Web MessageItem `senderCtxMenu`: right-click (or long press) on the
/// sender's name, or right-click on the avatar, offers Copy Name and, when the
/// sender has a handle, Copy Handle.
Future<void> showMessageSenderMenu(
  BuildContext context, {
  required Offset anchor,
  required String name,
  String? handle,
}) => showRaftMessageContextMenu<void>(
  context: context,
  anchor: anchor,
  builder: (menuContext) {
    RaftMessageContextMenuItem item(String key, String label, String text) =>
        RaftMessageContextMenuItem(
          key: ValueKey('sender-menu-$key'),
          label: raftText(menuContext, label),
          icon: raftMessageMenuIcon(RaftGlyph.copy),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: text));
            Navigator.of(menuContext).pop();
          },
        );
    return Semantics(
      label: raftText(menuContext, 'Sender context menu'),
      container: true,
      child: RaftMessageContextMenu(
        onDismiss: () => Navigator.of(menuContext).pop(),
        sections: [
          [
            item('name', 'Copy Name', name),
            if (handle != null && handle.isNotEmpty)
              item('handle', 'Copy Handle', handle),
          ],
        ],
      ),
    );
  },
);

/// Web `senderMention`: the sender's `@handle` when the roster knows one (a
/// deleted or departed sender has none), as `(type, name)` where type is
/// `agent` or `human`.
({String type, String name})? senderHandleOf(
  MessageReferenceDirectory directory,
  RaftMessage message,
) {
  final type = messageSenderIdentityKind(message);
  if (type == null) return null;
  final entry = (type == 'agent' ? directory.agents : directory.members)
      .where((row) => (row['userId'] ?? row['id']) == message.senderId)
      .firstOrNull;
  final name = entry?['name'];
  if (name is! String || name.isEmpty || entry?['deletedAt'] != null) {
    return null;
  }
  return (type: type, name: name);
}

/// [senderHandleOf] as written in a message: `@name`.
String? senderHandleText(
  MessageReferenceDirectory directory,
  RaftMessage message,
) {
  final handle = senderHandleOf(directory, message);
  return handle == null ? null : '@${handle.name}';
}

/// The row's `onAuthorMenu`: Copy Name / Copy Handle at the pointer.
ValueChanged<Offset> senderMenuOf(
  BuildContext context,
  MessageReferenceDirectory directory,
  RaftMessage message,
) =>
    (at) => showMessageSenderMenu(
      context,
      anchor: at,
      name: message.author,
      handle: senderHandleText(directory, message),
    );
