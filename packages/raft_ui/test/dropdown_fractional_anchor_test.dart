import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

const _trigger = ValueKey('fractional-dropdown-trigger');
const _surface = ValueKey('fractional-dropdown-surface');

void main() {
  for (final look in raftThemeMatrix([
    raftLookRaft,
    raftLookElegant,
    raftLookBrutal,
  ], look: (look) => look)) {
    for (final side in [RaftDropdownSide.bottom, RaftDropdownSide.right]) {
      testWidgets(
        '$look ${side.name} dropdown keeps source-aligned fractional anchor placement',
        (tester) async {
          tester.view.devicePixelRatio = 3;
          tester.view.physicalSize = const Size(2400, 1800);
          final controller = RaftMenuController();
          var invoked = 0;
          try {
            await tester.pumpWidget(
              MaterialApp(
                theme: raftTheme(
                  pack: switch (look) {
                    raftLookElegant => packForThemeId(elegantThemePackId),
                    raftLookBrutal => packForThemeId(brutalThemePackId),
                    _ => null,
                  },
                ),
                home: Scaffold(
                  body: Stack(
                    children: [
                      Positioned(
                        left: 350.25,
                        top: 120.25,
                        child: RaftDropdownMenu(
                          label: 'File actions',
                          controller: controller,
                          surfaceKey: _surface,
                          kind: RaftMenuKind.dropdownMenu,
                          side: side,
                          align: RaftDropdownAlign.end,
                          sideOffset: 4,
                          width: 240,
                          triggerBuilder: (context, focus, onPressed) =>
                              RaftButton(
                                key: _trigger,
                                uiSize: RaftButtonSize.iconSm,
                                uiVariant: RaftButtonVariant.ghost,
                                layoutTouchTarget: true,
                                expandTouchTarget: false,
                                focusNode: focus,
                                semanticLabel: 'File actions',
                                onPressed: onPressed,
                                glyph: RaftGlyph.moreHorizontal,
                              ),
                          entries: [
                            RaftMenuEntry(
                              label: 'Jump to original message',
                              onPressed: () => invoked++,
                            ),
                            RaftMenuEntry(
                              label: 'Download file',
                              onPressed: () => invoked++,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
            final anchor = tester.getRect(find.byKey(_trigger));
            expect(anchor.topLeft, const Offset(350.25, 120.25));
            await tester.tap(find.byKey(_trigger));
            await tester.pumpAndSettle();
            final popup = tester.getRect(find.byKey(_surface));
            final proposed = side == RaftDropdownSide.right
                ? Offset(anchor.right + 4, anchor.bottom - popup.height)
                : Offset(anchor.right - popup.width, anchor.bottom + 4);
            // The actual pinned Web Files popup places its 240x84 surface at
            // integer coordinates, including its 3x capture. The current
            // placement must retain that source alignment; frozen looks keep
            // their prior fractional placement unchanged.
            final expected = look == raftLookRaft
                ? Offset(
                    proposed.dx.roundToDouble(),
                    proposed.dy.roundToDouble(),
                  )
                : proposed;
            expect(popup.topLeft, expected);
            if (look == raftLookRaft) {
              expect(popup.size, const Size(240, 84));
            }
            await tester.tap(find.text('Download file'));
            await tester.pumpAndSettle();
            expect(invoked, 1);
            expect(controller.isOpen, isFalse);
            expect(find.byKey(_surface), findsNothing);
            expect(tester.takeException(), isNull);
          } finally {
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pump();
            controller.dispose();
            tester.view.reset();
          }
        },
      );
    }
  }
}
