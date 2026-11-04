import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

Widget page({
  bool loading = false,
  bool installing = false,
  bool installed = false,
  String? error,
  VoidCallback? onInstall,
  VoidCallback? onRetry,
  VoidCallback? onSettings,
}) => RaftPrivateAppInvitePage(
  loading: loading,
  name: loading ? null : 'Shared Calendar',
  description: 'A calendar shared by its publisher.',
  byline: 'Shared by Publisher from Design',
  details: const [
    ('Client ID', 'private-client'),
    ('Homepage', 'calendar.example.invalid'),
    ('Callback', 'calendar.example.invalid'),
    ('Invite expiry', 'No expiry'),
  ],
  servers: const [RaftSelectItem(value: 'design', label: 'Design')],
  selectedServer: 'design',
  installed: installed,
  installing: installing,
  error: error,
  onClose: () {},
  onRetry: onRetry ?? () {},
  onServer: (_) {},
  onInstall: onInstall ?? () {},
  onSettings: onSettings ?? () {},
);

void main() {
  for (final dark in [false, true]) {
    for (final scale in [1.0, 1.3, 2.0, 3.1]) {
      testWidgets('invitation remains readable at $dark/$scale', (t) async {
        t.view.devicePixelRatio = 1;
        t.view.physicalSize = const Size(390, 844);
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(dark: dark),
            home: MediaQuery(
              data: MediaQueryData(
                size: const Size(390, 844),
                textScaler: TextScaler.linear(scale),
              ),
              child: page(),
            ),
          ),
        );
        expect(find.text('Shared Calendar'), findsOneWidget);
        final install = find.byKey(
          const ValueKey('private-app-invite-install'),
        );
        await t.ensureVisible(install);
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        expect(install, findsOneWidget);
      });
    }
  }
  testWidgets(
    'pending and installed states expose only the applicable action',
    (t) async {
      final SemanticsHandle semantics = t.ensureSemantics();
      try {
        var installs = 0, opens = 0;
        Future<void> mount(Widget child) async {
          await t.pumpWidget(MaterialApp(theme: raftTheme(), home: child));
          await t.pumpAndSettle();
        }

        await mount(page(installing: true, onInstall: () => installs++));
        final pending = find.byKey(
          const ValueKey('private-app-invite-install'),
        );
        await t.ensureVisible(pending);
        expect(
          t.getSemantics(pending).getSemanticsData().flagsCollection.isEnabled,
          Tristate.isFalse,
        );
        await t.tap(pending);
        expect(installs, 0);
        await mount(page(installed: true, onSettings: () => opens++));
        expect(
          find.byKey(const ValueKey('private-app-invite-install')),
          findsNothing,
        );
        final settings = find.byKey(
          const ValueKey('private-app-invite-open-settings'),
        );
        await t.ensureVisible(settings);
        await t.tap(settings);
        expect(opens, 1);
      } finally {
        semantics.dispose();
      }
    },
  );
}
