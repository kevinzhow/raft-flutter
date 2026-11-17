import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  for (final dark in [false, true]) {
    for (final scale in [1.0, 3.1]) {
      testWidgets('toolbar file label stays compact at ${scale}x dark=$dark', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(pack: packForThemeId(raftThemePackId), dark: dark),
            builder: (_, child) => MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Scaffold(
              body: Align(
                alignment: Alignment.topCenter,
                child: RaftLightboxHeader(
                  title: 'research.md',
                  leading: const RaftFileTypeBadge(
                    filename: 'research.md',
                    headerLabel: true,
                  ),
                  onClose: () {},
                ),
              ),
            ),
          ),
        );
        final label = tester.getRect(find.byType(RaftFileTypeBadge));
        final header = tester.getRect(find.byType(RaftLightboxHeader));
        final text = tester.getRect(find.text('MD'));
        // Web 1.24 leads the toolbar with the `h-4 w-8` type badge (raft-ui
        // 0.7's 22px headerLabel chip is gone), centred within the toolbar.
        // Larger text grows the label, without stretching its fill to the bar.
        if (scale == 1) expect(label.height, 16);
        if (scale > 1) expect(label.height, greaterThan(16));
        expect(label.top, greaterThan(header.top));
        expect(label.bottom, lessThan(header.bottom));
        expect(label.contains(text.topLeft), isTrue);
        expect(
          label.contains(text.bottomRight - const Offset(.01, .01)),
          isTrue,
        );
        expect(tester.takeException(), isNull);
      });
    }
  }
}
