import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

import 'flutter_test_config.dart' show RaftTestBinding;

void main() {
  RaftTestBinding.showShadows();

  testWidgets('Raft skeleton is a flat fill-muted sticker block', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: const Center(child: RaftSkeleton(width: 100, height: 20)),
        ),
      ),
    );
    await tester.pump();
    final box = tester.widget<Container>(
      find
          .descendant(
            of: find.byType(RaftSkeleton),
            matching: find.byType(Container),
          )
          .first,
    );
    final decoration = box.decoration! as BoxDecoration;
    final t = RaftTokens.of(tester.element(find.byType(RaftSkeleton)));
    expect(decoration.color, t.colors['fill-muted']);
    expect(
      decoration.borderRadius,
      BorderRadius.circular(t.size('radius.sticker', fallback: 4)),
    );
  });
}
