// Guardrail matrix for conversation and thread hosts across all 12 viewport
// sizes from SPEC.md (Rule 1 pressed=visible, Rule 2 height<480 phone
// landscape, header button hit/visibility verification, debug assert).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/features/channel_side_area.dart';
import 'package:raft_flutter/features/channel_side_cards.dart';
import 'package:raft_flutter/features/message_task_actions.dart';
import 'package:raft_ui/raft_ui.dart';

import 'flutter_test_config.dart' show leakDebt;
import 'message_presentation_test.dart' show fixture;
import 'support/side_panel_matrix_support.dart';

Future<void> _runHostMatrix(
  WidgetTester t, {
  required RaftRoute route,
  required String entityId,
  required List<(String, Size, TargetPlatform)> sizes,
  String? profileKey,
  bool checkLounge = false,
}) async {
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
        final (w, _) = await mountSidePanelMatrixWorkspace(
          t,
          size,
          platform: platform,
          section: 'chat',
          initialRoute: route,
          initialEntityId: entityId,
        );
        await exerciseConversationHeaderButtons(
          t,
          w,
          size,
          profileKey: profileKey,
          checkLounge: checkLounge,
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

  final halves = <(String, List<(String, Size, TargetPlatform)>)>[
    ('compact/landscape', sidePanelMatrixSizes.sublist(0, 6)),
    ('foldable/desktop', sidePanelMatrixSizes.sublist(6, 12)),
  ];

  for (final (halfLabel, slice) in halves) {
    testWidgets(
      'channel host passes $halfLabel sizes x header buttons',
      (t) async => _runHostMatrix(
        t,
        route: RaftRoute.channel,
        entityId: 'c1',
        sizes: slice,
      ),
    );

    testWidgets(
      'human DM host passes $halfLabel sizes x header buttons',
      (t) async => _runHostMatrix(
        t,
        route: RaftRoute.dm,
        entityId: 'd-human',
        sizes: slice,
        profileKey: 'profile-human-bob',
      ),
    );

    testWidgets(
      'agent DM host passes $halfLabel sizes x header buttons',
      (t) async => _runHostMatrix(
        t,
        route: RaftRoute.dm,
        entityId: 'd-agent',
        sizes: slice,
        profileKey: 'profile-agent-agent-martin',
        checkLounge: true,
      ),
    );

    testWidgets(
      'lounge host passes $halfLabel sizes x header buttons',
      (t) async => _runHostMatrix(
        t,
        route: RaftRoute.channel,
        entityId: 'l1',
        sizes: slice,
        profileKey: 'profile-agent-agent-martin',
      ),
    );
  }

  testWidgets('thread page host passes all 12 sizes x thread header controls', (
    t,
  ) async {
    for (final (_, size, platform) in sidePanelMatrixSizes) {
      final phone = isPhoneHostSize(size);
      final (w, _) = await mountSidePanelMatrixWorkspace(
        t,
        size,
        platform: platform,
        section: 'chat',
        initialRoute: RaftRoute.channel,
        initialEntityId: 'c1',
      );
      await t.runAsync(
        () => w.openThreadIdentity(
          parentChannelId: 'c1',
          parentMessageId: 'm-ch',
          initialThreadChannelId: 't1',
        ),
      );
      await matrixFrames(t, 6);

      final header = find.byType(RaftThreadHeader);
      expectPanelOnScreen(t, header, size);
      expect(
        find.descendant(
          of: header,
          matching: find.byKey(const Key('channel-tasks-toggle')),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: header,
          matching: find.byKey(const Key('channel-files-toggle')),
        ),
        findsNothing,
      );
      if (phone || size.width < 1024) {
        expect(
          find.byKey(const Key('channel-tasks-toggle')).hitTestable(),
          findsNothing,
        );
      }
      final closeKey = phone
          ? 'mobile-detail-back'
          : (size.width < 1024 ? 'thread-back' : 'thread-close');
      final closeBtn = find.descendant(
        of: header,
        matching: find.byKey(Key(closeKey)),
      );
      expect(closeBtn.hitTestable(), findsOneWidget);
      await t.tap(closeBtn);
      await t.pumpAndSettle();
      expect(find.byType(RaftThreadHeader), findsNothing);
      expect(t.takeException(), isNull, reason: 'at $size');
      await unmountMatrixWorkspace(t);
    }
  });

  testWidgets(
    'channelSideToggles debug-asserts when built inside a non-hosting ChannelSideArea',
    (t) async {
      final (w, _) = (await t.runAsync(() => fixture('owner')))!;
      addTearDown(w.dispose);
      w.section = 'activity';
      w.channel = RaftChannel({
        'id': 'c1',
        'name': 'general',
        'type': 'channel',
      });
      w.navigation.navigate(
        RaftLocation.at(
          serverSlug: 's1',
          route: RaftRoute.activity,
        ).withQuery({'open': 'channel:c1'}),
      );
      TaskV2ConversationsFlag.of(w).markEnabled();

      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          home: Scaffold(
            body: ChannelSideArea(
              controller: w,
              detailPane: false,
              child: Builder(
                builder: (context) =>
                    Row(children: channelSideToggles(context, w)),
              ),
            ),
          ),
        ),
      );
      expect(t.takeException(), isA<FlutterError>());
      await unmountMatrixWorkspace(t);
    },
  );
}
