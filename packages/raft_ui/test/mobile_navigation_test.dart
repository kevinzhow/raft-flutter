import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

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
Widget host(Widget child, RaftFamily family, {bool dark = false}) =>
    MaterialApp(
      theme: raftTheme(family, dark: dark),
      home: Scaffold(
        body: RaftDensityScope(density: RaftDensity.desktop, child: child),
      ),
    );
void main() {
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    testWidgets(
      '$family dark=$dark Bell keeps 32px layout with a 48px touch target',
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
            family,
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
      '$family dark=$dark nav selects actual tab even when already active',
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
            family,
            dark: dark,
          ),
        );
        final home = find.widgetWithText(RaftControl, 'Home');
        final homeControl = family == RaftFamily.brutal
            ? home
            : find.byWidgetPredicate(
                (w) => w is RaftControl && w.semanticLabel == 'Home',
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
  for (final dark in [false, true]) {
    testWidgets(
      'Elegant touch keeps source capsule and distinct48px targets dark=$dark',
      (tester) async {
        final selected = <String>[];
        await tester.pumpWidget(
          host(
            RaftDensityScope(
              density: RaftDensity.touch,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: SizedBox(
                  width: 390,
                  child: RaftMobileNav(
                    items: tabs,
                    selectedId: 'chat',
                    onSelected: selected.add,
                    viewportHeight: 844,
                    bottomInset: 0,
                  ),
                ),
              ),
            ),
            RaftFamily.elegant,
            dark: dark,
          ),
        );
        await tester.pumpAndSettle();
        final capsule = tester.getRect(
          find.byKey(const ValueKey('mobile-nav-source-capsule')),
        );
        expect(capsule.size, const Size(208, 52));
        final targets = <Rect>[];
        final semantics = tester.ensureSemantics();
        try {
          for (var index = 0; index < tabs.length; index++) {
            final control = find.byWidgetPredicate(
              (w) => w is RaftControl && w.semanticLabel == tabs[index].label,
            );
            final target = tester.getRect(control);
            targets.add(target);
            expect(target.size, const Size(48, 48));
            expect(target.left - capsule.left, 2 + index * 52);
            expect(target.top - capsule.top, 2);
            expect(capsule.contains(target.topLeft), isTrue);
            expect(
              capsule.contains(target.bottomRight - const Offset(.01, .01)),
              isTrue,
            );
            expect(tester.getSemantics(control).rect.size, const Size(48, 48));
            final face = find.descendant(
              of: control,
              matching: find.byType(AnimatedContainer),
            );
            expect(tester.getSize(face), const Size(44, 44));
            expect(
              tester.getTopLeft(face) - target.topLeft,
              const Offset(2, 2),
            );
            // Tap outside the painted44px face but inside its real transparent target.
            await tester.tapAt(target.topLeft + const Offset(1, 24));
            expect(selected.last, tabs[index].id);
          }
          for (var index = 1; index < targets.length; index++) {
            expect(targets[index - 1].overlaps(targets[index]), isFalse);
            expect(targets[index].left - targets[index - 1].right, 4);
          }
          final count = selected.length;
          await tester.tapAt(Offset(targets[0].right + 2, capsule.center.dy));
          await tester.tapAt(capsule.topLeft - const Offset(0, 1));
          expect(selected.length, count);
        } finally {
          semantics.dispose();
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  testWidgets(
    'compact Brutal hides icons; Elegant never becomes a blank capsule',
    (tester) async {
      for (final family in RaftFamily.values) {
        await tester.pumpWidget(
          host(
            Align(
              alignment: Alignment.bottomCenter,
              child: SizedBox(
                width: 390,
                child: RaftMobileNav(
                  items: tabs,
                  selectedId: 'chat',
                  onSelected: (_) {},
                  viewportHeight: 560,
                  bottomInset: 0,
                ),
              ),
            ),
            family,
          ),
        );
        // AnimatedTheme must reach the requested family before testing its recipe.
        await tester.pumpAndSettle();
        expect(
          find.byType(RaftIcon),
          family == RaftFamily.brutal ? findsNothing : findsNWidgets(4),
        );
        if (family == RaftFamily.brutal) {
          expect(find.text('Home'), findsOneWidget);
          expect(tester.getSize(find.byType(RaftMobileNav)).height, 33);
        } else {
          expect(tester.getSize(find.byType(RaftMobileNav)).height, 68);
        }
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('guest composition, disabled item and one capped safe inset', (
    tester,
  ) async {
    var selected = 0;
    final guest = [
      tabs.first,
      const RaftMobileNavItem(
        id: 'tasks',
        label: 'Tasks',
        glyph: RaftGlyph.squareCheck,
        enabled: false,
      ),
      tabs.last,
    ];
    await tester.pumpWidget(
      host(
        Align(
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            width: 390,
            child: RaftMobileNav(
              items: guest,
              selectedId: 'chat',
              onSelected: (_) => selected++,
              viewportHeight: 844,
              bottomInset: 100,
            ),
          ),
        ),
        RaftFamily.brutal,
      ),
    );
    expect(find.text('Members'), findsNothing);
    expect(tester.getSize(find.byType(RaftMobileNav)).height, 87);
    await tester.tapAt(
      tester.getCenter(find.widgetWithText(RaftControl, 'Tasks')),
    );
    expect(selected, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });
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
        RaftFamily.brutal,
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
        RaftFamily.brutal,
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
  test(
    'selector vector preserves rotation and shadow offset; compact strips it',
    () {
      final t = raftTheme(RaftFamily.brutal).extension<RaftTokens>()!;
      final tall = RaftMobileServerSelectorRecipe(t, viewportHeight: 844);
      final compact = RaftMobileServerSelectorRecipe(t, viewportHeight: 560);
      expect(tall.contentAngle, -2 * math.pi / 180);
      expect(tall.contentAngle + tall.chevronAngle, 0);
      final face = tall.polygon(const Size(168, 36));
      final shadow = tall.polygon(const Size(168, 36), shadowOffset: 2);
      expect(face.first.dy, greaterThan(0));
      expect(
        (shadow.first - face.first).distance,
        closeTo(math.sqrt(8), .000001),
      );
      expect(compact.contentAngle, 0);
      expect(compact.contentInset, EdgeInsets.zero);
      expect(compact.polygon(const Size(168, 24)).first, Offset.zero);
    },
  );
  testWidgets(
    'server selector keyboard callback is real and only chevron counterrotates',
    (tester) async {
      var opened = 0;
      await tester.pumpWidget(
        host(
          RaftMobileRootHeader(
            viewportHeight: 844,
            leading: RaftMobileServerSelector(
              label: 'Workspace 中文',
              viewportHeight: 844,
              onPressed: () => opened++,
            ),
          ),
          RaftFamily.brutal,
        ),
      );
      expect(find.byType(RaftIcon), findsOneWidget);
      final rotations = tester
          .widgetList<Transform>(
            find.descendant(
              of: find.byType(RaftMobileServerSelector),
              matching: find.byType(Transform),
            ),
          )
          .where((w) => w.transform.storage[1].abs() > .001)
          .toList();
      expect(rotations.length, 2);
      expect(
        rotations[0].transform.storage[1],
        closeTo(math.sin(-2 * math.pi / 180), .000001),
      );
      expect(
        rotations[1].transform.storage[1],
        closeTo(math.sin(2 * math.pi / 180), .000001),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(opened, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
