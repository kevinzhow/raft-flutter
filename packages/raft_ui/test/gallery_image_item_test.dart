import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  testWidgets('GalleryImageItem keeps one image tile that opens the viewer', (
    tester,
  ) async {
    var opened = 0;
    var retried = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: RaftAttachmentCard(
            filename: 'diagram.webp',
            mimeType: 'image/webp',
            imageExtent: const Size(200, 120),
            error: 'The image could not be loaded.',
            onOpen: () => opened++,
            onRetry: () => retried++,
          ),
        ),
      ),
    );
    final placeholder = find.byWidgetPredicate(
      (widget) => widget is RaftIcon && widget.glyph == RaftGlyph.imageOff,
    );
    expect(placeholder, findsOneWidget);
    await tester.tap(placeholder);
    expect(opened, 1);
    expect(retried, 0);
  });
}
