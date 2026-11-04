import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/public_server_fixture.dart';

import 'package:raft_flutter/features/public_server_view.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final entry in [
    (const Size(1280, 900), TargetPlatform.linux),
    (const Size(390, 844), TargetPlatform.android),
    (const Size(856, 944), TargetPlatform.android),
    (const Size(944, 856), TargetPlatform.android),
  ]) {
    testWidgets(
      'public settings reopen resets the closed form scroll ${entry.$1}',
      (t) async {
        await mountPublicServer(t, size: entry.$1, translation: true);
        final client = t
            .widget<PublicServerView>(find.byType(PublicServerView))
            .client;
        addTearDown(() async {
          await t.pumpWidget(const SizedBox());
          await t.pumpAndSettle();
          await client.dispose();
        });
        Future<void> settings() async {
          if (entry.$1.width < 768) {
            t.view.physicalSize = Size(1280, entry.$1.height);
            await t.pumpAndSettle();
          }
          await openPublicSettings(t);
          await t.tap(
            find.byKey(
              const ValueKey('workspace-settings-nav-language-region'),
            ),
          );
          await t.pumpAndSettle();
          t.view.physicalSize = entry.$1;
          await t.pumpAndSettle();
        }

        await settings();
        final selector = find.byKey(const ValueKey('display-language-select'));
        expect(selector.hitTestable(), findsOneWidget);
        final footer = find.byKey(const ValueKey('date-time-save'));
        expect(
          footer.hitTestable(),
          findsNothing,
          reason: 'The user must scroll to the lower form.',
        );
        await t.ensureVisible(footer);
        await t.pumpAndSettle();
        expect(footer.hitTestable(), findsOneWidget);
        if (entry.$1.width < 768) {
          t.view.physicalSize = Size(1280, entry.$1.height);
          await t.pumpAndSettle();
        }
        await t.tap(find.byKey(const ValueKey('rail-chat')));
        await t.pumpAndSettle();
        await settings();
        // Web PublicServerPage unmounts the settings fork on Chat. Returning
        // creates its scroll surface at the beginning, rather than restoring
        // the scroll offset from a form that has already been closed.
        expect(selector.hitTestable(), findsOneWidget);
        expect(t.takeException(), isNull);
      },
      variant: TargetPlatformVariant({entry.$2}),
    );
  }
}
