import 'dart:ui' show SemanticsRole;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  setUpAll(() async {
    final loader = FontLoader('packages/raft_ui/SpaceGrotesk')
      ..addFont(
        rootBundle.load('packages/raft_ui/assets/fonts/SpaceGrotesk.ttf'),
      );
    await loader.load();
  });

  final scenarios = [
    (
      name: 'desktop',
      size: const Size(1280, 800),
      platform: TargetPlatform.linux,
    ),
    (
      name: 'narrow desktop',
      size: const Size(390, 844),
      platform: TargetPlatform.linux,
    ),
    (
      name: 'foldable portrait',
      size: const Size(856, 944),
      platform: TargetPlatform.android,
    ),
    (
      name: 'foldable landscape',
      size: const Size(944, 856),
      platform: TargetPlatform.android,
    ),
  ];
  for (final scenario in scenarios) {
    for (final dark in [false, true]) {
      testWidgets(
        '${scenario.name}/$dark: every visible action edge invokes its callback',
        (t) async {
          t.view.physicalSize = scenario.size;
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.reset);
          final hits = <String, int>{'keep': 0, 'discard': 0, 'save': 0};
          await t.pumpWidget(
            MaterialApp(
              theme: raftTheme(dark: dark)
                  .copyWith(platform: scenario.platform),
              builder: (context, child) => RaftTextScaling(child: child!),
              home: RaftUnsavedChangesPrompt(
                message: 'The channel name or description has unsaved edits. Save them before closing?',
                onKeepEditing: () => hits['keep'] = hits['keep']! + 1,
                onDiscard: () => hits['discard'] = hits['discard']! + 1,
                onSaveAndClose: () => hits['save'] = hits['save']! + 1,
              ),
            ),
          );
          await t.pumpAndSettle();
          for (final entry in {
            'keep': 'channel-overflow-unsaved-keep',
            'discard': 'channel-overflow-unsaved-discard',
            'save': 'channel-overflow-unsaved-save',
          }.entries) {
            final button = entry.key == 'keep'
                ? find.byWidgetPredicate(
                    (w) =>
                        w is RaftSettingsRecipeButton &&
                        w.label.toLowerCase() == 'keep editing',
                  )
                : find.byKey(ValueKey(entry.value));
            expect(button, findsOneWidget);
            final rect = t.getRect(button);
            for (final x in [rect.left + 2, rect.right - 2]) {
              final before = Map<String, int>.of(hits);
              await t.tapAt(Offset(x, rect.center.dy));
              await t.pump();
              expect(
                hits[entry.key],
                before[entry.key]! + 1,
                reason: '${entry.key} edge at $x must receive its own tap',
              );
              for (final other in hits.keys.where((key) => key != entry.key)) {
                expect(
                  hits[other],
                  before[other],
                  reason: 'Tapping ${entry.key} must not activate $other',
                );
              }
            }
          }
        },
      );
    }
  }

  for (final size in [const Size(390, 844), const Size(856, 944)]) {
    for (final scale in [1.3, 2.0, 3.1]) {
      testWidgets('$size at $scale keeps each action reachable', (t) async {
        t.view.physicalSize = size;
        t.view.devicePixelRatio = 1;
        t.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(t.view.reset);
        addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
        final hits = <String, int>{'keep': 0, 'discard': 0, 'save': 0};
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(),
            builder: (context, child) => RaftTextScaling(child: child!),
            home: RaftUnsavedChangesPrompt(
              message: 'The channel name or description has unsaved edits. Save them before closing?',
              onKeepEditing: () => hits['keep'] = hits['keep']! + 1,
              onDiscard: () => hits['discard'] = hits['discard']! + 1,
              onSaveAndClose: () => hits['save'] = hits['save']! + 1,
            ),
          ),
        );
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        for (final entry in {
          'keep': 'channel-overflow-unsaved-keep',
          'discard': 'channel-overflow-unsaved-discard',
          'save': 'channel-overflow-unsaved-save',
        }.entries) {
          final button = find.byKey(ValueKey(entry.value));
          await t.ensureVisible(button);
          await t.pumpAndSettle();
          final rect = t.getRect(button);
          await t.tapAt(Offset(rect.left + 2, rect.center.dy));
          await t.pump();
          expect(
            hits[entry.key],
            1,
            reason: '${entry.key} should remain reachable',
          );
          expect(t.takeException(), isNull);
        }
      });
    }
  }

  testWidgets('keep editing supports keyboard and semantic activation', (
    t,
  ) async {
    final semantics = t.ensureSemantics();
    var kept = 0;
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: RaftUnsavedChangesPrompt(
          message: 'Unsaved edits.',
          onKeepEditing: () => kept++,
          onDiscard: () {},
        ),
      ),
    );
    expect(
      t.getSemantics(
        find.byKey(const ValueKey('channel-overflow-unsaved-prompt')),
      ),
      isSemantics(
        role: SemanticsRole.dialog,
        label: 'Unsaved changes',
        scopesRoute: true,
        namesRoute: true,
      ),
    );
    expect(
      t.getSemantics(find.text('Keep editing')),
      isSemantics(isButton: true, isFocusable: true, hasTapAction: true),
    );
    await t.sendKeyEvent(LogicalKeyboardKey.tab);
    await t.pump();
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await t.pump();
    expect(kept, 1);
    t.semantics.tap(find.semantics.byLabel('Keep editing'));
    await t.pump();
    expect(kept, 2);
    semantics.dispose();
  });

  testWidgets('busy prompt disables its actions', (t) async {
    var hits = 0;
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: RaftUnsavedChangesPrompt(
          message: 'Unsaved edits.',
          busy: true,
          onKeepEditing: () => hits++,
          onDiscard: () => hits++,
          onSaveAndClose: () => hits++,
        ),
      ),
    );
    expect(find.text('Saving…'), findsOneWidget);
    for (final id in [
      'channel-overflow-unsaved-keep',
      'channel-overflow-unsaved-discard',
      'channel-overflow-unsaved-save',
    ]) {
      await t.tap(find.byKey(ValueKey(id)));
      await t.pump();
    }
    expect(hits, 0);
  });
}
