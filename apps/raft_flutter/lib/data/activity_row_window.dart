import 'dart:collection';

import 'resource_row_reconcile.dart';

/// Immutable row identities with a lookup that does not enumerate the window.
abstract class ResourceRowKeys extends ListBase<String?> {
  int? uniqueIndexOf(String key);
}

/// A lazy Activity projection that already owns its row identities.
abstract class IndexedActivityRows extends ListBase<Map<String, dynamic>> {
  ResourceRowKeys get rowKeys;
}

/// Accepted Activity rows, indexed by conversation and kept newest-first.
///
/// Both indexes are immutable balanced trees. A live preview replaces one row
/// and moves its rank, sharing all other branches with the previous window.
/// Saved snapshots, in-flight reconciles and a pressed row's order can therefore
/// retain the old window without copying it or observing later mutations.
class ActivityRowWindow extends IndexedActivityRows {
  factory ActivityRowWindow.from(List<Map<String, dynamic>> rows) {
    if (rows is ActivityRowWindow) return rows;
    final entries = <_Row>[];
    final lookups = <String, List<int>>{};
    for (final row in rows) {
      final entry = _Row(row);
      final rank = entries.length;
      entries.add(entry);
      for (final key in entry.lookups) {
        (lookups[key] ??= []).add(rank);
      }
    }
    final names = lookups.keys.toList()..sort();
    final lookup = _build(
      0,
      names.length,
      (i) => (names[i], lookups[names[i]]!),
    );
    return ActivityRowWindow._(
      _build(0, entries.length, (i) => (i, entries[i])),
      lookup,
      0,
      _ActivityKeys(
        _build(0, entries.length, (i) => (i, entries[i].key)),
        lookup,
      ),
    );
  }

  ActivityRowWindow._(this._order, this._lookup, this._front, this.rowKeys);

  final _Tree<int, _Row>? _order;
  final _Tree<String, List<int>>? _lookup;
  final int _front;
  @override
  final ResourceRowKeys rowKeys;

  @override
  int get length => _size(_order);
  @override
  Map<String, dynamic> operator [](int index) => _at(_order, index).value.row;
  @override
  Iterator<Map<String, dynamic>> get iterator =>
      _entries(_order).map((entry) => entry.value.row).iterator;
  @override
  set length(int value) => throw UnsupportedError('Immutable Activity window');
  @override
  void operator []=(int index, Map<String, dynamic> value) =>
      throw UnsupportedError('Immutable Activity window');

  /// Applies exactly the first loaded conversation advanced by this message,
  /// preserving the existing sequence validation and mute rule.
  ({ActivityRowWindow window, Map<String, dynamic> row, String? key})? advance(
    Map message, {
    required bool Function(Map<String, dynamic>) muted,
    required bool newestFirst,
  }) {
    final channel = message['channelId'];
    if (channel is! String || message['id'] is! String) return null;
    for (final rank in _get(_lookup, 'scope:$channel') ?? const <int>[]) {
      final entry = _get(_order, rank)!;
      final next = advanceActivityRow(entry.row, message);
      if (next == null) continue;
      if (muted(entry.row)) return null;
      return (
        window: _replace(rank, next, promote: newestFirst),
        row: next,
        key: entry.key,
      );
    }
    return null;
  }

  /// The accepted server window keeps its order while its live preview changes.
  ActivityRowWindow replaceKey(String? key, Map<String, dynamic> row) {
    var next = this;
    for (final rank in _get(_lookup, _identity(key)) ?? const <int>[]) {
      next = next._replace(rank, row);
    }
    return next;
  }

  /// Keep the displayed order during a pointer gesture, but resolve only the
  /// visible cards against the newest accepted content.
  IndexedActivityRows retaining(List<Map<String, dynamic>> order) =>
      _RetainedRows(ActivityRowWindow.from(order), this);

  ActivityRowWindow _replace(
    int rank,
    Map<String, dynamic> row, {
    bool promote = false,
  }) {
    final previous = _get(_order, rank)!;
    final entry = _Row(row);
    final move = promote && rank != _at(_order, 0).key;
    final nextRank = move ? _front - 1 : rank;
    var lookup = _lookup;
    if (move || previous.key != entry.key || previous.scope != entry.scope) {
      for (final key in previous.lookups) {
        final remaining = _get(lookup, key)!.where((i) => i != rank).toList();
        lookup = remaining.isEmpty
            ? _remove(lookup, key)
            : _put(lookup, key, remaining);
      }
      for (final key in entry.lookups) {
        final ranks = [...?_get(lookup, key), nextRank]..sort();
        lookup = _put(lookup, key, ranks);
      }
    }
    return ActivityRowWindow._(
      _put(move ? _remove(_order, rank) : _order, nextRank, entry),
      lookup,
      move ? nextRank : _front,
      !move && previous.key == entry.key
          ? rowKeys
          : _ActivityKeys(
              _put(
                move
                    ? _remove((rowKeys as _ActivityKeys)._order, rank)
                    : (rowKeys as _ActivityKeys)._order,
                nextRank,
                entry.key,
              ),
              lookup,
            ),
    );
  }
}

class _RetainedRows extends IndexedActivityRows {
  _RetainedRows(this.order, this.current);
  final ActivityRowWindow order, current;
  @override
  ResourceRowKeys get rowKeys => order.rowKeys;
  @override
  int get length => order.length;
  @override
  Map<String, dynamic> operator [](int index) {
    final key = rowKeys[index];
    final ranks = _get(current._lookup, _identity(key));
    return ranks == null ? order[index] : _get(current._order, ranks.last)!.row;
  }

  @override
  set length(int value) =>
      throw UnsupportedError('Immutable Activity projection');
  @override
  void operator []=(int index, Map<String, dynamic> value) =>
      throw UnsupportedError('Immutable Activity projection');
}

String _identity(String? key) => key == null ? 'null:' : 'key:$key';

class _Row {
  _Row(this.row) : key = activityItemKey(row), scope = activityScopeId(row);
  final Map<String, dynamic> row;
  final String? key, scope;
  Iterable<String> get lookups => [
    _identity(key),
    if (scope != null) 'scope:$scope',
  ];
}

class _ActivityKeys extends ResourceRowKeys {
  _ActivityKeys(this._order, this._lookup);
  // Metadata only: reusing keys for a content-only edit must not retain the
  // previous window's message bodies or row objects.
  final _Tree<int, String?>? _order;
  final _Tree<String, List<int>>? _lookup;
  @override
  int get length => _size(_order);
  @override
  String? operator [](int index) => _at(_order, index).value;
  @override
  int? uniqueIndexOf(String key) {
    final ranks = _get(_lookup, _identity(key));
    return ranks?.length == 1 ? _rank(_order, ranks!.single) : null;
  }

  @override
  Iterator<String?> get iterator =>
      _entries(_order).map((entry) => entry.value).iterator;
  @override
  set length(int value) =>
      throw UnsupportedError('Immutable Activity identities');
  @override
  void operator []=(int index, String? value) =>
      throw UnsupportedError('Immutable Activity identities');
}

/// Path-copying AVL tree, with subtree sizes for lazy list indexing.
class _Tree<K extends Comparable<dynamic>, V> {
  _Tree(this.key, this.value, this.left, this.right)
    : height =
          1 + (_height(left) > _height(right) ? _height(left) : _height(right)),
      size = 1 + _size(left) + _size(right);
  final K key;
  final V value;
  final _Tree<K, V>? left, right;
  final int height, size;
}

int _height(_Tree? tree) => tree?.height ?? 0;
int _size(_Tree? tree) => tree?.size ?? 0;

V? _get<K extends Comparable<dynamic>, V>(_Tree<K, V>? tree, K key) {
  while (tree != null) {
    final compare = key.compareTo(tree.key);
    if (compare == 0) return tree.value;
    tree = compare < 0 ? tree.left : tree.right;
  }
  return null;
}

_Tree<K, V>? _build<K extends Comparable<dynamic>, V>(
  int start,
  int end,
  (K, V) Function(int) entry,
) {
  if (start == end) return null;
  final middle = (start + end) ~/ 2;
  final (key, value) = entry(middle);
  return _Tree(
    key,
    value,
    _build(start, middle, entry),
    _build(middle + 1, end, entry),
  );
}

_Tree<K, V> _left<K extends Comparable<dynamic>, V>(_Tree<K, V> tree) {
  final right = tree.right!;
  return _Tree(
    right.key,
    right.value,
    _Tree(tree.key, tree.value, tree.left, right.left),
    right.right,
  );
}

_Tree<K, V> _right<K extends Comparable<dynamic>, V>(_Tree<K, V> tree) {
  final left = tree.left!;
  return _Tree(
    left.key,
    left.value,
    left.left,
    _Tree(tree.key, tree.value, left.right, tree.right),
  );
}

_Tree<K, V> _balance<K extends Comparable<dynamic>, V>(_Tree<K, V> tree) {
  final difference = _height(tree.left) - _height(tree.right);
  if (difference > 1) {
    final left = tree.left!;
    if (_height(left.left) < _height(left.right)) {
      tree = _Tree(tree.key, tree.value, _left(left), tree.right);
    }
    return _right(tree);
  }
  if (difference < -1) {
    final right = tree.right!;
    if (_height(right.right) < _height(right.left)) {
      tree = _Tree(tree.key, tree.value, tree.left, _right(right));
    }
    return _left(tree);
  }
  return tree;
}

_Tree<K, V> _put<K extends Comparable<dynamic>, V>(
  _Tree<K, V>? tree,
  K key,
  V value,
) {
  if (tree == null) return _Tree(key, value, null, null);
  final compare = key.compareTo(tree.key);
  if (compare == 0) return _Tree(key, value, tree.left, tree.right);
  return _balance(
    _Tree(
      tree.key,
      tree.value,
      compare < 0 ? _put(tree.left, key, value) : tree.left,
      compare > 0 ? _put(tree.right, key, value) : tree.right,
    ),
  );
}

_Tree<K, V>? _remove<K extends Comparable<dynamic>, V>(
  _Tree<K, V>? tree,
  K key,
) {
  if (tree == null) return null;
  final compare = key.compareTo(tree.key);
  if (compare == 0) {
    if (tree.left == null) return tree.right;
    if (tree.right == null) return tree.left;
    final successor = _at(tree.right, 0);
    return _balance(
      _Tree(
        successor.key,
        successor.value,
        tree.left,
        _remove(tree.right, successor.key),
      ),
    );
  }
  return _balance(
    _Tree(
      tree.key,
      tree.value,
      compare < 0 ? _remove(tree.left, key) : tree.left,
      compare > 0 ? _remove(tree.right, key) : tree.right,
    ),
  );
}

_Tree<K, V> _at<K extends Comparable<dynamic>, V>(
  _Tree<K, V>? tree,
  int index,
) {
  RangeError.checkValidIndex(index, tree, 'index', _size(tree));
  while (true) {
    final left = _size(tree!.left);
    if (index == left) return tree;
    if (index < left) {
      tree = tree.left;
    } else {
      index -= left + 1;
      tree = tree.right;
    }
  }
}

int _rank<K extends Comparable<dynamic>, V>(_Tree<K, V>? tree, K key) {
  var skipped = 0;
  while (tree != null) {
    final compare = key.compareTo(tree.key);
    if (compare == 0) return skipped + _size(tree.left);
    if (compare < 0) {
      tree = tree.left;
    } else {
      skipped += 1 + _size(tree.left);
      tree = tree.right;
    }
  }
  throw StateError('Activity rank is absent');
}

Iterable<_Tree<K, V>> _entries<K extends Comparable<dynamic>, V>(
  _Tree<K, V>? tree,
) sync* {
  if (tree == null) return;
  yield* _entries(tree.left);
  yield tree;
  yield* _entries(tree.right);
}
