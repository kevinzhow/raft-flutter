import '../data/raft_location.dart';
import '../data/raft_permalink.dart';
import '../data/workspace_controller.dart';
import 'quoted_message_preview.dart';

typedef ChatProfileOpener =
    void Function(
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
