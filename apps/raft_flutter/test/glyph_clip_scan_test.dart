import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

import 'support/glyph_clip_scan.dart';

void main() {
  const line = TextStyle(fontSize: 14, height: 1);

  testWidgets('flags a ClipRect that sits inside the glyph ink envelope', (
    t,
  ) async {
    await t.pumpWidget(
      const MaterialApp(
        home: Center(
          child: ClipRect(child: Text('tygg', style: line)),
        ),
      ),
    );
    final found = scanGlyphClips(t);
    expect(found, hasLength(1));
    expect(found.single.clip, 'RenderClipRect');
    expect(found.single.cutTop + found.single.cutBottom, greaterThan(.5));
  });

  testWidgets('accepts a clip with room for the ink', (t) async {
    await t.pumpWidget(
      const MaterialApp(
        home: Center(
          child: ClipRect(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Text('tygg', style: line),
            ),
          ),
        ),
      ),
    );
    expect(scanGlyphClips(t), isEmpty);
  });

  testWidgets('message header has no clip inside its ink', (t) async {
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 650,
              child: RaftMessageRow(
                author: 'tygg',
                timestamp: '23:16',
                subtitle: 'Public description',
                content: const SizedBox(height: 20, width: 200),
              ),
            ),
          ),
        ),
      ),
    );
    await t.pump();
    expect(scanGlyphClips(t).map((f) => f.toJson()), isEmpty);
  });
}
