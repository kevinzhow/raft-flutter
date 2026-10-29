import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  for (final scenario in [
    (TargetPlatform.android, const Size(856, 944)),
    (TargetPlatform.android, const Size(944, 856)),
    (TargetPlatform.linux, const Size(390, 844)),
  ]) {
    testWidgets(
      'dialog preserves failure and single submit ${scenario.$1} ${scenario.$2}',
      (tester) async {
        tester.view.physicalSize = scenario.$2;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        var requests = 0, fail = true;
        Completer<void>? pending;
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(platform: scenario.$1),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  child: const Text('Open'),
                  onPressed: () => showRaftDialog(
                    context: context,
                    builder: (_) => RaftFormDialog(
                      title: 'Create',
                      fields: const [
                        RaftFormField('title', 'Title', required: true),
                      ],
                      onSubmit: (data) async {
                        requests++;
                        expect(data['title'], '日本語 中文');
                        if (fail) throw const RaftUserError('Try Again');
                        pending = Completer<void>();
                        await pending!.future;
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        final surface = tester.getRect(find.byType(RaftDialogSurface));
        expect(
          surface.width,
          scenario.$2.width < 480 ? scenario.$2.width - 32 : 448,
        );
        expect(surface.center.dx, scenario.$2.width / 2);
        await tester.tap(find.text('Save'));
        await tester.pump();
        expect(requests, 0);
        await tester.enterText(find.byType(TextFormField), '日本語 中文');
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
        expect(find.text('日本語 中文'), findsOneWidget);
        expect(find.textContaining('Try Again'), findsOneWidget);
        fail = false;
        await tester.tap(find.text('Save'));
        await tester.pump();
        await tester.tap(
          find.byWidgetPredicate(
            (widget) => widget is RaftButton && widget.label == 'Save',
          ),
        );
        await tester.pump();
        expect(requests, 2);
        pending!.complete();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();
        expect(find.byType(RaftFormDialog), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'password fields preserve intentional leading and trailing spaces',
    (tester) async {
      String? submitted;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                child: const Text('Open'),
                onPressed: () => showRaftDialog(
                  context: context,
                  builder: (_) => RaftFormDialog(
                    title: 'Password',
                    fields: const [
                      RaftFormField(
                        'password',
                        'Password',
                        obscure: true,
                        required: true,
                        trim: false,
                      ),
                    ],
                    onSubmit: (data) async {
                      submitted = data['password'];
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), '  valid password  ');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(submitted, '  valid password  ');
    },
  );

  testWidgets(
    'errorContent replaces the plain banner; a code suffix follows the message',
    (tester) async {
      Object? error = const RaftUserError(
        'Plain failure',
        suffix: ' (SOME_CODE)',
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          home: Scaffold(
            body: RaftFormDialog(
              title: 'Create',
              fields: const [],
              errorContent: (context, e) =>
                  e is StateError ? const Text('Custom failure block') : null,
              onSubmit: (_) async => throw error!,
            ),
          ),
        ),
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      // No custom content for this error: the plain banner, suffix appended.
      expect(find.text('Plain failure (SOME_CODE)'), findsOneWidget);
      expect(find.text('Custom failure block'), findsNothing);
      error = StateError('x');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Custom failure block'), findsOneWidget);
      expect(find.textContaining('Plain failure'), findsNothing);
      expect(find.text('Could not complete that. Try again.'), findsNothing);
    },
  );
}
