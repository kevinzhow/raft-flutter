import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:raft_client/raft_client.dart';

import '../../data/cause_notice.dart';
import 'artifact_comment_models.dart';
import 'artifact_comment_store.dart';

final class ArtifactReviewDraft {
  ArtifactReviewDraft.fromJson(Map<String, Object?> row)
    : id = row['id'] as String,
      version = row['version'] as int,
      place = ArtifactCommentPlace.fromJson(row['target']),
      replyTo = row['replyTo'] as String?,
      body = readCommentBody(row['body']),
      images = commentRows(row['images'])
          .map((image) => image['fileId'])
          .whereType<String>()
          .toList();

  final String id;
  final int version;
  final ArtifactCommentPlace place;
  final String? replyTo;
  final List<ArtifactCommentPart> body;
  final List<String> images;
}

final class ArtifactReviewStore extends ChangeNotifier {
  ArtifactReviewStore(this.discussion) {
    unawaited(load());
  }

  final ArtifactCommentStore discussion;
  final _drafts = <String, ArtifactReviewDraft>{};
  final problem = CauseNotice();
  (int, String)? _attempt;
  bool _disposed = false;
  bool loaded = false, failed = false, busy = false;
  bool _reading = false;
  bool get _current => !_disposed && discussion.current;
  List<ArtifactReviewDraft> get drafts => List.unmodifiable(_drafts.values);
  RaftClient get _client => discussion.api.client;
  String get _path => '${discussion.api.path}/review/drafts';
  String _draftPath(String id) => '$_path/${Uri.encodeComponent(id)}';

  Future<void> load() async {
    if (!_current || _reading) return;
    _reading = true;
    failed = false;
    notifyListeners();
    try {
      final result = commentMap(await _client.get(_path));
      if (!_current) return;
      final rows = commentRows(result['drafts'])
          .map(ArtifactReviewDraft.fromJson);
      _drafts
        ..clear()
        ..addEntries(rows.map((draft) => MapEntry(draft.id, draft)));
      loaded = true;
    } catch (_) {
      failed = !loaded;
    } finally {
      _reading = false;
      if (_current) notifyListeners();
    }
  }

  Future<void> save(ArtifactCommentInput input) => _change(() async {
    final result = commentMap(await _client.post(_path, data: input.toJson()));
    if (!_current) return;
    final draft = ArtifactReviewDraft.fromJson(commentMap(result['draft']));
    _drafts[draft.id] = draft;
  });

  Future<void> edit(String id, List<ArtifactCommentPart> body) =>
      _change(() async {
        final result = commentMap(
          await _client.patch(
            _draftPath(id),
            data: {'body': body.map((part) => part.toJson()).toList()},
          ),
        );
        if (!_current) return;
        final draft = ArtifactReviewDraft.fromJson(commentMap(result['draft']));
        _drafts[draft.id] = draft;
      });

  Future<void> delete(String? id) => _change(() async {
    await _client.delete(id == null ? _path : _draftPath(id));
    if (!_current) return;
    if (id == null) {
      _drafts.clear();
    } else {
      _drafts.remove(id);
    }
  });

  Future<void> _change(Future<void> Function() write) async {
    if (!_current || busy || !loaded || _reading) {
      throw const RaftApiException('The drafts are unavailable.');
    }
    busy = true;
    problem.clear();
    notifyListeners();
    try {
      await write();
      _attempt = null;
    } finally {
      busy = false;
      if (_current) notifyListeners();
    }
  }

  Future<void> submit(int version) async {
    if (!_current || busy || _drafts.isEmpty || _reading) return;
    if (_attempt?.$1 != version) {
      final random = Random.secure();
      _attempt = (
        version,
        List.generate(
          16,
          (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
        ).join(),
      );
    }
    final key = _attempt!.$2;
    busy = true;
    problem.clear();
    notifyListeners();
    try {
      final response = commentMap(
        await _client.post(
          '${discussion.api.path}/review/submit',
          data: {'version': version, 'summary': null, 'clientKey': key},
        ),
      );
      if (!_current) return;
      if (response['status'] != 'ok') {
        problem.raise("Couldn't send. Your drafts are kept; try again.");
        return;
      }
      discussion.accept(
        commentRows(response['comments']).map(ArtifactComment.fromJson),
      );
      _drafts.clear();
      _attempt = null;
    } on RaftApiException catch (error) {
      if (!_current) return;
      switch (error.code) {
        case 'NO_DRAFTS':
          _attempt = null;
          await load();
          if (_current) {
            problem.raise('No drafts to send: they were sent or discarded.');
            unawaited(discussion.refresh());
          }
        case 'CLIENT_KEY_REUSED':
          _attempt = null;
          await load();
          if (_current) {
            problem.raise('These drafts were already sent.');
            unawaited(discussion.refresh());
          }
        case 'DRAFTS_CHANGED':
          _attempt = null;
          await load();
          if (_current) {
            problem.raise(
              "Your drafts changed while this was being sent, so nothing was sent. They're up to date now: check them and send again.",
            );
          }
        case 'COMMENT_NOT_FOUND':
          problem.raise(
            'The comment this draft replies to was deleted. Delete the draft.',
          );
        case 'MENTION_NOT_VISIBLE':
          problem.raise(
            "Someone this draft mentions can't see this Artifact. Remove the mention or delete the draft.",
          );
        case 'FILE_NOT_FOUND':
          problem.raise(
            "The file this draft is on isn't in the Artifact any more. Delete the draft.",
          );
        case 'VERSION_NOT_FOUND':
          problem.raise(
            "Nothing was sent: this version can't be reviewed any more. Open the current version and send again.",
          );
        default:
          problem.raise("Couldn't send. Your drafts are kept; try again.");
      }
    } catch (_) {
      if (_current) {
        problem.raise("Couldn't send. Your drafts are kept; try again.");
      }
    } finally {
      busy = false;
      if (_current) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
