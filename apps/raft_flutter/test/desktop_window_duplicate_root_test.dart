import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_flutter/platform/desktop_windows.dart';
import 'package:raft_ui/raft_ui.dart';

import 'app_global_server_selector_test.dart' show RootFixture;
import 'desktop_server_windows_test.dart' show WindowsFixture;

class DuplicateWindow extends WindowsFixture {
  @override
  bool get isChild => true;
  @override
  Future<void> selectServer(String serverId) async {
    if (serverId == 'b') throw const DesktopWindowAlreadyOpen();
  }
}

void main() {
  for (final replaceWithHome in [false, true]) {
    testWidgets(
      'actual Root restores its route and editable draft after a focused existing window, replaceWithHome=$replaceWithHome',
      (t) async {
        final f = RootFixture();
        await f.mount(
          t,
          'light',
          1280,
          uri: Uri(path: '/s/alpha'),
          desktopWindows: DuplicateWindow(),
        );
        final w = f.workspace(t), previous = f.router(t).currentConfiguration;
        final editor = find
            .descendant(
              of: find.byType(RaftComposer).first,
              matching: find.byType(TextField),
            )
            .first;
        await t.enterText(editor, 'Keep my original draft');
        await f.flush(t);
        final selected = w.servers.singleWhere((s) => s.id == 'b');
        final view = t.widget<WorkspaceView>(find.byType(WorkspaceView));
        unawaited(view.onSwitchServer!(selected, replaceWithHome));
        await f.flush(t);
        try {
          expect(find.byType(WorkspaceView), findsOneWidget);
          expect(identical(f.workspace(t), w), isTrue);
          expect(w.server!.id, 'a');
          expect(f.router(t).currentConfiguration, previous);
          expect(
            t.widget<TextField>(editor).controller!.text,
            'Keep my original draft',
          );
          expect(
            find.text('This server is already open in another window.'),
            findsOneWidget,
          );
          await t.enterText(editor, 'I can still edit here');
          await f.flush(t);
          expect(
            t.widget<TextField>(editor).controller!.text,
            'I can still edit here',
          );
        } finally {
          await f.close(t);
        }
      },
    );
  }
}
