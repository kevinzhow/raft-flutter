import 'package:flutter_test/flutter_test.dart' as flutter_test;

/// Spreads one test file's cases over several files, so the gate can run the
/// parts on different shards instead of one 4 minute file on one.
///
/// Every part file runs the same registration function and hands it its own
/// [TestPart]; the function calls [claim] (or [group]) once per case or group
/// declaration, always in the same order, and declares only what it claims.
/// Test names do not change, and the parts together declare exactly the cases
/// of the former single file. A declaration that must exist once (a test that
/// is not part of the spread) is guarded with [first].
///
/// A declaration goes to the part with the least weight so far (ties go to the
/// lowest part, so equal weights are dealt out in turn). Every part computes
/// the same assignment, because they declare in the same order.
class TestPart {
  TestPart(this.index, this.count)
    : assert(count > 0 && index >= 0 && index < count),
      _load = List.filled(count, 0);

  /// The whole file: claims every declaration.
  TestPart.whole() : this(0, 1);

  final int index;
  final int count;
  final List<int> _load;
  Map<String, int> _weights = const {};

  /// Relative cost of named [group]s (the default is 1), so one big group does
  /// not share a part with other big ones.
  void weigh(Map<String, int> weights) => _weights = weights;

  /// True when this part declares the next case or group, of the given [weight].
  bool claim([int weight = 1]) {
    var best = 0;
    for (var i = 1; i < count; i++) {
      if (_load[i] < _load[best]) best = i;
    }
    _load[best] += weight;
    return best == index;
  }

  /// True in the first part only.
  bool get first => index == 0;

  /// `group`, declared only when this part claims it.
  void group(String description, void Function() body) {
    if (claim(_weights[description] ?? 1)) {
      flutter_test.group(description, body);
    }
  }
}
