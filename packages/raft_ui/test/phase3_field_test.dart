import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    testWidgets('$family dark=$dark disabled field renders named hint safely', (
      tester,
    ) async {
      final theme = raftTheme(family, dark: dark);
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: const Scaffold(
            body: TextField(
              enabled: false,
              decoration: InputDecoration(
                labelText: 'Channel name',
                hintText: 'Disabled field',
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Disabled field'), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
      final tokens = theme.extension<RaftTokens>()!;
      final style = WidgetStateProperty.resolveAs<TextStyle>(
        theme.inputDecorationTheme.hintStyle!,
        {WidgetState.disabled},
      );
      expect(
        style.color,
        family == RaftFamily.brutal
            ? tokens.colors['foreground-placeholder']
            : tokens.colors['foreground-disabled'],
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
