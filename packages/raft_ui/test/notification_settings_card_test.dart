import 'dart:ui' show CheckedState;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    testWidgets(
      'source mute form keyboard and disabled/save semantics ${dark ? 'dark' : 'light'}',
      (t) async {
        bool muted = false, saved = false;
        int saves = 0;
        final handle = t.ensureSemantics();
        try {
          await t.pumpWidget(
            MaterialApp(
              theme: raftTheme(dark: dark),
              home: Scaffold(
                body: SizedBox(
                  width: 390,
                  child: StatefulBuilder(
                    builder: (context, setState) =>
                        RaftNotificationSettingsCard(
                          title: 'DMs, direct mentions, and followed thread replies',
                          description: 'Delivery description',
                          status: 'Unavailable',
                          actionLabel: 'Enable Notifications',
                          muted: muted,
                          muteDescription: 'Stops notifications from Fixture for your account. Other servers are unchanged.',
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
            t
                .getSemantics(checkbox)
                .getSemanticsData()
                .flagsCollection
                .isChecked,
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
            t
                .getSemantics(checkbox)
                .getSemanticsData()
                .flagsCollection
                .isChecked,
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
      },
    );
    testWidgets(
      'desktop card: header, pill, hint, banner, message, one test button ${dark ? 'dark' : 'light'}',
      (t) async {
        var sends = 0;
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(dark: dark),
            home: Scaffold(
              body: SingleChildScrollView(
                child: SizedBox(
                  width: 390,
                  child: RaftNotificationSettingsCard(
                    title: 'Desktop notifications',
                    description: 'Actual native delivery',
                    status: 'Managed by the system',
                    hint: 'System hint',
                    error: 'Could not post a test notification.',
                    message: 'Test notification posted to the system.',
                    actionLabel: 'Send a test notification',
                    muted: false,
                    onAction: () => sends++,
                  ),
                ),
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        expect(find.text('Notifications'), findsOneWidget);
        expect(find.text('Desktop notifications'), findsOneWidget);
        expect(find.text('Managed by the system'), findsOneWidget);
        expect(find.text('System hint'), findsOneWidget);
        expect(
          find.text('Test notification posted to the system.'),
          findsOneWidget,
        );
        expect(
          find.text('Could not post a test notification.'),
          findsOneWidget,
        );
        expect(find.byType(RaftButton), findsOneWidget);
        expect(find.text('Mute this server'), findsNothing);
        await t.tap(find.text('Send a test notification'));
        expect(sends, 1);
        expect(t.takeException(), isNull);
      },
    );
    testWidgets(
      'card without a handler disables its only action ${dark ? 'dark' : 'light'}',
      (t) async {
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(dark: dark),
            home: Scaffold(
              body: SizedBox(
                width: 390,
                child: RaftNotificationSettingsCard(
                  title: 'Desktop notifications',
                  description: 'd',
                  status: 'Unavailable',
                  hint: 'This desktop build cannot show system notifications.',
                  actionLabel: 'Send a test notification',
                  muted: false,
                ),
              ),
            ),
          ),
        );
        expect(
          t
              .widget<RaftButton>(
                find.byKey(const ValueKey('notification-settings-action')),
              )
              .onPressed,
          isNull,
        );
      },
    );
  }
}
