import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.linux]) {
    for (final dark in [false, true]) {
      testWidgets('$platform/$dark rail keeps source visual and real target', (
        t,
      ) async {
        t.view.physicalSize = const Size(856, 944);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        final calls = <String>[];
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(dark: dark),
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 57,
                  child: RaftWorkspaceRail(
                    workspaceName: 'V',
                    workspaceHeader: const SizedBox(height: 56),
                    onWorkspace: () {},
                    selected: 'none',
                    destinations: const [
                      RaftRailDestination(
                        id: 'chat',
                        label: 'Chat',
                        glyph: RaftGlyph.messageSquare,
                      ),
                      RaftRailDestination(
                        id: 'activity',
                        label: 'Activity',
                        glyph: RaftGlyph.activity,
                      ),
                    ],
                    onSelected: calls.add,
                    footer: RaftWorkspaceRailFooter(
                      children: [
                        RaftWorkspaceRailAction(
                          label: 'Settings',
                          glyph: RaftGlyph.settings,
                          onPressed: () => calls.add('settings'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        final first = find.byKey(const ValueKey('rail-chat'));
        final second = find.byKey(const ValueKey('rail-activity'));
        expect(t.getRect(first), const Rect.fromLTWH(8, 66, 40, 40));
        expect(t.getRect(second), const Rect.fromLTWH(8, 112, 40, 40));
        // These points lie outside the painted controls. Only touch-density
        // hosts route them; the gap belongs to the nearest target.
        await t.tapAt(const Offset(5, 86));
        await t.tapAt(const Offset(28, 110));
        final footer = find.byType(RaftWorkspaceRailAction).last;
        final footerBox = t.getRect(footer);
        await t.tapAt(Offset(footerBox.left - 3, footerBox.center.dy));
        expect(
          calls,
          platform == TargetPlatform.android
              ? ['chat', 'activity', 'settings']
              : isEmpty,
        );
        await t.tap(first);
        expect(calls.last, 'chat');
        await t.sendKeyEvent(LogicalKeyboardKey.space);
        await t.pump();
        expect(calls.last, 'chat');
        expect(
          calls.where((x) => x == 'chat').length,
          platform == TargetPlatform.android ? 3 : 2,
        );
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox.shrink());
      }, variant: TargetPlatformVariant.only(platform));
    }
  }
}
