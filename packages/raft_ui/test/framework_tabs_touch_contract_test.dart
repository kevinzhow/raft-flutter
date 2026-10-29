import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.linux]) {
    for (final width in [390.0, 856.0]) {
      testWidgets('$platform/$width tabs preserve visual32 and reach48', (
        t,
      ) async {
        t.view.physicalSize = Size(width, 944);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        var calls = 0;
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(),
            home: Scaffold(
              body: Column(
                children: [
                  RaftConversationTabs(
                    tabs: const [
                      RaftConversationTab(
                        id: RaftConversationTabId.chat,
                        label: 'Chat',
                      ),
                      RaftConversationTab(
                        id: RaftConversationTabId.files,
                        label: 'Files',
                      ),
                    ],
                    value: RaftConversationTabId.chat,
                    onChanged: (_) => calls++,
                  ),
                ],
              ),
            ),
          ),
        );
        final tab = t.getRect(find.byKey(const ValueKey('panel-tab-chat')));
        expect(tab.height, 32);
        expect(t.getSize(find.byType(RaftConversationTabs)).height, 49);
        // Actual pointer input in the 8px padding, outside the visible button.
        await t.tapAt(Offset(tab.center.dx, tab.top - 7));
        expect(calls, platform == TargetPlatform.android ? 1 : 0);
        await t.tapAt(Offset(tab.center.dx, tab.bottom + 7));
        expect(calls, platform == TargetPlatform.android ? 2 : 0);
        await t.tapAt(tab.center);
        expect(calls, platform == TargetPlatform.android ? 3 : 1);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox.shrink());
      }, variant: TargetPlatformVariant.only(platform));
    }
  }
}
