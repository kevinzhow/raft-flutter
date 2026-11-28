// #384 review: a thread the address names is open again after every way back
// onto it, and only when it is not open already. Back and Forward across an
// Artifact the address only stands beside keep the open thread (#383): no new
// reads, the draft and the composer stay. A Back whose channel is still
// loading opens the thread once, whatever else moves the address meanwhile.
// Activity, a thread, a task opened from the list beside it, then System Back
// or Escape: the thread takes text again.
import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/tap_target_registry.dart';
import 'package:raft_flutter/features/artifacts/artifact_session.dart';
import 'package:raft_flutter/features/task_content_slot.dart';
import 'package:raft_flutter/features/task_surface.dart';
import 'package:raft_flutter/features/workspace_history_controls.dart';
import 'package:raft_ui/raft_ui.dart';

import 'shell_artifact_place_test.dart' show serveArtifact, viewer;
import 'support/artifact_fake_client.dart' show artifactShort;
import 'tap_target_matrix_test.dart' show Ctx, channelPage, mount;
import 'task_surface_test.dart' show flush, modernTask;

const _replies = 'GET /messages/channel/t1',
    _parent = 'GET /messages/context/parent',
    _badgeParent = 'GET /messages/context/badge';

Future<void> _settle(WidgetTester t) async {
  await flush(t);
  await t.pumpAndSettle();
}

Future<void> _end(WidgetTester t) async {
  await t.pumpWidget(const SizedBox());
  await t.pump(const Duration(seconds: 5));
}

int _calls(Ctx c, String request) =>
    c.api.calls.where((o) => '${o.method} ${o.path}' == request).length;

PointerDeviceKind _kind(Ctx c) =>
    c.host.touch ? PointerDeviceKind.touch : PointerDeviceKind.mouse;

Finder _threadEditor(Ctx c) => find
    .descendant(
      of: c.threadView,
      matching: find.descendant(
        of: find.byType(RaftComposer),
        matching: find.byType(EditableText),
      ),
    )
    .hitTestable();

Future<void> _type(WidgetTester t, Ctx c, String text) async {
  final editor = _threadEditor(c);
  expect(
    editor,
    findsOneWidget,
    reason: "the thread's composer takes pointers",
  );
  await t.tap(editor, kind: _kind(c));
  await t.pumpAndSettle();
  expect(t.widget<EditableText>(editor).focusNode.hasFocus, isTrue);
  t.testTextInput.enterText(text);
  await t.pump();
  expect(t.widget<EditableText>(editor).controller.text, text);
}

String _draft(Ctx c) =>
    c.t.widget<EditableText>(_threadEditor(c)).controller.text;

/// The top bar's Back or Forward (and Alt+arrow): a visit to the entry
/// beside the current one.
Future<void> _step(Ctx c, {required bool forward}) async {
  final index = c.w.navigation.index + (forward ? 1 : -1);
  unawaited(
    visitWorkspaceHistory(
      c.w,
      index,
      authority: c.w.navigationAuthority,
      expectedUri: c.w.navigation.entries[index].uri,
    ),
  );
  await _settle(c.t);
}

TapHost _host(String id) =>
    TapTargetRegistry.hosts.firstWhere((h) => h.id == id);

void main() {
  for (final host in ['activity-thread-1280', 'chat-thread-1280']) {
    testWidgets('$host: Back and Forward across an Artifact a link put '
        'beside the thread keep the thread open', (t) async {
      final c = await mount(t, _host(host));
      serveArtifact(c);
      ArtifactSession.of(c.w).debugSetEnabled(true);
      await _settle(t);
      await _type(t, c, 'draft');
      final generation = c.w.messageDomain.threadGeneration,
          replies = _calls(c, _replies),
          parent = _calls(c, _parent);
      // A Raft link in the app pushes an Artifact address (Web navigate).
      c.w.navigation.navigate(
        c.w.location.withQuery({'artifact': artifactShort}),
      );
      c.w.notifyListeners();
      await _settle(t);
      // Activity's shell column shows it; a channel's own side area holds it.
      final shown = host.startsWith('activity') ? findsOneWidget : findsNothing;
      expect(viewer, shown);

      await _step(c, forward: false);
      expect(c.w.location.query('artifact'), isNull);
      expect(viewer, findsNothing);
      await _step(c, forward: true);
      expect(c.w.location.query('artifact'), artifactShort);
      expect(viewer, shown);
      await _step(c, forward: false);
      expect(c.w.location.query('artifact'), isNull);

      expect(
        c.w.messageDomain.threadGeneration,
        generation,
        reason: 'the same thread visit',
      );
      expect(_calls(c, _replies), replies, reason: 'no second replies read');
      expect(_calls(c, _parent), parent, reason: 'no second parent read');
      expect(_draft(c), 'draft', reason: 'the draft stays in the composer');
      await _type(t, c, 'draft and more');
      await _end(t);
    });
  }

  group('Back onto a side thread whose channel is still loading', () {
    late Ctx c;
    late List<Completer<Object?>> held;

    Future<void> start(WidgetTester t) async {
      c = await mount(t, _host('chat-thread-1280'));
      serveArtifact(c);
      ArtifactSession.of(c.w).debugSetEnabled(true);
      expect(c.w.location.query('thread'), 'c1:badge');
      c.api.routes['GET /messages/channel/c2'] = (_) => {
        'messages': [],
        'hasMore': false,
      };
      await t.runAsync(() => c.w.selectChannel(c.w.channels[1]));
      expect(c.w.channel?.id, 'c2');
      c.w.notifyListeners();
      await _settle(t);
      expect(c.threadView, findsNothing);
      held = [];
      c.api.routes['GET /messages/channel/c1'] = (_) {
        final answer = Completer<Object?>();
        held.add(answer);
        return answer.future;
      };
    }

    Future<void> answer(WidgetTester t) async {
      for (final request in held) {
        request.complete(channelPage);
      }
      await _settle(t);
    }

    testWidgets('an Artifact opening meanwhile: the thread opens', (t) async {
      await start(t);
      await _step(c, forward: false);
      expect(held, isNotEmpty, reason: 'the channel is still loading');
      // A link opens an Artifact beside the channel while it loads.
      c.w.navigation.navigate(
        c.w.location.withQuery({'artifact': artifactShort}),
      );
      c.w.notifyListeners();
      await answer(t);
      expect(c.w.threadIdentity?.parentMessageId, 'badge');
      expect(c.w.location.query('thread'), 'c1:badge');
      await _type(t, c, 'a reply');
      await _end(t);
    });

    testWidgets('Back, Forward, Back: the thread opens once', (t) async {
      await start(t);
      final parentReads = _calls(c, _badgeParent);
      await _step(c, forward: false);
      await _step(c, forward: true);
      await _step(c, forward: false);
      expect(c.w.location.query('thread'), 'c1:badge');
      await answer(t);
      expect(
        _calls(c, _badgeParent) - parentReads,
        1,
        reason: "only the last Back reads the thread's parent",
      );
      await _type(t, c, 'a reply');
      await _end(t);
    });
  });

  // A wide window shows the list beside the thread, so a task opens from it
  // in the list's slot. (A phone's thread is a page over the list.)
  for (final width in [1280.0, 816.0]) {
    for (final back in ['System Back', 'Escape']) {
      testWidgets('Activity thread at $width, a task opened from the list, '
          'then $back: the thread takes text', (t) async {
        final c = await mount(t, _host('activity-thread-${width.toInt()}'));
        final thread = c.w.location;
        expect(thread.query('thread'), 'c1:parent');
        await _type(t, c, 'draft');
        expect(
          openTaskFromList(c.w, {
            'kind': 'task',
            'taskId': modernTask['id'],
            'parentChannelId': 'c1',
          }, wide: true),
          isTrue,
        );
        await _settle(t);
        expect(find.byType(SourceTaskSurface), findsOneWidget);

        switch (back) {
          case 'System Back':
            await t.binding.handlePopRoute();
          default:
            // The shell's Escape: focus is not in the task (the task's own
            // Escape closes its slot, and a field's is the field's).
            FocusManager.instance.primaryFocus?.unfocus();
            await t.pump();
            await t.sendKeyEvent(LogicalKeyboardKey.escape);
        }
        await _settle(t);
        expect(find.byType(SourceTaskSurface), findsNothing);
        expect(c.w.location.query('thread'), thread.query('thread'));
        expect(c.w.threadIdentity?.parentMessageId, 'parent');
        expect(_draft(c), 'draft', reason: 'the draft is back');
        await _type(t, c, 'draft and more');
        await _end(t);
      });
    }
  }
}
