import 'package:flutter/material.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/raft_navigation_history.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'message_presentation_test.dart' show fixture;

void main() {
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    testWidgets(
      'Mounted desktop Thread header inherits its root $family/$dark',
      (t) async {
        SharedPreferences.setMockInitialValues({});
        await t.binding.setSurfaceSize(const Size(957, 689));
        addTearDown(() => t.binding.setSurfaceSize(null));
        final (w, _) = (await t.runAsync(() => fixture('owner')))!;
        addTearDown(w.dispose);
        w.ledger.switchServer('s1');
        w.threadParent = RaftMessage({
          'id': 'parent',
          'channelId': 'c1',
          'seq': 1,
          'senderType': 'user',
          'content': 'Public parent',
        });
        w.threadChannelId = 'thread-c1';
        // The mounted workspace derives its thread surface from the location.
        // Retain the accepted parent facts while supplying its real URL anchor.
        w.navigation.navigate(
          w.location.withQuery({'thread': 'c1:parent'}),
          kind: RaftNavigationKind.replace,
        );
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(family, dark: dark),
            home: WorkspaceView(
              controller: w,
              appearance: RaftAppearance(light: family),
              onAppearance: (_) async {},
              onLogout: () async {},
            ),
          ),
        );
        await t.pumpAndSettle();
        final root = find.byType(RaftConversationSurface);
        expect(root, findsOneWidget);
        final header = find.descendant(
          of: root,
          matching: find.byType(RaftThreadHeader),
        );
        expect(header, findsOneWidget);
        final paint = t.widget<ColoredBox>(
          find.descendant(of: root, matching: find.byType(ColoredBox)).first,
        );
        expect(paint.color, dark ? const Color(0xff1b1b19) : Colors.white);
        await t.pumpWidget(const SizedBox());
        await t.pump(const Duration(seconds: 1));
        expect(t.takeException(), isNull);
      },
    );
    for (final thread in [false, true]) {
      for (final state in ['loaded', 'empty', 'loading']) {
        testWidgets('Actual timeline surface $family/$dark/$thread/$state', (
          t,
        ) async {
          final (w, _) = (await t.runAsync(() => fixture('owner')))!;
          addTearDown(w.dispose);
          w.ledger.switchServer('s1');
          if (thread) {
            w.threadParent = RaftMessage({
              'id': 'parent',
              'channelId': 'c1',
              'seq': 1,
              'senderType': 'user',
              'senderName': 'Public parent',
              'content': 'Public parent body',
            });
            w.threadChannelId = 'thread-c1';
            w.threadLoading = state == 'loading';
          } else {
            w.loading = state == 'loading';
          }
          final channelId = thread ? 'thread-c1' : 'c1';
          if (state == 'loaded') {
            w.ledger.ingest([
              {
                'id': 'message',
                'channelId': channelId,
                'seq': 1,
                'senderType': 'user',
                'senderName': 'Public author',
                'content': 'Public loaded body',
              },
            ], expectedGeneration: w.ledger.generation);
            w.visibleIds[channelId] = {'message'};
          }
          await t.pumpWidget(
            MaterialApp(
              theme: raftTheme(family, dark: dark),
              home: Scaffold(
                body: thread
                    ? RaftConversationSurface(
                        role: RaftConversationSurfaceRole.threadTimeline,
                        child: RaftChatView(controller: w, thread: true),
                      )
                    : RaftChatView(controller: w),
              ),
            ),
          );
          await t.pumpAndSettle();
          // Source ThreadPanel.tsx:2523–2552 renders the actual parent and
          // loading body while replies wait, with its composer still mounted.
          final replyLoading = thread && state == 'loading';
          final Color timelineColor;
          if (replyLoading) {
            expect(find.byType(Chat), findsNothing);
            expect(find.byType(RaftThreadRepliesLoadingBody), findsOneWidget);
            expect(find.text('Loading...'), findsOneWidget);
            expect(find.text('Public parent body'), findsOneWidget);
            expect(
              t.widget<RaftComposer>(find.byType(RaftComposer)).enabled,
              true,
            );
            final surface = find.byType(RaftConversationSurface);
            timelineColor = t
                .widget<ColoredBox>(
                  find
                      .descendant(
                        of: surface,
                        matching: find.byType(ColoredBox),
                      )
                      .first,
                )
                .color;
          } else {
            timelineColor = t.widget<Chat>(find.byType(Chat)).backgroundColor!;
          }
          expect(
            timelineColor,
            dark
                ? thread
                      ? const Color(0xff1b1b19)
                      : const Color(0xff242422)
                : family == RaftFamily.brutal
                ? Colors.white
                : const Color(0xffffffff),
          );
          final tokens = RaftTokens.of(t.element(find.byType(RaftChatView)));
          final recipe = RaftThreadCompositionRecipe(
            tokens,
            viewportWidth: 800,
            viewportHeight: 600,
            presentation: RaftThreadPresentation.side,
          );
          expect(
            recipe.parentBackground,
            dark ? const Color(0xff242422) : Colors.white,
          );
          expect(find.byType(RaftComposer), findsOneWidget);
          if (state == 'loaded') {
            expect(find.text('Public loaded body'), findsOneWidget);
          }
          await t.pumpWidget(const SizedBox());
          await t.pump(const Duration(seconds: 1));
          expect(t.takeException(), isNull);
        });
      }
    }
  }
}
