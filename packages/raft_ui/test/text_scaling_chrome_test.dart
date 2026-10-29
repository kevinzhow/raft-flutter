// Fixed chrome (conversation tabs, bottom navigation, icon buttons, counters)
// is bounded at 1.35x and offers the Large Content Viewer at large text sizes.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  Future<void> pumpAt(WidgetTester t, double factor, Widget child) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    t.platformDispatcher.textScaleFactorTestValue = factor;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        builder: (context, child) => RaftTextScaling(child: child!),
        home: Scaffold(
          body: Align(alignment: Alignment.bottomCenter, child: child),
        ),
      ),
    );
  }

  final viewer = find.byKey(const Key('raft-large-content-viewer'));
  // iOS Accessibility 5: body 53pt.
  const ax5 = 53 / 17;

  group('RaftConversationTabs', () {
    final tabs = const [
      RaftConversationTab(id: RaftConversationTabId.chat, label: 'Chat'),
      RaftConversationTab(id: RaftConversationTabId.tasks, label: 'Tasks'),
      RaftConversationTab(id: RaftConversationTabId.files, label: 'Files'),
    ];

    testWidgets(
      'label text stays within the chrome bound and the strip grows',
      (t) async {
        await pumpAt(
          t,
          ax5,
          RaftConversationTabs(
            tabs: tabs,
            value: RaftConversationTabId.chat,
            onChanged: (_) {},
          ),
        );
        final scaler = t
            .widget<RichText>(
              find
                  .descendant(
                    of: find.text('Chat'),
                    matching: find.byType(RichText),
                  )
                  .first,
            )
            .textScaler;
        expect(
          scaler.scale(100),
          closeTo(100 * RaftTextScaling.chromeMaxScale, 1e-6),
          reason: 'chrome text is bounded at 1.35x, not the 3.1x content scale',
        );
        expect(t.takeException(), isNull);
      },
    );

    testWidgets('a long press on a tab shows it large and release selects it', (
      t,
    ) async {
      final changes = <RaftConversationTabId>[];
      await pumpAt(
        t,
        ax5,
        RaftConversationTabs(
          tabs: tabs,
          value: RaftConversationTabId.chat,
          onChanged: changes.add,
        ),
      );
      final g = await t.startGesture(t.getCenter(find.text('Files')));
      await t.pump(const Duration(milliseconds: 700));
      expect(viewer, findsOneWidget);
      expect(
        find.descendant(of: viewer, matching: find.text('Files')),
        findsOneWidget,
      );
      expect(changes, isEmpty);
      await g.up();
      await t.pump();
      expect(viewer, findsNothing);
      expect(changes, [RaftConversationTabId.files]);
    });

    testWidgets('a tap selects the tab without the viewer', (t) async {
      final changes = <RaftConversationTabId>[];
      await pumpAt(
        t,
        ax5,
        RaftConversationTabs(
          tabs: tabs,
          value: RaftConversationTabId.chat,
          onChanged: changes.add,
        ),
      );
      await t.tap(find.text('Tasks'));
      await t.pump(const Duration(milliseconds: 700));
      expect(viewer, findsNothing);
      expect(changes, [RaftConversationTabId.tasks]);
    });

    testWidgets('no viewer at the default text size', (t) async {
      await pumpAt(
        t,
        1.0,
        RaftConversationTabs(
          tabs: tabs,
          value: RaftConversationTabId.chat,
          onChanged: (_) {},
        ),
      );
      final g = await t.startGesture(t.getCenter(find.text('Files')));
      await t.pump(const Duration(seconds: 1));
      expect(viewer, findsNothing);
      await g.up();
      await t.pump();
    });
  });

  group('RaftMobileNav', () {
    const items = [
      RaftMobileNavItem(id: 'chat', label: 'Home', glyph: RaftGlyph.home),
      RaftMobileNavItem(
        id: 'tasks',
        label: 'Tasks',
        glyph: RaftGlyph.squareCheck,
        badgeCount: 7,
      ),
      RaftMobileNavItem(
        id: 'members',
        label: 'Members',
        glyph: RaftGlyph.users,
      ),
    ];

    testWidgets(
      'long press shows the item, slide and release select the other',
      (t) async {
        final selected = <String>[];
        await pumpAt(
          t,
          ax5,
          RaftMobileNav(
            items: items,
            selectedId: 'chat',
            onSelected: selected.add,
            bottomInset: 0,
          ),
        );
        final tasks = find.byType(RaftLargeContentViewer).at(1);
        final members = find.byType(RaftLargeContentViewer).at(2);
        final g = await t.startGesture(t.getCenter(tasks));
        await t.pump(const Duration(milliseconds: 700));
        expect(viewer, findsOneWidget);
        expect(
          find.descendant(of: viewer, matching: find.text('Tasks')),
          findsOneWidget,
        );
        await g.moveTo(t.getCenter(members));
        await t.pump();
        expect(
          find.descendant(of: viewer, matching: find.text('Members')),
          findsOneWidget,
        );
        await g.up();
        await t.pump();
        expect(viewer, findsNothing);
        expect(selected, ['members']);
        expect(t.takeException(), isNull);
      },
    );
  });

  group('RaftIconButton', () {
    testWidgets('long press shows the tooltip as the large label', (t) async {
      var pressed = 0;
      await pumpAt(
        t,
        ax5,
        RaftIconButton(
          glyph: RaftGlyph.search,
          tooltip: 'Search',
          onPressed: () => pressed++,
        ),
      );
      final g = await t.startGesture(t.getCenter(find.byType(RaftIconButton)));
      await t.pump(const Duration(milliseconds: 700));
      expect(
        find.descendant(of: viewer, matching: find.text('Search')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: viewer, matching: find.byType(RaftIcon)),
        findsOneWidget,
      );
      await g.up();
      await t.pump();
      expect(pressed, 1);
    });

    testWidgets('a quick tap presses the button', (t) async {
      var pressed = 0;
      await pumpAt(
        t,
        ax5,
        RaftIconButton(
          glyph: RaftGlyph.search,
          tooltip: 'Search',
          onPressed: () => pressed++,
        ),
      );
      await t.tap(find.byType(RaftIconButton));
      await t.pump(const Duration(milliseconds: 700));
      expect(pressed, 1);
      expect(viewer, findsNothing);
    });
  });

  group('counters', () {
    testWidgets('the unread count follows the chrome bound at 3.1x', (t) async {
      await pumpAt(t, ax5, const RaftSidebarUnreadCount(count: 12));
      final size = t.getSize(find.text('12'));
      // 11px caption at 3.1x content scale would be ~40px; chrome keeps 1.35x.
      expect(size.height, lessThan(11 * RaftTextScaling.chromeMaxScale * 2.0));
      expect(t.takeException(), isNull);
    });
  });
}
