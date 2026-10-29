import 'dart:math';

import 'package:flutter_chat_core/flutter_chat_core.dart' as chat;
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/timeline_extents.dart';
import 'package:raft_flutter/features/timeline_boundary_change.dart';

void main() {
  test('incremental sums retain measurements through interleaved history and arrivals', () {
    final random = Random(74);
    var values = [for (var i = 0; i < 40; i++) 20.0 + random.nextInt(200)];
    final index = TimelineExtentIndex(values.length, (i) => values[i]);
    for (var round = 0; round < 25; round++) {
      final head = [for (var i = 0; i < 3; i++) 20.0 + random.nextInt(200)];
      final tail = [20.0 + random.nextInt(200)];
      index.prepend(head.length, (i) => head[i]);
      index.append(tail.length, (i) => tail[i]);
      values = [...head, ...values, ...tail];
      final at = random.nextInt(values.length),
          height = random.nextDouble() * 400;
      values[at] = height;
      index.update(at, height);
      expect(index.length, values.length);
      for (var i = 0; i < values.length; i++) {
        expect(index.valueAt(i), values[i]);
        expect(
          index.sum(0, i + 1),
          closeTo(values.take(i + 1).fold(0.0, (a, b) => a + b), .000001),
        );
      }
      expect(
        index.sum(5, values.length - 5),
        closeTo(
          values.sublist(5, values.length - 5).fold(0.0, (a, b) => a + b),
          .000001,
        ),
      );
    }
  });
  test(
    'boundary fast path rejects changed versions, deletes and reordering',
    () {
      chat.Message row(String id) =>
          chat.Message.text(id: id, authorId: 'a', text: id);
      final old = [row('1'), row('2'), row('3')];
      final extended = [row('0'), ...old, row('4')];
      final delta = TimelineBoundaryChange.between(old, extended)!;
      expect((delta.before, delta.after), (1, 1));
      for (final changed in [
        [old[0], row('2'), old[2]],
        [old[0], old[2]],
        [old[1], old[0], old[2]],
      ]) {
        expect(TimelineBoundaryChange.between(old, changed), isNull);
      }
    },
  );
}
