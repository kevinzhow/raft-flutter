import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
    RaftHoverDismissController? hover,
  }) async {
    final tabs = DesktopBrowserTabs()..open('channel', first);
    await tester.pumpWidget(
      RaftHoverDismissScope(
        controller: hover,
        navigation: tabs,
        location: () => 'channel',
        child: MaterialApp(
          theme: ThemeData(platform: TargetPlatform.linux),
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

  testWidgets('Enter dismisses hover and keeps the narrow security hint', (
    tester,
  ) async {
    final hover = RaftHoverDismissController();
    addTearDown(hover.dispose);
    final tabs = await mount(tester, width: 224, hover: hover);
    await tester.tap(find.byKey(address));
    await tester.pump();
    await tester.enterText(find.byKey(input), 'localhost:8040/service');
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(
      tester.getCenter(find.byKey(const ValueKey('browser-open-tab'))),
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 800));
    expect(find.text('Open in browser'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('Open in browser'), findsNothing);
    expect(find.byKey(input), findsNothing);
    expect(tabs.forConversation('channel')!.active.url!.scheme, 'http');
    expect(
      tester.widget<RaftInteractive>(find.byKey(address)).semanticHint,
      'Not secure',
    );
  });

  testWidgets('tab close and Escape work immediately after address submit', (
    tester,
  ) async {
    final tabs = await mount(tester);
    await tester.tap(find.byKey(plus));
    await tester.pump();
    await tester.enterText(find.byKey(input), 'example.test/second');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyW);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(tabs.forConversation('channel')!.tabs, hasLength(1));

    await tester.tap(find.byKey(address));
    await tester.pump();
    await tester.enterText(find.byKey(input), 'example.test/third');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(tabs.forConversation('channel'), isNull);
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
      tabs.open('channel', Uri.parse('http://site$number.test/a-long-path'));
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
    final title = find.descendant(
      of: find.byKey(const ValueKey('browser-tab-12')),
      matching: find.text('site12.test'),
    );
    final close = find.byKey(const ValueKey('browser-tab-close-12'));
    final addressText = find.descendant(
      of: find.byKey(address),
      matching: find.text('site12.test/a-long-path', findRichText: true),
    );
    final paragraph = tester.renderObject<RenderParagraph>(title);
    expect(
      paragraph.getBoxesForSelection(
        const TextSelection(baseOffset: 0, extentOffset: 1),
      ),
      isNotEmpty,
    );
    expect(addressText, findsNothing);
    expect(
      tester.widget<RaftInteractive>(find.byKey(address)).tooltip,
      contains('Not secure'),
    );
    expect(
      tester.getRect(title).right,
      lessThanOrEqualTo(tester.getCenter(close).dx),
    );
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

  testWidgets('More tabs stays pressed until Escape dismisses its menu', (
    tester,
  ) async {
    final tabs = await mount(tester, width: 224);
    for (var number = 2; number <= 5; number++) {
      tabs.open('channel', Uri.parse('https://site$number.test/'));
    }
    await tester.pump();
    final trigger = find.descendant(
      of: find.byKey(more),
      matching: find.byType(RaftInteractive),
    );
    await tester.tap(find.byKey(more));
    await tester.pumpAndSettle();
    expect(tester.widget<RaftInteractive>(trigger).toggled, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(tester.widget<RaftInteractive>(trigger).toggled, isFalse);
    expect(tabs.forConversation('channel'), isNotNull);
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

  testWidgets('uncovering a previously focused page keeps restored focus', (
    tester,
  ) async {
    final tabs = DesktopBrowserTabs()..open('channel', first);
    final opener = FocusNode();
    addTearDown(tabs.dispose);
    addTearDown(opener.dispose);
    late StateSetter change;
    var showing = true;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              change = setState;
              return Column(
                children: [
                  Focus(
                    focusNode: opener,
                    child: const Text('Artifact opener'),
                  ),
                  Expanded(
                    child: Offstage(
                      offstage: !showing,
                      child: DesktopBrowserPanel(
                        tabs: tabs,
                        conversation: 'channel',
                        raftHosts: const {},
                        showing: showing,
                        pageBuilder: (_, _, _, _) => const SizedBox.expand(),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    change(() => showing = false);
    await tester.pumpAndSettle();
    opener.requestFocus();
    change(() => showing = true);
    await tester.pumpAndSettle();
    expect(opener.hasFocus, isTrue);
  });
}
