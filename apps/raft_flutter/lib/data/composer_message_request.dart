import 'package:raft_client/raft_client.dart';

import '../platform/device_timezone.dart';
import 'workspace_sends.dart' show ComposerReceipt, ComposerSendVisit;

/// Native metadata at the dispatch boundary, after optimistic publication.
/// Reuses the editor's existing visit binding; it owns no composer state.
extension ComposerMessageRequest on RaftClient {
  Future<ComposerReceipt> sendForVisit(
    ComposerSendVisit visit,
    String channelId,
    String content, {
    List<String>? attachments,
    List<Map<String, dynamic>>? mentions,
    String? randomId,
    bool asTask = false,
  }) async {
    final generation = this.generation;
    // WorkspaceEditor.draftScope uses this namespace only for thread replies.
    // Plain channel/DM sends (including a newly resolved DM) use channel IDs.
    final timezone = visit.scope.startsWith('thread:')
        ? null
        : await readDeviceTimezone();
    if (generation != this.generation || !visit.current()) {
      throw const RaftApiException(
        'The send destination is no longer current.',
      );
    }
    return sendWithReceipt(
      channelId,
      content,
      attachments: attachments,
      mentions: mentions,
      randomId: randomId,
      asTask: asTask,
      timezone: timezone,
    );
  }
}
