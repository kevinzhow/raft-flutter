import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  for (final card in [false, true]) {
    testWidgets(
      'dialog paints Material interactions above its surface: $card',
      (t) async {
        var pressed = false;
        final row = ListTile(
          title: const Text('Choose row'),
          onTap: () => pressed = true,
        );
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(),
            home: Scaffold(
              body: Center(
                child: card
                    ? RaftDialog.card(
                        title: 'Choose',
                        onClose: () {},
                        child: row,
                      )
                    : RaftDialog(title: 'Choose', content: row),
              ),
            ),
          ),
        );
        expect(t.takeException(), isNull);
        await t.tap(find.text('Choose row'));
        await t.pump();
        expect(pressed, isTrue);
        expect(t.takeException(), isNull);
      },
    );
  }
}
