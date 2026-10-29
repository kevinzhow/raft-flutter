/// Measured extents around a stable origin. Older pages append to the reverse
/// side; newer pages append to the forward side. Neither rebuilds old sums.
class TimelineExtentIndex {
  TimelineExtentIndex(int count, double Function(int) estimate)
    : _forward = _ExtentSums(count, estimate);
  final _ExtentSums _forward;
  final _older = _ExtentSums(0, (_) => 0);
  int get length => _older.length + _forward.length;

  double valueAt(int index) => index < _older.length
      ? _older.values[_older.length - index - 1]
      : _forward.values[index - _older.length];

  void prepend(int count, double Function(int) estimate) {
    for (var i = count - 1; i >= 0; i--) {
      _older.append(estimate(i));
    }
  }

  void append(int count, double Function(int) estimate) {
    for (var i = 0; i < count; i++) {
      _forward.append(estimate(i));
    }
  }

  void update(int index, double height) {
    if (index < _older.length) {
      _older.update(_older.length - index - 1, height);
    } else {
      _forward.update(index - _older.length, height);
    }
  }

  double _prefix(int end) {
    final older = _older.length;
    if (end <= older) return _older.prefix(older) - _older.prefix(older - end);
    return _older.prefix(older) + _forward.prefix(end - older);
  }

  double sum(int start, int end) => _prefix(end) - _prefix(start);
}

class _ExtentSums {
  _ExtentSums(int count, double Function(int) estimate)
    : values = List.generate(count, estimate),
      tree = List.filled(count + 1, 0, growable: true) {
    for (var i = 0; i < count; i++) {
      tree[i + 1] += values[i];
      final parent = i + 1 + ((i + 1) & -(i + 1));
      if (parent < tree.length) tree[parent] += tree[i + 1];
    }
  }
  final List<double> values, tree;
  int get length => values.length;
  void append(double value) {
    final i = length + 1;
    tree.add(value + prefix(i - 1) - prefix(i - (i & -i)));
    values.add(value);
  }

  void update(int index, double height) {
    final delta = height - values[index];
    if (delta == 0) return;
    values[index] = height;
    for (var i = index + 1; i < tree.length; i += i & -i) {
      tree[i] += delta;
    }
  }

  double prefix(int end) {
    var value = 0.0;
    for (var i = end; i > 0; i -= i & -i) {
      value += tree[i];
    }
    return value;
  }
}
