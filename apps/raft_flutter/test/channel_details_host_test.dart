import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/channel_details_host.dart';
import 'package:raft_flutter/features/channel_settings.dart';
import 'package:raft_flutter/features/channel_side_cards.dart';
import 'package:raft_flutter/features/channel_side_store.dart';
import 'package:raft_ui/raft_ui.dart';

import 'channel_side_area_test.dart' show pumpArea, probeInits, probeTaps;

void main() {
  for (final dark in [false, true]) {
    testWidgets('details is a seam column and leaves chat reachable / $dark', (
      t,
    ) async {
      final rig = await pumpArea(t, size: const Size(1280, 800), dark: dark);
      final details = ChannelDetailsStore.of(rig.w);
      details.open(rig.w.channel!);
      await t.pumpAndSettle();
      expect(find.byType(ChannelSettings), findsOneWidget);
      expect(find.text('Details'), findsOneWidget);
      expect(find.byKey(const Key('channel-overflow-scrim')), findsNothing);
      expect(t.getSize(find.byKey(const Key('channel-details'))).width, 400);
      final column = find.byKey(const Key('channel-side-column-3'));
      final frame = find.descendant(
        of: column,
        matching: find.byType(RaftSidePanelFrame),
      );
      expect(frame, findsOneWidget);
      final box = t.widget<Container>(
        find.descendant(of: frame, matching: find.byType(Container)).first,
      );
      final tokens = RaftTokens.of(t.element(column));
      final border =
          (box.foregroundDecoration as BoxDecoration).border! as Border;
      expect(border.left.color, tokens.colors['line-seam']);
      expect(border.left.width, 1);
      await t.tap(find.byKey(const Key('chat-messages')));
      await t.pump();
      expect(probeTaps, 1);
      expect(find.byType(ChannelSettings), findsOneWidget);
      await t.tap(find.byKey(const Key('channel-details-close')));
      await t.pumpAndSettle();
      expect(find.byType(ChannelSettings), findsNothing);
      expect(probeInits, 1);
    });
  }

  testWidgets('details coexists with Tasks and Escape restores opener focus', (
    t,
  ) async {
    final opener = FocusNode();
    addTearDown(opener.dispose);
    final rig = await pumpArea(
      t,
      size: const Size(1280, 800),
      chat: Focus(focusNode: opener, child: const Text('Conversation')),
    );
    ChannelSideCards.toggle(rig.w, ChannelSideCard.tasks);
    await t.pump();
    opener.requestFocus();
    await t.pump();
    ChannelDetailsStore.of(rig.w).open(rig.w.channel!);
    await t.pumpAndSettle();
    expect(find.byKey(const Key('body-tasks')), findsOneWidget);
    expect(find.byType(ChannelSettings), findsOneWidget);
    expect(opener.hasFocus, isFalse);
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pumpAndSettle();
    expect(find.byType(ChannelSettings), findsNothing);
    expect(find.byKey(const Key('body-tasks')), findsOneWidget);
    expect(opener.hasFocus, isTrue);
  });

  testWidgets('Escape cancels a details header move before closing details', (
    t,
  ) async {
    final semantics = t.ensureSemantics();
    try {
      final rig = await pumpArea(t, size: const Size(1280, 800));
      ChannelSideCards.toggle(rig.w, ChannelSideCard.tasks);
      ChannelDetailsStore.of(rig.w).open(rig.w.channel!);
      await t.pumpAndSettle();
      final grip = find.byKey(const Key('side-section-grip-details'));
      expect(grip, findsOneWidget);
      expect(find.bySemanticsLabel('Move Details'), findsOneWidget);
      Focus.of(t.element(grip)).requestFocus();
      await t.pump();
      await t.sendKeyEvent(LogicalKeyboardKey.space);
      await t.pump();
      expect(find.byKey(const Key('side-section-proxy')), findsOneWidget);
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pump();
      expect(find.byKey(const Key('side-section-proxy')), findsNothing);
      expect(find.byType(ChannelSettings), findsOneWidget);
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
      expect(find.byType(ChannelSettings), findsNothing);
      expect(rig.saves, isEmpty);
    } finally {
      semantics.dispose();
    }
  });
}
