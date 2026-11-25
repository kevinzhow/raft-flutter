// The heads that can stand in the Artifact column (the desktop browser, a web
// page's panel) draw Back instead of their close X when their host stacks them
// over another pane, and that Back is the host's (it pops this pane and shows
// the one underneath).
//
// Covering the conversation they already drew Back; standing beside it with a
// pane waiting behind them they kept drawing the X, because nothing told them
// they were stacked. `ChannelSideArea` now hands the column a
// `RaftPanelHeaderChrome.onBack`, as it does for Details and the profile.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/channel_side_web_preview.dart';
import 'package:raft_flutter/features/channel_side_web_preview_panel.dart';
import 'package:raft_flutter/features/desktop_browser_panel.dart';
import 'package:raft_flutter/features/desktop_browser_tabs.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import 'close_dialogs_test.dart' show ignoreOverflow;
import 'support/fake_webview.dart';
import 'support/web_preview_fixture.dart';

/// Beside the conversation on a desktop window, in a column of its own.
Future<void> _mount(
  WidgetTester t,
  Widget head, {
  VoidCallback? hostBack,
}) async {
  t.view.physicalSize = const Size(1280, 800);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      theme: raftTheme().copyWith(platform: TargetPlatform.linux),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topRight,
          child: SizedBox(
            width: 400,
            child: hostBack == null
                ? head
                : RaftPanelHeaderChrome(
                    actions: const [],
                    onBack: hostBack,
                    child: head,
                  ),
          ),
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
}

void main() {
  setUpAll(() => WebViewPlatform.instance = FakeWebView());
  setUp(FakeWebView.reset);

  group('the desktop browser head', () {
    const close = ValueKey('browser-close');
    const back = ValueKey('browser-back');

    Widget panel(DesktopBrowserTabs tabs) => DesktopBrowserPanel(
      tabs: tabs,
      conversation: 'c1',
      raftHosts: const {},
      covering: false,
      pageBuilder: (_, _, _, _) => const SizedBox.expand(),
    );

    DesktopBrowserTabs open(WidgetTester t) {
      final tabs = DesktopBrowserTabs();
      addTearDown(tabs.dispose);
      tabs.open('c1', Uri.parse('https://page.test/'));
      return tabs;
    }

    testWidgets('on its own draws its close', (t) async {
      await _mount(t, panel(open(t)));
      expect(find.byKey(close), findsOneWidget);
      expect(find.byKey(back), findsNothing);
    });

    testWidgets('stacked draws the host\'s Back', (t) async {
      var popped = 0;
      final tabs = open(t);
      await _mount(t, panel(tabs), hostBack: () => popped++);
      expect(find.byKey(back), findsOneWidget);
      expect(find.byKey(close), findsNothing);
      await t.tap(find.byKey(back));
      await t.pumpAndSettle();
      expect(popped, 1);
      expect(
        tabs.forConversation('c1'),
        isNotNull,
        reason: 'the host pops the pane; the browser keeps its tabs',
      );
    });
  });

  group('the web page head', () {
    const close = ValueKey('web-preview-close');
    const back = ValueKey('web-preview-back');

    Future<Widget> panel(WidgetTester t) async {
      ignoreOverflow();
      final (w, _) = (await t.runAsync(webPreviewFixture))!;
      addTearDown(w.dispose);
      final store = WebPreviewStore.of(w)
        ..open(
          const WebPreviewPage(
            url: 'https://docs.example.com/',
            conversationId: 'c1',
          ),
        );
      return WebPreviewPanel(store: store, page: store.page!, covering: false);
    }

    testWidgets('on its own draws its close', (t) async {
      await _mount(t, await panel(t));
      expect(find.byKey(close), findsOneWidget);
      expect(find.byKey(back), findsNothing);
    });

    testWidgets('stacked draws the host\'s Back', (t) async {
      var popped = 0;
      await _mount(t, await panel(t), hostBack: () => popped++);
      expect(find.byKey(back), findsOneWidget);
      expect(find.byKey(close), findsNothing);
      await t.tap(find.byKey(back));
      await t.pumpAndSettle();
      expect(popped, 1);
    });
  });
}
