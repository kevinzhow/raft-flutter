// Shared by the Administration sections (Web v1.24.0
// features/settings/administration/*): the error text, the region key, the
// fenced section read and the confirmation dialog.
import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/user_error.dart';
import '../data/workspace_controller.dart';
import 'management_support.dart'
    show pageIdentity, readPageSnapshot, writePageSnapshot;

/// `err.response?.data?.error || fallback`.
String adminApiError(Object error, String fallback) =>
    userErrorText(error, fallback: fallback, where: 'administration');

Key adminRegion(String section) => ValueKey('admin-section-$section');

/// Section reads fenced by [pageIdentity]; accepted results are kept as the
/// section's page snapshot so a revisit paints them in the first frame.
mixin AdminSectionLoad<T extends StatefulWidget> on State<T> {
  WorkspaceController get w;
  String get snapshotKey;
  int _ticket = 0;

  Map<String, Object?>? readSnapshot() => readPageSnapshot(w, snapshotKey);

  /// Runs [read]; [accept] applies the result when it is still current.
  Future<void> load<R>(
    Future<R> Function() read,
    void Function(R value) accept, {
    void Function(Object error)? failed,
    VoidCallback? done,
  }) async {
    final ticket = ++_ticket, identity = pageIdentity(w);
    try {
      final value = await read();
      if (!mounted || ticket != _ticket || identity != pageIdentity(w)) {
        return;
      }
      setState(() => accept(value));
      writePageSnapshot(w, snapshotKey, identity, captureSnapshot());
    } catch (e) {
      if (mounted && ticket == _ticket && identity == pageIdentity(w)) {
        setState(() => failed?.call(e));
      }
    } finally {
      if (mounted && ticket == _ticket) setState(() => done?.call());
    }
  }

  Map<String, Object?> captureSnapshot();
  void saveSnapshot() =>
      writePageSnapshot(w, snapshotKey, pageIdentity(w), captureSnapshot());
}

Future<bool> adminConfirm(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Cancel',
  required String loadingLabel,
  required Future<void> Function() onConfirm,
  RaftButtonRecipeVariant confirmVariant = RaftButtonRecipeVariant.danger,
  Key confirmKey = const ValueKey('admin-confirm'),
}) async =>
    await RaftConfirmDialog.show(
      context,
      RaftConfirmDialog(
        surfaceKey: const ValueKey('admin-confirm-dialog'),
        confirmKey: confirmKey,
        confirmVariant: confirmVariant,
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        loadingLabel: loadingLabel,
        onConfirm: onConfirm,
      ),
    ) ==
    true;
