import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/attachment_limit_decision.dart';

// Web v1.24 `decideMessageAttachmentSelection` (utils/messageAttachmentLimits.ts)
// and `attachmentRejectionPlan` (utils/attachmentLimitPresentation.ts): the
// composer's accept / reject decision, and what a Free server does with the
// rejected files (limit notice for what Pro would take, failed rows for what
// no plan changes).
const mb = 1024 * 1024;

typedef FileRow = ({String name, int size});

FileRow f(String name, int size) => (name: name, size: size);

AttachmentSelectionDecision<FileRow> decide(
  List<FileRow> files, {
  AttachmentUploadLimits? limits = const AttachmentUploadLimits(
    maxBytes: 50 * mb,
  ),
  int existing = 0,
}) => decideAttachmentSelection<FileRow>(
  existingCount: existing,
  candidates: files,
  sizeOf: (x) => x.size,
  limits: limits,
);

AttachmentRejectionPlan<FileRow> plan(
  AttachmentSelectionDecision<FileRow> decision, {
  bool free = true,
}) => planAttachmentRejection<FileRow>(
  rejected: decision.rejected,
  limits: decision.limits,
  freePlan: free,
  nameOf: (x) => x.name,
  sizeOf: (x) => x.size,
);

MonthlyUploadQuota quota(int remaining, {bool appsumo = false}) =>
    MonthlyUploadQuota(
      month: '2026-11',
      limitBytes: 100 * mb,
      remainingBytes: remaining,
      appsumo: appsumo,
    );

void main() {
  group('decideAttachmentSelection', () {
    test('an unknown ceiling refuses every file as unchecked', () {
      final d = decide([f('a', 1), f('b', 2)], limits: null);
      expect(d.accepted, isEmpty);
      expect(d.rejected.map((r) => r.reason), [
        AttachmentRejectionReason.unchecked,
        AttachmentRejectionReason.unchecked,
      ]);
      expect(d.limits, isNull);
    });

    test('reasons keep the picked order: empty, size, count, quota', () {
      final d = decide(
        [f('empty', 0), f('big', 60 * mb), f('ok', mb), f('late', mb)],
        limits: AttachmentUploadLimits(
          maxBytes: 50 * mb,
          monthlyUpload: quota(mb),
        ),
        existing: 9,
      );
      expect(d.accepted.map((x) => x.name), ['ok']);
      expect(d.rejected.map((r) => (r.file.name, r.reason)), [
        ('empty', AttachmentRejectionReason.empty),
        ('big', AttachmentRejectionReason.size),
        ('late', AttachmentRejectionReason.count),
      ]);
    });

    test('a file the month has no room for does not use the room a smaller one fits in', () {
      final d = decide(
        [f('big', 30 * mb), f('small', 5 * mb)],
        limits: AttachmentUploadLimits(
          maxBytes: 50 * mb,
          monthlyUpload: quota(10 * mb),
        ),
      );
      expect(d.accepted.map((x) => x.name), ['small']);
      expect(d.rejected.single.file.name, 'big');
      expect(d.rejected.single.reason, AttachmentRejectionReason.quota);
    });

    test('accepted files use up the quota in order', () {
      final d = decide(
        [f('a', 6 * mb), f('b', 6 * mb)],
        limits: AttachmentUploadLimits(
          maxBytes: 50 * mb,
          monthlyUpload: quota(10 * mb),
        ),
      );
      expect(d.accepted.map((x) => x.name), ['a']);
      expect(d.rejected.single.reason, AttachmentRejectionReason.quota);
    });

    test('ten per message counts the files already in the row', () {
      final d = decide([for (var i = 0; i < 4; i++) f('f$i', 1)], existing: 8);
      expect(d.accepted, hasLength(2));
      expect(d.rejected.map((r) => r.reason).toSet(), {
        AttachmentRejectionReason.count,
      });
    });
  });

  group('planAttachmentRejection', () {
    test('Free: over Free but within Pro opens the file-size notice and does not stay', () {
      final p = plan(decide([f('video.mov', 80 * mb), f('ok.txt', 1)]));
      expect(p.upgradeGate, AttachmentUpgradeGate.fileSize);
      expect(p.upgradeContext!.files, [(name: 'video.mov', size: 80 * mb)]);
      expect(p.keep, isEmpty);
    });

    test('Free: over Pro too stays failed as size, with no notice', () {
      final p = plan(decide([f('huge.iso', 300 * mb)]));
      expect(p.upgradeGate, isNull);
      expect(p.keep.single.reason, NotAttachedReason.size);
    });

    test('Free: files beyond the monthly quota open the quota notice', () {
      final q = quota(10 * mb);
      final p = plan(
        decide([
          f('a', 30 * mb),
          f('b', 20 * mb),
        ], limits: AttachmentUploadLimits(maxBytes: 50 * mb, monthlyUpload: q)),
      );
      expect(p.upgradeGate, AttachmentUpgradeGate.monthlyQuota);
      expect(p.upgradeContext!.quota, q);
      expect(p.upgradeContext!.files.map((x) => x.name), ['a', 'b']);
      expect(p.keep, isEmpty);
    });

    test('quota wins over file size when both are hit', () {
      final p = plan(
        decide(
          [f('over', 80 * mb), f('quota', 30 * mb)],
          limits: AttachmentUploadLimits(
            maxBytes: 50 * mb,
            monthlyUpload: quota(10 * mb),
          ),
        ),
      );
      expect(p.upgradeGate, AttachmentUpgradeGate.monthlyQuota);
      expect(p.upgradeContext!.files.map((x) => x.name), ['quota']);
    });

    test('count, empty and unchecked stay failed on any plan', () {
      for (final free in [true, false]) {
        final count = plan(decide([f('a', 1)], existing: 10), free: free);
        expect(count.keep.single.reason, NotAttachedReason.count);
        expect(count.upgradeGate, isNull);
        expect(
          plan(decide([f('e', 0)]), free: free).keep.single.reason,
          NotAttachedReason.empty,
        );
        expect(
          plan(
            decide([f('a', 1)], limits: null),
            free: free,
          ).keep.single.reason,
          NotAttachedReason.unchecked,
        );
      }
    });

    test('a Pro server: over its ceiling stays failed, no notice', () {
      final p = plan(
        decide([
          f('big', 250 * mb),
        ], limits: const AttachmentUploadLimits(maxBytes: 200 * mb)),
        free: false,
      );
      expect(p.upgradeGate, isNull);
      expect(p.keep.single.reason, NotAttachedReason.size);
    });

    test('an AppSumo quota opens the notice on a plan that is not Free', () {
      final p = plan(
        decide(
          [f('a', 30 * mb)],
          limits: AttachmentUploadLimits(
            maxBytes: 200 * mb,
            monthlyUpload: quota(10 * mb, appsumo: true),
          ),
        ),
        free: false,
      );
      expect(p.upgradeGate, AttachmentUpgradeGate.monthlyQuota);
      expect(p.keep, isEmpty);
    });
  });

  group('upload capabilities', () {
    test('monthlyUpload is read like Web readMonthlyUploadQuota', () {
      final limits = AttachmentUploadLimits.parse({
        'maxBytes': 50 * mb,
        'monthlyUpload': {
          'month': '2026-11',
          'limitBytes': 100 * mb,
          'remainingBytes': 7 * mb,
        },
      });
      expect(limits!.maxBytes, 50 * mb);
      expect(limits.monthlyUpload!.remainingBytes, 7 * mb);
      expect(limits.monthlyUpload!.resetsAt, DateTime.utc(2026, 12));
      expect(
        AttachmentUploadLimits.parse({
          'maxBytes': 1,
          'monthlyUpload': {'month': 'x'},
        })!.monthlyUpload,
        isNull,
      );
    });

    test('a non-positive or missing ceiling is unknown, never a guess', () {
      expect(AttachmentUploadLimits.parse({'maxBytes': 0}), isNull);
      expect(AttachmentUploadLimits.parse({'maxBytes': -5}), isNull);
      expect(AttachmentUploadLimits.parse({}), isNull);
      expect(AttachmentUploadLimits.parse(null), isNull);
    });
  });
}
