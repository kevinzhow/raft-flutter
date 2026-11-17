import 'attachment_limit_decision.dart';
import 'workspace_uploads.dart';

// The composer's selection check applied to its upload drafts (Web v1.24
// MessageInput `validateSelection`): what the server allows, what the plan
// would take, what stays failed. Kept out of WorkspaceUploads, which only
// sequences the check and the transfers.

/// What one selection is checked against: the server's rule (null when it
/// could not be read), whether the server is on Free, and which server.
typedef SelectionLimits = ({
  AttachmentUploadLimits? limits,
  bool freePlan,
  String? serverId,
});

/// Reads `GET /attachments/upload-capabilities` through [query] (every
/// selection, never cached) for [server]. Free is `plan || "free"` is free.
Future<SelectionLimits> readSelectionLimits(
  Future<dynamic> Function(String path) query,
  Map<String, dynamic>? server,
) async {
  AttachmentUploadLimits? limits;
  try {
    limits = AttachmentUploadLimits.parse(
      await query('/attachments/upload-capabilities'),
    );
  } catch (_) {}
  return (
    limits: limits,
    freePlan: (server?['plan'] ?? 'free') == 'free',
    serverId: server?['id'] as String?,
  );
}

/// Web `PendingFile.notAttached`: a draft the check refused for a reason no
/// plan changes stays in the row, failed; its error only marks it failed.
final notAttachedOf = Expando<NotAttached>('notAttached');

/// Decides [alive] (the drafts of this selection) among the [list] already in
/// the row. Refused drafts leave [list] unless they stay as failed rows;
/// returns the accepted drafts and the plan's limit notice (null when none).
({List<UploadDraft> accepted, AttachmentRejectionPlan<UploadDraft> plan})
applySelectionLimits(
  List<UploadDraft> list,
  List<UploadDraft> alive,
  SelectionLimits env,
) {
  final decision = decideAttachmentSelection<UploadDraft>(
    existingCount: list
        .where(
          (d) => !d.checking && notAttachedOf[d] == null && !alive.contains(d),
        )
        .length,
    candidates: alive,
    sizeOf: (d) => d.sizeBytes,
    limits: env.limits,
  );
  final plan = planAttachmentRejection<UploadDraft>(
    rejected: decision.rejected,
    limits: env.limits,
    freePlan: env.freePlan,
    nameOf: (d) => d.filename,
    sizeOf: (d) => d.sizeBytes,
  );
  final kept = {for (final k in plan.keep) k.file: k.reason};
  for (final draft in alive) {
    draft.checking = false;
    final reason = kept[draft];
    if (reason != null) {
      draft.canRetry = false;
      notAttachedOf[draft] = NotAttached(reason, env.limits?.maxBytes);
      draft.error = 'Not attached';
    } else if (!decision.accepted.contains(draft)) {
      list.remove(draft);
    }
  }
  return (accepted: decision.accepted, plan: plan);
}
