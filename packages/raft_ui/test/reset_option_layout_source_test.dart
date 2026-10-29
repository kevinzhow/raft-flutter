import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/src/recipes/web_agent_reset_options.g.dart';
import 'package:raft_ui/test_themes.dart';

// Actual ResetAgentDialog, not a radio specimen: source db5e Reset labels use
// gap-0, min-h-11/py-3/gap-3 and the generated title/description composition.
// These rendered-box assertions do not replace paired Web/Flutter acceptance.
void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    for (final size in [const Size(1280, 800), const Size(390, 844)]) {
      testWidgets('Reset rendered option slots dark=$dark size=$size', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
        });
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(dark: dark).copyWith(
              platform: size.width == 390
                  ? TargetPlatform.linux
                  : TargetPlatform.android,
            ),
            home: Scaffold(
              body: RaftResetAgentDialog(
                agentName: 'Test Agent',
                canFullReset: true,
                onConfirm: (_) async {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final first = find.byKey(const ValueKey('agent-reset-option-restart'));
        final tokens = RaftTokens.of(tester.element(first));
        expect(tokens.isRaftLook, isTrue);
        final recipe = RaftWebAgentResetOptionsRecipe.resolve(
          tokens: tokens.recipeTokens,
        );
        final rects = <Rect>[];
        for (final mode in ['restart', 'session', 'full']) {
          final finder = find.byKey(ValueKey('agent-reset-option-$mode'));
          final row = tester.widget<RaftRadioGroupItem<String>>(finder);
          final rowRect = tester.getRect(finder);
          final labelRect = tester.getRect(find.byWidget(row.child!));
          final markRect = tester.getRect(
            find.descendant(of: finder, matching: find.byType(RaftRadioMark)),
          );
          final padding = recipe.row.padding;
          final markMargin = recipe.indicator.margin;
          expect(
            labelRect.top - rowRect.top,
            closeTo(padding.top, .001),
            reason: '$mode label consumes the published vertical row padding',
          );
          expect(
            rowRect.bottom - labelRect.bottom,
            closeTo(padding.bottom, .001),
          );
          expect(
            labelRect.left - markRect.right,
            closeTo(markMargin.right + (recipe.row.columnGap ?? 0), .001),
          );
          expect(
            rowRect.height,
            closeTo(
              math.max(
                recipe.row.minHeight ?? 0,
                padding.vertical +
                    math.max(
                      labelRect.height,
                      markRect.height + markMargin.vertical,
                    ),
              ),
              .001,
            ),
            reason: 'row height follows its real label plus generated padding',
          );
          rects.add(rowRect);
        }
        for (var i = 1; i < rects.length; i++) {
          expect(
            rects[i].top - rects[i - 1].bottom,
            closeTo(recipe.root.rowGap ?? 0, .001),
            reason: 'source gap-0 is applied between actual option rows',
          );
        }
        expect(find.text('Restart'), findsNWidgets(2));
        await tester.tap(find.byKey(const ValueKey('agent-reset-option-full')));
        await tester.pumpAndSettle();
        final fullMark = tester.widget<RaftRadioMark>(
          find.descendant(
            of: find.byKey(const ValueKey('agent-reset-option-full')),
            matching: find.byType(RaftRadioMark),
          ),
        );
        expect(fullMark.checked, isTrue);
        expect(
          find.text(
            'This will permanently delete all workspace files including MEMORY.md and notes/. This cannot be undone.',
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });
    }
  }
}
