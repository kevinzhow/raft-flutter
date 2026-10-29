import 'package:flutter/foundation.dart';
import 'package:raft_client/raft_client.dart';

import 'raft_location.dart';

/// D3's original raw list assignments: no row-write revision or notification.
abstract interface class WorkspacePresentationDirectoryPort {
  List<RaftChannel> get channels;
  set channels(List<RaftChannel> value);
  List<RaftChannel> get dms;
  set dms(List<RaftChannel> value);
}

/// Live D4 facts and the existing overridable entrypoints used by D3.
abstract interface class WorkspacePresentationConversationPort {
  bool get hasNewer;
  String? get threadChannelId;
  int get generation;
  String replyToken(String? id);
  Future<void> markRead(String id);
  Future<void> selectChannel(
    RaftChannel next, {
    bool autoRead = true,
    bool navigate = true,
    bool retainContextUntilAccepted = false,
    bool preserveThread = false,
    VoidCallback? onDraftRestored,
  });
}

/// Source-only presentation dispatch. Keeps public overrides and notification
/// order without importing a controller or sharing receiver-local state.
abstract interface class WorkspacePresentationSourcePort {
  String get navigationAuthority;
  void setChatTabPresentation(Object owner, bool visible);
  void releaseChatTabPresentation(Object owner);
  void setConversationPresentation(
    Object owner, {
    required bool main,
    required bool thread,
  });
  void releaseConversationPresentation(Object owner);
  Future<void> resolveConversationChannel(
    String id, {
    bool preserveThread = false,
  });
  Map<String, dynamic>? externalProfile(String messageId);
  void openProfile(
    RaftProfileKind kind,
    String id, {
    String? agentTab,
    String? channelId,
    Map<String, dynamic>? externalAuthor,
  });
  void closeProfile();
  void setSection(String section);
  void setError(String? value);
}
