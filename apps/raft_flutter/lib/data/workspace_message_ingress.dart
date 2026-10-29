import 'dart:async';

import 'package:raft_client/raft_client.dart';
import 'package:raft_sync/raft_sync.dart';

import 'workspace_message_windows.dart';
import 'workspace_session_context.dart';

/// Live presentation facts and existing side effects for message ingress.
/// Every getter remains live; no snapshot replaces an original admission check.
abstract interface class WorkspaceMessageIngressPort {
  RaftChannel? get channel;
  String? get threadChannelId;
  bool get hasNewer;
  void confirmMessageSend(Map<String, dynamic> row);
  void storeMessage(Map<String, dynamic> row, {bool updateOnly = false});
  void overlayMessageReactions(Map<String, dynamic> row);
  void receiveMessageUnread(Map<String, dynamic> row);
  Future<void> revalidateMessageTail(String id);
  Future<void> saveMessageWindow(
    String id, {
    bool thread = false,
    bool coalesce = false,
  });
}

/// The original message:new/message:updated block. False means the surrounding
/// event router must return before publishing its final notification.
bool consumeWorkspaceMessageEvent(
  RaftEvent event, {
  required WorkspaceSessionContext context,
  required WorkspaceMessageIngressPort presentation,
  required MessageLedger ledger,
  required WorkspaceMessageWindows windows,
}) {
  if ((event.name == 'message:new' || event.name == 'message:updated') &&
      event.payload is Map) {
    final row = Map<String, dynamic>.from(event.payload);
    final channelId = row['channelId'];
    if (channelId is String && context.isChannelRevoked(channelId)) {
      return false;
    }
    presentation.confirmMessageSend(row);
    final duplicate =
        row['channelId'] is String &&
        row['id'] is String &&
        ledger.contains(row['channelId'], row['id']);
    if (event.name == 'message:updated') {
      presentation.storeMessage(row, updateOnly: true);
      if (!ledger.ingestUpdate(row, expectedGeneration: ledger.generation)) {
        return false;
      }
      presentation.overlayMessageReactions(row);
    } else {
      // Server-wide sequences are sparse within a channel, and a later frame
      // may arrive before an earlier one. The ledger owns identity de-duplication.
      presentation.storeMessage(row);
      ledger.ingest([row], expectedGeneration: ledger.generation);
    }
    final id = row['channelId'];
    if (id == presentation.channel?.id && !presentation.hasNewer ||
        id == presentation.threadChannelId && !windows.contextHasNewer(id)) {
      if (event.name == 'message:new' && id == presentation.channel?.id) {
        if (windows.fillWindowGap(id, row['id'])) {
          unawaited(presentation.revalidateMessageTail(id));
        }
      }
      windows.reveal(liveWindowWrite, id, [row['id']]);
      presentation.saveMessageWindow(
        id,
        thread: id == presentation.threadChannelId,
        coalesce: event.name == 'message:updated',
      );
    } else if (event.name == 'message:new' &&
        id is String &&
        row['id'] is String &&
        windows.retainsLiveTail(id)) {
      windows.reveal(liveWindowWrite, id, [row['id']]);
    }
    // Source messageStore: counts move per event; only a first delivery
    // counts, and an edit never does.
    if (event.name == 'message:new' && !duplicate) {
      presentation.receiveMessageUnread(row);
    }
  }
  return true;
}
