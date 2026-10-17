import 'workspace_uploads.dart';

/// The receiver's original virtual editor calls (contract v4).
///
/// The composition root binds these existing public entrypoints. Calling them
/// preserves overrides and source dispatch while the bodies move into D5.
/// This interface owns no state, subscription or notification policy.
abstract interface class WorkspaceEditorEntrypoints {
  Map<String, String> get drafts;
  Map<String, List<Map<String, dynamic>>> get pendingMentionActions;
  Map<String, ({List<String> unresolved, bool agentStopped})> get sendWarnings;
  Map<String, String?> get shareHolds;
  bool get conversationPaused;
  String? draftScope({bool thread = false});
  void saveDraft(String text, {bool thread = false});
  List<UploadDraft> uploads({bool thread = false});
  bool sharedBlocked({bool thread = false});
  Future<int?> uploadLimitBytes();
  Future<Map<String, Map<String, dynamic>>> executeMentionActionResults(
    String action,
    List<String> resolutionIds,
  );
}
