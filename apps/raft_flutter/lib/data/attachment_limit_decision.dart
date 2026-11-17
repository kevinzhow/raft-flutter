// The composer's accept / reject decision for a batch of picked files (Web
// v1.24 utils/messageAttachmentLimits.ts `decideMessageAttachmentSelection`,
// utils/attachmentUploadLimit.ts `AttachmentUploadLimits`,
// utils/attachmentLimitPresentation.ts `attachmentRejectionPlan`, and
// utils/monthlyUploadQuota.ts `readMonthlyUploadQuota`).
//
// The ceiling is server-owned: nothing here computes a limit. An unknown
// ceiling refuses the batch (`unchecked`) instead of falling back to a guess.

/// Web `MAX_MESSAGE_ATTACHMENTS`.
const maxMessageAttachments = 10;

/// `@botiverse/raft-shared` Free / Pro single-file ceilings.
const freeSingleFileUploadLimitBytes = 50 * 1024 * 1024;
const proSingleFileUploadLimitBytes = 200 * 1024 * 1024;

/// Web `MONTHLY_UPLOAD_USED_UP_BELOW_BYTES`: less left than this is "used up".
const monthlyUploadUsedUpBelowBytes = 1024 * 1024;

/// What is left of a limited server's monthly upload quota, as
/// `GET /attachments/upload-capabilities` reports it (`monthlyUpload`).
class MonthlyUploadQuota {
  const MonthlyUploadQuota({
    required this.month,
    required this.limitBytes,
    required this.remainingBytes,
    this.appsumo = false,
  });

  /// The UTC month it counts, `YYYY-MM`.
  final String month;
  final int limitBytes, remainingBytes;
  final bool appsumo;

  /// Web `readMonthlyUploadQuota`: null when the value is not a quota (an
  /// older server, ordinary Pro).
  static MonthlyUploadQuota? read(Object? value) {
    if (value is! Map) return null;
    final month = value['month'], limit = value['limitBytes'];
    final remaining = value['remainingBytes'];
    if (month is! String || !RegExp(r'^\d{4}-\d{2}$').hasMatch(month)) {
      return null;
    }
    if (limit is! num || !limit.isFinite || limit <= 0) return null;
    if (remaining is! num || !remaining.isFinite || remaining < 0) return null;
    final grant = value['appsumo'];
    return MonthlyUploadQuota(
      month: month,
      limitBytes: limit.toInt(),
      remainingBytes: remaining.toInt(),
      appsumo:
          value['source'] == 'appsumo' ||
          (grant is Map && grant['tier'] is String),
    );
  }

  /// Web `monthlyUploadResetsAt`: the first moment of the next UTC month.
  DateTime get resetsAt {
    final parts = month.split('-').map(int.parse).toList();
    return DateTime.utc(parts[0], parts[1] + 1, 1);
  }

  @override
  bool operator ==(Object other) =>
      other is MonthlyUploadQuota &&
      other.month == month &&
      other.limitBytes == limitBytes &&
      other.remainingBytes == remainingBytes &&
      other.appsumo == appsumo;

  @override
  int get hashCode => Object.hash(month, limitBytes, remainingBytes, appsumo);
}

/// What a selection is checked against: the single-file ceiling and what is
/// left of a Free server's monthly quota (null where none applies).
class AttachmentUploadLimits {
  const AttachmentUploadLimits({required this.maxBytes, this.monthlyUpload});
  final int maxBytes;
  final MonthlyUploadQuota? monthlyUpload;

  /// Web `resolveAttachmentUploadLimits`: null when the body is not a usable
  /// rule (a non-positive or non-finite ceiling reads as unknown).
  static AttachmentUploadLimits? parse(Object? value) {
    final max = value is Map ? value['maxBytes'] : null;
    if (max is! num || !max.isFinite || max <= 0) return null;
    return AttachmentUploadLimits(
      maxBytes: max.toInt(),
      monthlyUpload: MonthlyUploadQuota.read((value as Map)['monthlyUpload']),
    );
  }
}

/// Why a picked file was not attached (Web `AttachmentRejectionReason`).
enum AttachmentRejectionReason {
  /// Over the server's single-file ceiling.
  size,

  /// Over the per-message attachment count.
  count,
  empty,

  /// More than the monthly upload quota has left.
  quota,

  /// The ceiling could not be checked, so nothing was attached.
  unchecked,
}

/// A reason no plan changes: the file stays in the row, failed, saying why.
enum NotAttachedReason { size, count, empty, unchecked }

class RejectedAttachment<T> {
  const RejectedAttachment(this.file, this.reason);
  final T file;
  final AttachmentRejectionReason reason;
}

class AttachmentSelectionDecision<T> {
  const AttachmentSelectionDecision(this.accepted, this.rejected, this.limits);
  final List<T> accepted;

  /// In the order the files were picked.
  final List<RejectedAttachment<T>> rejected;

  /// What the files were checked against; null when it was unknown.
  final AttachmentUploadLimits? limits;
}

/// Web `decideMessageAttachmentSelection` / `applyMessageAttachmentLimits`.
/// [existingCount] counts the files already in the row; [sizeOf] is a file's
/// size in bytes. `limits == null` refuses the whole batch (`unchecked`).
AttachmentSelectionDecision<T> decideAttachmentSelection<T>({
  required int existingCount,
  required List<T> candidates,
  required int Function(T) sizeOf,
  required AttachmentUploadLimits? limits,
}) {
  if (limits == null) {
    return AttachmentSelectionDecision<T>(const [], [
      for (final file in candidates)
        RejectedAttachment(file, AttachmentRejectionReason.unchecked),
    ], null);
  }
  final accepted = <T>[], rejected = <RejectedAttachment<T>>[];
  var slots = (maxMessageAttachments - existingCount).clamp(
    0,
    maxMessageAttachments,
  );
  var quota = limits.monthlyUpload?.remainingBytes;
  for (final file in candidates) {
    final size = sizeOf(file);
    AttachmentRejectionReason? reason;
    if (size == 0) {
      reason = AttachmentRejectionReason.empty;
    } else if (size > limits.maxBytes) {
      reason = AttachmentRejectionReason.size;
    } else if (slots <= 0) {
      reason = AttachmentRejectionReason.count;
    } else if (quota != null && size > quota) {
      // A file the month has no room for doesn't use the room a later,
      // smaller one fits in.
      reason = AttachmentRejectionReason.quota;
    }
    if (reason != null) {
      rejected.add(RejectedAttachment(file, reason));
      continue;
    }
    accepted.add(file);
    slots--;
    if (quota != null) quota -= size;
  }
  return AttachmentSelectionDecision<T>(accepted, rejected, limits);
}

/// Which upgrade gate (`WebBillingGate`) an upload limit opens.
enum AttachmentUpgradeGate { fileSize, monthlyQuota }

/// A file the upgrade notice names.
typedef LimitFile = ({String name, int size});

/// Web `UploadLimitContext`: what an upload limit was hit with, so the notice
/// says it.
class UploadLimitContext {
  const UploadLimitContext.fileSize(this.files) : quota = null;
  const UploadLimitContext.monthlyQuota(
    MonthlyUploadQuota this.quota,
    this.files,
  );
  final MonthlyUploadQuota? quota;
  final List<LimitFile> files;
  bool get isQuota => quota != null;
}

/// Web `AttachmentRejectionPlan`: Pro would take the recoverable files, so the
/// limit notice opens and they don't stay; what no plan changes stays in the
/// row as a failed file that says why, until it is removed.
class AttachmentRejectionPlan<T> {
  const AttachmentRejectionPlan(
    this.upgradeGate,
    this.upgradeContext,
    this.keep,
  );
  final AttachmentUpgradeGate? upgradeGate;
  final UploadLimitContext? upgradeContext;

  /// The files that stay in the row, failed.
  final List<({T file, NotAttachedReason reason})> keep;
}

/// Web `attachmentRejectionPlan`. [freePlan] is the current server's plan
/// being Free (`plan == 'free'`).
AttachmentRejectionPlan<T> planAttachmentRejection<T>({
  required List<RejectedAttachment<T>> rejected,
  required AttachmentUploadLimits? limits,
  required bool freePlan,
  required String Function(T) nameOf,
  required int Function(T) sizeOf,
}) {
  // Pro takes a file over Free's ceiling but within its own, and has no
  // monthly quota.
  bool proTakes(RejectedAttachment<T> entry) =>
      freePlan &&
      (entry.reason == AttachmentRejectionReason.quota ||
          (entry.reason == AttachmentRejectionReason.size &&
              sizeOf(entry.file) <= proSingleFileUploadLimitBytes));
  final recoverable = [
    for (final entry in rejected)
      if (proTakes(entry) ||
          (entry.reason == AttachmentRejectionReason.quota &&
              (limits?.monthlyUpload?.appsumo ?? false)))
        entry,
  ];
  final overQuota = [
    for (final e in recoverable)
      if (e.reason == AttachmentRejectionReason.quota) e,
  ];
  final quota = limits?.monthlyUpload;
  List<LimitFile> named(Iterable<RejectedAttachment<T>> list) => [
    for (final e in list) (name: nameOf(e.file), size: sizeOf(e.file)),
  ];
  AttachmentUpgradeGate? gate;
  UploadLimitContext? context;
  if (overQuota.isNotEmpty && quota != null) {
    gate = AttachmentUpgradeGate.monthlyQuota;
    context = UploadLimitContext.monthlyQuota(quota, named(overQuota));
  } else if (recoverable.isNotEmpty) {
    gate = AttachmentUpgradeGate.fileSize;
    context = UploadLimitContext.fileSize(
      named([
        for (final e in recoverable)
          if (e.reason == AttachmentRejectionReason.size) e,
      ]),
    );
  }
  final keep = <({T file, NotAttachedReason reason})>[];
  for (final entry in rejected) {
    if (proTakes(entry) || entry.reason == AttachmentRejectionReason.quota) {
      continue;
    }
    keep.add((
      file: entry.file,
      reason: switch (entry.reason) {
        AttachmentRejectionReason.size => NotAttachedReason.size,
        AttachmentRejectionReason.count => NotAttachedReason.count,
        AttachmentRejectionReason.empty => NotAttachedReason.empty,
        _ => NotAttachedReason.unchecked,
      },
    ));
  }
  return AttachmentRejectionPlan<T>(gate, context, keep);
}

/// Why a file stays in the row: the data behind its failed cover (the copy is
/// built where a BuildContext is at hand: `notAttachedCopy`).
class NotAttached {
  const NotAttached(this.reason, this.maxBytes);
  final NotAttachedReason reason;

  /// The ceiling the file was checked against; null when it was unknown.
  final int? maxBytes;
}
