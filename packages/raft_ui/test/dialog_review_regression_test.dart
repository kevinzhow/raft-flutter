import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  for (final closesOnBackdrop in [false, true]) {
    testWidgets(
      'product modal blocks the background (backdrop=$closesOnBackdrop)',
      (tester) async {
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
        });
        var backgroundCalls = 0;
        var backdropCalls = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(dark: false),
            home: Builder(
              builder: (context) => Scaffold(
                body: Stack(
                  children: [
                    Positioned(
                      left: 0,
                      top: 0,
                      width: 96,
                      height: 64,
                      child: TextButton(
                        onPressed: () => backgroundCalls++,
                        child: const Text('Background'),
                      ),
                    ),
                    Center(
                      child: ElevatedButton(
                        key: const Key('open-modal'),
                        onPressed: () => showRaftModal<void>(
                          context,
                          builder: (dialogContext) => RaftModalBackdrop(
                            onBackdrop: closesOnBackdrop
                                ? () => backdropCalls++
                                : null,
                            child: RaftDialogCard(
                              title: 'Modal',
                              onClose: () => Navigator.of(dialogContext).pop(),
                              child: const Text('Modal body'),
                            ),
                          ),
                        ),
                        child: const Text('Open'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.byKey(const Key('open-modal')));
        await tester.pumpAndSettle();
        expect(find.text('Modal body'), findsOneWidget);
        await tester.tapAt(const Offset(24, 24));
        await tester.pumpAndSettle();
        expect(
          backgroundCalls,
          0,
          reason: 'A modal must not activate controls behind its backdrop.',
        );
        expect(backdropCalls, closesOnBackdrop ? 1 : 0);
        expect(find.text('Modal body'), findsOneWidget);
      },
    );
  }

  for (final checkKey in [false, true]) {
    testWidgets(
      'dialog preserves caller column ${checkKey ? "key" : "spacing"}',
      (tester) async {
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
        });
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(dark: false),
            home: Scaffold(
              body: RaftDialog(
                child: Column(
                  key: const Key('custom-column'),
                  mainAxisSize: MainAxisSize.min,
                  spacing: 19,
                  children: const [
                    Text('First', key: Key('first')),
                    Text('Second', key: Key('second')),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (checkKey) {
          expect(find.byKey(const Key('custom-column')), findsOneWidget);
        } else {
          final first = tester.getRect(find.byKey(const Key('first')));
          final second = tester.getRect(find.byKey(const Key('second')));
          expect(second.top - first.bottom, 19);
        }
      },
    );
  }
}
