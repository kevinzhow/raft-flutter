import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/recipes.dart';

// Pinned Web db5e399f / raft-ui 0.7.0:
// ResetAgentDialog -> ConfirmDialog uses plainMessage, Cancel, warning for
// restart/session and danger for full reset. Its ordinary RotateCcw and
// Spinner have no data-icon="inline-start" marker. The lg Button therefore
// keeps px-4, rather than the marker-only pl-3.5 override.
// Source identities and exact lines: Dialog-family-readonly/footer-review.md.

bool _realFontsLoaded = false;

Future<void> _loadRealFonts(WidgetTester tester) async {
  if (_realFontsLoaded) return;
  await tester.runAsync(() async {
    Directory? fonts;
    var directory = Directory.current;
    while (fonts == null) {
      for (final relative in [
        'assets/fonts/',
        'packages/raft_ui/assets/fonts/',
      ]) {
        final candidate = Directory.fromUri(directory.uri.resolve(relative));
        if (File.fromUri(candidate.uri.resolve('SpaceGrotesk.ttf'))
            .existsSync()) {
          fonts = candidate;
          break;
        }
      }
      if (fonts != null) break;
      final parent = directory.parent;
      if (parent.path == directory.path) {
        throw StateError('Cannot locate the checked-out raft_ui font assets.');
      }
      directory = parent;
    }
    for (final family in [
      'SpaceGrotesk',
      'SpaceMono',
      'HankenGrotesk',
      'Inter',
      'Geist',
      'GeistMono',
    ]) {
      final bytes = await File.fromUri(fonts.uri.resolve('$family.ttf'))
          .readAsBytes();
      await (FontLoader(
        'packages/raft_ui/$family',
      )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
    }
    // A missing file or failed font registration must fail this case and let
    // the next case retry, never silently cache a fallback to Ahem.
    _realFontsLoaded = true;
  });
  if (!_realFontsLoaded) {
    throw StateError('Real-font loading failed; geometry was not exercised.');
  }
}

Finder _button(String label) => find.byWidgetPredicate(
  (widget) => widget is RaftButton && widget.label == label,
  description: 'visible RaftButton labelled $label',
);

Finder _buttonSurface(Finder button) => find.descendant(
  of: button,
  matching: find.byWidgetPredicate(
    (widget) =>
        widget is RaftRecipeBox && widget.style.classes.contains('h-11'),
  ),
);

String _buttonFontDiagnostic(WidgetTester tester, Finder button) {
  final label = find.descendant(of: button, matching: find.byType(Text)).first;
  final text = tester.widget<Text>(label);
  final context = tester.element(label);
  final style = DefaultTextStyle.of(context).style.merge(text.style);
  return 'font=${style.fontFamily} fallback=${style.fontFamilyFallback} '
      'size=${style.fontSize} weight=${style.fontWeight} '
      'scaledSize=${MediaQuery.textScalerOf(context).scale(style.fontSize!)}';
}

Future<void> _open(
  WidgetTester tester, {
  required bool dark,
  required WidgetBuilder dialog,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: raftTheme(dark: dark, platform: TargetPlatform.linux),
      home: Scaffold(
        body: Builder(
          builder: (context) => RaftButton(
            label: 'Open source confirmation',
            onPressed: () async {
              await showRaftDialog<void>(
                context: context,
                barrierDismissible: false,
                builder: dialog,
              );
            },
          ),
        ),
      ),
    ),
  );
  await tester.tap(_button('Open source confirmation'));
  await tester.pumpAndSettle();
}

void _expectAction(
  WidgetTester tester,
  Finder button,
  RaftButtonRecipeVariant variant,
) {
  expect(button, findsOneWidget);
  final tokens = RaftTokens.of(tester.element(button));
  final expected = RaftButtonRecipe.resolve(
    theme: tokens.recipeTheme,
    variant: variant,
    size: RaftButtonRecipeSize.lg,
    states: tokens.recipeStates(),
    tokens: tokens.recipeTokens,
  ).root;
  final surface = _buttonSurface(button);
  expect(surface, findsOneWidget);
  final actual = tester.widget<RaftRecipeBox>(surface);
  expect(
    actual.style.backgroundColor?.resolve(tokens.recipeTokens),
    expected.backgroundColor?.resolve(tokens.recipeTokens),
    reason: 'The visible confirmation colour states the selected consequence.',
  );
  expect(tester.getSize(surface).height, expected.height);
  expect(expected.height, 44);
}

void _expectUnmarkedLeadingInset(
  WidgetTester tester,
  Finder button,
  Finder leading,
) {
  final tokens = RaftTokens.of(tester.element(button));
  final expected = RaftButtonRecipe.resolve(
    theme: tokens.recipeTheme,
    variant: RaftButtonRecipeVariant.warning,
    size: RaftButtonRecipeSize.lg,
    states: tokens.recipeStates(),
    tokens: tokens.recipeTokens,
  ).root;
  expect(expected.padding.left, 16);
  final surface = _buttonSurface(button);
  expect(surface, findsOneWidget);
  expect(leading, findsOneWidget);
  final painted = tester.widget<RaftRecipeBox>(surface);
  final actualInset =
      tester.getRect(leading).left -
      tester.getRect(surface).left -
      painted.style.borderWidth.left;
  expect(
    actualInset,
    closeTo(expected.padding.left, .01),
    reason: 'An ordinary SVG/Spinner does not opt into inline-start padding.',
  );
  expect(tester.getSize(surface).height, expected.height);
}

void _contractTest(
  String description,
  Future<void> Function(WidgetTester tester) body,
) {
  testWidgets(description, (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    try {
      // Resolve the same real bundled faces independently of test cwd and
      // AssetBundle prefix conventions. Ahem makes long labels artificially
      // wide and can move an otherwise matching footer to two runs.
      await _loadRealFonts(tester);
      await body(tester);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      tester.view.reset();
    }
  });
}

void main() {
  // These source assertions apply only to the current Raft look. Frozen
  // Elegant/Brutal contracts are intentionally covered by their own tests.
  for (final dark in [false, true]) {
    _contractTest('Reset footer follows each source mode, dark=$dark', (
      tester,
    ) async {
      for (final choice in [
        (mode: 'restart', label: 'Restart'),
        (mode: 'session', label: 'Reset Session & Restart'),
        (mode: 'full', label: 'Full Reset & Restart'),
      ]) {
        final pending = Completer<void>();
        final calls = <String>[];
        try {
          await _open(
            tester,
            dark: dark,
            dialog: (_) => RaftResetAgentDialog(
              agentName: 'Source QA',
              canFullReset: true,
              onConfirm: (mode) async {
                calls.add(mode);
                await pending.future;
              },
            ),
          );
          if (choice.mode != 'restart') {
            await tester.tap(
              find.byKey(ValueKey('agent-reset-option-${choice.mode}')),
            );
            await tester.pumpAndSettle();
          }
          final cancel = _button('Cancel');
          final confirm = _button(choice.label);
          expect(cancel, findsOneWidget);
          expect(
            find.descendant(of: confirm, matching: find.text(choice.label)),
            findsOneWidget,
          );
          _expectAction(
            tester,
            confirm,
            choice.mode == 'full'
                ? RaftButtonRecipeVariant.danger
                : RaftButtonRecipeVariant.warning,
          );
          final banners = find.byType(RaftBanner);
          expect(
            banners,
            choice.mode == 'full' ? findsOneWidget : findsNothing,
          );
          if (choice.mode == 'full') {
            expect(
              tester.widget<RaftBanner>(banners).status,
              RaftBannerRecipeStatus.destructive,
            );
            expect(
              find.text(
                'This will permanently delete all workspace files including '
                'MEMORY.md and notes/. This cannot be undone.',
              ),
              findsOneWidget,
            );
          }
          final surface = tester.getRect(
            find.byKey(const ValueKey('agent-dialog')),
          );
          final cancelRect = tester.getRect(_buttonSurface(cancel));
          final confirmRect = tester.getRect(_buttonSurface(confirm));
          final diagnostic =
              'mode=${choice.mode} dark=$dark dialog=$surface '
              'cancel=$cancelRect confirm=$confirmRect '
              'cancelFont=[${_buttonFontDiagnostic(tester, cancel)}] '
              'confirmFont=[${_buttonFontDiagnostic(tester, confirm)}]';
          debugPrint('[source-confirm-footer] $diagnostic');
          expect(
            confirmRect.left - cancelRect.right,
            closeTo(8, .01),
            reason: diagnostic,
          );
          expect(
            surface.right - confirmRect.right,
            closeTo(20, .01),
            reason: diagnostic,
          );

          await tester.tap(confirm);
          await tester.pump();
          expect(calls, [choice.mode]);
          final processing = _button('Restarting…');
          expect(processing, findsOneWidget);
          expect(
            find.descendant(of: processing, matching: find.byType(RaftSpinner)),
            findsOneWidget,
          );
          await tester.tap(cancel);
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await tester.pump();
          expect(find.byType(RaftResetAgentDialog), findsOneWidget);
          pending.complete();
          await tester.pumpAndSettle();
          expect(find.byType(RaftResetAgentDialog), findsNothing);
          expect(calls, [choice.mode]);
          expect(tester.takeException(), isNull);
        } finally {
          if (!pending.isCompleted) pending.complete();
        }
      }
    });

    _contractTest(
      'member-runtime Reset keeps typed source actions, dark=$dark',
      (tester) async {
        for (final choice in [
          (mode: 'restart', label: 'Restart Model'),
          (mode: 'session', label: 'Reset Model'),
        ]) {
          final calls = <String>[];
          await _open(
            tester,
            dark: dark,
            dialog: (_) => RaftResetAgentDialog(
              agentName: 'Source member',
              canFullReset: true,
              memberRuntimeOnly: true,
              onConfirm: (mode) async => calls.add(mode),
            ),
          );
          expect(
            find.byKey(const ValueKey('agent-reset-option-full')),
            findsNothing,
          );
          if (choice.mode == 'session') {
            await tester.tap(
              find.byKey(const ValueKey('agent-reset-option-session')),
            );
            await tester.pumpAndSettle();
          }
          expect(_button('Cancel'), findsOneWidget);
          final confirm = _button(choice.label);
          _expectAction(tester, confirm, RaftButtonRecipeVariant.warning);
          expect(find.byType(RaftBanner), findsNothing);
          await tester.tap(confirm);
          await tester.pumpAndSettle();
          expect(calls, [choice.mode]);
          expect(find.byType(RaftResetAgentDialog), findsNothing);
          expect(tester.takeException(), isNull);
        }
      },
    );

    _contractTest(
      'Confirm SVG and pending Spinner keep unmarked inset, dark=$dark',
      (tester) async {
        final pending = Completer<void>();
        var calls = 0;
        try {
          await _open(
            tester,
            dark: dark,
            dialog: (_) => RaftConfirmDialog(
              title: 'Source icon confirmation',
              message: 'One explanation.',
              plainMessage: true,
              confirmLabel: 'Run source action',
              loadingLabel: 'Running source action…',
              confirmGlyph: RaftGlyph.rotateCcw,
              confirmVariant: RaftButtonRecipeVariant.warning,
              onConfirm: () async {
                calls++;
                await pending.future;
              },
            ),
          );
          final confirm = _button('Run source action');
          _expectUnmarkedLeadingInset(
            tester,
            confirm,
            find.descendant(
              of: confirm,
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is RaftIcon && widget.glyph == RaftGlyph.rotateCcw,
              ),
            ),
          );
          await tester.tap(confirm);
          await tester.pump();
          expect(calls, 1);
          final processing = _button('Running source action…');
          _expectUnmarkedLeadingInset(
            tester,
            processing,
            find.descendant(of: processing, matching: find.byType(RaftSpinner)),
          );
          pending.complete();
          await tester.pumpAndSettle();
          expect(find.byType(RaftConfirmDialog), findsNothing);
          expect(calls, 1);
          expect(tester.takeException(), isNull);
        } finally {
          if (!pending.isCompleted) pending.complete();
        }
      },
    );
  }
}
