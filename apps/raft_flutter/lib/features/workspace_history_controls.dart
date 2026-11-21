import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/raft_location.dart';
import '../data/raft_navigation_history.dart' show RaftNavigationKind;
import '../data/workspace_controller.dart';
import '../platform/content_coordinator.dart';
import '../platform/content_links.dart';
import '../platform/content_target.dart';
import 'apps_route.dart';

/// Visits an observed entry without appending another history entry. Only the
/// bound workspace owns these entries; late popup actions cannot cross epochs.
Future<void> visitWorkspaceHistory(
  WorkspaceController w,
  int index, {
  required String authority,
  required Uri expectedUri,
}) async {
  final history = w.navigation;
  if (w.navigationAuthority != authority ||
      index < 0 ||
      index >= history.entries.length ||
      history.entries[index].uri != expectedUri) {
    return;
  }
  final previous = w.location;
  while (history.index > index) {
    history.back();
  }
  while (history.index < index) {
    if (!history.forward()) return;
  }
  final next = w.location;
  if (next.thread == null) w.closeThread(navigate: false);
  w.notifyListeners();
  if ({RaftRoute.channel, RaftRoute.dm}.contains(next.route)) {
    if (w.channel?.id != next.entityId ||
        next.messageId != previous.messageId) {
      // A thread permalink's msg belongs to the reply window. Restore the
      // channel's accepted window, then hydrate the independent thread below.
      await w.jumpToMessage(
        next.entityId!,
        next.thread == null ? next.messageId : null,
        navigate: false,
      );
    }
    if (w.navigationAuthority != authority || w.location.uri != next.uri) {
      return;
    }
    final thread = next.thread;
    if (thread != null) {
      await w.openThreadIdentity(
        parentChannelId: thread.channelId,
        parentMessageId: thread.itemId,
        focusedMessageId: next.threadFocusedMessageId,
        navigate: false,
      );
    }
  }
}

/// After selecting the workspace, send explicit message links through content
/// authorization and restore other routes from the accepted workspace URI.
void restoreAcceptedLocation(
  WorkspaceController w,
  Uri uri, {
  NativeContentCoordinator? externalLinks,
}) {
  final target = appsRouteLocation(
    uri,
    guest: w.server?.string('role') == 'guest',
  );
  if (externalLinks != null && target.messageId != null) {
    final frontend = ContentLinks.originFor(w.client.origin);
    final landing = ContentTarget.parse(
      frontend.resolveUri(target.uri),
      origin: frontend,
    );
    if (landing != null) {
      unawaited(
        externalLinks.navigate(landing, replaceEntry: true, externalLink: true),
      );
      return;
    }
  }
  final routeChanged = w.location.uri != target.uri;
  if (routeChanged) {
    w.navigation.navigate(target, kind: RaftNavigationKind.replace);
  }
  restoreAcceptedConversation(w, target, routeChanged: routeChanged);
}

/// A conversation route the app root accepted over the cache-painted workspace
/// (a remembered surface, a cold link). The accepted route wins over a
/// different cached selection: resolve without blocking the cached first frame
/// or rewriting that route. A thread it names is already on screen (the
/// phone's page, the wide panel); a cold start after iOS reclaimed the app has
/// no thread open, so read it, or the page stays "No replies yet".
void restoreAcceptedConversation(
  WorkspaceController w,
  RaftLocation target, {
  required bool routeChanged,
}) {
  if (!{RaftRoute.channel, RaftRoute.dm}.contains(target.route)) return;
  final thread = target.thread;
  if (routeChanged || w.channel?.id != target.entityId) {
    unawaited(
      w.resolveConversationChannel(
        target.entityId!,
        preserveThread: thread != null,
      ),
    );
  }
  if (thread == null || w.threadIdentity?.parentMessageId == thread.itemId) {
    return;
  }
  unawaited(
    w.openThreadIdentity(
      parentChannelId: thread.channelId,
      parentMessageId: thread.itemId,
      focusedMessageId: target.threadFocusedMessageId,
      initialThreadChannelId: target.knownThreadChannelId,
      navigate: false,
    ),
  );
}

String _historyLabel(
  BuildContext context,
  WorkspaceController w,
  RaftLocation entry,
) {
  final channel = w.channels.where((c) => c.id == entry.entityId).firstOrNull;
  final name = channel?.name;
  if ((entry.route == RaftRoute.channel || entry.route == RaftRoute.dm) &&
      name != null) {
    return entry.route == RaftRoute.channel ? '#$name' : name;
  }
  final label = switch (entry.route) {
    RaftRoute.home => 'Home',
    RaftRoute.channel || RaftRoute.dm => 'Chat',
    RaftRoute.agent => 'Agent',
    RaftRoute.human => 'Member',
    RaftRoute.computer => 'Computer',
    RaftRoute.members => 'Members',
    RaftRoute.computers => 'Computers',
    RaftRoute.artifacts => 'Artifacts',
    RaftRoute.apps => 'Apps',
    RaftRoute.search => 'Search',
    RaftRoute.settings => 'Settings',
    RaftRoute.activity => 'Activity',
    RaftRoute.tasks => 'Tasks',
    RaftRoute.saved => 'Saved',
    RaftRoute.drafts => 'Drafts',
    RaftRoute.releaseNotes => 'Release notes',
    RaftRoute.unknown => 'Home',
  };
  return raftText(context, label);
}

/// Desktop history shares the same accepted locations as phone Back and deep
/// links. Narrow desktop rows put Back/Forward in the history menu.
class WorkspaceHistoryControls extends StatelessWidget {
  const WorkspaceHistoryControls({super.key, required this.controller});
  final WorkspaceController controller;

  @override
  Widget build(BuildContext context) {
    final w = controller, history = w.navigation;
    final entries = history.entries;
    final authority = w.navigationAuthority;
    final compact = MediaQuery.sizeOf(context).width < 1000;
    VoidCallback? visit(int index) => index < 0 || index >= entries.length
        ? null
        : () => unawaited(
            visitWorkspaceHistory(
              w,
              index,
              authority: authority,
              expectedUri: entries[index].uri,
            ),
          );
    final back = visit(history.index - 1), forward = visit(history.index + 1);
    // AppTopBar places the history controls in a gap-0.5 group.
    final historyGap = RaftTokens.of(context).desktop ? RaftSpace.half : 0.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: historyGap,
      children: [
        if (!compact) ...[
          RaftIconButton(
            key: const Key('topbar-back'),
            uiVariant: RaftButtonVariant.onFrame,
            glyph: RaftGlyph.arrowLeft,
            tooltip: 'Go back',
            semanticLabel: raftText(context, 'Go back'),
            onPressed: back,
          ),
          RaftIconButton(
            key: const Key('topbar-forward'),
            uiVariant: RaftButtonVariant.onFrame,
            glyph: RaftGlyph.arrowRight,
            tooltip: 'Go forward',
            semanticLabel: raftText(context, 'Go forward'),
            onPressed: forward,
          ),
        ],
        RaftDropdownMenu(
          key: ValueKey('topbar-history-$authority'),
          label: raftText(context, 'History'),
          tooltip: 'History',
          width: 280,
          triggerBuilder: (context, focus, open) => Focus(
            focusNode: focus,
            child: RaftIconButton(
              key: const Key('topbar-history'),
              uiVariant: RaftButtonVariant.onFrame,
              glyph: RaftGlyph.history,
              tooltip: 'History',
              semanticLabel: raftText(context, 'History'),
              onPressed: open,
            ),
          ),
          entries: [
            if (compact) ...[
              RaftMenuEntry(
                label: raftText(context, 'Go back'),
                glyph: RaftGlyph.arrowLeft,
                onPressed: back,
              ),
              RaftMenuEntry(
                label: raftText(context, 'Go forward'),
                glyph: RaftGlyph.arrowRight,
                onPressed: forward,
              ),
              const RaftMenuEntry.separator(),
            ],
            for (
              var i = entries.length - 1;
              i >= (entries.length - 30).clamp(0, entries.length);
              i--
            )
              RaftMenuEntry(
                label: _historyLabel(context, w, entries[i]),
                glyph: i == history.index ? RaftGlyph.check : null,
                onPressed: i == history.index ? null : visit(i),
              ),
          ],
        ),
      ],
    );
  }
}
