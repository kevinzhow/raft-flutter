import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_flutter/data/workspace_composer.dart';
import 'package:raft_flutter/platform/desktop_window_exit.dart';

import 'app_global_server_selector_test.dart' show RootFixture;
import 'desktop_window_draft_close_test.dart' show CloseWindow, HoldDraftCache;

void main() {
  testWidgets(
    'actual child Root vetoes an unacknowledged draft save within its deadline and restores editable current text',
    (t) async {
      final cache = HoldDraftCache(), window = CloseWindow();
      final f = RootFixture(cache: cache);
      await f.mount(
        t,
        'light',
        1280,
        uri: Uri(path: '/s/beta'),
        desktopWindows: window,
      );
      final w = f.workspace(t), scope = f.workspace(t).channel!.id;
      final editor = find
          .descendant(
            of: find.byType(RaftComposer).first,
            matching: find.byType(TextField),
          )
          .first;
      await t.enterText(editor, 'held old text');
      await f.flush(t);
      cache.hold = Completer<void>();
      bool? result;
      final closing = window.prepare!().then((v) => result = v);
      await f.flush(t);
      expect(cache.entered.isCompleted, isTrue);
      await t.pump(const Duration(seconds: 6));
      await f.flush(t);
      try {
        expect(
          result,
          isFalse,
          reason: 'A child cache that never ACKs must not freeze the editor/quit indefinitely.',
        );
        expect(find.text('Drafts are taking too long to save'), findsOneWidget);
        await t.tap(find.text('OK'));
        await f.flush(t);
        await t.enterText(editor, 'new text after the timeout');
        await f.flush(t);
        cache.hold!.complete();
        await f.flush(t);
        await closing;
        expect(
          t.widget<TextField>(editor).controller!.text,
          'new text after the timeout',
        );
        expect(w.composer.drafts[scope], 'new text after the timeout');
      } finally {
        if (!cache.hold!.isCompleted) cache.hold!.complete();
        await f.flush(t);
        await f.close(t);
      }
    },
  );
  test('a cancelled held save never starts a later rewrite across newer editing or authority retirement', () async {
    final entered = Completer<void>(), release = Completer<void>();
    var active = true;
    final writes = <String>[];
    final composer = WorkspaceComposer(
      owner: Object(),
      read: (k, id) async => null,
      write: (kind, id, value, {required bool requiredSuccess}) async {
        if (kind != 'draft') return;
        writes.add(value['text']);
        if (!entered.isCompleted) {
          entered.complete();
          await release.future;
        }
      },
    );
    composer.drafts['c'] = 'old';
    final closing = prepareDesktopComposerClose(
      composer,
      current: () => active,
    );
    final refused = expectLater(closing, throwsStateError);
    await entered.future;
    active = false;
    composer.drafts['c'] = 'new';
    release.complete();
    await refused;
    expect(writes, ['old']);
  });
}
