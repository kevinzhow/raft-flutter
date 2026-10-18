import 'dart:async';
import 'dart:convert';

import 'package:raft_client/raft_client.dart';

import 'workspace_uploads.dart';

typedef ComposerReceipt = ({RaftMessage message, Map<String, dynamic> receipt});

class ComposerSendAttempt {
  ComposerSendAttempt(this.fingerprint, this.randomId);
  final String fingerprint, randomId;
  bool inFlight = false;
}

/// Bindings captured by the editor that submits a draft. Selection matters
/// before dispatch. A dispatched request belongs to the session thereafter.
class ComposerSendVisit {
  const ComposerSendVisit({
    required this.scope,
    required this.channelId,
    required this.parentChannelId,
    required this.author,
    required this.displaySeq,
    required this.current,
    required this.prepare,
    required this.limit,
    required this.transfer,
    required this.started,
    required this.failed,
    required this.received,
  });
  final String scope;
  final String? channelId;
  final String? parentChannelId;
  final Map<String, dynamic> author;
  final BigInt displaySeq;
  final bool Function() current;
  final Future<String?> Function() prepare;
  final Future<int?> Function() limit;
  final Future<void> Function(UploadDraft file) transfer;
  final void Function() started;
  final void Function(Object cause) failed;
  final void Function(ComposerReceipt receipt) received;
}

class ComposerPendingSend {
  ComposerPendingSend(this.attempt, this.row, this.draft, this.uploads);
  final ComposerSendAttempt attempt;
  final RaftMessage row;
  final String draft;
  final List<UploadDraft> uploads;
  String get randomId => attempt.randomId;
  String? channelId;
  bool confirmed = false;
}

class _QueuedDraft {
  _QueuedDraft(this.text);
  final String text;
}

/// Pending sends and retry identities shared by all editors of one session.
/// Accepted messages are published to the existing window owners, not stored
/// here. Requests run concurrently, as in Web MessageInput / messageStore.
class WorkspaceSends {
  WorkspaceSends({
    required this.drafts,
    required this.uploads,
    required this.captureScope,
    required this.persistDraft,
    required this.persistAttempt,
    required this.changed,
  });
  final Map<String, String> drafts;
  final WorkspaceUploads uploads;
  final bool Function() Function(String scope) captureScope;
  final ComposerUploadPersist persistDraft;
  final Future<void> Function(String, ComposerSendAttempt?, {String? channelId})
  persistAttempt;
  final void Function(String scope) changed;
  final attempts = <String, ComposerSendAttempt>{};
  final pending = <String, List<ComposerPendingSend>>{};
  final _queued = <String, _QueuedDraft>{};
  final _localIds = <String, String>{};
  final _observers =
      <Object, void Function(String scope, RaftMessage? accepted)>{};

  void attach(Object owner, void Function(String, RaftMessage?) observer) =>
      _observers[owner] = observer;
  void detach(Object owner) => _observers.remove(owner);
  bool queued(String? scope) => _queued.containsKey(scope);
  String queuedText(String scope) => _queued[scope]?.text ?? '';
  bool localId(String id) => _localIds.containsKey(id);

  List<RaftMessage> project(List<RaftMessage> rows, String scope) {
    final sends = pending[scope];
    if (sends == null || sends.isEmpty) return rows;
    final confirmed = {for (final row in rows) row.json['randomId']};
    return [
      ...rows,
      for (final send in sends)
        if (!confirmed.contains(send.randomId)) send.row,
    ]..sort((a, b) {
      BigInt? sequence(RaftMessage row) => BigInt.tryParse(
        '${row.json['seq'] ?? row.json['optimisticDisplaySeq']}',
      );
      final aSeq = sequence(a), bSeq = sequence(b);
      if (aSeq != null && bSeq != null && aSeq != bSeq) {
        return aSeq.compareTo(bSeq);
      }
      final aTime = DateTime.tryParse(a.string('createdAt'));
      final bTime = DateTime.tryParse(b.string('createdAt'));
      if (aTime != null && bTime != null && aTime != bTime) {
        return aTime.compareTo(bTime);
      }
      if (aSeq != null && bSeq == null) return 1;
      if (bSeq != null && aSeq == null) return -1;
      return a.id.compareTo(b.id);
    });
  }

  void _publish(String scope, [RaftMessage? accepted]) {
    changed(scope);
    for (final observer in _observers.values.toList()) {
      observer(scope, accepted);
    }
  }

  /// A socket echo can settle delivery even when its HTTP response is lost.
  /// Keep the pending projection until each window receives its own echo.
  void confirm(Map<String, dynamic> row) {
    final randomId = row['randomId'];
    if (randomId is! String) return;
    for (final sends in pending.values) {
      for (final send in sends) {
        if (send.randomId == randomId && send.channelId == row['channelId']) {
          send.confirmed = true;
        }
      }
    }
  }

  Future<bool> send(
    String text, {
    required RaftClient client,
    required ComposerSendVisit visit,
    List<String>? attachments,
    List<Map<String, dynamic>> mentions = const [],
    String? randomId,
    bool asTask = false,
    Future<String?> Function()? readTimezone,
    required String Function(int) attachmentsOnlyBody,
  }) async {
    final scope = visit.scope, sessionCurrent = captureScope(visit.scope);
    final selectedIds = attachments == null
        ? null
        : List<String>.unmodifiable(attachments);
    bool current() => sessionCurrent() && visit.current();
    if (!current()) return false;
    final files = List<UploadDraft>.of(uploads.byScope[scope] ?? const []);
    if (files.any((file) => file.queued)) {
      if (queued(scope)) return false;
      final reservation = _QueuedDraft(text);
      _queued[scope] = reservation;
      var ready = false;
      unawaited(persistDraft(scope));
      try {
        final limit = await visit.limit();
        if (!current()) return false;
        if (limit == null ||
            files.any((f) => f.local != null && f.sizeBytes > limit)) {
          visit.failed(
            RaftApiException(
              limit == null
                  ? 'The upload size limit could not be checked. Try again in a moment.'
                  : 'A shared file exceeds the upload size limit.',
            ),
          );
          return false;
        }
        for (final file in files.where((file) => file.queued)) {
          if (!current()) return false;
          await visit.transfer(file);
          if (!current() || file.id == null) return false;
        }
        ready = true;
      } catch (cause) {
        if (current()) visit.failed(cause);
        return false;
      } finally {
        if (identical(_queued[scope], reservation)) _queued.remove(scope);
        if (!ready && sessionCurrent()) {
          drafts[scope] = _mergeFailed(text, drafts[scope] ?? '');
          unawaited(persistDraft(scope));
          _publish(scope);
        }
      }
    }
    if (!current()) return false;
    if (files.any((file) => file.id == null)) {
      visit.failed(
        const RaftApiException(
          'Wait for uploads to finish, or remove the failed file.',
        ),
      );
      return false;
    }
    final ids = List<String>.unmodifiable(
      selectedIds ?? files.map((f) => f.id!),
    );
    final body = text.trim().isEmpty && ids.isNotEmpty
        ? attachmentsOnlyBody(ids.length)
        : text;
    final fingerprint = jsonEncode([
      text,
      ids,
      if (mentions.isNotEmpty) mentions,
      if (asTask) true,
    ]);
    final retained = attempts[scope];
    final fresh =
        retained == null ||
        retained.fingerprint != fingerprint ||
        retained.inFlight;
    final attempt = fresh
        ? ComposerSendAttempt(fingerprint, randomId ?? client.newRandomId())
        : retained;
    attempts[scope] = attempt;
    attempt.inFlight = true;
    final selectedFiles = files.where((f) => ids.contains(f.id)).toList();
    final displaySeq =
        (pending[scope] ?? const <ComposerPendingSend>[]).fold(
          visit.displaySeq,
          (maximum, send) {
            final value = BigInt.parse(send.row.json['optimisticDisplaySeq']);
            return value > maximum ? value : maximum;
          },
        ) +
        BigInt.one;
    final send = ComposerPendingSend(
      attempt,
      RaftMessage({
        'id': 'optimistic-${attempt.randomId}',
        'randomId': attempt.randomId,
        'channelId': visit.channelId,
        ...visit.author,
        'messageType': 'chat',
        'content': body,
        'optimisticDisplaySeq': '$displaySeq',
        if (mentions.isNotEmpty) 'mentions': mentions,
        'createdAt': DateTime.now().toUtc().toIso8601String(),
        if (selectedFiles.isNotEmpty)
          'attachments': [
            for (final file in selectedFiles)
              file.metadata ??
                  {
                    'id': file.id,
                    'filename': file.filename,
                    'sizeBytes': file.sizeBytes,
                  },
          ],
        'pendingSend': true,
      }),
      text,
      selectedFiles,
    );
    (pending[scope] ??= []).add(send);
    _localIds[attempt.randomId] = scope;
    uploads.byScope[scope]?.removeWhere(selectedFiles.contains);
    if (uploads.byScope[scope]?.isEmpty ?? false) uploads.byScope.remove(scope);
    visit.started();
    _publish(scope);

    void settle() {
      attempt.inFlight = false;
      // Remove only this operation; a new session may already use this scope.
      pending[scope]?.remove(send);
      if (pending[scope]?.isEmpty ?? false) pending.remove(scope);
    }

    Future<bool> accepted([ComposerReceipt? receipt]) async {
      settle();
      if (!sessionCurrent()) return true;
      if (identical(attempts[scope], attempt)) {
        attempts.remove(scope);
        unawaited(persistAttempt(scope, null));
      }
      if (receipt != null && current()) visit.received(receipt);
      _publish(scope, receipt?.message);
      if (selectedFiles.any((file) => file.local != null)) {
        await persistDraft(scope);
        if (!sessionCurrent()) return true;
        await WorkspaceUploads.release(selectedFiles);
        if (!sessionCurrent()) return true;
      }
      return true;
    }

    bool failed([Object? cause]) {
      settle();
      if (!sessionCurrent()) return false;
      final currentText = drafts[scope] ?? '';
      drafts[scope] = _mergeFailed(text, currentText);
      if (selectedFiles.isNotEmpty) {
        uploads.byScope[scope] = [...selectedFiles, ...?uploads.byScope[scope]];
      }
      attempts[scope] = attempt;
      unawaited(
        persistAttempt(scope, attempt, channelId: visit.parentChannelId),
      );
      unawaited(persistDraft(scope));
      if (cause != null && current()) visit.failed(cause);
      _publish(scope);
      return false;
    }

    try {
      final id = await visit.prepare();
      if (id == null || !current()) return failed();
      send.channelId = id;
      if (fresh) {
        await persistAttempt(scope, attempt, channelId: visit.parentChannelId);
      }
      if (!current()) return failed();
      final timezone = await readTimezone?.call();
      if (!current()) return failed();
      final result = await client.sendWithReceipt(
        id,
        body,
        attachments: ids,
        mentions: mentions.isEmpty ? null : mentions,
        randomId: attempt.randomId,
        asTask: asTask,
        timezone: timezone,
      );
      send.confirmed = true;
      return await accepted((
        message: RaftMessage({
          ...result.message.json,
          'randomId': result.message.json['randomId'] ?? attempt.randomId,
        }),
        receipt: result.receipt,
      ));
    } catch (cause) {
      if (send.confirmed && sessionCurrent()) return accepted();
      return failed(cause);
    }
  }

  void retireScope(String scope) {
    pending.remove(scope);
    attempts.remove(scope);
    _queued.remove(scope);
    _localIds.removeWhere((_, owner) => owner == scope);
  }

  void clear() {
    pending.clear();
    attempts.clear();
    _queued.clear();
    _localIds.clear();
  }

  void dispose() {
    clear();
    _observers.clear();
  }
}

String _mergeFailed(String failed, String current) {
  if (current.isEmpty) return failed;
  if (failed.isEmpty) return current;
  return '$failed${failed.endsWith('\n') || current.startsWith('\n') ? '' : '\n'}$current';
}
