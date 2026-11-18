import 'package:flutter/widgets.dart';
import 'package:raft_client/raft_client.dart';

import '../data/raft_location.dart';
import '../data/raft_permalink.dart';
import '../data/workspace_controller.dart';
import 'quoted_message_preview.dart';

/// The actions owned by a surface that presents a borrowed timeline.
class ChatNavigationScope extends InheritedWidget {
  const ChatNavigationScope({
    super.key,
    required this.navigation,
    required super.child,
  });

  final ChatNavigation navigation;

  static ChatNavigation? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<ChatNavigationScope>()
      ?.navigation;

  @override
  bool updateShouldNotify(ChatNavigationScope oldWidget) =>
      oldWidget.navigation != navigation;
}

String? jointSenderProfileChannel(
  WorkspaceController controller,
  RaftMessage message, {
  required bool thread,
}) {
  final id = thread
      ? controller.threadIdentity?.parentChannelId ?? message.channelId
      : message.channelId;
  final selected = controller.channel;
  final channel = selected?.id == id ? selected : controller.channelById(id);
  return channel?.type == 'joint' ? id : null;
}

typedef ChatProfileOpener = void Function(
  RaftProfileKind kind,
  String id, {
  String? agentTab,
  String? channelId,
  Map<String, dynamic>? externalAuthor,
});

/// Route owners for a timeline mounted with its own message window.
class ChatNavigation {
  const ChatNavigation({
    required this.workspace,
    required this.profiles,
    required this.current,
    required this.onConversationOpened,
  });

  final WorkspaceController workspace;
  final WorkspaceController profiles;
  final bool Function() current;
  final void Function() onConversationOpened;

  void openProfile(
    RaftProfileKind kind,
    String id, {
    String? agentTab,
    String? channelId,
    Map<String, dynamic>? externalAuthor,
  }) {
    if (!current()) return;
    profiles.openProfile(
      kind,
      id,
      agentTab: agentTab,
      channelId: channelId,
      externalAuthor: externalAuthor,
    );
  }

  Future<void> navigate(
    Future<void> Function(WorkspaceController) action,
  ) async {
    if (!current()) return;
    final previous = workspace.location;
    await action(workspace);
    if (current() && workspace.location != previous) onConversationOpened();
  }

  Future<void> openPermalink(RaftPermalink link) => navigate(
    (host) => openRaftPermalink(host, link, selectChannelRoute: true),
  );
}
