import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/app_link_store.dart';
import 'package:raft_flutter/features/connected_app_bot.dart';
import 'package:raft_flutter/features/connected_app_prompt_text_panel.dart';
import 'package:raft_flutter/features/link_preview_consents.dart';
import 'package:raft_ui/raft_ui.dart';

import 'close_dialogs_test.dart'
    show anyX, fromIntegrations, openFromButton, registerNoScrimTests;
import 'parity/cases/screens/screen_fixture.dart';
import 'support/close_registry_apps.dart';
import 'support/close_registry_dialogs.dart';
import 'support/close_runner.dart';
import 'support/close_surface.dart';

WorkspaceController _workspace(WidgetTester tester) {
  final client = ScreenFixtureClient(
    (method, path, _) => switch (path) {
      '/integrations/clients/garden/prompt-text' => {
        'can_review': true,
        'pending': {
          'id': 'revision',
          'name': 'Garden',
          'when_to_use': 'Plan planting',
        },
      },
      '/integrations/link-preview-consents' => {
        'allowed': [
          {
            'app': {'id': 'garden', 'name': 'Garden', 'icon': null},
            'granted_at': '2026-11-20T00:00:00Z',
          },
        ],
        'declined': [],
      },
      _ => const <String, Object>{},
    },
    user: const {'id': 'owner'},
    server: 'server',
  );
  final workspace = WorkspaceController(client)
    ..server = RaftRecord({'id': 'server', 'name': 'Nursery', 'role': 'owner'});
  addTearDown(workspace.dispose);
  addTearDown(client.dispose);
  return workspace;
}

SurfaceProbe _probe(String id) => SurfaceProbe(
  isOpen: () => find.byKey(ValueKey(id)).evaluate().isNotEmpty,
  x: anyX,
  scrim: const Offset(6, 6),
);

Future<void> _openDetail(
  WidgetTester tester,
  Size size,
  Widget child,
  String action,
) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await openFromButton(
    tester,
    size,
    (context) => unawaited(
      showRaftDialog<void>(
        context: context,
        builder: (modal) => RaftDialog.card(
          title: 'Garden',
          onClose: () => Navigator.of(modal).pop(),
          child: child,
        ),
      ),
    ),
  );
  await tester.tap(find.text(action));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    final previous = WidgetController.hitTestWarningShouldBeFatal;
    WidgetController.hitTestWarningShouldBeFatal = true;
    addTearDown(() => WidgetController.hitTestWarningShouldBeFatal = previous);
  });

  registerCloseTests(
    [
      appsSurfaces.firstWhere(
        (surface) => surface.id == 'settings-apps-add-menu',
      ),
    ],
    {
      'settings-apps-add-menu': (tester, size) => fromIntegrations(
        tester,
        size,
        tap: const ValueKey('connected-apps-register'),
        surface: const ValueKey('settings-apps-add-menu'),
      ),
    },
  );
  final harness = <String, OpenSurface>{
    'connected-app-bot-remove-dialog': (tester, size) async {
      await _openDetail(
        tester,
        size,
        ConnectedAppBot(
          workspace: _workspace(tester),
          clientId: 'garden',
          appName: 'Garden',
          offer: const {'handle': 'sprinkler', 'grant': 'granted'},
          onChanged: (_) {},
          onViewProfile: (_) {},
        ),
        'Remove',
      );
      return _probe('connected-app-bot-remove-dialog');
    },
    'app-prompt-text-reject-dialog': (tester, size) async {
      await _openDetail(
        tester,
        size,
        ConnectedAppPromptTextPanel(
          workspace: _workspace(tester),
          clientId: 'garden',
          service: 'garden',
          onReviewed: () async {},
        ),
        'Reject text update',
      );
      return _probe('app-prompt-text-reject-dialog');
    },
    for (final revoke in [false, true])
      (revoke
          ? 'link-preview-consents-revoke-dialog'
          : 'link-preview-consents-dialog'): (tester, size) async {
        await tester.pumpWidget(const SizedBox.shrink());
        final store = AppLinkStore.of(_workspace(tester));
        await store.readConsentChoices();
        await openFromButton(
          tester,
          size,
          (context) => unawaited(openLinkPreviewConsents(context, store)),
        );
        if (revoke) {
          await tester.tap(find.text('Revoke'));
          await tester.pumpAndSettle();
          final alert = find.byKey(
            const ValueKey('link-preview-consents-revoke-dialog'),
          );
          expect(
            find.descendant(of: alert, matching: find.byType(RaftDialogClose)),
            findsNothing,
          );
          expect(
            find.descendant(of: alert, matching: find.text('Keep allowed')),
            findsOneWidget,
          );
          return _probe('link-preview-consents-revoke-dialog');
        }
        final sheet = find.byType(RaftFormSheet);
        if (sheet.evaluate().isNotEmpty) {
          expect(find.byKey(const ValueKey('raft-sheet-handle')), findsNothing);
          final head = find.byKey(const ValueKey('raft-form-sheet-head'));
          await tester.fling(head, const Offset(0, 140), 1000);
          await tester.pumpAndSettle();
          expect(sheet, findsOneWidget);
        }
        return _probe('link-preview-consents-dialog');
      },
  };
  final surfaces = dialogSurfaces
      .where((surface) => harness.containsKey(surface.id))
      .toList();
  registerCloseTests(surfaces, harness);
  registerNoScrimTests(surfaces, harness);
}
