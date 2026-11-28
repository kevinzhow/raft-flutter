// #383: after an Artifact opened from a message is closed again (×, Escape or
// Back), the composer of the conversation it was opened from still takes a
// tap, focus and typed text, in every place an Artifact opens in: beside the
// channel, covering it on a medium window, a phone's page, stacked over a
// side thread, the shell's column beside a thread opened in Activity, and
// over a task dialog's card.
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/tap_target_registry.dart';
import 'package:raft_flutter/features/artifacts/artifact_session.dart';
import 'package:raft_ui/raft_ui.dart';

import 'artifact_dialog_cover_test.dart' show frame, mountTaskDialog;
import 'shell_artifact_place_test.dart'
    show artifactLink, card, mountArtifactThread, serveArtifact, viewer;
import 'tap_target_matrix_test.dart'
    show Ctx, channelMessages, mount, msg, threadReplies;
import 'task_surface_test.dart' show flush;

enum _Close { button, escape, back }

typedef _Place = ({
  String name,
  bool touch,
  Future<void> Function(WidgetTester) mount,
  Finder opener,
  Set<_Close> closes,
});

final _editors = find.descendant(
  of: find.byType(RaftComposer),
  matching: find.byType(EditableText),
);

Future<void> _ready(WidgetTester t, Ctx c) async {
  serveArtifact(c);
  ArtifactSession.of(c.w).debugSetEnabled(true);
  await flush(t);
  await t.pumpAndSettle();
}

Future<void> _chat(WidgetTester t, double width, {bool touch = false}) async {
  channelMessages.removeWhere((m) => m['id'] == 'art');
  channelMessages.add(msg('art', 'c1', 6, artifactLink));
  addTearDown(() => channelMessages.removeWhere((m) => m['id'] == 'art'));
  await _ready(
    t,
    await mount(t, TapHost('chat', TapSurface.chat, width, '', touch: touch)),
  );
}

final _inChat = find.descendant(
  of: find.byKey(const ValueKey('message-art')),
  matching: card,
);

TapHost _host(String id) =>
    TapTargetRegistry.hosts.firstWhere((h) => h.id == id);

final _places = <_Place>[
  (
    name: 'beside the channel, desktop 1280',
    touch: false,
    mount: (t) => _chat(t, 1280),
    opener: _inChat,
    closes: {_Close.button, _Close.escape},
  ),
  (
    name: 'covering the channel, foldable 816',
    touch: true,
    mount: (t) => _chat(t, 816, touch: true),
    opener: _inChat,
    closes: _Close.values.toSet(),
  ),
  (
    name: 'a page, phone 390',
    touch: true,
    mount: (t) => _chat(t, 390, touch: true),
    opener: _inChat,
    closes: _Close.values.toSet(),
  ),
  (
    name: 'over the side thread, desktop 1280',
    touch: false,
    mount: (t) async {
      threadReplies['messages'] = [
        msg(
          'r1',
          't1',
          1,
          'The plan: $artifactLink',
          extra: {'senderName': 'Cindy', 'senderId': 'cindy'},
        ),
      ];
      await _ready(t, await mount(t, _host('chat-thread-1280')));
    },
    opener: card,
    closes: {_Close.button},
  ),
  (
    name: "the shell's column beside an Activity thread, desktop 1280",
    touch: false,
    mount: mountArtifactThread,
    opener: card,
    closes: _Close.values.toSet(),
  ),
  (
    name: "the shell's column over an Activity thread, foldable 816",
    touch: true,
    mount: (t) => mountArtifactThread(t, 'activity-thread-816'),
    opener: card,
    closes: _Close.values.toSet(),
  ),
  (
    name: "over a task dialog's card, desktop 1280",
    touch: false,
    mount: mountTaskDialog,
    opener: find.descendant(of: frame, matching: card),
    closes: _Close.values.toSet(),
  ),
];

void main() {
  for (final place in _places) {
    for (final close in place.closes) {
      testWidgets('${place.name}: after ${close.name} the composer takes a '
          'tap and text', (t) async {
        final kind = place.touch
            ? PointerDeviceKind.touch
            : PointerDeviceKind.mouse;
        await place.mount(t);
        final composers = _editors.hitTestable().evaluate().length;
        expect(composers, greaterThan(0));

        await t.tap(place.opener.hitTestable().first, kind: kind);
        await flush(t);
        await t.pumpAndSettle();
        expect(viewer, findsOneWidget);
        // Focus goes into the Artifact, as a click in it does.
        await t.tap(viewer, kind: kind, warnIfMissed: false);
        await t.pumpAndSettle();

        switch (close) {
          case _Close.button:
            await t.tap(
              find.byKey(const ValueKey('artifact-viewer-close')),
              kind: kind,
            );
          case _Close.escape:
            await t.sendKeyEvent(LogicalKeyboardKey.escape);
          case _Close.back:
            await t.binding.handlePopRoute();
        }
        await flush(t);
        await t.pumpAndSettle();
        expect(viewer, findsNothing);

        final shown = _editors.hitTestable();
        expect(
          shown,
          findsNWidgets(composers),
          reason: 'every composer on screen before takes pointers again',
        );
        for (var i = 0; i < composers; i++) {
          FocusManager.instance.primaryFocus?.unfocus();
          await t.pump();
          await t.tap(shown.at(i), kind: kind);
          await t.pumpAndSettle();
          final editor = t.widget<EditableText>(shown.at(i));
          expect(editor.focusNode.hasFocus, isTrue, reason: 'composer $i');
          t.testTextInput.enterText('reply $i');
          await t.pump();
          expect(
            t.widget<EditableText>(shown.at(i)).controller.text,
            'reply $i',
          );
        }
        await t.pumpWidget(const SizedBox());
        await t.pump(const Duration(seconds: 5));
      });
    }
  }
}
