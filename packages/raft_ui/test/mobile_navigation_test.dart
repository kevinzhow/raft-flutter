import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

const tabs = [
  RaftMobileNavItem(id: 'chat', label: 'Home', glyph: RaftGlyph.home),
  RaftMobileNavItem(id: 'tasks', label: 'Tasks', glyph: RaftGlyph.squareCheck),
  RaftMobileNavItem(id: 'members', label: 'Members', glyph: RaftGlyph.users),
  RaftMobileNavItem(
    id: 'settings',
    label: 'Settings',
    glyph: RaftGlyph.settings,
  ),
];
Widget host(Widget child, {bool dark = false}) => MaterialApp(
  theme: raftTheme(dark: dark),
  home: Scaffold(
    body: RaftDensityScope(density: RaftDensity.desktop, child: child),
  ),
);
void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    testWidgets(
      '${dark ? 'dark' : 'light'} Bell keeps 32px layout with a 48px touch target',
      (tester) async {
        var opened = 0;
        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(
          host(
            RaftDensityScope(
              density: RaftDensity.touch,
              child: Center(
                child: RaftMobileNotificationButton(onPressed: () => opened++),
              ),
            ),
            dark: dark,
          ),
        );
        final bell = find.byType(RaftMobileNotificationButton);
        expect(tester.getSize(bell), const Size.square(32));
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        // This point lies outside the 32px visual, inside the 48px target.
        await tester.tapAt(tester.getCenter(bell) + const Offset(0, 20));
        await tester.pump();
        expect(opened, 1);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        expect(opened, 2);
        expect(tester.takeException(), isNull);
        semantics.dispose();
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
    testWidgets(
      '${dark ? 'dark' : 'light'} nav selects actual tab even when already active',
      (tester) async {
        final ids = <String>[];
        await tester.pumpWidget(
          host(
            Align(
              alignment: Alignment.bottomCenter,
              child: SizedBox(
                width: 390,
                child: RaftMobileNav(
                  items: tabs,
                  selectedId: 'chat',
                  onSelected: ids.add,
                  viewportHeight: 844,
                  bottomInset: 0,
                ),
              ),
            ),
            dark: dark,
          ),
        );
        final homeControl = find.byWidgetPredicate(
          (w) =>
              (w is RaftControl && w.semanticLabel == 'Home') ||
              (w is RaftInteractive && w.semanticLabel == 'Home'),
        );
        await tester.tap(homeControl);
        expect(ids, ['chat']);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        expect(ids, ['chat', 'tasks']);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  testWidgets('Home header Bell keeps source glyph and real callback', (
    tester,
  ) async {
    var opened = 0;
    await tester.pumpWidget(
      host(
        RaftMobileRootHeader(
          viewportHeight: 844,
          leading: RaftMobileServerSelector(
            label: 'Workspace',
            onPressed: () {},
            viewportHeight: 844,
          ),
          actions: [RaftMobileNotificationButton(onPressed: () => opened++)],
        ),
      ),
    );
    final bell = find.byWidgetPredicate(
      (w) => w is RaftIcon && w.glyph == RaftGlyph.bell,
    );
    expect(bell, findsOneWidget);
    expect(tester.widget<RaftIcon>(bell).size, 16);
    await tester.tap(find.byType(RaftMobileNotificationButton));
    expect(opened, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('390px Home header bounds long CJK server label beside Bell', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const label = '很长的工作空间名称 日本語 Long workspace name';
    await tester.pumpWidget(
      host(
        RaftMobileRootHeader(
          viewportHeight: 844,
          leading: RaftMobileServerSelector(
            label: label,
            viewportHeight: 844,
            onPressed: () {},
          ),
          actions: [RaftMobileNotificationButton(onPressed: () {})],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final header = tester.getRect(find.byType(RaftMobileRootHeader));
    final server = tester.getRect(find.byType(RaftMobileServerSelector));
    final bell = tester.getRect(find.byType(RaftMobileNotificationButton));
    expect(server.right, lessThanOrEqualTo(bell.left - 12));
    expect(bell.right, lessThanOrEqualTo(header.right - 16));
    expect(
      tester.widget<Text>(find.text(label)).overflow,
      TextOverflow.ellipsis,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
