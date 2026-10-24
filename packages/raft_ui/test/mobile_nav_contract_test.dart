import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

const _items = [
  RaftMobileNavItem(id: 'chat', label: 'Home', glyph: RaftGlyph.home),
  RaftMobileNavItem(id: 'tasks', label: 'Tasks', glyph: RaftGlyph.checkSquare),
  RaftMobileNavItem(id: 'members', label: 'Members', glyph: RaftGlyph.users),
  RaftMobileNavItem(
    id: 'settings',
    label: 'Settings',
    glyph: RaftGlyph.settings,
  ),
];
Widget _host({
  required bool dark,
  required Widget child,
  bool touch = false,
  double width = 390,
}) => MaterialApp(
  theme: raftTheme(
    dark: dark,
  ).copyWith(platform: touch ? TargetPlatform.android : TargetPlatform.linux),
  home: Scaffold(
    body: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: width,
        child: RaftDensityScope(
          density: touch ? RaftDensity.touch : RaftDensity.desktop,
          child: child,
        ),
      ),
    ),
  ),
);
void main() {
  // Web v1.21.23 MainLayout.MobileTabBar + computed raft-ui 0.7.0 recipe.
  for (final dark in [false, true]) {
    testWidgets(
      'docked bar matches source bounds and visible labels dark=$dark',
      (tester) async {
        await tester.pumpWidget(
          _host(
            dark: dark,
            child: RaftMobileNav(
              items: _items,
              selectedId: 'chat',
              onSelected: (_) {},
              bottomInset: 0,
            ),
          ),
        );
        expect(tester.getSize(find.byType(RaftMobileNav)), const Size(390, 52));
        for (final item in _items) {
          expect(find.text(item.label), findsOneWidget);
        }
        expect(
          tester.widgetList<RaftIcon>(find.byType(RaftIcon)).map((i) => i.size),
          everyElement(22),
        );
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
    testWidgets(
      'docked labels activate roots by pointer and keyboard dark=$dark',
      (tester) async {
        final selected = <String>[];
        await tester.pumpWidget(
          _host(
            dark: dark,
            child: RaftMobileNav(
              items: _items,
              selectedId: 'chat',
              onSelected: selected.add,
              bottomInset: 0,
            ),
          ),
        );
        await tester.tap(find.text('Home'));
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        expect(selected, ['chat', 'tasks']);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  for (final size in [
    const Size(390, 844),
    const Size(856, 944),
    const Size(944, 856),
  ]) {
    testWidgets('touch targets stay inside docked chrome at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final selected = <String>[];
      await tester.pumpWidget(
        _host(
          dark: false,
          touch: true,
          width: size.width,
          child: RaftMobileNav(
            items: _items,
            selectedId: 'chat',
            onSelected: selected.add,
            bottomInset: 0,
          ),
        ),
      );
      final bar = tester.getRect(find.byType(RaftMobileNav));
      expect(bar.size, Size(size.width, 52));
      for (final item in _items) {
        final control = find.byWidgetPredicate(
          (w) =>
              (w is RaftControl && w.semanticLabel == item.label) ||
              (w is RaftInteractive && w.semanticLabel == item.label),
        );
        final target = tester.getRect(control);
        expect(target.height, greaterThanOrEqualTo(48));
        expect(target.width, greaterThanOrEqualTo(48));
        expect(bar.contains(target.topLeft), isTrue);
        expect(
          bar.contains(target.bottomRight - const Offset(.01, .01)),
          isTrue,
        );
        await tester.tapAt(target.bottomCenter - const Offset(0, 1));
        expect(selected.last, item.id);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  testWidgets('visible label is spoken once and disabled tab stays inert', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final selected = <String>[];
    await tester.pumpWidget(
      _host(
        dark: false,
        touch: true,
        child: RaftMobileNav(
          items: const [
            RaftMobileNavItem(id: 'chat', label: 'Home', glyph: RaftGlyph.home),
            RaftMobileNavItem(
              id: 'tasks',
              label: 'Tasks',
              glyph: RaftGlyph.checkSquare,
              enabled: false,
            ),
          ],
          selectedId: 'chat',
          onSelected: selected.add,
          bottomInset: 0,
        ),
      ),
    );
    final home = find.byWidgetPredicate(
      (w) => w is RaftInteractive && w.semanticLabel == 'Home',
    );
    expect(tester.getSemantics(home).label, 'Home');
    await tester.tap(find.text('Tasks'));
    expect(selected, isEmpty);
    await tester.tap(find.text('Home'));
    expect(selected, ['chat']);
    semantics.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
