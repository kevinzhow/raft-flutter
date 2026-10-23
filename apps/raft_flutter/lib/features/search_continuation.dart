import 'dart:convert';

/// Web MessageSearchPage `SearchContinuation`: a recent-sort text search can
/// stop at the server's scan budget before a page fills (`incomplete`). What
/// is on screen is then not every match, and the search continues from
/// `nextCursor` (`MessageSearchContinueHint`). The cursor also pages a
/// complete page, so a cursor continues exactly below what was shown where an
/// offset would restart the server's scan from the newest message.
class SearchContinuation {
  const SearchContinuation({
    this.cursor,
    this.incomplete = false,
    this.searchedThrough,
  });

  static const none = SearchContinuation();

  /// `readSearchContinuation`: nothing without a cursor.
  factory SearchContinuation.read(Object? data) {
    final map = data is Map ? data : const {};
    final cursor = map['nextCursor'];
    if (cursor is! String || cursor.isEmpty) return none;
    final through = map['searchedThrough'];
    return SearchContinuation(
      cursor: cursor,
      incomplete: map['incomplete'] == true,
      searchedThrough: through is String ? DateTime.tryParse(through) : null,
    );
  }

  final String? cursor;
  final bool incomplete;

  /// The oldest message time the walk read.
  final DateTime? searchedThrough;

  /// `searchIncomplete`: the server stopped early and can go on.
  bool get pending => incomplete && cursor != null;
}

/// The continuation of each accepted search view (query, filters, sort and
/// time range, without the page window and the clock), so a view shown again
/// continues where it stopped.
class SearchContinuations {
  SearchContinuations(this._range);
  static const maxViews = 8;
  final String Function() _range;
  final _byView = <String, SearchContinuation>{};

  /// A request's `view` key (ResourceFilters.viewKey) with the clock-derived
  /// `after` / `before` replaced by the chosen range: the relative window moves
  /// with every request but the view stays the same.
  String _key(String view) {
    final decoded = jsonDecode(view) as List;
    final params = {...(decoded[1] as Map<String, dynamic>)}
      ..remove('after')
      ..remove('before');
    return jsonEncode([decoded[0], params, _range()]);
  }

  SearchContinuation of(String? view) => view == null
      ? SearchContinuation.none
      : _byView[_key(view)] ?? SearchContinuation.none;

  /// Records what the answer for [view] says; true while the search is
  /// incomplete and can continue (the list then offers it like "Load More").
  bool accept(String view, Object? answer) {
    final key = _key(view), next = SearchContinuation.read(answer);
    _byView.remove(key);
    if (next.cursor != null) {
      _byView[key] = next;
      while (_byView.length > maxViews) {
        _byView.remove(_byView.keys.first);
      }
    }
    return next.pending;
  }
}
