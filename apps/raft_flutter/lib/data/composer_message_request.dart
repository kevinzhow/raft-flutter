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
    // Web sends the sender's zone on every composer send, thread replies included.
    final timezone = await readDeviceTimezone();
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
