import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

Widget _host(Widget child) => MaterialApp(
  theme: raftTheme(),
  home: Scaffold(body: child),
);

void main() {
  // Web draws drawers and dialogs on raft-ui's `bg-layer-popover` (Drawer popup,
  // DialogSurface), not on the page canvas (`layer-panel` in the Raft pack).
  testWidgets(
    'settings drawer and dialog card paint the popover role in dark',
    (t) async {
      final dark = MaterialApp(
        theme: raftTheme(dark: true),
        home: Scaffold(
          body: Column(
            children: [
              Expanded(
                child: RaftOverflowSheet(
                  title: '#fixture',
                  onClose: () {},
                  children: const [],
                ),
              ),
              Expanded(
                child: RaftDialogCard(
                  title: 'Dialog',
                  onClose: () {},
                  child: const Text('Body'),
                ),
              ),
            ],
          ),
        ),
      );
      await t.pumpWidget(dark);
      await t.pumpAndSettle();
      final tokens = RaftTokens.of(t.element(find.byType(RaftOverflowSheet)));
      final popover = tokens.popover;
      expect(popover, isNot(tokens.panel));
      final sheet = find.byKey(const ValueKey('channel-overflow-sheet'));
      final drawer = t.widget<Material>(
        find.descendant(of: sheet, matching: find.byType(Material)).first,
      );
      expect(drawer.color, popover);
      final fills = [
        for (final box in t.widgetList<DecoratedBox>(
          find.descendant(
            of: find.byType(RaftDialogCard),
            matching: find.byType(DecoratedBox),
          ),
        ))
          if (box.decoration is BoxDecoration)
            (box.decoration as BoxDecoration).color,
      ];
      expect(fills, contains(popover));
    },
  );
  testWidgets('settings drawer lays out only visible panel rows', (t) async {
    var built = 0;
    await t.pumpWidget(
      _host(
        RaftOverflowSheet(
          title: '#fixture',
          onClose: () {},
          children: [
            RaftOverflowPanelBody(
              children: [
                for (var i = 0; i < 1000; i++)
                  Builder(
                    builder: (_) {
                      built++;
                      return SizedBox(height: 60, child: Text('Preference $i'));
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(built, lessThan(30));
    await t.scrollUntilVisible(
      find.text('Preference 999'),
      3000,
      scrollable: find.byType(Scrollable),
      maxScrolls: 30,
    );
    expect(find.text('Preference 999'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  group(
    'members strip layout (getVisibleMemberLimit / getStripColumnCount)',
    () {
      test('column count follows the grid width', () {
        expect(RaftMembersStrip.columnsFor(0), 7);
        expect(RaftMembersStrip.columnsFor(416), 9); // elegant 448 - 32
        expect(RaftMembersStrip.columnsFor(510), 11); // brutal 544 - 34
        expect(RaftMembersStrip.columnsFor(10), 1);
      });
      test(
        'add keeps a slot; overflow reserves one more; never a fourth row',
        () {
          expect(RaftMembersStrip.visibleLimit(5, 9), 5);
          // 3 rows x 9 = 27 slots: 26 members + add still fit.
          expect(RaftMembersStrip.visibleLimit(26, 9), 26);
          // 27 members + add do not: show 25, then +N and add.
          expect(RaftMembersStrip.visibleLimit(27, 9), 25);
          expect(RaftMembersStrip.visibleLimit(500, 9), 25);
          expect(RaftMembersStrip.visibleLimit(3, 1), 1);
        },
      );
    },
  );

  testWidgets('Raft drawer follows source 420px, phones full width', (t) async {
    for (final (view, width) in [(1280.0, 420.0), (390.0, 390.0)]) {
      t.view.physicalSize = Size(view, 800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        _host(
          RaftOverflowSheet(title: '#work', onClose: () {}, children: const []),
        ),
      );
      // The theme change animates; let it land before measuring.
      await t.pumpAndSettle(const Duration(seconds: 1));
      expect(
        t.getSize(find.byKey(const ValueKey('channel-overflow-sheet'))).width,
        width,
        reason: '@ $view',
      );
    }
  });

  testWidgets(
    'header: title, badge, one collapsed description line; back only on phones',
    (t) async {
      t.view.physicalSize = const Size(1280, 800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      var closed = 0;
      await t.pumpWidget(
        _host(
          RaftOverflowSheet(
            title: '#work',
            badge: 'Private',
            subtitle: 'line one\nline two',
            onClose: () => closed++,
            children: const [],
          ),
        ),
      );
      expect(find.text('#work'), findsOneWidget);
      expect(find.text('Private'), findsOneWidget);
      expect(find.text('line one line two'), findsOneWidget);
      expect(find.byKey(const ValueKey('channel-overflow-back')), findsNothing);
      t.view.physicalSize = const Size(390, 800);
      await t.pump();
      await t.tap(find.byKey(const ValueKey('channel-overflow-back')));
      expect(closed, 1);
    },
  );

  testWidgets(
    'RaftConfirmDialog onConfirm: busy label, error banner, then success',
    (t) async {
      var attempt = 0;
      final gate = Completer<void>();
      Future<void> action() async {
        attempt++;
        if (attempt == 1) throw const RaftUserError('Server said no');
        await gate.future;
      }

      bool? result;
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async => result = await RaftConfirmDialog.show(
                context,
                RaftConfirmDialog(
                  title: 'Archive Channel',
                  message: 'Sure?',
                  confirmLabel: 'Archive',
                  loadingLabel: 'Archiving…',
                  confirmVariant: RaftButtonRecipeVariant.warning,
                  onConfirm: action,
                ),
              ),
              child: const Text('go'),
            ),
          ),
        ),
      );
      await t.tap(find.text('go'));
      await t.pumpAndSettle();
      await t.tap(find.text('Archive'));
      await t.pumpAndSettle();
      // A failure keeps the dialog open and shows the message under the copy.
      expect(find.text('Server said no'), findsOneWidget);
      expect(find.text('Archive'), findsOneWidget);
      await t.tap(find.text('Archive'));
      await t.pump();
      expect(find.text('Archiving…'), findsOneWidget);
      // Cancel and close are disabled while the action runs.
      await t.tap(find.text('Cancel'), warnIfMissed: false);
      await t.pump();
      expect(find.text('Archiving…'), findsOneWidget);
      gate.complete();
      await t.pumpAndSettle();
      expect(result, isTrue);
      expect(find.text('Archive'), findsNothing);
    },
  );

  testWidgets(
    'unsaved prompt: three actions, Save and Close only when savable',
    (t) async {
      final taps = <String>[];
      await t.pumpWidget(
        _host(
          RaftUnsavedChangesPrompt(
            message: 'Unsaved edits.',
            onKeepEditing: () => taps.add('keep'),
            onDiscard: () => taps.add('discard'),
            onSaveAndClose: () => taps.add('save'),
          ),
        ),
      );
      // Press through the buttons: the unwrapped test-font row may overflow.
      void press(String label) => t
          .widget<RaftSettingsRecipeButton>(
            find.widgetWithText(RaftSettingsRecipeButton, label),
          )
          .onPressed!();
      press('Keep Editing');
      press('Discard Changes');
      press('Save and Close');
      expect(taps, ['keep', 'discard', 'save']);
      await t.pumpWidget(
        _host(
          RaftUnsavedChangesPrompt(
            message: 'Invitation unsent.',
            onKeepEditing: () {},
            onDiscard: () {},
          ),
        ),
      );
      expect(find.text('Save and Close'), findsNothing);
    },
  );

  testWidgets('divide-y rows take their 1px border in layout', (t) async {
    late double firstTop, secondTop;
    await t.pumpWidget(
      _host(
        Builder(
          builder: (context) => SingleChildScrollView(
            child: raftSheetSection(
              context,
              RaftTokens.of(context),
              RaftSheetSection('Preferences', [
                RaftSheetSwitchRow(
                  title: 'A',
                  description: 'a',
                  value: false,
                  onChanged: (_) {},
                ),
                RaftSheetSwitchRow(
                  title: 'B',
                  description: 'b',
                  value: false,
                  onChanged: (_) {},
                ),
              ]),
            ),
          ),
        ),
      ),
    );
    firstTop = t.getTopLeft(find.text('A')).dy;
    secondTop = t.getTopLeft(find.text('B')).dy;
    // py-3 + 20 title + 4 + 16 description + py-3 = 64, plus the 1px divider.
    expect(secondTop - firstTop, 65);
  });
}
