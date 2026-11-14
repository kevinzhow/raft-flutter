// What an attachment was saved as, and saving one.
//
// Source: packages/web/src/apps/artifacts/{ArtifactAttachment.tsx,
// artifactAttachmentSaves.ts} and components/message/
// artifactAttachmentSaved.ts at v1.24.0-source.1: messages carry nothing
// about Artifacts, so the attachments on screen are asked together
// (`attachmentSaves`, up to 50 a request, requests of one tick batched); the
// saver's own answer bridges the round trip; `artifact:attachment-saved`
// (channelId, messageId, attachmentId; no Artifact, who may see it differs
// per person) asks again for that attachment.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:raft_client/raft_client.dart';

import 'artifact_api.dart';

/// Web `ARTIFACT_SAVE_MAX_TEXT_BYTES` / `ARTIFACT_SAVE_MAX_BINARY_BYTES`.
const artifactSaveMaxTextBytes = 16 * 1024 * 1024;
const artifactSaveMaxBinaryBytes = 15 * 1024 * 1024;

/// Web `ARTIFACT_ATTACHMENT_SAVES_MAX_IDS`.
const artifactAttachmentSavesMaxIds = 50;

/// Extensions served as UTF-8 text (shared `artifactFileType(...).text`).
const _textExtensions = {
  'html', 'htm', 'md', 'markdown', 'txt', 'csv', 'tsv', 'css', 'js', 'mjs', //
  'json', 'xml', 'yaml', 'yml', 'svg',
};

/// Web `canSaveAsArtifact`: any type, except one still uploading or larger
/// than an Artifact file may be (the server answers 422 ATTACHMENT_NOT_SAVABLE).
bool canSaveAsArtifact({
  required String id,
  required String filename,
  required int sizeBytes,
}) {
  if (id.startsWith('optimistic-att-')) return false;
  final name = filename.substring(filename.lastIndexOf('/') + 1);
  final dot = name.lastIndexOf('.');
  final text =
      dot > 0 &&
      _textExtensions.contains(name.substring(dot + 1).toLowerCase());
  return sizeBytes <=
      (text ? artifactSaveMaxTextBytes : artifactSaveMaxBinaryBytes);
}

/// Why a save failed (the i18n id of Web's `SaveFailureReason`).
enum ArtifactSaveFailure { uploading, tooLarge, notFound, quota, failed }

/// A save under way, or the last one that failed.
class ArtifactSaveAttempt {
  const ArtifactSaveAttempt.saving() : failure = null;
  const ArtifactSaveAttempt.failed(ArtifactSaveFailure this.failure);
  final ArtifactSaveFailure? failure;
  bool get saving => failure == null;

  /// Trying again can help (Web `retry`): not for one too large, gone, or out
  /// of quota.
  bool get retryable =>
      failure == ArtifactSaveFailure.uploading ||
      failure == ArtifactSaveFailure.failed;
}

/// What happened to one [AttachmentSaves.save].
enum ArtifactSaveOutcome { created, existing, hidden, failed, ignored }

class AttachmentSaves extends ChangeNotifier {
  AttachmentSaves({required this.api});

  final ArtifactApi api;

  final _fetched = <String, ArtifactAttachmentSave?>{};
  final _savedHere = <String, ArtifactAttachmentSave>{};
  final _attempts = <String, ArtifactSaveAttempt>{};
  final _pending = <String>{};
  final _inFlight = <String>{};
  bool _scheduled = false;
  bool _ended = false;
  int _generation = 0;

  /// The line under [id]: the server's answer wins (it may be newer: deleted,
  /// moved out of reach); absent or null means not known (yet).
  ArtifactAttachmentSave? savedAs(String id) => _fetched[id] ?? _savedHere[id];

  ArtifactSaveAttempt? attempt(String id) => _attempts[id];

  /// Whether [id] was ever asked of the server (or saved here).
  bool knows(String id) =>
      _fetched.containsKey(id) ||
      _inFlight.contains(id) ||
      _pending.contains(id);

  /// Ask what these attachments were saved as; [again] asks even for ones
  /// already known. Requests of one tick go out together.
  void request(Iterable<String> ids, {bool again = false}) {
    for (final id in ids) {
      if (!again && (_fetched.containsKey(id) || _inFlight.contains(id))) {
        continue;
      }
      _pending.add(id);
    }
    if (_pending.isEmpty || _scheduled || _ended) return;
    _scheduled = true;
    // ignore: raft_lints/avoid_unreviewed_idle_work -- one microtask per batch, only after a request; it batches the same turn's asks (Web setTimeout 0) and ends.
    scheduleMicrotask(_flush);
  }

  Future<void> _flush() async {
    _scheduled = false;
    if (_ended) return;
    final ids = _pending.toList();
    _pending.clear();
    final asked = _generation;
    for (var i = 0; i < ids.length; i += artifactAttachmentSavesMaxIds) {
      final chunk = ids.skip(i).take(artifactAttachmentSavesMaxIds).toList();
      _inFlight.addAll(chunk);
      unawaited(() async {
        try {
          final answered = await api.attachmentSaves(chunk);
          if (asked != _generation || _ended) return;
          for (final id in chunk) {
            _fetched[id] = answered[id];
          }
          notifyListeners();
        } catch (_) {
          // A failed lookup shows no line; the next mount asks again.
        } finally {
          if (asked == _generation) _inFlight.removeAll(chunk);
        }
      }());
    }
  }

  /// Save [id] as an Artifact, no dialog: named after the file, at home where
  /// the attachment is. One save per attachment at a time.
  Future<({ArtifactSaveOutcome outcome, String? title})> save(String id) async {
    if (_attempts[id]?.saving == true) {
      return (outcome: ArtifactSaveOutcome.ignored, title: null);
    }
    final generation = _generation;
    _attempts[id] = const ArtifactSaveAttempt.saving();
    notifyListeners();
    try {
      final saved = await api.saveAttachment(id);
      if (generation != _generation || _ended) {
        return (outcome: ArtifactSaveOutcome.ignored, title: null);
      }
      // One batch: the saving line becomes the saved line in the same frame.
      _savedHere[id] = ArtifactAttachmentSave(card: saved.card);
      _attempts.remove(id);
      notifyListeners();
      // No event tells this client: ask the server's answer for the line.
      request([id], again: true);
      return (
        outcome: saved.created
            ? ArtifactSaveOutcome.created
            : ArtifactSaveOutcome.existing,
        title: saved.card.title,
      );
    } catch (error) {
      if (generation != _generation || _ended) {
        return (outcome: ArtifactSaveOutcome.ignored, title: null);
      }
      final code = error is RaftApiException ? error.code : null;
      if (code == 'ALREADY_SAVED') {
        // Saved, as one this person can't see: nothing to show under it.
        _attempts.remove(id);
        notifyListeners();
        return (outcome: ArtifactSaveOutcome.hidden, title: null);
      }
      // The refusal's `reason` is not among the error details this client
      // keeps; an upload under way is never offered a save (optimistic id).
      _attempts[id] = ArtifactSaveAttempt.failed(
        code == 'ATTACHMENT_NOT_SAVABLE'
            ? ArtifactSaveFailure.tooLarge
            : code == 'ATTACHMENT_NOT_FOUND'
            ? ArtifactSaveFailure.notFound
            : code == 'FILE_UPLOAD_QUOTA_EXCEEDED'
            ? ArtifactSaveFailure.quota
            : ArtifactSaveFailure.failed,
      );
      notifyListeners();
      return (outcome: ArtifactSaveOutcome.failed, title: null);
    }
  }

  /// `artifact:attachment-saved`: ask again for an attachment this client
  /// shows (one nobody here showed is read when it is first shown).
  void saved(String attachmentId) {
    if (knows(attachmentId)) request([attachmentId], again: true);
  }

  /// A server or person switch: every answer belongs to the last one.
  void clear() {
    _generation++;
    _fetched.clear();
    _savedHere.clear();
    _attempts.clear();
    _pending.clear();
    _inFlight.clear();
    if (!_ended) notifyListeners();
  }

  @override
  void dispose() {
    _ended = true;
    super.dispose();
  }
}
