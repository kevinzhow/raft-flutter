import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  for (final theme in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    testWidgets(
      'Combobox filters, selects by keyboard and rejects disabled interaction $theme',
      (tester) async {
        final selected = <String>[];
        var enabled = true, dismissed = 0;
        late StateSetter update;
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(theme.$1, dark: theme.$2),
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 220,
                  child: StatefulBuilder(
                    builder: (context, set) {
                      update = set;
                      return RaftComboboxPanel(
                        label: 'Channels',
                        glyph: RaftGlyph.hash,
                        options: const {
                          'design': '#design',
                          'general': '#general',
                        },
                        enabled: enabled,
                        onSelected: selected.add,
                        onDismiss: () => dismissed++,
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
        expect(find.text('#design'), findsOneWidget);
        await tester.enterText(find.byType(TextField), 'gen');
        await tester.pump();
        expect(find.text('#design'), findsNothing);
        expect(find.text('#general'), findsOneWidget);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        expect(selected, ['general']);
        await tester.enterText(find.byType(TextField), 'absent');
        await tester.pump();
        expect(find.text('No results'), findsOneWidget);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        expect(selected, ['general']);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        expect(dismissed, 1);
        await tester.enterText(find.byType(TextField), '');
        await tester.pump();
        await tester.tap(find.text('#design'));
        expect(selected, ['general', 'design']);
        update(() => enabled = false);
        await tester.pump();
        await tester.tap(find.text('#design'));
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        expect(selected, ['general', 'design']);
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets('Combobox rejects retired selections $theme', (tester) async {
      final selected = <String>[];
      var options = const {'general': '#general'};
      var enabled = true;
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(theme.$1, dark: theme.$2),
          home: Scaffold(
            body: SizedBox(
              width: 220,
              child: StatefulBuilder(
                builder: (context, set) {
                  update = set;
                  return RaftComboboxPanel(
                    label: 'Channels',
                    options: options,
                    enabled: enabled,
                    onSelected: selected.add,
                    onDismiss: () {},
                  );
                },
              ),
            ),
          ),
        ),
      );
      final select = tester
          .widget<RaftInteractive>(
            find.ancestor(
              of: find.text('#general'),
              matching: find.byType(RaftInteractive),
            ),
          )
          .onPressed!;
      update(() => options = const {});
      await tester.pump();
      select();
      expect(selected, isEmpty);
      update(() {
        options = const {'general': '#general'};
        enabled = false;
      });
      await tester.pump();
      select();
      expect(selected, isEmpty);
      update(() => enabled = true);
      await tester.pump();
      select();
      expect(selected, ['general']);
      await tester.pumpWidget(const SizedBox());
      select();
      expect(selected, ['general']);
      expect(tester.takeException(), isNull);
    });
  }
}
