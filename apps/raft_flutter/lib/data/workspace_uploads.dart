import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:raft_client/raft_client.dart';

import 'shared_draft_attachment.dart';
import 'upload_failure.dart';
import 'upload_mime.dart';

class UploadDraft {
  UploadDraft(this.filename, this.bytes, {required this.key}) : local = null;
  UploadDraft.shared(SharedDraftAttachment file, {required this.key})
    : filename = file.filename,
      bytes = Uint8List(0),
      local = file,
      queued = true;

  /// Session-unique identity for presentation (rows, hover, tests).
  final int key;
  final String filename;
  final Uint8List bytes;
  final SharedDraftAttachment? local;
  int get sizeBytes => local?.sizeBytes ?? bytes.length;
  bool queued = false;
  var cancel = UploadCancellation();
  double progress = 0;
  // ignore: raft_lints/avoid_imperative_notice_state -- Per-upload failure on its draft chip; composer upload state owned by the lead (cleared on retry, removal or send).
  String? id, error;

  /// Web `uploadStatus: "validating"`: shown, but the selection check (size
  /// ceiling, count, empty file) has not decided yet and nothing is sent.
  bool checking = false;

  /// Web `uploadCanRetry`: false once the selection check was interrupted.
  bool canRetry = true;

  /// Browser `File.type` of the picked name (file card meta, image preview).
  String get mimeType => local?.mimeType ?? composerMimeType(filename);

  /// The accepted upload record (`POST /attachments/upload`), so an
  /// optimistic row can present the attachment before the message exists.
  Map<String, dynamic>? metadata;
}

typedef ComposerUploadPersist = Future<void> Function(
  String scope, {
  bool requiredSuccess,
});

/// Immutable bindings for one editor visit. The session owns the operation;
/// leaving an editor can stop its unstarted selection without cancelling an
/// already running transfer owned by that session.
class ComposerUploadVisit {
  const ComposerUploadVisit({
    required this.scope,
    required this.channelId,
    required this.thread,
    required this.selectionCurrent,
    required this.resolveThread,
    required this.limit,
    required this.upload,
    required this.persist,
    required this.notice,
  });
  final String scope;
  final String? channelId;
  final bool thread;
  final bool Function() selectionCurrent;
  final Future<String?> Function() resolveThread;
  final Future<int?> Function() limit;
  final Future<List<Map<String, dynamic>>> Function(
    String id,
    UploadDraft draft,
    void Function(int, int) progress,
  )
  upload;
  final ComposerUploadPersist persist;
  final void Function(String? message) notice;
}

class _UploadOperation {
  _UploadOperation(this.id, this.scope, this.cancellation);
  final int id;
  final String scope;
  final UploadCancellation cancellation;
}

/// Session-owned attachment transactions. Every completion and progress event
/// must still own its operation id, scope epoch and session authority.
class WorkspaceUploads {
  WorkspaceUploads({required this.changed, required this.authority});
  final void Function(String scope) changed;
  final Object Function() authority;
  final byScope = <String, List<UploadDraft>>{};
  final holds = <String, String?>{};
  final _scopeEpochs = <String, int>{};
  final _operations = <UploadDraft, _UploadOperation>{};
  Future<void> _selectionQueue = Future<void>.value();
  int nextKey = 0, _nextOperation = 0, _epoch = 0;
  bool _closed = false;

  bool Function() captureScope(String scope) {
    final epoch = _epoch, scopeEpoch = _scopeEpochs[scope], owner = authority();
    return () =>
        !_closed &&
        epoch == _epoch &&
        scopeEpoch == _scopeEpochs[scope] &&
        owner == authority();
  }

  Future<void> select(
    List<({String name, Uint8List bytes})> files,
    ComposerUploadVisit visit, {
    required String Function(String key, Map<String, Object> args) text,
  }) {
    if (_closed || files.isEmpty) return Future<void>.value();
    final scope = visit.scope, sessionCurrent = captureScope(visit.scope);
    final batch = [
      for (final file in files)
        UploadDraft(file.name, file.bytes, key: nextKey++)..checking = true,
    ];
    (byScope[scope] ??= []).addAll(batch);
    changed(scope);
    Future<void> decide() => _decideSelection(
      scope,
      batch,
      visit: visit,
      sessionCurrent: sessionCurrent,
      current: () => sessionCurrent() && visit.selectionCurrent(),
      text: text,
    );
    final run = _selectionQueue.then((_) => decide(), onError: (_) => decide());
    _selectionQueue = run.catchError((Object _) {});
    return run;
  }

  Future<void> attach(String name, Uint8List bytes, ComposerUploadVisit visit) {
    if (_closed) return Future<void>.value();
    if (bytes.isEmpty) {
      throw const RaftApiException('Empty files cannot be uploaded.');
    }
    if ((byScope[visit.scope]?.length ?? 0) >= 10) {
      throw const RaftApiException('Attach up to 10 files per message.');
    }
    final draft = UploadDraft(name, bytes, key: nextKey++);
    (byScope[visit.scope] ??= []).add(draft);
    return transfer(draft, visit);
  }

  Future<void> retry(UploadDraft draft, ComposerUploadVisit visit) async {
    if (_closed ||
        !(byScope[visit.scope]?.contains(draft) ?? false) ||
        draft.error == null ||
        !draft.canRetry) {
      return;
    }
    draft.cancel = UploadCancellation();
    draft.error = null;
    draft.progress = 0;
    await transfer(draft, visit);
  }

  Future<void> transfer(UploadDraft draft, ComposerUploadVisit visit) async {
    if (_closed || !(byScope[visit.scope]?.contains(draft) ?? false)) {
      return;
    }
    final scope = visit.scope, sessionCurrent = captureScope(visit.scope);
    final operation = _UploadOperation(++_nextOperation, scope, draft.cancel);
    _operations.remove(draft)?.cancellation.cancel();
    _operations[draft] = operation;
    bool current() =>
        sessionCurrent() &&
        _operations[draft]?.id == operation.id &&
        !operation.cancellation.cancelled &&
        (byScope[scope]?.contains(draft) ?? false);
    draft.queued = false;
    changed(scope);
    try {
      final id = visit.thread ? await visit.resolveThread() : visit.channelId;
      if (id == null || !current()) return;
      void progress(int sent, int total) {
        if (!current()) return;
        draft.progress = total > 0 ? sent / total : 0;
        changed(scope);
      }

      final files = await visit.upload(id, draft, progress);
      if (!current()) return;
      draft.id = files.single['id'];
      draft.metadata = files.single;
      draft.progress = 1;
      if (draft.local != null) await visit.persist(scope);
    } catch (e) {
      if (current()) recordUploadFailure(draft, e);
    } finally {
      // A removed, cancelled or replaced operation cannot settle its successor
      // and cannot notify a new session which happens to reuse the scope id.
      if (current()) {
        _operations.remove(draft);
        changed(scope);
      }
    }
  }

  void remove(UploadDraft draft, ComposerUploadPersist persist) {
    _operations.remove(draft)?.cancellation.cancel();
    draft.cancel.cancel();
    discardDirectUpload(draft);
    for (final entry in byScope.entries.toList()) {
      if (!entry.value.remove(draft)) continue;
      if (entry.value.isEmpty) byScope.remove(entry.key);
      if (draft.local != null) unawaited(persist(entry.key));
      changed(entry.key);
    }
    if (draft.local != null) unawaited(release([draft]));
  }

  void revokeScope(String scope, {bool keepFiles = false}) {
    _scopeEpochs[scope] = (_scopeEpochs[scope] ?? 0) + 1;
    for (final entry in _operations.entries.toList()) {
      if (entry.value.scope != scope) continue;
      entry.value.cancellation.cancel();
      _operations.remove(entry.key);
    }
    final files = keepFiles ? byScope[scope] : byScope.remove(scope);
    for (final draft in files ?? <UploadDraft>[]) {
      draft.cancel.cancel();
    }
    if (!keepFiles && files != null) unawaited(release(files));
  }

  void clear() {
    _epoch++;
    for (final files in byScope.values) {
      for (final draft in files) {
        draft.cancel.cancel();
      }
    }
    _operations.clear();
    byScope.clear();
    holds.clear();
    _scopeEpochs.clear();
    _selectionQueue = Future<void>.value();
  }

  void dispose() {
    clear();
    _closed = true;
  }

  static Future<void> release(Iterable<UploadDraft> files) async {
    for (final file in files) {
      try {
        await file.local?.release();
      } catch (_) {
        // Accepted sends are not turned into failures by local cleanup.
      }
    }
  }

  Future<void> restore(
    String scope,
    List<Map> files, {
    required Future<SharedDraftAttachment?> Function(Map<String, dynamic>) read,
  }) async {
    final current = captureScope(scope);
    for (final row in files) {
      if (row['ref'] is! Map) continue;
      final file = await read(Map<String, dynamic>.from(row['ref']));
      if (!current()) return;
      if (file == null) continue;
      final list = byScope[scope] ??= [];
      if (list.any(
        (u) =>
            u.local != null &&
            jsonEncode(u.local!.reference) == jsonEncode(file.reference),
      )) {
        continue;
      }
      final draft = UploadDraft.shared(file, key: nextKey++);
      if (row['id'] is String) {
        draft.id = row['id'];
        draft.queued = false;
        draft.progress = 1;
        if (row['metadata'] is Map) {
          draft.metadata = Map<String, dynamic>.from(row['metadata']);
        }
      }
      list.add(draft);
      changed(scope);
    }
  }

  Future<void> _decideSelection(
    String scope,
    List<UploadDraft> batch, {
    required ComposerUploadVisit visit,
    required bool Function() sessionCurrent,
    required bool Function() current,
    required String Function(String key, Map<String, Object> args) text,
  }) async {
    if (!sessionCurrent()) return;
    final limit = await visit.limit();
    if (!sessionCurrent()) return;
    final list = byScope[scope];
    if (!current()) {
      // Web markInterruptedUploads: the check never finished for this draft.
      for (final draft in batch) {
        if (!draft.checking) continue;
        draft.checking = false;
        draft.canRetry = false;
        draft.error =
            'File checking was interrupted. Remove it and attach again.';
      }
      changed(scope);
      return;
    }
    // Rows the user removed meanwhile release their slot.
    final alive = [
      for (final d in batch)
        if (list?.contains(d) ?? false) d,
    ];
    if (alive.isEmpty) return;
    final accepted = <UploadDraft>[];
    var count = 0, empty = 0;
    final oversize = <int>[];
    var slots = (10 - list!.where((d) => !d.checking).length).clamp(0, 10);
    if (limit != null) {
      for (final draft in alive) {
        if (draft.bytes.isEmpty) {
          empty++;
        } else if (draft.bytes.length > limit) {
          oversize.add(draft.bytes.length);
        } else if (slots <= 0) {
          count++;
        } else {
          accepted.add(draft);
          slots--;
        }
      }
    }
    for (final draft in alive) {
      draft.checking = false;
      if (!accepted.contains(draft)) list.remove(draft);
    }
    final parts = <String>[
      if (limit == null)
        text(
          'The upload size limit could not be checked. Try again in a moment.',
          const {},
        ),
      // Web ICU plurals (`one` / `other`).
      if (count > 0)
        text(
          count == 1
              ? 'Only {max} attachments per message. {extra} extra file skipped.'
              : 'Only {max} attachments per message. {extra} extra files skipped.',
          {'max': 10, 'extra': count},
        ),
      if (empty > 0)
        text(
          empty == 1
              ? '{count} empty file skipped.'
              : '{count} empty files skipped.',
          {'count': empty},
        ),
      if (oversize.isNotEmpty)
        text('Max {maxSize} per file. Current largest file is {largest}.', {
          'maxSize': _limitLabel(limit!),
          'largest': _bytesLabel(oversize.reduce((a, b) => a > b ? a : b)),
        }),
    ];
    visit.notice(parts.isEmpty ? null : parts.join(' '));
    if (list.isEmpty) byScope.remove(scope);
    changed(scope);
    // One transfer at a time, each fenced by the authority the selection was
    // made under: after a conversation, role or account change the files that
    // have not started are dropped rather than sent under the new authority.
    for (final draft in accepted) {
      if (!sessionCurrent()) return;
      if (!current()) {
        byScope[scope]?.remove(draft);
        if (byScope[scope]?.isEmpty ?? false) byScope.remove(scope);
        changed(scope);
        continue;
      }
      await transfer(draft, visit);
    }
  }

  static String uploadErrorText(Object failure) => uploadFailureText(failure);

  static String _limitLabel(int bytes) => bytes % (1024 * 1024) == 0
      ? '${bytes ~/ (1024 * 1024)}MB'
      : _bytesLabel(bytes);

  static String _bytesLabel(int bytes) {
    if (bytes <= 0) return '0B';
    const units = ['B', 'KB', 'MB', 'GB'];
    var value = bytes.toDouble();
    var unit = 0;
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit++;
    }
    return '${unit == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(1)}${units[unit]}';
  }
}
