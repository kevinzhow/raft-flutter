import 'dart:typed_data';

/// One layer option of the human pixel-avatar art (humanAvatarLayers.json): a
/// `raftHumanAvatarSize` square of role indices. [runs] is the run-length text
/// tool/gen_human_avatar_data.py writes: rows joined with `/`, each a sequence
/// of `<role letter><count>` where the letter is `A` + the role index.
class RaftHumanAvatarLayer {
  const RaftHumanAvatarLayer(this.layer, this.option, this.z, this.runs);

  /// `base`, `hair`, `expression` or `accessory`.
  final String layer, option;

  /// Draw order among accessories (ascending).
  final int z;
  final String runs;

  /// `size * size` role indices, row-major; 0 is transparent.
  Uint8List grid(int size) {
    final out = Uint8List(size * size);
    var at = 0;
    var i = 0;
    while (i < runs.length) {
      final unit = runs.codeUnitAt(i);
      if (unit == 0x2f) {
        i++;
        continue;
      }
      final role = unit - 0x41;
      var count = 0;
      i++;
      while (i < runs.length) {
        final d = runs.codeUnitAt(i) - 0x30;
        if (d < 0 || d > 9) break;
        count = count * 10 + d;
        i++;
      }
      if (role != 0) out.fillRange(at, at + count, role);
      at += count;
    }
    return out;
  }
}
