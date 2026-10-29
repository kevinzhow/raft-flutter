import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:raft_client/raft_client.dart';

import 'package:flutter/foundation.dart';

import 'shared_draft_attachment.dart';
import 'workspace_uploads.dart';
import 'workspace_sends.dart';

export 'workspace_sends.dart' show ComposerSendAttempt;

typedef ComposerRecordRead = Future<dynamic> Function(
  String kind,
  String scope,
);
typedef ComposerRecordWrite = Future<void> Function(
  String kind,
  String scope,
  dynamic value, {
  required bool requiredSuccess,
});
typedef ComposerStoredFile = ({
  SharedDraftAttachment local,
  String? id,
  Map<String, dynamic>? metadata,
});

/// One draft/attempt record owner for a session, borrowed by its editors.
/// Each conversation has its own signal; typing never notifies other scopes.
class WorkspaceComposer {
  WorkspaceComposer({
    required this._owner,
    required this._read,
    required this._write,
    Object Function()? authority,
  }) {
    uploads = WorkspaceUploads(
      changed: _changed,
      authority: () => (_epoch, authority?.call()),
    );
    sends = WorkspaceSends(
      drafts: drafts,
      uploads: uploads,
      captureScope: uploads.captureScope,
      persistDraft: saveScope,
      persistAttempt: saveAttempt,
      changed: _changed,
    );
  }

  final Object _owner;
  late final WorkspaceUploads uploads;
  final ComposerRecordRead _read;
  final ComposerRecordWrite _write;
  final _text = <String, String>{};
  final _signals = <String?, ValueNotifier<int>>{};
  late final WorkspaceSends sends;
  Map<String, ComposerSendAttempt> get attempts => sends.attempts;
  final shareTokens = <String, Set<String>>{};
  final revisions = <String, int>{};
  late final Map<String, String> drafts = _DraftMap(this);
  Future<void> _pending = Future<void>.value();
  int _epoch = 0;
  bool _closed = false;

  bool ownedBy(Object owner) => identical(owner, _owner);
  Future<void> get flushed => _pending;

  ValueListenable<int> changes(String? scope) =>
      _signals.putIfAbsent(scope, () => ValueNotifier<int>(0));

  void _textChanged(String scope) {
    revisions[scope] = (revisions[scope] ?? 0) + 1;
    _changed(scope);
  }

  void _changed(String scope) {
    final signal = _signals[scope];
    if (signal != null && !_closed) signal.value++;
  }

  Future<void> _save(
    String kind,
    String scope,
    dynamic value, {
    bool requiredSuccess = false,
  }) {
    if (_closed) return Future<void>.value();
    // The supplied writer retains the session's existing write/purge queue.
    final writing = _write(
      kind,
      scope,
      value,
      requiredSuccess: requiredSuccess,
    );
    _pending = Future.wait([_pending, writing])
        .then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return writing;
  }

  Future<void> saveScope(String scope, {bool requiredSuccess = false}) {
    final pending = sends.pending[scope] ?? const <ComposerPendingSend>[];
    final files = [
      ...?uploads.byScope[scope],
      for (final send in pending) ...send.uploads,
    ].where((file) => file.local != null);
    return saveDraft(
      scope,
      pendingText: pending.map((send) => send.draft),
      queuedText: sends.queuedText(scope),
      files: [
        for (final file in files)
          (local: file.local!, id: file.id, metadata: file.metadata),
      ],
      requiredSuccess: requiredSuccess,
    );
  }

  Future<void> saveDraft(
    String scope, {
    required Iterable<String> pendingText,
    required String queuedText,
    required List<ComposerStoredFile> files,
    bool requiredSuccess = false,
  }) => _save(
    'draft',
    scope,
    draftRecord(
      scope,
      pendingText: pendingText,
      queuedText: queuedText,
      files: files,
    ),
    requiredSuccess: requiredSuccess,
  );

  /// Encodes the existing disk format. Omitting files and share tokens gives
  /// revocation a snapshot containing only the user's unsent text.
  Map<String, dynamic>? draftRecord(
    String scope, {
    Iterable<String> pendingText = const [],
    String queuedText = '',
    List<ComposerStoredFile> files = const [],
    bool includeShareTokens = true,
  }) {
    final text = [
      if (files.isNotEmpty) ...pendingText,
      queuedText,
      drafts[scope] ?? '',
    ].where((s) => s.isNotEmpty).toSet().join('\n\n');
    return text.isEmpty && files.isEmpty
        ? null
        : {
            'text': text,
            'channelId': scope,
            'shareTokens': includeShareTokens
                ? shareTokens[scope]?.toList()
                : null,
            'files': [
              for (final file in files)
                {
                  'ref': file.local.reference,
                  'id': file.id,
                  'metadata': {
                    for (final key in [
                      'id',
                      'filename',
                      'mimeType',
                      'sizeBytes',
                    ])
                      if (file.metadata?.containsKey(key) == true)
                        key: file.metadata![key],
                  },
                },
            ],
          };
  }

  Future<void> saveAttempt(
    String scope,
    ComposerSendAttempt? attempt, {
    String? channelId,
  }) => _save(
    'attempt',
    scope,
    attempt == null
        ? null
        : {
            'fingerprint': attempt.fingerprint,
            'randomId': attempt.randomId,
            'channelId': channelId,
          },
  );

  Future<void> removeStoredDraft(String scope) => _save('draft', scope, null);

  Future<void> restore(
    String scope, {
    required bool Function() current,
    required Future<void> Function(List<Map> files) restoreFiles,
    required VoidCallback restored,
  }) async {
    final epoch = _epoch;
    bool accepted() => !_closed && epoch == _epoch && current();
    final value = await _read('draft', scope);
    if (!accepted() || drafts.containsKey(scope)) return;
    if (value is Map && value['text'] is String) {
      drafts[scope] = value['text'];
      if (value['shareTokens'] is List) {
        shareTokens[scope] = (value['shareTokens'] as List)
            .whereType<String>()
            .take(64)
            .toSet();
      }
      if (value['files'] is List) {
        await restoreFiles((value['files'] as List).whereType<Map>().toList());
      }
      if (!accepted()) return;
      restored();
    }
    final attempt = await _read('attempt', scope);
    if (accepted() && attempt is Map && !attempts.containsKey(scope)) {
      attempts[scope] = ComposerSendAttempt(
        attempt['fingerprint'],
        attempt['randomId'],
      );
    }
  }

  /// The existing thread-route path restores text only, without changing its
  /// attachment/attempt admission policy during this persistence extraction.
  Future<bool> restoreText(String scope, bool Function() current) async {
    final epoch = _epoch;
    final value = await _read('draft', scope);
    if (_closed || epoch != _epoch || !current() || drafts.containsKey(scope)) {
      return false;
    }
    if (value is! Map || value['text'] is! String) return false;
    drafts[scope] = value['text'];
    return true;
  }

  /// Stage local queued files without uploading or replacing the user's draft.
  Future<void> stageSharedDraft(
    String scope,
    String text,
    List<SharedDraftAttachment> files, {
    required ComposerUploadPersist persist,
    String? sourceToken,
  }) async {
    if (_closed) return;
    if (sourceToken != null &&
        (shareTokens[scope]?.contains(sourceToken) ?? false)) {
      return;
    }
    final list = uploads.byScope[scope] ??= [];
    final additions = files
        .where(
          (f) => !list.any(
            (u) =>
                u.local != null &&
                jsonEncode(u.local!.reference) == jsonEncode(f.reference),
          ),
        )
        .toList();
    if (list.length + additions.length > 10) {
      throw const RaftApiException('Attach up to 10 files per message.');
    }
    final previous = drafts[scope] ?? '', current = uploads.captureScope(scope);
    final staged = additions
        .map((file) => UploadDraft.shared(file, key: uploads.nextKey++))
        .toList();
    list.addAll(staged);
    final next = text.trim();
    if (next.isNotEmpty && previous.trim() != next) {
      drafts[scope] = previous.isEmpty ? next : '$previous\n\n$next';
    }
    final stagedText = drafts[scope] ?? '';
    if (sourceToken != null) {
      final tokens = shareTokens[scope] ??= {};
      tokens.add(sourceToken);
      if (tokens.length > 64) tokens.remove(tokens.first);
    }
    try {
      await persist(scope, requiredSuccess: true);
    } catch (_) {
      if (current()) {
        list.removeWhere(staged.contains);
        if ((drafts[scope] ?? '') == stagedText) {
          drafts[scope] = previous;
        }
        shareTokens[scope]?.remove(sourceToken);
        _changed(scope);
      }
      rethrow;
    }
    if (!current()) return;
    revisions[scope] = (revisions[scope] ?? 0) + 1;
    _changed(scope);
  }

  /// Replace a local DM destination after resolution. A null hold is still
  /// an active membership check and must move with the draft.
  void adoptScope(String from, String to) {
    if (_closed || from == to) return;
    uploads.revokeScope(from, keepFiles: true);
    sends.retireScope(from);
    final text = drafts.remove(from), files = uploads.byScope.remove(from);
    if (text != null && text.isNotEmpty) {
      final held = drafts[to] ?? '';
      drafts[to] = held.isEmpty ? text : '$held\n\n$text';
    }
    if (files != null) {
      for (final file in files.where((file) => file.id == null)) {
        file.cancel = UploadCancellation();
        file.checking = false;
        file.queued = file.local != null;
        file.canRetry = true;
        file.error = file.queued ? null : 'Upload interrupted. Tap to retry.';
      }
      (uploads.byScope[to] ??= []).addAll(files);
    }
    final tokens = shareTokens.remove(from);
    if (tokens != null) (shareTokens[to] ??= {}).addAll(tokens);
    if (uploads.holds.containsKey(from)) {
      uploads.holds[to] = uploads.holds.remove(from);
    }
    revisions.remove(from);
    revisions[to] = (revisions[to] ?? 0) + 1;
    _changed(to);
    _signals.remove(from)?.dispose();
    unawaited(removeStoredDraft(from));
    unawaited(saveAttempt(from, null));
    unawaited(saveScope(to));
  }

  void retireScope(String scope, {bool keepFiles = false}) {
    uploads.revokeScope(scope, keepFiles: keepFiles);
    sends.retireScope(scope);
    _signals.remove(scope)?.dispose();
  }

  void _clearSignals() {
    for (final signal in _signals.values) {
      signal.dispose();
    }
    _signals.clear();
  }

  void clearOwnedBy(Object owner) {
    if (!ownedBy(owner) || _closed) return;
    _epoch++;
    drafts.clear();
    uploads.clear();
    _clearSignals();
    sends.clear();
    revisions.clear();
    shareTokens.clear();
  }

  void disposeOwnedBy(Object owner) {
    if (!ownedBy(owner) || _closed) return;
    _closed = true;
    _epoch++;
    _text.clear();
    uploads.dispose();
    sends.dispose();
    revisions.clear();
    shareTokens.clear();
    _clearSignals();
  }
}

class _DraftMap extends MapBase<String, String> {
  _DraftMap(this.owner);
  final WorkspaceComposer owner;
  @override
  String? operator [](Object? key) => owner._text[key];
  @override
  Iterable<String> get keys => owner._text.keys;
  @override
  void operator []=(String key, String value) {
    if (owner._closed || owner._text[key] == value) return;
    owner._text[key] = value;
    owner._textChanged(key);
  }

  @override
  String? remove(Object? key) {
    final previous = owner._text.remove(key);
    if (previous != null && key is String) owner._textChanged(key);
    return previous;
  }

  @override
  void clear() {
    for (final key in keys.toList()) {
      remove(key);
    }
  }
}
