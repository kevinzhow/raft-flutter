import 'workspace_uploads.dart';

typedef ComposerSendWarnings = ({
  List<String> unresolved,
  bool agentStopped,
  bool agentStuck,
});

/// The receiver's original virtual editor calls (contract v4).
///
/// The composition root binds these existing public entrypoints. Calling them
/// preserves overrides and source dispatch while the bodies move into D5.
/// This interface owns no state, subscription or notification policy.
abstract interface class WorkspaceEditorEntrypoints {
  Map<String, String> get drafts;
  Map<String, List<Map<String, dynamic>>> get pendingMentionActions;
  Map<String, ComposerSendWarnings> get sendWarnings;
  Map<String, String?> get shareHolds;
  bool get conversationPaused;
  String? draftScope({bool thread = false});
  void saveDraft(String text, {bool thread = false});
  List<UploadDraft> uploads({bool thread = false});
  bool sharedBlocked({bool thread = false});

  /// The server's upload rule for one selection (`readSelectionLimits`).
  Future<SelectionLimits> uploadLimits();
  Future<Map<String, Map<String, dynamic>>> executeMentionActionResults(
    String action,
    List<String> resolutionIds,
  );
}
