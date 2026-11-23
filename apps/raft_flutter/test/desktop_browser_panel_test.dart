import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/desktop_browser_panel.dart';
import 'package:raft_flutter/features/desktop_browser_tabs.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  final first = Uri.parse('https://example.test/a?q=1');
  const plus = ValueKey('browser-new-tab');
  const input = ValueKey('browser-address-input');
  const address = ValueKey('browser-address');
  const more = ValueKey('browser-more-tabs');

  Future<DesktopBrowserTabs> mount(
    WidgetTester tester, {
    double width = 480,
    bool allControls = false,
  }) async {
    final tabs = DesktopBrowserTabs()..open('channel', first);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              height: 500,
              child: DesktopBrowserPanel(
                tabs: tabs,
                conversation: 'channel',
                raftHosts: const {'raft.test'},
                onShowArtifact: allControls ? () {} : null,
                onExpand: allControls ? () {} : null,
                pageBuilder: (context, tab, visible, events) =>
                    Text('Page ${tab.id}'),
              ),
            ),
          ),
        ),
      ),
    );
    addTearDown(tabs.dispose);
    return tabs;
  }

  testWidgets('new tab focuses an empty address and Enter loads it', (
    tester,
  ) async {
    final tabs = await mount(tester);
    await tester.tap(find.byKey(plus));
    await tester.pump();
    expect(find.text('Type an address above to open a page.'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byKey(input)).focusNode!.hasFocus,
      isTrue,
    );
    await tester.enterText(find.byKey(input), 'localhost:8040/service');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(
      tabs.forConversation('channel')!.active.url,
      Uri.parse('http://localhost:8040/service'),
    );
    expect(find.text('Not secure'), findsOneWidget);
  });

  testWidgets(
    'editing Escape restores the address, then Escape closes the panel',
    (tester) async {
      final tabs = await mount(tester);
      await tester.tap(find.byKey(address));
      await tester.pump();
      await tester.enterText(find.byKey(input), 'raft.test');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(find.byKey(input), findsOneWidget);
      expect(tabs.forConversation('channel')!.active.url, first);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(find.byKey(address), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(tabs.forConversation('channel'), isNull);
    },
  );

  testWidgets('the narrowest dock keeps the tab and header actions reachable', (
    tester,
  ) async {
    final tabs = await mount(tester, width: 160, allControls: true);
    for (var number = 2; number <= desktopBrowserTabLimit; number++) {
      tabs.open('channel', Uri.parse('https://site$number.test/'));
    }
    await tester.pump();
    for (final key in [
      'switch-to-artifact',
      'browser-expand',
      'browser-close',
      'browser-tab-close-12',
      'browser-more-tabs',
      'browser-new-tab',
    ]) {
      expect(
        find.byKey(ValueKey(key)).hitTestable(),
        findsOneWidget,
        reason: key,
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('overflow keeps the active tab visible and selects hidden tabs', (
    tester,
  ) async {
    final tabs = await mount(tester, width: 330);
    for (var number = 2; number <= desktopBrowserTabLimit; number++) {
      tabs.open('channel', Uri.parse('https://site$number.test/'));
    }
    await tester.pump();
    expect(find.byKey(const ValueKey('browser-tab-12')), findsOneWidget);
    await tester.tap(find.byKey(more));
    await tester.pumpAndSettle();
    await tester.tap(find.text('site8.test'));
    await tester.pumpAndSettle();
    expect(tabs.forConversation('channel')!.active.url!.host, 'site8.test');
    expect(find.byKey(const ValueKey('browser-tab-8')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tab shortcuts close only the active tab', (tester) async {
    final tabs = await mount(tester);
    await tester.tap(find.byKey(plus));
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyW);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(tabs.forConversation('channel')!.tabs, hasLength(1));
    expect(tabs.forConversation('channel')!.active.url, first);
  });
}
