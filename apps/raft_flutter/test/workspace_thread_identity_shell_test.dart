import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'history_memory_viewport_test.dart' show drainIo;
import 'message_presentation_test.dart' show fixture;
import 'support/app_services_fixture.dart';

Future<void> _parentSettled(WorkspaceController w) async {
  if (!w.messageDomain.threadParentLoading) return;
  final completed = Completer<void>();
  void changed() {
    if (!w.messageDomain.threadParentLoading && !completed.isCompleted) {
      completed.complete();
    }
  }

  w.addListener(changed);
  try {
    changed();
    await completed.future;
  } finally {
    w.removeListener(changed);
  }
}

void main() {
  testWidgets(
    'parent readiness does not finish before a held HTTP response is accepted',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final (w, api) = (await tester.runAsync(() => fixture('owner')))!;
      w.messageDomain.ledger.switchServer('s1');
      final requested = Completer<void>(), delivery = Completer<void>();
      api.routes['GET /channels/c1/threads/parent'] = (_) => {
        'threadChannelId': 'thread-1',
      };
      api.routes['GET /messages/channel/thread-1'] = (_) => {'messages': []};
      api.routes['GET /messages/context/parent'] = (_) async {
        requested.complete();
        await delivery.future;
        return {
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
        };
      };
      late Future<void> opening;
      final accepted = Completer<void>();
      void changed() {
        if (!w.messageDomain.threadParentLoading && !accepted.isCompleted) {
          accepted.complete();
        }
      }

      try {
        await tester.runAsync(() async {
          opening = w.openThreadIdentity(
            parentChannelId: 'c1',
            parentMessageId: 'parent',
          );
          unawaited(opening);
        });
        await drainIo(tester, requested.future);
        w.addListener(changed);
        var ready = false;
        final settled = _parentSettled(w).then((_) => ready = true);
        // Exercise the former 20ms boundary in fake time while actual response
        // delivery is still gated. Completion must follow the controller event.
        await tester.pump(const Duration(milliseconds: 20));
        expect(w.messageDomain.threadParentLoading, isTrue);
        expect(w.presentedThreadParent, isNull);
        expect(ready, isFalse);
        delivery.complete();
        await drainIo(tester, settled);
        expect(ready, isTrue);
        expect(w.messageDomain.threadParentLoading, isFalse);
        expect(w.presentedThreadParent?.id, 'parent');
      } finally {
        if (!delivery.isCompleted) delivery.complete();
        await drainIo(tester, accepted.future);
        await tester.runAsync(
          () => opening.timeout(const Duration(seconds: 5)),
        );
        w.removeListener(changed);
        w.dispose();
      }
    },
  );

  for (final dark in raftThemeMatrix([false, true])) {
    for (final width in [390.0, 1280.0]) {
      testWidgets(
        '${dark ? 'dark' : 'light'}/$width pending identity keeps actual plain thread shell',
        (tester) async {
          SharedPreferences.setMockInitialValues({});
          tester.view.physicalSize = Size(width, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final (w, api) = (await tester.runAsync(() => fixture('owner')))!;
          addTearDown(w.dispose);
          w.loading = false;
          w.messageDomain.ledger.switchServer('s1');
          final resolution = Completer<Map<String, dynamic>>(),
              parent = Completer<Map<String, dynamic>>();
          final resolutionStarted = Completer<void>(),
              parentStarted = Completer<void>();
          api.routes['GET /channels/c1/threads/parent'] = (_) {
            resolutionStarted.complete();
            return resolution.future;
          };
          api.routes['GET /messages/context/parent'] = (_) {
            parentStarted.complete();
            return parent.future;
          };
          api.routes['GET /messages/channel/thread-1'] = (_) => {
            'messages': [],
          };
          api.routes['GET /channels/threads/followed'] = (_) => {'threads': []};
          api.routes['GET /servers/s1/setup-projection'] = (_) => {
            'phase': 'complete',
            'surface': 'complete',
            'blocksChat': false,
          };
          late Future<void> opening;
          await tester.runAsync(() async {
            opening = w.openThreadIdentity(
              parentChannelId: 'c1',
              parentMessageId: 'parent',
            );
            unawaited(opening);
          });
          await drainIo(
            tester,
            Future.wait([resolutionStarted.future, parentStarted.future]),
          );
          await tester.pumpWidget(
            MaterialApp(
              theme: raftTheme(dark: dark),
              home: withAppServices(
                WorkspaceView(
                  controller: w,
                  appearance: RaftAppearance(),
                  onAppearance: (_) async {},
                  onLogout: () async {},
                ),
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
            expect(find.byTooltip('Jump to Beginning'), findsNothing);
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
              find.descendant(of: root, matching: find.text('Loading thread…')),
              findsOneWidget,
            );
          }
          await tester.runAsync(() async {
            resolution.complete({'threadChannelId': 'thread-1'});
            // The parent request stays held below. Wait for the separate
            // identity/reply load to finish before checking the resolved shell.
            await opening.timeout(const Duration(seconds: 5));
          });
          // Apply the resolved identity to the header; the parent is still
          // pending, and the header must then hold still.
          for (
            var settle = 0;
            settle < 30 &&
                tester.widget<RaftThreadHeader>(headerFinder).parentLabel ==
                    null;
            ++settle
          ) {
            await tester.pump(const Duration(milliseconds: 16));
          }
          for (var frame = 0; frame < 4; ++frame) {
            await tester.pump(const Duration(milliseconds: 16));
            expect(w.messageDomain.threadParentLoading, isTrue);
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
          });
          await drainIo(tester, _parentSettled(w));
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
          await drainIo(tester, w.services.followedThreads.idle);
          expect(w.services.followedThreads.loaded, isTrue);
          await tester.pumpWidget(const SizedBox());
          await tester.pump();
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
