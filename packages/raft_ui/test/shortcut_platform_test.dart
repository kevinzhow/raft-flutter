import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

/// Shortcuts follow each OS convention (Source `isApplePlatform`): Cmd on
/// macOS and iOS, Ctrl on Linux, Windows and Android.
void main() {
  test('label and modifier choice per platform', () {
    expect(globalSearchShortcutLabel(TargetPlatform.macOS), '⌘K');
    expect(globalSearchShortcutLabel(TargetPlatform.iOS), '⌘K');
    expect(globalSearchShortcutLabel(TargetPlatform.linux), 'Ctrl+K');
    expect(globalSearchShortcutLabel(TargetPlatform.windows), 'Ctrl+K');
    expect(primaryShortcutFlags(TargetPlatform.macOS), (
      control: false,
      meta: true,
    ));
    expect(primaryShortcutFlags(TargetPlatform.linux), (
      control: true,
      meta: false,
    ));
  });

  for (final platform in [
    (TargetPlatform.macOS, LogicalKeyboardKey.metaLeft, LogicalKeyboardKey.controlLeft),
    (TargetPlatform.linux, LogicalKeyboardKey.controlLeft, LogicalKeyboardKey.metaLeft),
    (TargetPlatform.windows, LogicalKeyboardKey.controlLeft, LogicalKeyboardKey.metaLeft),
  ]) {
    testWidgets(
      '${platform.$1.name}: the attachment preview closes on its own modifier+W only',
      (tester) async {
        var closed = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(),
            home: RaftAttachmentPreviewShell(
              filename: 'notes.txt',
              onClose: () => closed++,
              copyText: 'hello',
              commentsBuilder: (_, _) => const SizedBox(),
              child: const Text('body'),
            ),
          ),
        );
        await tester.pump();
        await tester.sendKeyDownEvent(platform.$3);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyW);
        await tester.sendKeyUpEvent(platform.$3);
        expect(closed, 0);
        await tester.sendKeyDownEvent(platform.$2);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyW);
        await tester.sendKeyUpEvent(platform.$2);
        expect(closed, 1);
      },
      variant: TargetPlatformVariant.only(platform.$1),
    );
  }
}
