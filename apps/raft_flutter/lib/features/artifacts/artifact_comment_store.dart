import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:raft_client/raft_client.dart';

import '../../data/workspace_controller.dart';
import '../private_route_guard.dart';
import 'artifact_comment_api.dart';
import 'artifact_comment_models.dart';

class ArtifactCommentStore extends ChangeNotifier {
  ArtifactCommentStore(this.workspace, String id, {this.reviewId})
    : api = ArtifactCommentApi(workspace.client, id),
      authority = channelSearchPageAuthority(workspace),
      serverId = workspace.server?.id {
    final cached = _cache[workspace]?[_key];
    if (cached != null) {
      _rows.addAll(cached.rows);
      cursor = cached.cursor;
      review = cached.review;
      loaded = true;
    }
    _events = workspace.client.events.listen(_event);
    workspace.addListener(_scopeChanged);
    unawaited(refresh());
  }

  final WorkspaceController workspace;
  final ArtifactCommentApi api;
  final String authority;
  final String? serverId;
  String? reviewId;

  final _rows = <String, ArtifactComment>{};
  final _writesInFlight = <String>{};
  late final StreamSubscription<RaftEvent> _events;
  bool _disposed = false, _revoked = false;
  bool _reading = false, _queued = false;
  bool loaded = false,
      failed = false,
      earlierFailed = false,
      loadingEarlier = false;
  int _revision = 0;
  String? cursor;
  Map<String, Object?>? review;

  static final _cache =
      Expando<
        LinkedHashMap<
          (String, String, String?),
          ({
            Map<String, ArtifactComment> rows,
            String? cursor,
            Map<String, Object?>? review,
          })
        >
      >();

  (String, String, String?) get _key => (authority, api.artifactId, reviewId);
  bool get current =>
      !_disposed &&
      !_revoked &&
      channelSearchPageAuthority(workspace) == authority;

  List<ArtifactCommentThread> get threads {
    final ordered = _rows.values.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return artifactCommentThreads(ordered);
  }

  void _scopeChanged() {
    if (current || _disposed || _revoked) return;
    _revoked = true;
    _cache[workspace]?.clear();
    _rows.clear();
    review = null;
    cursor = null;
    notifyListeners();
  }

  void _event(RaftEvent event) {
    if (event.name == 'connected') {
      unawaited(refresh());
    } else if (event.name == 'activity:changed') {
      final payload = commentMap(event.payload);
      if (payload['serverId'] == null || payload['serverId'] == serverId) {
        unawaited(refresh());
      }
    }
  }

  void _save() {
    final cache = _cache[workspace] ??= LinkedHashMap();
    cache.remove(_key);
    cache[_key] = (rows: Map.of(_rows), cursor: cursor, review: review);
    if (cache.length > 24) cache.remove(cache.keys.first);
    notifyListeners();
  }

  void showAll() {
    if (reviewId == null) return;
    reviewId = null;
    review = null;
    cursor = null;
    loaded = false;
    _revision++;
    _rows.clear();
    notifyListeners();
    unawaited(refresh());
  }

  Future<void> refresh() async {
    if (!current) return;
    if (_reading) {
      _queued = true;
      return;
    }
    _reading = true;
    try {
      do {
        _queued = false;
        final revision = _revision;
        final filter = reviewId;
        try {
          if (failed) {
            failed = false;
            notifyListeners();
          }
          final result = await api.list(review: filter);
          if (!current) return;
          if (revision != _revision) {
            _queued = true;
            continue;
          }
          final first = result.comments.firstOrNull?.createdAt;
          final before = result.cursor != null && first != null
              ? _rows.values
                    .where((row) => row.createdAt.compareTo(first) < 0)
                    .toList()
              : const <ArtifactComment>[];
          _rows
            ..clear()
            ..addEntries([
              for (final row in [...before, ...result.comments])
                MapEntry(row.id, row),
            ]);
          cursor = before.isEmpty ? result.cursor : cursor;
          review = result.review;
          loaded = true;
          _save();
        } catch (_) {
          if (!current) return;
          if (!loaded && revision == _revision) {
            failed = true;
            notifyListeners();
          }
        }
      } while (_queued && current);
    } finally {
      _reading = false;
    }
  }

  Future<void> earlier() async {
    final before = cursor;
    if (!current || loadingEarlier || before == null) return;
    final filter = reviewId;
    loadingEarlier = true;
    earlierFailed = false;
    notifyListeners();
    try {
      final page = await api.list(before: before, review: filter);
      if (!current || reviewId != filter) return;
      for (final row in page.comments) {
        _rows.putIfAbsent(row.id, () => row);
      }
      cursor = page.cursor;
    } catch (_) {
      if (!current || reviewId != filter) return;
      earlierFailed = true;
    } finally {
      loadingEarlier = false;
      if (current) _save();
    }
  }

  void accept(Iterable<ArtifactComment> comments) {
    if (!current) return;
    _revision++;
    for (final comment in comments) {
      if (reviewId == null || reviewId == comment.reviewId) {
        _rows[comment.id] = comment;
      }
    }
    _save();
  }

  Future<ArtifactComment> send(ArtifactCommentInput input) async {
    _requireCurrent();
    final result = await api.post(input);
    if (result.replyTo case final parent?) {
      final root = threads
          .where(
            (thread) =>
                thread.id == parent ||
                thread.replies.any((row) => row.id == parent),
          )
          .firstOrNull
          ?.root;
      if (root?.resolvedAt != null) unawaited(refresh());
    }
    accept([result]);
    return result;
  }

  Future<void> edit(String id, List<ArtifactCommentPart> body) async {
    _requireCurrent();
    accept([await api.edit(id, body)]);
  }

  bool changing(String id) => _writesInFlight.contains(id);

  Future<void> changeThread(ArtifactComment root, bool resolved) async {
    _requireCurrent();
    if (!_writesInFlight.add(root.id)) return;
    notifyListeners();
    try {
      accept([await api.resolve(root.id, resolved)]);
    } finally {
      _writesInFlight.remove(root.id);
      if (current) notifyListeners();
    }
  }

  Future<void> delete(String id) async {
    _requireCurrent();
    await api.delete(id);
    if (!current) return;
    _revision++;
    if (_rows.values.any((row) => row.replyTo == id)) {
      await refresh();
    } else {
      _rows.remove(id);
      _save();
    }
  }

  void _requireCurrent() {
    if (!current) {
      throw const RaftApiException('Artifact is no longer available.');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    workspace.removeListener(_scopeChanged);
    unawaited(_events.cancel());
    super.dispose();
  }
}
