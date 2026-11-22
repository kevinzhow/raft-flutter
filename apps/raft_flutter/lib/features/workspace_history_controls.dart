import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/raft_location.dart';
import '../data/raft_navigation_history.dart';
import '../data/workspace_controller.dart';
import '../platform/content_coordinator.dart';
import '../platform/content_links.dart';
import '../platform/content_target.dart';
import 'apps_route.dart';
import 'quick_switcher.dart';
import 'quick_switcher_host.dart';
import 'resource_search.dart';
import 'sender_avatar_projection.dart';

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
  if (!history.visit(index)) return;
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

VoidCallback? _historyStep(
  WorkspaceController workspace, {
  required bool forward,
}) {
  final history = workspace.navigation;
  final entries = history.entries;
  final index = nextRaftHistoryPlace(
    [for (final entry in entries) entry.uri],
    history.index,
    forward: forward,
  );
  if (index == null) return null;
  final expectedUri = entries[index].uri;
  final authority = workspace.navigationAuthority;
  return () => unawaited(
    visitWorkspaceHistory(
      workspace,
      index,
      authority: authority,
      expectedUri: expectedUri,
    ),
  );
}

bool handleWorkspaceHistoryShortcut(
  WorkspaceController workspace,
  LogicalKeyboardKey key,
  HardwareKeyboard keyboard,
  TargetPlatform platform,
) {
  if (keyboard.isControlPressed || keyboard.isShiftPressed) return false;
  final mac = platform == TargetPlatform.macOS;
  if (keyboard.isMetaPressed != mac || keyboard.isAltPressed == mac) {
    return false;
  }
  final back = mac
      ? LogicalKeyboardKey.bracketLeft
      : LogicalKeyboardKey.arrowLeft;
  final forward = mac
      ? LogicalKeyboardKey.bracketRight
      : LogicalKeyboardKey.arrowRight;
  if (key != back && key != forward) return false;
  _historyStep(workspace, forward: key == forward)?.call();
  return true;
}

Widget _recentIdentity(SearchEntity entity, QuickSwitcherData data) {
  if (entity.kind == 'channel') {
    return RaftIcon(switch (entity.row['type']) {
      'private' => RaftGlyph.lock,
      _ => RaftGlyph.hash,
    }, size: 16);
  }
  final agent = entity.kind == 'agent';
  final kind = agent ? RaftAvatarKind.agent : RaftAvatarKind.human;
  final avatar = projectSenderAvatar(
    origin: data.origin,
    senderId: entity.id,
    senderType: agent ? 'agent' : 'user',
    agents: data.agents,
    members: data.members,
    currentUser: data.currentUser,
  );
  return RaftAvatar(
    name: entity.title,
    kind: kind,
    size: 20,
    content: RaftAvatarContent(
      name: entity.title,
      kind: agent ? RaftAvatarContentKind.agent : RaftAvatarContentKind.human,
      uploadedUrl: avatar.uploadedUrl,
      pixelKey: agent ? avatar.pixelKey ?? 'robot' : null,
    ),
  );
}

List<RaftMenuEntry> _recentEntries(
  BuildContext context,
  WorkspaceController workspace,
  QuickSwitcherHost host,
) {
  final data = host.data(includeComputers: false);
  final recent = data.catalog.recent(
    visited: data.visited,
    excludeChannelId: data.excludeChannelId,
    fillFromActivity: false,
  );
  if (recent.isEmpty) {
    return [
      RaftMenuEntry(label: raftText(context, 'No recent conversations yet')),
    ];
  }
  return [
    for (final entity in recent)
      RaftMenuEntry(
        label: entity.title,
        leading: SizedBox.square(
          dimension: 20,
          child: Center(child: _recentIdentity(entity, data)),
        ),
        onPressed: () {
          final channel = [...workspace.channels, ...workspace.dms]
              .where(
                (channel) =>
                    channel.id == data.catalog.conversationIdOf(entity),
              )
              .firstOrNull;
          if (channel != null)
            unawaited(host.actions.openConversation(channel));
        },
      ),
  ];
}

/// Desktop history shares the same accepted locations as phone Back and deep
/// links. Narrow desktop rows put Back/Forward in the history menu.
class WorkspaceHistoryControls extends StatelessWidget {
  const WorkspaceHistoryControls({
    super.key,
    required this.controller,
    required this.quickSwitcher,
  });
  final WorkspaceController controller;
  final QuickSwitcherHost quickSwitcher;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: quickSwitcher.recents,
    builder: _buildControls,
  );

  Widget _buildControls(BuildContext context, Widget? child) {
    final w = controller;
    final authority = w.navigationAuthority;
    final compact = MediaQuery.sizeOf(context).width < 1000;
    final back = _historyStep(w, forward: false);
    final forward = _historyStep(w, forward: true);
    final mac = defaultTargetPlatform == TargetPlatform.macOS;
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
            tooltip: '${raftText(context, 'Go back')} ${mac ? '⌘[' : 'Alt+←'}',
            semanticLabel: raftText(context, 'Go back'),
            onPressed: back,
          ),
          RaftIconButton(
            key: const Key('topbar-forward'),
            uiVariant: RaftButtonVariant.onFrame,
            glyph: RaftGlyph.arrowRight,
            tooltip:
                '${raftText(context, 'Go forward')} ${mac ? '⌘]' : 'Alt+→'}',
            semanticLabel: raftText(context, 'Go forward'),
            onPressed: forward,
          ),
        ],
        RaftDropdownMenu(
          key: ValueKey('topbar-history-$authority'),
          label: raftText(context, 'History'),
          tooltip: 'History',
          width: 240,
          sideOffset: 4,
          surfaceKey: const Key('topbar-history-menu'),
          header: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              raftText(context, 'Recent conversations'),
              style: RaftTypography.body(
                RaftTokens.of(context),
                size: 12,
                line: 16,
              ),
            ),
          ),
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
            ..._recentEntries(context, w, quickSwitcher),
          ],
        ),
      ],
    );
  }
}
