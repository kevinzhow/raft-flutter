import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_flutter/platform/desktop_title_bar.dart';
import 'package:raft_ui/raft_ui.dart';

import 'app_global_server_selector_test.dart' show RootFixture;

void main() {
  tearDownAll(() => DesktopTitleBarController.platform.state.dispose());
  testWidgets(
    'choosing a native workspace retains the Router and channel editor',
    (t) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      final f = RootFixture();
      try {
        await f.mount(t, 'light', 1200);
        final router = find.byWidgetPredicate((widget) => widget is Router);
        final original = t.state(router);
        await t.tap(find.byKey(const ValueKey('global-server-a')));
        await f.flush(t);
        expect(t.state(router), same(original));
        expect(find.byType(WorkspaceView), findsOneWidget);
        expect(f.workspace(t).channel?.id, 'ca');
        expect(find.text('Accepted a', findRichText: true), findsWidgets);
        expect(
          find.descendant(
            of: find.byType(RaftComposer),
            matching: find.byType(TextField),
          ),
          findsOneWidget,
        );
      } finally {
        await f.close(t);
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );
}
