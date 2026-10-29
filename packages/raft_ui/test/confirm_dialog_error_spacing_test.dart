import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

void main() {
  for (final id in raftThemeMatrix([
    raftThemePackId,
    elegantThemePackId,
    brutalThemePackId,
  ], look: raftLookOf)) {
    for (final dark in [false, true]) {
      testWidgets(
        'confirm error uses source gap and retry clears it $id/$dark',
        (t) async {
          const explanation = 'Try confirming this action.';
          const failure = 'The action failed. Please try again.';
          const confirm = ValueKey('confirm-action');
          final retry = Completer<void>();
          var attempts = 0;
          bool? result;
          addTearDown(() => t.pumpWidget(const SizedBox()));
          await t.pumpWidget(
            MaterialApp(
              theme: raftTheme(pack: packForThemeId(id), dark: dark),
              home: Builder(
                builder: (context) => TextButton(
                  onPressed: () async {
                    result = await RaftConfirmDialog.show(
                      context,
                      RaftConfirmDialog(
                        title: 'Confirm action',
                        message: explanation,
                        confirmLabel: 'Continue',
                        confirmKey: confirm,
                        confirmVariant: RaftButtonRecipeVariant.warning,
                        onConfirm: () async {
                          attempts++;
                          if (attempts == 1) {
                            throw const RaftUserError(failure);
                          }
                          await retry.future;
                        },
                      ),
                    );
                  },
                  child: const Text('Open confirmation'),
                ),
              ),
            ),
          );
          await t.tap(find.text('Open confirmation'));
          await t.pumpAndSettle();
          expect(find.byType(RaftErrorBanner), findsNothing);

          await t.tap(find.byKey(confirm));
          await t.pumpAndSettle();
          expect(attempts, 1);
          expect(find.text(failure), findsOneWidget);
          final gap =
              t.getTopLeft(find.byType(RaftErrorBanner)).dy -
              t
                  .getBottomLeft(
                    find.ancestor(
                      of: find.text(explanation),
                      matching: find.byType(RaftCssText),
                    ),
                  )
                  .dy;

          await t.tap(find.byKey(confirm));
          await t.pump();
          expect(attempts, 2);
          expect(find.text(failure), findsNothing);
          expect(find.byType(RaftErrorBanner), findsNothing);
          retry.complete();
          await t.pumpAndSettle();
          expect(result, isTrue);
          expect(find.byType(RaftConfirmDialog), findsNothing);

          // Reopening the dialog must not restore a resolved failure.
          await t.tap(find.text('Open confirmation'));
          await t.pumpAndSettle();
          expect(find.text(explanation), findsOneWidget);
          expect(find.byType(RaftErrorBanner), findsNothing);
          await t.tap(find.text('Cancel'));
          await t.pumpAndSettle();
          expect(find.byType(RaftConfirmDialog), findsNothing);

          // Web ConfirmDialog.tsx: the warning error Banner uses `mt-3`.
          // Frozen Elegant/Brutal keep their existing `mt-4` layout.
          expect(gap, id == raftThemePackId ? 12 : 16);
        },
      );
    }
  }
}
