import 'workspace_uploads.dart';

/// Web `handleAttachmentDragEnd`: puts the chips named by [keys]
/// (`UploadDraft.key`, in the new order) into [drafts]. The chips take the
/// places the dragged ones held, so a failed-upload row keeps its position.
/// Returns false, leaving the list alone, when a key is unknown (the chip was
/// removed meanwhile) or repeated.
bool reorderUploadDrafts(List<UploadDraft> drafts, List<int> keys) {
  final byKey = {for (final draft in drafts) draft.key: draft};
  final moved = [for (final key in keys) ?byKey[key]];
  if (moved.length != keys.length || moved.toSet().length != moved.length) {
    return false;
  }
  final slots = [
    for (var i = 0; i < drafts.length; i++)
      if (moved.contains(drafts[i])) i,
  ];
  for (var i = 0; i < slots.length; i++) {
    drafts[slots[i]] = moved[i];
  }
  return true;
}
