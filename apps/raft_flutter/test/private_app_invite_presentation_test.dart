import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/human_login_sheet.dart';
import 'package:raft_flutter/features/private_app_invite.dart';
import 'package:raft_flutter/features/private_app_invite_view.dart';
import 'package:raft_ui/raft_ui.dart';

import 'parity/parity_harness.dart' show loadParityFonts;
import 'parity/cases/screens/screen_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadParityFonts);
  void retire(WidgetTester t) => addTearDown(() async {
    await t.pumpWidget(const SizedBox.shrink());
    await t.pumpAndSettle();
  });
  testWidgets('wrapped permission summary uses the whole disclosure width', (
    t,
  ) async {
    retire(t);
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: const Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 282,
              child: RequestedAppScopes(
                scopes: ['openid', 'profile'],
                collapseIdentity: true,
              ),
            ),
          ),
        ),
      ),
    );
    final disclosure = find.byKey(
      const ValueKey('human-login-identity-disclosure'),
    );
    final paragraph = find.descendant(
      of: disclosure,
      matching: find.byType(RichText),
    );
    expect(paragraph, findsOneWidget);
    expect(
      t.getTopLeft(paragraph).dx,
      t.getTopLeft(disclosure).dx,
      reason:
          'HTML summary places its marker on the first line only; '
          'wrapped copy must return to the left edge.',
    );
    expect(t.getSize(paragraph).height, greaterThan(40));
    final render = t.renderObject<RenderParagraph>(paragraph);
    final boxes = render.getBoxesForSelection(
      TextSelection(
        baseOffset: 0,
        extentOffset: render.text.toPlainText().length,
      ),
    );
    expect(boxes.map((b) => b.top).toSet().length, greaterThan(1));
    await t.tap(disclosure);
    await t.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('human-login-scope-openid')),
      findsOneWidget,
    );
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await t.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('human-login-scope-openid')),
      findsNothing,
    );
  });

  testWidgets('native retry does not alter the Web error banner line box', (
    t,
  ) async {
    retire(t);
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: RaftPrivateAppInvitePage(
          error: 'Private app invite not found',
          onClose: () {},
          onRetry: () {},
          onServer: (_) {},
          onInstall: () {},
          onSettings: () {},
        ),
      ),
    );
    expect(t.getSize(find.byType(RaftBanner)).height, 44);
    expect(
      find.byKey(const ValueKey('private-app-invite-retry')),
      findsOneWidget,
    );
    expect(t.takeException(), isNull);
  });

  for (final (look, dark) in [
    (raftThemePackId, false),
    (raftThemePackId, true),
    (elegantThemePackId, false),
    (elegantThemePackId, true),
    (brutalThemePackId, false),
  ]) {
    testWidgets('retry resolves and navigation stays reachable: $look/$dark', (
      t,
    ) async {
      retire(t);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetDevicePixelRatio);
      addTearDown(t.view.resetPhysicalSize);
      final semantics = t.ensureSemantics();
      try {
        for (final width in [390.0, 856.0]) {
          for (final scale in [1.0, 1.3, 2.0, 3.1]) {
            t.view.physicalSize = Size(width, 944);
            var loads = 0;
            final client = ScreenFixtureClient((method, path, _) {
              expect(method, 'GET');
              expect(path, '/integration-invites/test-invite');
              if (++loads == 1) {
                throw const RaftApiException('Private app invite not found');
              }
              return {
                'client': {
                  'id': 'private-app',
                  'clientId': 'private-client',
                  'name': 'Shared Calendar',
                  'allowedScopes': ['openid', 'profile'],
                },
                'link': {'id': 'invite', 'expiresAt': null},
                'manageableServers': <Object?>[],
              };
            }, user: const {'id': 'alice'});
            var closed = false;
            Widget host(Key key) => MaterialApp(
              theme: raftTheme(pack: builtInTheme(look), dark: dark),
              home: MediaQuery(
                data: MediaQueryData(
                  size: Size(width, 944),
                  textScaler: TextScaler.linear(scale),
                ),
                child: StatefulBuilder(
                  builder: (context, setState) => closed
                      ? const Text('Returned to Raft')
                      : PrivateAppInviteView(
                          key: key,
                          client: client,
                          link: const PrivateAppInviteLink('test-invite'),
                          onClose: () => setState(() => closed = true),
                          onSettings: (_, _) async {},
                        ),
                ),
              ),
            );
            await t.pumpWidget(host(UniqueKey()));
            await t.pumpAndSettle();
            expect(find.text('Private app invite not found'), findsOneWidget);
            final retry = find.byKey(
              const ValueKey('private-app-invite-retry'),
            );
            final exit = find.byKey(const ValueKey('private-app-invite-close'));
            final viewport = Offset.zero & Size(width, 944);
            expect(viewport.contains(t.getCenter(retry)), isTrue);
            expect(viewport.contains(t.getCenter(exit)), isTrue);
            expect(find.bySemanticsLabel('Retry'), findsOneWidget);
            expect(find.bySemanticsLabel('Go to Raft'), findsOneWidget);
            if (width == 390) {
              await t.tap(retry);
            } else {
              await t.sendKeyEvent(LogicalKeyboardKey.tab);
              await t.pump();
              await t.sendKeyEvent(LogicalKeyboardKey.enter);
            }
            await t.pumpAndSettle();
            expect(loads, 2);
            expect(find.text('Shared Calendar'), findsOneWidget);
            expect(find.text('Private app invite not found'), findsNothing);
            expect(retry, findsNothing);
            // The server is now available; revisiting must not retain the notice.
            await t.pumpWidget(host(UniqueKey()));
            await t.pumpAndSettle();
            expect(loads, 3);
            expect(find.text('Private app invite not found'), findsNothing);
            for (var i = 0; i < 8; i++) {
              if (FocusManager.instance.primaryFocus?.context
                      ?.findAncestorWidgetOfExactType<RaftButton>()
                      ?.key ==
                  const ValueKey('private-app-invite-close')) {
                break;
              }
              await t.sendKeyEvent(LogicalKeyboardKey.tab);
              await t.pump();
            }
            await t.sendKeyEvent(LogicalKeyboardKey.enter);
            await t.pumpAndSettle();
            expect(find.text('Returned to Raft'), findsOneWidget);
            expect(t.takeException(), isNull);
            await t.pumpWidget(const SizedBox.shrink());
            await t.pumpAndSettle();
            await client.dispose();
          }
        }
      } finally {
        semantics.dispose();
      }
    });
  }
}
