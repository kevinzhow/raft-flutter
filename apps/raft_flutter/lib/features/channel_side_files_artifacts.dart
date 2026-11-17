// The conversation's own Artifacts, as its Files panel shows them above the
// files (workspace_artifacts_v0).
//
// Source: packages/web/src/apps/artifacts/conversationArtifacts.ts
// (`useConversationArtifacts`) at v1.24.0-source.1: the first page when
// shown (and again on Retry), the next on Show More. Unlike Web, which reads
// on every mount, one store per conversation outlives the panel: a revisit
// paints the rows it holds and reads the first page again behind them
// (docs: panel revisit), so only the first read ever shows "loading".
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:raft_client/raft_client.dart';

import '../data/workspace_controller.dart';
import 'artifacts/artifact_api.dart' show artifactErrorCode;
import 'artifacts/artifact_models.dart';
import 'artifacts/artifact_session.dart';

enum ConversationArtifactsStatus { hidden, loading, failed, ready }

enum ConversationArtifactsMore { idle, loading, failed }

typedef ConversationArtifactsGet = Future<Object?> Function(String path);

/// The route (`artifactWebPaths.conversationArtifacts`; the client adds the
/// `/api` prefix itself).
String conversationArtifactsPath(String conversationId, [String? cursor]) =>
    '/artifacts/conversations/${Uri.encodeComponent(conversationId)}'
    '${cursor == null ? '' : '?cursor=${Uri.encodeQueryComponent(cursor)}'}';

class ConversationArtifactsStore extends ChangeNotifier {
  ConversationArtifactsStore({
    required this.conversationId,
    required this.get,
    required this.enabled,
    required this.authority,
  }) : _authority = authority();

  /// The store [w] keeps for [conversationId], created on first use and
  /// disposed with the session.
  static ConversationArtifactsStore of(
    WorkspaceController w,
    String conversationId,
  ) {
    final owned = _owners[w] ??= () {
      final map = <String, ConversationArtifactsStore>{};
      w.services.disposeWithSession(() {
        for (final store in map.values) {
          store.dispose();
        }
        map.clear();
      });
      return map;
    }();
    return owned[conversationId] ??= () {
      final session = ArtifactSession.of(w);
      return ConversationArtifactsStore(
        conversationId: conversationId,
        get: session.api.client.get,
        enabled: () => session.enabled,
        authority: () => session.generation,
      );
    }();
  }

  static final _owners = Expando<Map<String, ConversationArtifactsStore>>(
    'conversation artifacts',
  );

  final String conversationId;
  final ConversationArtifactsGet get;

  /// workspace_artifacts_v0 for the server (Web `useWorkspaceArtifactsEnabled`).
  final bool Function() enabled;

  /// Changes when the account or server does: what was read is dropped.
  final Object? Function() authority;

  Object? _authority;
  int _ticket = 0;
  bool _disposed = false;
  // 403 ARTIFACTS_NOT_ENABLED: Artifacts are off for this server.
  bool _forbidden = false;
  ConversationArtifactsStatus _state = ConversationArtifactsStatus.loading;
  List<ArtifactCard> _cards = const [];
  String? _nextCursor;
  ConversationArtifactsMore more = ConversationArtifactsMore.idle;

  ConversationArtifactsStatus get status =>
      !enabled() || _forbidden ? ConversationArtifactsStatus.hidden : _state;
  List<ArtifactCard> get cards => _cards;
  String? get nextCursor => _nextCursor;

  void _syncAuthority() {
    final current = authority();
    if (current == _authority) return;
    _authority = current;
    _ticket++;
    _forbidden = false;
    _state = ConversationArtifactsStatus.loading;
    _cards = const [];
    _nextCursor = null;
    more = ConversationArtifactsMore.idle;
  }

  /// Reads the first page. Rows already held stay on screen and are replaced
  /// in place; a read that fails then keeps them.
  Future<void> load() async {
    _syncAuthority();
    if (!enabled()) return;
    final ticket = ++_ticket;
    try {
      final page = _page(await get(conversationArtifactsPath(conversationId)));
      if (!_current(ticket)) return;
      _forbidden = false;
      if (_state == ConversationArtifactsStatus.ready) {
        _replaceFirstPage(page.cards, page.next);
      } else {
        _cards = page.cards;
        _nextCursor = page.next;
        more = ConversationArtifactsMore.idle;
      }
      _state = ConversationArtifactsStatus.ready;
    } catch (error) {
      if (!_current(ticket)) return;
      final code = error is RaftApiException ? artifactErrorCode(error) : null;
      if (code == 'ARTIFACTS_NOT_ENABLED') {
        _forbidden = true;
      } else if (code == 'TARGET_NOT_FOUND') {
        _forbidden = false;
        _cards = const [];
        _nextCursor = null;
        _state = ConversationArtifactsStatus.ready;
      } else if (_state != ConversationArtifactsStatus.ready) {
        _state = ConversationArtifactsStatus.failed;
      }
    }
    _notify();
  }

  /// Retry after a failed first read: back to "loading", then the read.
  Future<void> retry() {
    _syncAuthority();
    _state = ConversationArtifactsStatus.loading;
    _notify();
    return load();
  }

  /// Show More: the next page, onto the list it was asked for (the same read,
  /// still at this cursor).
  Future<void> showMore() async {
    final cursor = _nextCursor;
    if (status != ConversationArtifactsStatus.ready ||
        cursor == null ||
        more == ConversationArtifactsMore.loading) {
      return;
    }
    final ticket = _ticket;
    more = ConversationArtifactsMore.loading;
    _notify();
    bool same() => _current(ticket) && _nextCursor == cursor;
    try {
      final page = _page(
        await get(conversationArtifactsPath(conversationId, cursor)),
      );
      if (!same()) return;
      final known = {for (final card in _cards) card.id};
      _cards = List.unmodifiable([
        ..._cards,
        for (final card in page.cards)
          if (!known.contains(card.id)) card,
      ]);
      _nextCursor = page.next;
      more = ConversationArtifactsMore.idle;
    } catch (_) {
      if (!same()) return;
      more = ConversationArtifactsMore.failed;
    }
    _notify();
  }

  bool _current(int ticket) =>
      !_disposed && ticket == _ticket && authority() == _authority;

  ({List<ArtifactCard> cards, String? next}) _page(Object? data) {
    final rows = data is Map ? data['rows'] : null;
    final next = data is Map ? data['nextCursor'] : null;
    if (rows is! List || (next != null && next is! String)) {
      throw const FormatException('Invalid Artifacts response.');
    }
    final cards = <ArtifactCard>[];
    for (final row in rows) {
      final card = row is Map ? ArtifactCard.fromJson(row['card']) : null;
      if (card != null) cards.add(card);
    }
    return (cards: List.unmodifiable(cards), next: next as String?);
  }

  /// A refreshed first page replaces the rows it covers; rows already paged
  /// in beyond it stay, with their cursor.
  void _replaceFirstPage(List<ArtifactCard> page, String? pageCursor) {
    final tail = <ArtifactCard>[];
    var cursor = pageCursor;
    if (page.isNotEmpty && pageCursor != null && _cards.length > page.length) {
      final ids = {for (final card in page) card.id};
      final at = _cards.indexWhere((card) => card.id == page.last.id);
      if (at >= 0) {
        for (final card in _cards.skip(at + 1)) {
          if (!ids.contains(card.id)) tail.add(card);
        }
        if (tail.isNotEmpty) cursor = _nextCursor;
      }
    }
    _cards = List.unmodifiable([...page, ...tail]);
    _nextCursor = cursor;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _ticket++;
    super.dispose();
  }
}
