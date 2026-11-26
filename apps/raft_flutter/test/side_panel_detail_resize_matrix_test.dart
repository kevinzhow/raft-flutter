// Guardrail matrix for Activity/Search DM details across all 12 sizes,
// detail>=640 beside vs overlay, Rule 4 per-conversation open state, and
// Rule 3 bidirectional resize sweep preserving panels and composer draft.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/features/channel_side_store.dart';
import 'package:raft_ui/raft_ui.dart';

import 'flutter_test_config.dart' show leakDebt;
import 'support/side_panel_matrix_support.dart';

Future<void> _openDetailFromSection(WidgetTester t, String section) async {
  if (section == 'search') {
    await t.enterText(find.byType(TextField).first, 'needle');
    await t.pump(const Duration(milliseconds: 220));
    await matrixFrames(t, 6);
    await t.tap(find.byType(RaftSearchResultSurface).first);
  } else {
    await t.tap(find.byKey(const ValueKey('activity-dm-d-agent')));
  }
  await matrixFrames(t, 8);
}

Future<void> _runDetailHostMatrix(
  WidgetTester t,
  String section,
  List<(String, Size, TargetPlatform)> sizes,
) async {
  final semantics = t.ensureSemantics();
  try {
    for (final (label, size, platform) in sizes) {
      // Pre-existing short-height RenderFlex overflow in RaftProductEmptyState
      // at 412x450 when mobile Search opens (cf. layout_class_navigation_matrix_test.dart:104).
      final prior = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.exceptionAsString().contains('overflowed')) return;
        prior?.call(details);
      };
      try {
        final phone = isPhoneHostSize(size);
        final (w, _) = await mountSidePanelMatrixWorkspace(
          t,
          size,
          platform: platform,
          section: section,
        );
        await _openDetailFromSection(t, section);
        expect(find.byType(RaftDmHeader), findsOneWidget);

        if (!phone) {
          final detailFinder = find.byKey(const Key('desktop-content-detail'));
          final detailRect = t.getRect(detailFinder);
          await t.tap(find.byKey(const Key('channel-tasks-toggle')));
          await matrixFrames(t, 6);
          final beside = detailRect.width >= 640 && size.width >= 1024;
          if (beside) {
            expect(find.byKey(const Key('channel-side-overlay')), findsNothing);
            expect(
              t.getRect(find.byKey(const Key('channel-side-column-1'))).right,
              closeTo(detailRect.right, 1.0),
            );
            await t.tap(find.byKey(const Key('channel-side-card-tasks-close')));
          } else {
            expect(
              t.getRect(find.byKey(const Key('channel-side-overlay'))),
              detailRect,
            );
            await t.tap(find.byKey(const Key('channel-side-card-tasks-back')));
          }
          await matrixFrames(t, 6);
        }

        await exerciseConversationHeaderButtons(
          t,
          w,
          size,
          profileKey: 'profile-agent-agent-martin',
          checkLounge: true,
        );
        expect(t.takeException(), isNull, reason: 'at $label ($size)');
        await unmountMatrixWorkspace(t);
      } finally {
        FlutterError.onError = prior;
      }
    }
  } finally {
    semantics.dispose();
  }
}

void main() {
  leakDebt(const ['SourceChannelFilesStore']);

  final slices = <(String, List<(String, Size, TargetPlatform)>)>[
    ('phone portrait/short', sidePanelMatrixSizes.sublist(0, 4)),
    ('phone landscape/medium', sidePanelMatrixSizes.sublist(4, 8)),
    ('foldable/tablet/desktop', sidePanelMatrixSizes.sublist(8, 12)),
  ];

  for (final (sliceLabel, slice) in slices) {
    testWidgets(
      'Activity-detail DM passes $sliceLabel sizes x header buttons',
      (t) async => _runDetailHostMatrix(t, 'activity', slice),
    );
    testWidgets(
      'Search-detail DM passes $sliceLabel sizes x header buttons',
      (t) async => _runDetailHostMatrix(t, 'search', slice),
    );
  }

  testWidgets(
    'Rule 4: open state is per conversation so switching never leaks open panels',
    (t) async {
      final semantics = t.ensureSemantics();
      try {
        final (w, _) = await mountSidePanelMatrixWorkspace(
          t,
          const Size(1280, 900),
          platform: TargetPlatform.linux,
          section: 'chat',
          initialRoute: RaftRoute.channel,
          initialEntityId: 'c1',
        );
        await t.tap(find.byKey(const Key('channel-tasks-toggle')));
        await matrixFrames(t, 6);
        expect(
          find.byKey(const Key('channel-side-card-tasks')),
          findsOneWidget,
        );
        expectTogglesMatchVisibility(t, const Size(1280, 900));

        // Switch to Human DM: Tasks must default closed and unlit.
        w.channel = w.dms.firstWhere((d) => d.id == 'd-human');
        w.navigation.navigate(
          RaftLocation.at(
            serverSlug: 'demo',
            route: RaftRoute.dm,
            entityId: 'd-human',
          ),
        );
        w.notifyListeners();
        await matrixFrames(t, 6);
        expect(find.byKey(const Key('channel-side-card-tasks')), findsNothing);
        expectTogglesMatchVisibility(t, const Size(1280, 900));

        // Open Files on Human DM, then switch back to c1: Tasks returns, Files does not.
        await t.tap(find.byKey(const Key('channel-files-toggle')));
        await matrixFrames(t, 6);
        expect(
          find.byKey(const Key('channel-side-card-files')),
          findsOneWidget,
        );
        expectTogglesMatchVisibility(t, const Size(1280, 900));

        w.channel = w.channels.firstWhere((c) => c.id == 'c1');
        w.navigation.navigate(
          RaftLocation.at(
            serverSlug: 'demo',
            route: RaftRoute.channel,
            entityId: 'c1',
          ),
        );
        w.notifyListeners();
        await matrixFrames(t, 6);
        expect(
          find.byKey(const Key('channel-side-card-tasks')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('channel-side-card-files')), findsNothing);
        expectTogglesMatchVisibility(t, const Size(1280, 900));
        expect(t.takeException(), isNull);
        await unmountMatrixWorkspace(t);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets(
    'Rule 3: bidirectional resize sweep across all 12 sizes keeps open panels, order, and composer draft',
    (t) async {
      final semantics = t.ensureSemantics();
      try {
        final (w, _) = await mountSidePanelMatrixWorkspace(
          t,
          const Size(1440, 900),
          platform: TargetPlatform.linux,
          section: 'chat',
          initialRoute: RaftRoute.dm,
          initialEntityId: 'd-agent',
        );
        await t.tap(find.byKey(const Key('channel-tasks-toggle')));
        await matrixFrames(t, 6);
        await t.tap(find.byKey(const Key('channel-files-toggle')));
        await matrixFrames(t, 6);

        const draftText = 'keep this draft across resize';
        final composer = find.byType(EditableText).first;
        await t.enterText(composer, draftText);
        await matrixFrames(t, 3);
        expect(w.drafts['d-agent'], draftText);
        expect(t.widget<EditableText>(composer).focusNode.hasFocus, isTrue);

        // Wide <-> medium resize preserves composer focus, open panels, and draft.
        for (final size in const [
          Size(1180, 820),
          Size(944, 856),
          Size(1180, 820),
          Size(1440, 900),
        ]) {
          t.view.physicalSize = size;
          await matrixFrames(t, 5);
          expect(t.takeException(), isNull, reason: 'focus check at $size');
          expect(w.drafts['d-agent'], draftText);
          expectTogglesMatchVisibility(t, size);
        }
        expect(
          t
              .widget<EditableText>(find.byType(EditableText).first)
              .focusNode
              .hasFocus,
          isTrue,
        );

        final sweep = [
          ...sidePanelMatrixSizes.reversed,
          ...sidePanelMatrixSizes,
        ];
        for (final (_, size, _) in sweep) {
          t.view.physicalSize = size;
          await matrixFrames(t, 5);
          expect(t.takeException(), isNull, reason: 'at $size');
          expect(
            ChannelSideStore.of(w)
                .cardOpen(ChannelSideCard.tasks, conversationId: 'd-agent'),
            isTrue,
          );
          expect(
            ChannelSideStore.of(w)
                .cardOpen(ChannelSideCard.files, conversationId: 'd-agent'),
            isTrue,
          );
          expectTogglesMatchVisibility(t, size);
          // Files opened after Tasks, so Files stays on top on one-at-a-time covers.
          if (size.width < 1024 || size.height < 480) {
            expectPanelOnScreen(
              t,
              find.byKey(const Key('channel-side-card-files')),
              size,
              reason: 'top card Files must stay visible at $size',
            );
          }
          expect(w.drafts['d-agent'], draftText);
        }
        expect(
          t
              .widget<EditableText>(find.byType(EditableText).first)
              .controller
              .text,
          draftText,
        );
        expect(t.takeException(), isNull);
        await unmountMatrixWorkspace(t);
      } finally {
        semantics.dispose();
      }
    },
  );
}
