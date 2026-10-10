import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
    for (final width in [390.0, 1280.0]) {
      testWidgets(
        '$family/$dark/$width pending identity keeps actual plain thread shell',
        (tester) async {
          SharedPreferences.setMockInitialValues({});
          tester.view.physicalSize = Size(width, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final (w, api) = (await tester.runAsync(() => fixture('owner')))!;
          addTearDown(w.dispose);
          w.loading = false;
          w.ledger.switchServer('s1');
          final resolution = Completer<Map<String, dynamic>>(),
              parent = Completer<Map<String, dynamic>>();
          api.routes['GET /channels/c1/threads/parent'] = (_) =>
              resolution.future;
          api.routes['GET /messages/context/parent'] = (_) => parent.future;
          api.routes['GET /messages/channel/thread-1'] = (_) => {
            'messages': [],
          };
          api.routes['GET /channels/threads/followed'] = (_) => {'threads': []};
          api.routes['GET /servers/s1/setup-projection'] = (_) => {
            'phase': 'complete',
            'surface': 'complete',
            'blocksChat': false,
          };
          await tester.runAsync(() async {
            unawaited(
              w.openThreadIdentity(
                parentChannelId: 'c1',
                parentMessageId: 'parent',
              ),
            );
            await Future<void>.delayed(const Duration(milliseconds: 20));
          });
          await tester.pumpWidget(
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
          final root = find.byType(RaftConversationSurface);
          // The actual narrow shell keeps its header above the timeline
          // surface, while the wide shell mounts it inside the thread column.
          final headerFinder = find.byType(RaftThreadHeader);
          for (var frame = 0; frame < 4; ++frame) {
            await tester.pump(const Duration(milliseconds: 16));
            expect(w.location.thread?.itemId, 'parent');
            expect(w.presentedThreadParent, isNull);
            expect(headerFinder, findsOneWidget);
            final header = tester.widget<RaftThreadHeader>(headerFinder);
            expect(header.parentLabel, isNull);
            expect(header.interactiveTitle, isFalse);
            expect(header.onJumpToStart, isNull);
            expect(header.actions, isEmpty);
            expect(find.byTooltip('Jump to beginning'), findsNothing);
            expect(
              find.byKey(const Key('mobile-detail-back')),
              width < 768 ? findsOneWidget : findsNothing,
            );
            expect(
              find.byKey(const Key('thread-close')),
              width >= 1024 ? findsOneWidget : findsNothing,
            );
            expect(
              find.descendant(of: root, matching: find.byType(RaftComposer)),
              findsNothing,
            );
            expect(
              find.descendant(of: root, matching: find.text('Loading...')),
              findsOneWidget,
            );
          }
          await tester.runAsync(() async {
            resolution.complete({'threadChannelId': 'thread-1'});
            // Wait for the resolution to be applied, not a fixed wall-clock
            // slice: a loaded host can take longer than one short delay.
            final deadline = DateTime.now().add(const Duration(seconds: 5));
            while (w.presentedThreadParent == null &&
                DateTime.now().isBefore(deadline)) {
              await Future<void>.delayed(const Duration(milliseconds: 10));
            }
          });
          for (var frame = 0; frame < 4; ++frame) {
            await tester.pump(const Duration(milliseconds: 16));
            expect(w.threadParentLoading, isTrue);
            final header = tester.widget<RaftThreadHeader>(headerFinder);
            expect(header.parentLabel, '#test');
            expect(header.interactiveTitle, isTrue);
            expect(header.onJumpToStart, isNotNull);
            // Source ThreadOverflowMenu needs only the resolved identity: the
            // menu is present before the parent row loads (first frame final).
            expect(header.actions, hasLength(1));
            final composer = find.descendant(
              of: root,
              matching: find.byType(RaftComposer),
            );
            expect(composer, findsOneWidget);
            expect(tester.widget<RaftComposer>(composer).enabled, isTrue);
          }
          await tester.runAsync(() async {
            parent.complete({
              'messages': [
                {
                  'id': 'parent',
                  'channelId': 'c1',
                  'seq': '1',
                  'senderId': 'alice',
                  'senderType': 'user',
                  'content': 'Real parent',
                },
              ],
            });
            await Future<void>.delayed(const Duration(milliseconds: 20));
          });
          await tester.pump();
          expect(w.presentedThreadParent?.id, 'parent');
          // The parent row arriving does not change the header.
          expect(
            tester.widget<RaftThreadHeader>(headerFinder).actions,
            hasLength(1),
          );
          // Mounting the genuine parent action queries its followed state.
          // Flush that request before disposal instead of suppressing it.
          for (var frame = 0; frame < 4; ++frame) {
            await tester.pump(const Duration(milliseconds: 16));
          }
          await tester.pumpWidget(const SizedBox());
          await tester.pump();
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
