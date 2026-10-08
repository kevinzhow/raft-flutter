import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  testWidgets(
    'dialog retains values after failure, submits once and owns editor through exit animation',
    (tester) async {
      var requests = 0, fail = true;
      Completer<void>? pending;
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.elegant),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                child: const Text('Open'),
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => RaftFormDialog(
                    title: 'Create',
                    fields: const [
                      RaftFormField('title', 'Title', required: true),
                    ],
                    onSubmit: (data) async {
                      requests++;
                      expect(data['title'], '日本語 中文');
                      if (fail) throw StateError('Try again');
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
      await tester.tap(find.text('Save'));
      await tester.pump();
      expect(requests, 0);
      await tester.enterText(find.byType(TextFormField), '日本語 中文');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('日本語 中文'), findsOneWidget);
      expect(find.textContaining('Try again'), findsOneWidget);
      fail = false;
      await tester.tap(find.text('Save'));
      await tester.pump();
      await tester.tap(find.text('Save'));
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
                onPressed: () => showDialog(
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
}
