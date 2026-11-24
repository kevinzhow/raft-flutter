import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/desktop_browser_panel.dart';
import 'package:raft_flutter/features/desktop_browser_tabs.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  testWidgets('the active tab close icon uses dark ink in the dark theme', (
    tester,
  ) async {
    final tabs = DesktopBrowserTabs()
      ..open('channel', Uri.parse('https://example.test/'));
    addTearDown(tabs.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(dark: true).copyWith(platform: TargetPlatform.linux),
        home: Scaffold(
          body: DesktopBrowserPanel(
            tabs: tabs,
            conversation: 'channel',
            raftHosts: const {},
            pageBuilder: (_, _, _, _) => const SizedBox.expand(),
          ),
        ),
      ),
    );
    final activeId = tabs.forConversation('channel')!.activeId;
    final closeIcon = find.descendant(
      of: find.byKey(ValueKey('browser-tab-close-$activeId')),
      matching: find.byWidgetPredicate(
        (widget) => widget is RaftIcon && widget.glyph == RaftGlyph.x,
      ),
    );
    final ink = tester.widget<RaftIcon>(closeIcon).color;
    final expected = RaftTokens.of(tester.element(closeIcon)).ui.stickerInk;
    await tester.pumpWidget(const SizedBox.shrink());
    expect(ink, expected);
  });

  testWidgets('the browser switch globe aligns with the Web artifact header', (
    tester,
  ) async {
    const header = ValueKey('artifact-header');
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 900);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme().copyWith(platform: TargetPlatform.linux),
        home: Scaffold(
          body: RaftPanelHeaderBar(
            key: header,
            title: 'Release plan',
            desktopBar: true,
            leading: BrowserSwitchChip(
              glyph: RaftGlyph.globe,
              label: 'Back to browser, 2 tabs',
              count: 2,
              onPressed: () {},
            ),
          ),
        ),
      ),
    );
    final globe = find.byWidgetPredicate(
      (widget) => widget is RaftIcon && widget.glyph == RaftGlyph.globe,
    );
    final offset =
        tester.getTopLeft(globe).dx - tester.getTopLeft(find.byKey(header)).dx;
    await tester.pumpWidget(const SizedBox.shrink());
    expect(offset, 15.5);
  });
}
