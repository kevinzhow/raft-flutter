import 'dart:ui' show CheckedState;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  for (final theme in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    testWidgets('source mute form keyboard and disabled/save semantics $theme', (
      t,
    ) async {
      bool muted = false, saved = false;
      int saves = 0;
      final handle = t.ensureSemantics();
      try {
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(theme.$1, dark: theme.$2),
            home: Scaffold(
              body: SizedBox(
                width: 390,
                child: StatefulBuilder(
                  builder: (context, setState) => RaftNotificationSettingsCard(
                    title: 'DMs, direct mentions, and followed thread replies',
                    description: 'Delivery description',
                    status: 'Unavailable',
                    enableLabel: 'Enable Push Notifications',
                    muted: muted,
                    muteDescription: 'Stops web push notifications from Fixture for your account. Other servers are unchanged.',
                    onMutedChanged: (v) => setState(() => muted = v),
                    onSave: muted == saved
                        ? null
                        : () => setState(() {
                            saved = muted;
                            saves++;
                          }),
                  ),
                ),
              ),
            ),
          ),
        );
        final checkbox = find.byType(RaftCheckbox);
        expect(
          t.getSemantics(checkbox).getSemanticsData().flagsCollection.isChecked,
          CheckedState.isFalse,
        );
        await t.sendKeyEvent(LogicalKeyboardKey.tab);
        await t.pump();
        expect(
          FocusManager.instance.primaryFocus!.context!
              .findAncestorWidgetOfExactType<RaftCheckbox>(),
          isNotNull,
        );
        await t.sendKeyEvent(LogicalKeyboardKey.space);
        await t.pumpAndSettle();
        expect(muted, true);
        expect(
          t.getSemantics(checkbox).getSemanticsData().flagsCollection.isChecked,
          CheckedState.isTrue,
        );
        await t.sendKeyEvent(LogicalKeyboardKey.tab);
        await t.pump();
        await t.sendKeyEvent(LogicalKeyboardKey.enter);
        await t.pumpAndSettle();
        expect(saved, true);
        expect(saves, 1);
        expect(
          t
              .widget<RaftButton>(
                find.byKey(const ValueKey('notification-settings-save')),
              )
              .onPressed,
          isNull,
        );
        await t.tap(find.text('Mute this server'));
        await t.pumpAndSettle();
        expect(muted, false);
        expect(saved, true);
        expect(t.takeException(), isNull);
      } finally {
        handle.dispose();
      }
    });
    testWidgets(
      'source status/error/success and truthful native actions $theme',
      (t) async {
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(theme.$1, dark: theme.$2),
            home: Scaffold(
              body: SingleChildScrollView(
                child: SizedBox(
                  width: 390,
                  child: RaftNotificationSettingsCard(
                    title: 'System notifications',
                    description: 'Actual native delivery',
                    status: 'Enabled',
                    enableLabel: 'Disable Push Notifications',
                    muted: false,
                    onEnable: () {},
                    showTest: true,
                    onTest: () {},
                    showSettings: true,
                    onOpenSettings: () {},
                    availabilityHint: 'Actual availability',
                    error: 'Failed to update server notification setting.',
                    message: 'Saved current preference',
                  ),
                ),
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        expect(find.text('Saved current preference'), findsOneWidget);
        expect(find.text('Send test notification'), findsOneWidget);
        expect(find.text('Open system settings'), findsOneWidget);
        expect(find.text('Mute this server'), findsNothing);
        expect(find.text('Permission denied'), findsNothing);
        expect(t.takeException(), isNull);
      },
    );
  }
}
