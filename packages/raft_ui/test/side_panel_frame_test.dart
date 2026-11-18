import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  for (final dark in [false, true]) {
    testWidgets(
      'side-panel frames use canonical paint (${dark ? 'dark' : 'light'})',
      (t) async {
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(dark: dark),
            home: Row(
              children: [
                for (final placement in RaftSidePanelPlacement.values)
                  Expanded(
                    child: RaftSidePanelFrame(
                      key: ValueKey(placement),
                      placement: placement,
                      child: const ColoredBox(color: Colors.red),
                    ),
                  ),
              ],
            ),
          ),
        );
        final tokens = RaftTokens.of(
          t.element(find.byType(RaftSidePanelFrame).first),
        );
        for (final placement in RaftSidePanelPlacement.values) {
          final container = t.widget<Container>(
            find.descendant(
              of: find.byKey(ValueKey(placement)),
              matching: find.byType(Container),
            ),
          );
          final back = container.decoration! as BoxDecoration;
          final front = container.foregroundDecoration! as BoxDecoration;
          final border = front.border! as Border;
          expect(back.color, tokens.ui.layerCanvas);
          expect(front.borderRadius, BorderRadius.zero);
          expect(
            border.left.width,
            placement == RaftSidePanelPlacement.overlay ? 0 : 1,
          );
          if (placement != RaftSidePanelPlacement.overlay) {
            expect(border.left.color, tokens.ui.lineSeam);
          }
          expect(
            border.bottom.width,
            placement == RaftSidePanelPlacement.floating ? 1 : 0,
          );
          expect(
            back.boxShadow?.isNotEmpty ?? false,
            placement == RaftSidePanelPlacement.floating,
          );
        }
        expect(
          RaftSidePanelFrame.headerRule(tokens).bottom,
          BorderSide(color: tokens.ui.lineSeam, width: 1),
        );
      },
    );
  }
}
