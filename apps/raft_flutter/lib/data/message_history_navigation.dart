import 'message_history.dart';
import 'message_history_pages.dart';
import 'message_history_positions.dart';
import 'message_history_summaries.dart';
import 'message_window_snapshot.dart';
import 'workspace_message_host.dart';
import 'workspace_message_windows.dart';
import 'thread_visit.dart';
import 'user_error.dart';

/// Paging commands share the receiver's existing request and boundary owners.
class MessageHistoryNavigation {
  static Future<bool> page(
    WorkspaceMessageHost host, {
    required bool thread,
    required bool newer,
    BigInt? gapBefore,
    bool silent = false,
    required MessageWindowRequest Function(String) requestFor,
    required void Function(String, dynamic) summaries,
  }) async {
    final w = host.messageDomain;
    final current = thread ? w.replies : w.messages;
    final id = thread ? w.state.threadChannelId : w.presentation.channel?.id;
    final more = newer
        ? (thread ? w.messageWindows.contextHasNewer(id) : w.state.hasNewer)
        : (thread ? w.state.threadHasMore : w.state.hasMore);
    if (id == null ||
        w.state.loadingOlder ||
        gapBefore == null && !more ||
        current.isEmpty) {
      return false;
    }
    if (!silent &&
        gapBefore != null &&
        !current.any((row) => row.seq == gapBefore)) {
      return false;
    }
    final request = requestFor(id);
    w.state.loadingOlder = true;
    w.context.changed();
    try {
      final page = await MessageHistoryPages.read(
        w,
        request,
        id,
        thread: thread,
        before: gapBefore ?? (newer ? null : current.first.seq),
        after: newer ? current.last.seq : null,
        gap: gapBefore != null,
      );
      if (!request.current) return false;
      final rows = acceptedWindowRows(page['messages'], id);
      w.messageWindows.acceptRows(request, id, rows);
      if (!await MessageHistoryPages.record(w, request, page)) return false;
      if (!request.current) return false;
      final limited = page['historyLimited'] == true;
      final hasMore =
          !limited &&
          (page['hasMore'] is bool
              ? page['hasMore'] as bool
              : rows.length >= 50);
      if (newer) {
        w.messageWindows.setContextMode(request, id, hasMore ? true : null);
        if (!thread) w.state.hasNewer = hasMore;
      } else if (gapBefore != null) {
        // An interior gap has no authority over the oldest window boundary.
      } else if (thread) {
        w.state.threadHistoryLimited = limited;
        w.state.threadHasMore = hasMore;
      } else {
        w.state.historyLimited = limited;
        w.state.hasMore = hasMore;
      }
      if (!thread) {
        final carried = page['threadSummariesByParentMessageId'];
        summaries(
          id,
          page is MessageHistoryPage && page.local
              ? MessageHistorySummaries.unheld(w, id, carried)
              : carried,
        );
      }
      MessageHistoryPages.storage(w.device.cache)?.memory
          .direction(w.context.receiverKey, id, older: !newer);
      await w.saveHistoryWindow(id, thread: thread);
      return true;
    } catch (cause) {
      if (request.current && !silent) {
        w.presentation.assignError(
          userErrorText(
            cause,
            where: newer ? 'load newer messages' : 'load older messages',
          ),
        );
      }
      return false;
    } finally {
      if (request.current) {
        w.state.loadingOlder = false;
        w.context.changed();
      }
    }
  }

  static Future<void> latest(
    WorkspaceMessageHost host, {
    required bool thread,
    required bool navigate,
  }) async {
    final w = host.messageDomain;
    final selectedId = thread
        ? w.state.threadChannelId
        : w.presentation.channel?.id;
    if (selectedId == null) return;
    final identity = w.threadIdentity;
    final positionScope = MessageHistoryPages.scope(
      w,
      selectedId,
      parent: thread ? w.threadParentChannelId : selectedId,
      parentMessage: thread ? w.threadParentMessageId : null,
    );
    if (thread) {
      w.messageWindows.threadGeneration++;
      // The thread stays open: its identity must outlive the new epoch also
      // when the window needs no reload below.
      if (identity != null) ThreadVisit.renew(w.windowReceiver);
    } else {
      w.messageWindows.channelGeneration++;
    }
    final revision = w.presentation.navigationRevision,
        seal = w.messageHistoryTicket('');
    final request = w.messageWindows.request(
      thread: thread,
      allowed: () =>
          w.device.writable &&
          revision == w.presentation.navigationRevision &&
          seal == w.messageHistoryTicket('') &&
          selectedId ==
              (thread ? w.state.threadChannelId : w.presentation.channel?.id),
    );
    MessageHistoryPages.storage(w.device.cache)?.memory
        .direction(w.context.receiverKey, selectedId, older: false);
    try {
      await MessageHistoryPositions.clear(
        w,
        selectedId,
        thread: thread,
        current: () => request.current,
        boundScope: positionScope,
      );
    } catch (cause) {
      if (request.current) {
        w.presentation.assignError(
          userErrorText(cause, where: 'load latest messages'),
        );
        w.context.changed();
      }
      return;
    }
    if (!request.current) return;
    w.entries.clearHighlightedMessage(w.state.highlightedMessageId);
    if (thread) {
      final id = w.state.threadChannelId;
      if (identity != null &&
          id != null &&
          w.messageWindows.contextHasNewer(id)) {
        await w.entries.openThreadIdentity(
          parentChannelId: identity.parentChannelId,
          parentMessageId: identity.parentMessageId,
          initialThreadChannelId: id,
          navigate: navigate,
        );
      }
    } else if (w.presentation.channel case final selected?) {
      if (w.state.hasNewer) {
        await w.entries.selectChannel(
          selected,
          navigate: navigate,
          retainContextUntilAccepted: true,
        );
      }
    }
  }
}
