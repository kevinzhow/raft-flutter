import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/app_link_models.dart';
import 'package:raft_flutter/features/app_link_view.dart';
import 'package:raft_flutter/features/message_presentation.dart';
import 'package:raft_ui/raft_ui.dart';

import 'app_link_preview_test.dart' show appLinkTestAnswer;
import 'close_dialogs_test.dart' show openFromButton;
import 'message_presentation_test.dart' show fixture;
import 'support/close_registry_app_links.dart';
import 'support/close_runner.dart';
import 'support/close_surface.dart';

const _url = 'https://tickets.example.org/123';

void main() {
  TestGesture? hoverPointer;
  Future<SurfaceProbe> open(
    WidgetTester tester,
    Size size,
    String surface,
  ) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final (workspace, transport) = (await tester.runAsync(
      () => fixture('member'),
    ))!;
    addTearDown(workspace.dispose);
    transport.routes['POST /feature-flags/evaluate'] = (_) => {
      'evaluations': [
        {'key': 'interactive_link_cards', 'enabled': true},
      ],
    };
    transport.routes['POST /messages/m1/link-cards/read'] = (_) =>
        surface == 'app-link-consent-popover'
        ? {
            'prompts': [
              {
                'url': _url,
                'app': {'id': 'tickets', 'name': 'Tickets', 'icon': null},
              },
            ],
          }
        : appLinkTestAnswer(
            hover: surface == 'app-link-hover-card',
            overflow: surface == 'app-link-more-menu',
          );
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(
          platform: size.width >= 1200
              ? TargetPlatform.linux
              : TargetPlatform.android,
        ),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: RaftInteractionScope(
              interaction: size.width >= 1200
                  ? RaftInteraction.pointerMode
                  : RaftInteraction.touchMode,
              child: MessagePresentation(
                controller: workspace,
                message: RaftMessage({
                  'id': 'm1',
                  'channelId': 'c1',
                  'content': _url,
                }),
                onExternalLink: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final chip = find.byKey(const ValueKey('app-link-chip-$_url'));
    if (surface == 'app-link-hover-card') {
      if (hoverPointer == null) {
        final pointer = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        hoverPointer = pointer;
        await pointer.addPointer(location: const Offset(5, 5));
        addTearDown(() async {
          hoverPointer = null;
          await pointer.removePointer();
        });
      }
      final pointer = hoverPointer!;
      await pointer.moveTo(const Offset(5, 5));
      await pointer.moveTo(tester.getCenter(find.text('Ticket 123')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    } else if (surface == 'app-link-more-menu') {
      await tester.tap(find.byKey(const ValueKey('app-link-more-trigger')));
    } else {
      await tester.tap(chip);
    }
    await tester.pumpAndSettle();
    return SurfaceProbe(
      isOpen: () => find.byKey(ValueKey(surface)).evaluate().isNotEmpty,
      scrim: Offset(size.width - 12, size.height - 12),
    );
  }

  registerCloseTests(appLinkSurfaces, {
    'app-link-confirmation': (tester, size) async {
      await openFromButton(
        tester,
        size,
        (context) => unawaited(
          showAppLinkConfirmation(
            context,
            const AppLinkPreview(
              _url,
              (id: 'tickets', name: 'Tickets', icon: null),
              title: 'Printer ticket',
              chipTitle: 'Ticket 123',
              placement: AppLinkPlacement.block,
            ),
            const {
              'title': 'Close ticket?',
              'confirm_label': 'Close ticket',
              'cancel_label': 'Keep open',
            },
          ),
        ),
      );
      return SurfaceProbe(
        isOpen: () => find
            .byKey(const ValueKey('app-link-confirmation'))
            .evaluate()
            .isNotEmpty,
        scrim: const Offset(6, 6),
      );
    },
    for (final surface in [
      'app-link-consent-popover',
      'app-link-hover-card',
      'app-link-more-menu',
    ])
      surface: (tester, size) => open(tester, size, surface),
  });
}
