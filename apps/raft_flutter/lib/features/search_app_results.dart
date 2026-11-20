import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import 'artifacts/artifact_models.dart';
import 'artifacts/artifact_session.dart';
import 'artifacts/artifact_text.dart';
import 'private_route_guard.dart';
import 'search_highlight.dart';

enum SearchAppStatus { idle, loading, ready, failed, timedOut }

typedef _SearchSnapshot = ({String authority, String query, _AppPage page});

class _AppPage {
  const _AppPage(this.status, {this.hits = const [], this.cursor});

  static _AppPage? read(Object? answer) {
    final groups = answer is Map ? answer['groups'] : null;
    if (groups is! List) return null;
    final group = groups
        .whereType<Map>()
        .where((group) => group['app'] == SearchAppResults.app)
        .firstOrNull;
    if (group == null) return null;
    final items = group['items'];
    if (items is! List) {
      return _AppPage(
        group['error'] == 'timeout'
            ? SearchAppStatus.timedOut
            : SearchAppStatus.failed,
      );
    }
    final hits = <String, ArtifactCard>{};
    for (final item in items.whereType<Map>()) {
      final card = ArtifactCard.fromJson(item['card']);
      if (card != null) hits.putIfAbsent(card.id, () => card);
    }
    final cursor = group['nextCursor'];
    return _AppPage(
      SearchAppStatus.ready,
      hits: hits.values.toList(growable: false),
      cursor: cursor is String && cursor.isNotEmpty ? cursor : null,
    );
  }

  final SearchAppStatus status;
  final List<ArtifactCard> hits;
  final String? cursor;

  _AppPage append(_AppPage next) {
    final shown = hits.map((card) => card.id).toSet();
    return _AppPage(
      SearchAppStatus.ready,
      hits: [...hits, ...next.hits.where((card) => shown.add(card.id))],
      cursor: next.cursor,
    );
  }
}

class SearchAppResults extends ChangeNotifier {
  SearchAppResults(this.workspace, this.field, {this.previewLimit}) {
    field.addListener(_update);
    workspace.addListener(_update);
    _update();
  }

  static const app = 'artifacts';
  static const label = 'Artifacts';
  static final _cache = Expando<Map<int?, _SearchSnapshot>>();
  static String keyOf(ArtifactCard card) => 'app:$app:${card.id}';

  final WorkspaceController workspace;
  final TextEditingController field;
  ArtifactSession? _artifacts;
  final int? previewLimit;
  _AppPage? _page;
  Timer? _debounce;
  int _generation = 0;
  String? _authority;
  String query = '';
  bool paging = false;
  bool _refreshing = false;
  SearchAppStatus _status = SearchAppStatus.idle;

  List<ArtifactCard> get hits {
    final cards = _page?.hits ?? const <ArtifactCard>[];
    final limit = previewLimit;
    return limit == null || cards.length <= limit
        ? cards
        : cards.take(limit).toList(growable: false);
  }

  SearchAppStatus get status => _page?.status ?? _status;
  bool get hasGroup => _page != null;
  bool get hasMore => !isPreview && _page?.cursor != null;
  bool get isPreview => previewLimit != null;

  String get serverName => workspace.server?.string('name') ?? '';

  void _update() {
    final authority = directoryAuthority(workspace);
    final authorityChanged = authority != _authority;
    final value = field.value;
    if (!authorityChanged &&
        _artifacts?.enabled == true &&
        value.isComposingRangeValid) {
      return;
    }
    final words = value.isComposingRangeValid ? '' : value.text.trim();
    if (words.isNotEmpty && words.runes.length <= 200 && _artifacts == null) {
      _artifacts = ArtifactSession.of(workspace)..addListener(_update);
    }
    final enabled = _artifacts?.enabled == true;
    final next = enabled && words.runes.length <= 200 ? words : '';
    if (!authorityChanged && next == query) return;
    _authority = authority;
    query = next;
    _debounce?.cancel();
    final ticket = ++_generation;
    paging = _refreshing = false;
    final snapshots = _cache[workspace];
    final saved = snapshots?[previewLimit];
    if (!enabled || (saved != null && saved.authority != authority)) {
      snapshots?.remove(previewLimit);
    }
    _page = null;
    _status = SearchAppStatus.idle;
    if (next.isNotEmpty) {
      if (saved?.authority == authority && saved?.query == next) {
        _page = saved?.page;
        _status = SearchAppStatus.ready;
      } else {
        _status = SearchAppStatus.loading;
        if (saved?.authority == authority) {
          _page = const _AppPage(SearchAppStatus.loading);
        }
        _debounce = Timer(
          const Duration(milliseconds: 200),
          () => unawaited(_load(ticket)),
        );
      }
    }
    notifyListeners();
  }

  bool _current(int ticket) =>
      ticket == _generation &&
      _authority == directoryAuthority(workspace) &&
      _artifacts?.enabled == true;

  Future<_AppPage?> _request({bool grouped = false, String? cursor}) async =>
      _AppPage.read(
        await workspace.query(
          '/search',
          query: {
            'q': query,
            'limit': ?previewLimit,
            if (grouped) 'app': app,
            'cursor': ?cursor,
          },
        ),
      );

  void _remember() {
    final page = _page;
    if (page == null || page.status != SearchAppStatus.ready) {
      _cache[workspace]?.remove(previewLimit);
      return;
    }
    (_cache[workspace] ??= {})[previewLimit] = (
      authority: _authority!,
      query: query,
      page: page,
    );
  }

  Future<void> _load(int ticket, {bool grouped = false}) async {
    try {
      final page = await _request(grouped: grouped);
      if (!_current(ticket)) return;
      _page = page;
      _status = SearchAppStatus.ready;
      _remember();
    } catch (error) {
      if (!_current(ticket)) return;
      final refused =
          error is RaftApiException &&
          (grouped ? error.status == 404 : error.status == 400);
      _status = refused ? SearchAppStatus.ready : SearchAppStatus.failed;
      _page = refused || _page == null ? null : _AppPage(_status);
      _remember();
    }
    notifyListeners();
  }

  void retry() {
    final ticket = _generation;
    if (query.isEmpty ||
        !_current(ticket) ||
        (status != SearchAppStatus.failed &&
            status != SearchAppStatus.timedOut)) {
      return;
    }
    final grouped = hasGroup;
    _status = SearchAppStatus.loading;
    if (grouped) _page = const _AppPage(SearchAppStatus.loading);
    notifyListeners();
    unawaited(_load(ticket, grouped: grouped));
  }

  Future<bool> loadMore() async {
    final current = _page;
    final ticket = _generation;
    if (current == null || !hasMore || paging || !_current(ticket)) return true;
    paging = true;
    notifyListeners();
    try {
      final next = await _request(grouped: true, cursor: current.cursor);
      if (!_current(ticket)) return true;
      if (next == null || next.status != SearchAppStatus.ready) return false;
      _page = current.append(next);
      _remember();
      return true;
    } catch (_) {
      return !_current(ticket);
    } finally {
      if (_current(ticket)) {
        paging = false;
        notifyListeners();
      }
    }
  }

  Future<void> refresh() async {
    final ticket = _generation;
    if (query.isEmpty ||
        _refreshing ||
        paging ||
        status == SearchAppStatus.loading ||
        !_current(ticket)) {
      return;
    }
    _refreshing = true;
    try {
      final page = await _request();
      if (!_current(ticket)) return;
      _status = SearchAppStatus.ready;
      _page = page;
      _remember();
      notifyListeners();
    } catch (_) {
      return;
    } finally {
      if (_current(ticket)) _refreshing = false;
    }
  }

  @override
  void dispose() {
    _generation++;
    _debounce?.cancel();
    workspace.removeListener(_update);
    field.removeListener(_update);
    _artifacts?.removeListener(_update);
    super.dispose();
  }
}

class SearchAppGroupSection extends StatelessWidget {
  const SearchAppGroupSection({
    super.key,
    required this.results,
    required this.selectedKey,
    required this.onOpen,
    this.wrapHit,
  });

  final SearchAppResults results;
  final String? selectedKey;
  final ValueChanged<ArtifactCard> onOpen;
  final Widget Function(String key, Widget row)? wrapHit;

  @override
  Widget build(BuildContext context) {
    final label = raftText(context, SearchAppResults.label);
    final grouped = results.hasGroup;
    final status = results.status;
    if (status == SearchAppStatus.idle ||
        (status == SearchAppStatus.ready && results.hits.isEmpty) ||
        (status == SearchAppStatus.loading && !grouped)) {
      return const SizedBox.shrink();
    }
    final failure = switch (status) {
      SearchAppStatus.timedOut => "Searching {app} took too long.",
      SearchAppStatus.failed =>
        grouped ? "Couldn't search {app}." : "Some results couldn't load.",
      _ => null,
    };
    final count = status == SearchAppStatus.ready ? results.hits.length : null;
    return RaftQuickSwitcherSection(
      heading: grouped ? (count == null ? label : '$label   $count') : null,
      children: [
        if (status == SearchAppStatus.loading)
          const RaftQuickSwitcherSkeleton()
        else if (failure != null)
          RaftBanner(
            description: raftFormat(context, failure, {'app': label}),
            glyph: RaftGlyph.triangleAlert,
            size: RaftBannerRecipeSize.sm,
            live: false,
            action: RaftButton(
              label: raftText(context, 'Retry'),
              uiVariant: RaftButtonVariant.outline,
              onPressed: results.retry,
            ),
          )
        else
          for (final card in results.hits)
            _hit(context, card, SearchAppResults.keyOf(card)),
        if (results.hasMore)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: RaftButton(
              label: raftText(
                context,
                results.paging ? 'Loading…' : 'Load more',
              ),
              uiVariant: RaftButtonVariant.ghost,
              onPressed: results.paging ? null : () => _more(context),
            ),
          ),
      ],
    );
  }

  Widget _hit(BuildContext context, ArtifactCard card, String key) {
    final tokens = RaftTokens.of(context);
    final recipe = RaftSearchRecipe(tokens, mobile: false);
    final subtitle = [
      artifactScopeLabel(
        context,
        card.home,
        fromAnotherServer: card.fromAnotherServer,
        serverName: results.serverName,
      ),
      artifactActorName(context, card.author),
      artifactRelativeTime(context, card.updatedAt),
    ].where((text) => text.isNotEmpty).join(' · ');
    final row = RaftSearchResultSurface(
      key: ValueKey(key),
      selected: selectedKey == key,
      entity: true,
      onPressed: () => onOpen(card),
      child: Row(
        spacing: RaftSpace.x3,
        children: [
          RaftQuickSwitcherIconBox(artifactKindGlyph(card.kind)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SearchHighlight(
                  text: card.title,
                  query: results.query,
                  style: recipe.strongEntityTitle,
                  maxLines: 1,
                ),
                Text(
                  subtitle,
                  style: recipe.metadata,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
    return wrapHit?.call(key, row) ?? row;
  }

  Future<void> _more(BuildContext context) async {
    if (await results.loadMore() || !context.mounted) return;
    showRaftToast(
      context,
      raftFormat(context, "Couldn't load more from {app}.", {
        'app': raftText(context, SearchAppResults.label),
      }),
      tone: RaftToastRecipeTone.warning,
    );
  }
}
