import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  testWidgets('a focused destination accepts Enter and Space', (tester) async {
    var presses = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(dark: false).copyWith(platform: TargetPlatform.linux),
        home: Scaffold(
          body: RaftForwardTargetRow(
            label: 'Release discussion',
            icon: const RaftIcon(RaftGlyph.hash),
            selected: false,
            checkbox: true,
            onTap: () => presses++,
          ),
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(presses, 2);
  });
}
