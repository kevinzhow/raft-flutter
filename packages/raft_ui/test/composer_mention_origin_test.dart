import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  testWidgets(
    'shows the first origin server, additional count, and guest role',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(dark: false),
          home: Scaffold(
            body: RaftComposer(
              onSend: (_) async => true,
              suggestions: const [
                RaftComposerSuggestion(
                  type: 'user',
                  id: 'partner',
                  name: 'partner',
                  originServers: ['Acme', 'Lumen'],
                ),
                RaftComposerSuggestion(
                  type: 'user',
                  id: 'visitor',
                  name: 'visitor',
                  guest: true,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), '@');
      await tester.pumpAndSettle();
      expect(find.text('Human'), findsNWidgets(2));
      expect(find.text('Guest'), findsOneWidget);
      expect(find.text('Acme +1'), findsOneWidget);
      final server = find.byKey(const ValueKey('mention-source-server'));
      expect(
        tester
            .widget<RaftTooltip>(
              find.ancestor(of: server, matching: find.byType(RaftTooltip)),
            )
            .message,
        'Source server: Acme, Lumen',
      );
    },
  );
}
