import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Media UI draws its own rails (video_controls.dart, inline_media.dart). The
/// Material `Slider` ban is the `avoid_material_slider` lint (tool/raft_lints);
/// this pins the rail components that replace it.
void main() {
  test('the media viewer and cards use the shared rails', () {
    final controls = File('../../packages/raft_ui/lib/src/video_controls.dart')
        .readAsStringSync();
    expect(controls, contains('class RaftVideoControlBar'));
    expect(controls, contains('class _VideoRail'));
    for (final name in const ['inline_media.dart', 'video_viewer.dart']) {
      final src = File('../../packages/raft_ui/lib/src/$name')
          .readAsStringSync();
      expect(src, isNot(contains("material.dart' show Slider")));
    }
  });
}
