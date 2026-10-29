import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

Widget _host(Widget child) => MaterialApp(
  theme: raftTheme(),
  home: Scaffold(body: Center(child: child)),
);

void main() {
  testWidgets(
    'RaftFormDialog shows the surface fallback, never the exception',
    (tester) async {
      await tester.pumpWidget(
        _host(
          Builder(
            builder: (context) => TextButton(
              child: const Text('Open'),
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => RaftFormDialog(
                  title: 'Rename',
                  fields: const [],
                  errorFallback: 'Failed to update channel',
                  onSubmit: (_) async =>
                      throw StateError('Bad state: db://host?token=abc'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Failed to update channel'), findsOneWidget);
      expect(find.textContaining('Bad state'), findsNothing);
      expect(find.textContaining('token'), findsNothing);
      expect(find.byType(RaftErrorBanner), findsOneWidget);
    },
  );

  testWidgets('RaftFormDialog without a fallback uses the generic Web copy', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        Builder(
          builder: (context) => TextButton(
            child: const Text('Open'),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => RaftFormDialog(
                title: 'Rename',
                fields: const [],
                onSubmit: (_) async => throw const FormatException('nope'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Could not complete that. Try again.'), findsOneWidget);
    expect(find.textContaining('nope'), findsNothing);
  });

  testWidgets('RaftConfirmDialog shows RaftUserError text, hides the rest', (
    tester,
  ) async {
    var attempt = 0;
    await tester.pumpWidget(
      _host(
        Builder(
          builder: (context) => TextButton(
            child: const Text('Open'),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => RaftConfirmDialog(
                title: 'Archive',
                message: 'Sure?',
                onConfirm: () async {
                  attempt++;
                  if (attempt == 1) throw const RaftUserError('Agent is busy');
                  throw Exception('SocketException: host');
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(find.text('Agent is busy'), findsOneWidget);
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(find.text('Could not complete that. Try again.'), findsOneWidget);
    expect(find.textContaining('Socket'), findsNothing);
  });

  testWidgets('RaftInviteHumanDialog falls back to Failed to send invites', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _host(
        RaftInviteHumanDialog(
          onClose: () {},
          onSend: (_) async => throw StateError('Bad state: boom'),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField).first, 'a@b.co');
    await tester.pump();
    await tester.tap(find.text('Send Invites'));
    await tester.pumpAndSettle();
    expect(find.text('Failed to send invites'), findsOneWidget);
    expect(find.textContaining('boom'), findsNothing);
  });
}
