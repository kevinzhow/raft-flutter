import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  // Web v1.21.12 (raft-ui 0.5.36+) lands the avatar on 20 at every width: the
  // wrapper keeps its 12 inset and the row adds 8. The phone exception of
  // 2026-10-12 (no wrapper inset) is gone with the brutal row's `mx-3`.
  test('timeline rows keep the wrapper inset at every width', () {
    const recipe = RaftTimelineCompositionRecipe();
    for (final width in [390.0, 767.0, 768.0, 1280.0]) {
      expect(recipe.messageInsetFor(width), recipe.messageInset);
    }
    expect(recipe.messageInset, const EdgeInsets.symmetric(horizontal: 12));
  });
}
