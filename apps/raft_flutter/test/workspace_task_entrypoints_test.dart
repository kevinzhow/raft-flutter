import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/raft_navigation_history.dart';
import 'package:raft_flutter/features/conversation_panel.dart';
import 'package:raft_flutter/features/task_surface.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

import 'message_context_transition_test.dart' show row;
import 'task_surface_test.dart' show modernTask, taskRoutes, flush;
import 'workspace_source_location_contract_test.dart' show pageFixture;
import 'support/app_services_fixture.dart';

void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    for (final width in [390.0, 1280.0]) {
      for (final chip in [false, true]) {
        testWidgets(
          '[K10b entry] actual ${chip ? 'message footer chip' : 'channel Tasks tab card'} owns task URI ${dark ? 'dark' : 'light'}/$width',
          (t) async {
            // Source TasksPanel964–987 and MessageItem3685–3700 distinguish
            // board arbitration from footer task intent; neither steals side.
            t.view.physicalSize = Size(width, 844);
            t.view.devicePixelRatio = 1;
            addTearDown(t.view.reset);
            final (w, api) = await pageFixture(t, section: 'chat');
            taskRoutes(api, modernTask);
            api.routes['GET /tasks/channel/c1'] = (request) => {
              'tasks':
                  request.queryParameters['status'] == null ||
                      request.queryParameters['status'] == modernTask['status']
                  ? [modernTask]
                  : [],
              'nextCursor': null,
            };
            final detail = Completer<Map>();
            api.routes['GET /tasks/channel/c1/number/8'] = (_) => detail.future;
            w.messageDomain.ledger.ingest([
              row('task-parent', 'c1', 1),
            ], expectedGeneration: w.messageDomain.ledger.generation);
            w.messageDomain.visibleIds['c1'] = {'task-parent'};
            if (width >= 768) {
              w.messageDomain.state.threadParent = RaftMessage(
                row('ordinary-parent', 'c1', 2),
              );
              w.threadChannelId = 'ordinary-side';
              w.messageDomain.state.threadLoading = false;
              w.drafts[w.draftScope(thread: true)!] = 'Retained side draft';
            }
            w.navigation.navigate(
              w.location.withQuery({
                if (width >= 768) 'thread': 'c1:ordinary-parent',
                // On a phone an open profile is a page that covers the chat.
                if (width >= 768) 'profile': 'human:alice',
                'kept': 'yes',
              }),
              kind: RaftNavigationKind.replace,
            );
            await t.pumpWidget(
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
            await flush(t);
            final mainComposer = find.descendant(
              of: find.byType(ConversationPanel),
              matching: find.byType(RaftComposer),
            );
            final editor = find.descendant(
              of: mainComposer,
              matching: find.byType(TextField),
            );
            await t.enterText(editor, 'Real main task-entry draft');
            final field = t.widget<TextField>(editor);
            field.controller!.selection = const TextSelection.collapsed(
              offset: 7,
            );
            final composerState = t.state(mainComposer);
            if (!chip) {
              final tabs = find.byKey(const Key('conversation-tabs'));
              await t.tap(
                find.descendant(of: tabs, matching: find.text('Tasks')),
              );
              await flush(t);
              expect(w.location.chatTab, 'tasks');
            }
            final mainRevision = w.navigationRevision;
            final historyIndex = w.navigation.index;
            if (chip) {
              await t.tap(
                find.byKey(const ValueKey('message-task-task-parent')),
              );
            } else {
              await t.tap(find.text('Scoped actual task'));
            }
            await flush(t);
            final surface = find.byType(SourceTaskSurface);
            expect(surface, findsOneWidget);
            expect(w.location.query('task'), 'c1:task-parent');
            expect(w.location.query('kept'), 'yes');
            expect(
              w.location.thread?.itemId,
              width >= 768 ? 'ordinary-parent' : null,
            );
            expect(w.threadChannelId, width >= 768 ? 'ordinary-side' : null);
            expect(
              w.navigationRevision,
              // Board activation drops an open profile (a retiring change);
              // a phone has none (its profile page covers the chat).
              chip || width < 768 ? mainRevision : mainRevision + 1,
            );
            // Board activation removes profile, so its Source sync replaces;
            // footer-chip activation changes only its independent task slot.
            expect(
              w.navigation.index,
              chip || width < 768 ? historyIndex + 1 : historyIndex,
            );
            expect(
              w.location.query('profile'),
              chip && width >= 768 ? 'human:alice' : null,
            );
            expect(w.location.chatTab, chip ? null : 'tasks');
            detail.complete({'task': modernTask});
            await flush(t);
            expect(
              find.byKey(const ValueKey('task-modal-title')),
              findsOneWidget,
            );
            expect(w.threadChannelId, width >= 768 ? 'ordinary-side' : null);
            await t.sendKeyEvent(LogicalKeyboardKey.escape);
            await flush(t);
            await t.pumpAndSettle();
            expect(surface, findsNothing);
            expect(w.location.query('task'), isNull);
            expect(
              w.location.thread?.itemId,
              width >= 768 ? 'ordinary-parent' : null,
            );
            expect(w.location.query('kept'), 'yes');
            if (width >= 768) {
              expect(
                w.drafts[w.draftScope(thread: true)],
                'Retained side draft',
              );
            }
            if (!chip) {
              final tabs = find.byKey(const Key('conversation-tabs'));
              await t.tap(
                find.descendant(of: tabs, matching: find.text('Chat')),
              );
              await flush(t);
            }
            expect(t.state(mainComposer), same(composerState));
            expect(
              t.widget<TextField>(editor).controller,
              same(field.controller),
            );
            expect(field.controller!.text, 'Real main task-entry draft');
            expect(field.controller!.selection.baseOffset, 7);
            expect(t.takeException(), isNull);
            await t.pumpWidget(const SizedBox.shrink());
            await t.pump(const Duration(milliseconds: 300));
          },
        );
      }
    }
  }
}
