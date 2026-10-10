import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'chat_focus_receipt_test.dart' show paintedMessage;
import 'message_presentation_test.dart' show fixture;
import 'workspace_activity_activation_test.dart' show channelRow, message;

/// ChatPanel.tsx:581-597: a jump to a message in another conversation moves
/// through exactly one ordered progression - (resolving the channel) -> the
/// destination's chrome with a loading message area -> the target window. It
/// never shows the previous conversation under the new slot, the destination's
/// stale cached tail, an empty-channel state, or a stage that goes backwards.
void main() {
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    for (final source in ['search', 'activity']) {
      for (final known in [true, false]) {
        testWidgets(
          '[K03] $family/$dark desktop $source click on a ${known ? 'known' : 'not yet loaded'} channel target shows one ordered progression',
          (tester) async {
            SharedPreferences.setMockInitialValues({});
            tester.view.physicalSize = const Size(1440, 900);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            final (w, api) = (await tester.runAsync(() => fixture('owner')))!;
            addTearDown(w.dispose);
            w.loading = false;
            w.ledger.switchServer('s1');
            final destination = known ? 'c1' : 'c9';
            final unrelated = RaftChannel({
              'id': 'unrelated',
              'name': 'retained main channel',
              'joined': true,
            });
            w.channels = [w.channel!, unrelated];
            w.channel = unrelated;
            w.ledger.ingest([
              message('old-main', 'unrelated'),
              // A cached, unaccepted tail of the destination: never shown.
              message('cached-tail', destination),
            ], expectedGeneration: w.ledger.generation);
            w.visibleIds['unrelated'] = {'old-main'};
            w.section = source;
            final metadata = Completer<Map<String, dynamic>>();
            final context = Completer<Map<String, dynamic>>();
            if (!known) api.routes['GET /channels/c9'] = (_) => metadata.future;
            api.routes['GET /messages/context/target'] = (_) => context.future;
            api.routes['GET /channels/inbox'] = (_) => {
              'items': [
                {
                  ...channelRow,
                  'channelId': destination,
                  'firstUnreadMessageId': 'target',
                },
              ],
            };
            api.routes['GET /messages/search'] = (_) => {
              'results': [
                {
                  ...message('target', destination),
                  'content': 'Selected public hit',
                  'channelName': 'test',
                  'senderName': 'Public sender',
                  'createdAt': '2026-10-08T00:00:00Z',
                },
              ],
              'hasMore': false,
            };
            api.routes['GET /channels/threads/followed'] = (_) => {
              'threads': [],
            };
            api.routes['POST /channels/$destination/read'] = (_) => {};
            api.routes['POST /feature-flags/evaluate'] = (_) => {
              'evaluations': [],
            };
            api.routes['GET /servers/s1/setup-projection'] = (_) => {
              'phase': 'complete',
              'surface': 'complete',
              'blocksChat': false,
            };
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
            await tester.pumpAndSettle();
            final Finder entry;
            if (source == 'search') {
              await tester.enterText(find.byType(TextField).first, 'public');
              await tester.pump(const Duration(milliseconds: 500));
              await tester.pumpAndSettle();
              entry = find.text('Selected public hit');
            } else {
              entry = find.byKey(ValueKey('activity-channel-$destination'));
            }
            expect(entry, findsOneWidget);

            // 0: nothing open, 1: resolving, 2: destination chrome + loading,
            // 3: target painted.
            var stage = 0, targetFrames = 0;
            Rect? targetRect;
            final seen = <int>{};
            void observe(String when) {
              final painted = paintedMessage(tester, 'target');
              final next = painted != null
                  ? 3
                  : find.byType(RaftComposer).evaluate().isNotEmpty
                  ? 2
                  : find.text('LOADING CHANNEL').evaluate().isNotEmpty
                  ? 1
                  : 0;
              expect(next, greaterThanOrEqualTo(stage), reason: when);
              stage = next;
              seen.add(next);
              // Never the previous conversation, its title or a stale tail.
              expect(paintedMessage(tester, 'old-main'), isNull, reason: when);
              expect(
                paintedMessage(tester, 'cached-tail'),
                isNull,
                reason: when,
              );
              expect(find.text('retained main channel'), findsNothing);
              expect(find.text('Start the conversation'), findsNothing);
              if (stage == 1) {
                // A bare, chrome-less "Loading..." is not a stage.
                expect(find.text('Loading...'), findsNothing, reason: when);
                expect(find.byType(RaftComposer), findsNothing);
              }
              if (stage >= 2) {
                expect(find.byType(RaftChatView), findsOneWidget);
                expect(find.byType(RaftComposer), findsOneWidget);
              }
              if (stage == 3) {
                targetFrames++;
                targetRect ??= painted;
                expect(painted, targetRect, reason: 'target must not jump');
              }
            }

            await tester.tap(entry);
            // Activity waits 220 ms before activating, then resolves the
            // channel and holds its target request.
            for (var frame = 0; frame < 30; frame++) {
              await tester.pump(const Duration(milliseconds: 16));
              observe('pending frame $frame');
            }
            if (!known) {
              await tester.runAsync(() async {
                metadata.complete({
                  'id': 'c9',
                  'serverId': 's1',
                  'name': 'late',
                  'joined': true,
                });
                await Future<void>.delayed(const Duration(milliseconds: 35));
              });
              for (var frame = 0; frame < 6; frame++) {
                await tester.pump(const Duration(milliseconds: 16));
                observe('metadata frame $frame');
              }
            }
            expect(stage, lessThan(3));
            expect(
              api.calls.where((r) => r.path == '/messages/context/target'),
              isNotEmpty,
            );
            await tester.runAsync(() async {
              context.complete({
                'messages': [message('target', destination)],
              });
              await Future<void>.delayed(const Duration(milliseconds: 35));
            });
            for (var frame = 0; frame < 20; frame++) {
              await tester.pump(const Duration(milliseconds: 16));
              observe('target frame $frame');
            }
            expect(stage, 3);
            expect(targetFrames, greaterThan(10));
            expect(seen.contains(2), isTrue);
            expect(w.channel?.id, destination);
            expect(w.section, source);
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox());
            await tester.pump();
          },
        );
      }
    }
  }
}
