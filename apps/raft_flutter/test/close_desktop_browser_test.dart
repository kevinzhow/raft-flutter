import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/desktop_browser_panel.dart';
import 'package:raft_flutter/features/desktop_browser_tabs.dart';
import 'package:raft_flutter/features/web_link_open.dart';
import 'package:raft_ui/raft_ui.dart';

import 'support/close_registry_desktop_browser.dart';
import 'support/close_runner.dart';
import 'support/close_surface.dart';
import 'support/web_preview_fixture.dart';

void main() {
  const conversation = 'c1';
  const browserClose = ValueKey('browser-close');
  const browserBack = ValueKey('browser-back');
  const more = ValueKey('browser-more-tabs');
  const moreMenu = ValueKey('browser-more-tabs-menu');
  const linkMenu = ValueKey('desktop-web-link-menu');

  Future<void> mount(WidgetTester tester, Size size, Widget body) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme().copyWith(platform: TargetPlatform.linux),
        home: Scaffold(body: body),
      ),
    );
    await tester.pumpAndSettle();
  }

  OpenSurface browser({bool openMenu = false}) => (tester, size) async {
    final tabs = DesktopBrowserTabs();
    addTearDown(tabs.dispose);
    for (
      var index = 0;
      index < (openMenu ? desktopBrowserTabLimit : 1);
      index++
    ) {
      tabs.open(conversation, Uri.parse('https://page$index.test/'));
    }
    await mount(
      tester,
      size,
      Align(
        alignment: Alignment.topRight,
        child: SizedBox(
          width: 330,
          child: DesktopBrowserPanel(
            tabs: tabs,
            conversation: conversation,
            raftHosts: const {},
            covering: size.width < 768,
            pageBuilder: (_, _, _, _) => const SizedBox.expand(),
          ),
        ),
      ),
    );
    if (openMenu) {
      await tester.tap(find.byKey(more));
      await tester.pumpAndSettle();
      return SurfaceProbe(
        isOpen: () => find.byKey(moreMenu).evaluate().isNotEmpty,
        scrim: Offset(12, size.height - 12),
      );
    }
    return SurfaceProbe(
      isOpen: () => tabs.forConversation(conversation) != null,
      x: find.byKey(browserClose),
      back: find.byKey(browserBack),
    );
  };

  registerCloseTests(desktopBrowserSurfaces, {
    'desktop-browser': browser(),
    'desktop-browser-more-tabs': browser(openMenu: true),
    'desktop-browser-link-menu': (tester, size) async {
      final (workspace, _) = (await tester.runAsync(webPreviewFixture))!;
      addTearDown(workspace.dispose);
      await mount(
        tester,
        size,
        Builder(
          builder: (context) => Center(
            child: RaftButton(
              label: 'Open menu',
              onPressed: () => showDesktopWebLinkMenu(
                context,
                workspace,
                'https://page.test/',
                conversation,
                const Offset(160, 80),
                () {},
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open menu'));
      await tester.pumpAndSettle();
      return SurfaceProbe(
        isOpen: () => find.byKey(linkMenu).evaluate().isNotEmpty,
        scrim: Offset(12, size.height - 12),
      );
    },
  });
}
