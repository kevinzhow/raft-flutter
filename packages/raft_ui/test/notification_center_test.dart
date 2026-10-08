import 'dart:ui' show SemanticsRole;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

const _themes = [
  (RaftFamily.brutal, false),
  (RaftFamily.elegant, false),
  (RaftFamily.elegant, true),
];

Widget _host(
  Widget child, {
  RaftFamily family = RaftFamily.elegant,
  bool dark = false,
  RaftDensity density = RaftDensity.desktop,
  double textScale = 1,
}) => MaterialApp(
  theme: raftTheme(family, dark: dark),
  home: Scaffold(
    body: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: RaftDensityScope(
        density: density,
        child: Center(child: child),
      ),
    ),
  ),
);

Finder _action(String id, String label) =>
    find.byKey(ValueKey('notification-action-$id-$label'));

void main() {
  for (final (family, dark) in _themes) {
    final themeName = '$family/$dark';
    testWidgets('empty center retains mounted 320x288 composition $themeName', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const RaftNotificationCenter(entries: []),
          family: family,
          dark: dark,
        ),
      );
      expect(
        tester.getSize(find.byKey(const Key('notification-center-surface'))),
        const Size(320, 288),
      );
      expect(
        find.text(
          family == RaftFamily.brutal ? 'NOTIFICATIONS' : 'Notifications',
        ),
        findsOneWidget,
      );
      expect(find.text('all clear'), findsOneWidget);
      expect(find.text('No notifications right now'), findsOneWidget);
      expect(
        find.text("You'll see things here that need your attention."),
        findsOneWidget,
      );
      expect(find.byType(RaftControl), findsNothing);
      final semantics = tester.widgetList<Semantics>(
        find.descendant(
          of: find.byType(RaftNotificationCenter),
          matching: find.byType(Semantics),
        ),
      );
      expect(
        semantics.any(
          (widget) => widget.properties.role == SemanticsRole.dialog,
        ),
        isTrue,
      );
      expect(
        semantics.any((widget) => widget.properties.role == SemanticsRole.menu),
        isFalse,
      );
      final emptyPadding = tester.widget<Padding>(
        find.byKey(const Key('notification-center-empty')),
      );
      expect(
        emptyPadding.padding,
        const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('notification-center-empty')),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Padding &&
                widget.padding ==
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
          ),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'rows retain input order and only supplied actions fire $themeName',
      (tester) async {
        var view = 0, secondary = 0, dismiss = 0, disabled = 0;
        final entries = [
          RaftNotificationEntry(
            id: 'information',
            kind: RaftNotificationKind.info,
            title: 'Plan notice',
            body: 'Your plan needs attention.',
            actions: [
              RaftNotificationAction(
                label: 'View',
                primary: true,
                onPressed: () => view++,
              ),
              RaftNotificationAction(
                label: 'Details',
                onPressed: () => secondary++,
              ),
              RaftNotificationAction(
                label: 'Dismiss',
                onPressed: () => dismiss++,
              ),
              RaftNotificationAction(
                label: 'Unavailable',
                enabled: false,
                onPressed: () => disabled++,
              ),
            ],
          ),
          const RaftNotificationEntry(
            id: 'error',
            kind: RaftNotificationKind.error,
            title: 'Computer offline',
          ),
        ];
        await tester.pumpWidget(
          _host(
            RaftNotificationCenter(entries: entries),
            family: family,
            dark: dark,
          ),
        );
        expect(
          tester.getTopLeft(find.text('Plan notice')).dy,
          lessThan(tester.getTopLeft(find.text('Computer offline')).dy),
        );
        expect(find.text('2 items'), findsOneWidget);
        final rowNode = tester.getSemantics(
          find.byKey(const ValueKey('notification-entry-information')),
        );
        expect(rowNode.getSemanticsData().role, SemanticsRole.listItem);
        expect(rowNode.parent!.getSemanticsData().role, SemanticsRole.list);
        await tester.tap(find.text('Plan notice'));
        await tester.tap(_action('information', 'Unavailable'));
        expect([view, secondary, dismiss, disabled], [0, 0, 0, 0]);
        for (final label in ['View', 'Details', 'Dismiss']) {
          await tester.tap(_action('information', label));
          await tester.pump();
        }
        expect([view, secondary, dismiss, disabled], [1, 1, 1, 0]);
        // Dismissal is controlled by the caller, with no private list mutation.
        expect(find.text('Plan notice'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'action visual height stays 24 while touch bounds reach 48 $themeName',
      (tester) async {
        final center = RaftNotificationCenter(
          entries: [
            RaftNotificationEntry(
              id: 'computer',
              kind: RaftNotificationKind.warning,
              title: 'Computer update available',
              actions: [
                RaftNotificationAction(
                  label: 'View',
                  primary: true,
                  onPressed: () {},
                ),
              ],
            ),
          ],
        );
        await tester.pumpWidget(_host(center, family: family, dark: dark));
        expect(tester.getSize(_action('computer', 'View')).height, 24);
        await tester.pumpWidget(
          _host(center, family: family, dark: dark, density: RaftDensity.touch),
        );
        final bounds = tester.getSize(_action('computer', 'View'));
        expect(bounds.height, greaterThanOrEqualTo(48));
        expect(bounds.width, greaterThanOrEqualTo(48));
        final control = tester.widget<RaftControl>(_action('computer', 'View'));
        expect(control.visualHeight, 24);
        expect(control.recipe!.visualHeight, 24);
        expect(
          control.recipe!.radius,
          RaftControlRecipe(
            control.recipe!.tokens,
            variant: RaftControlVariant.primary,
            visualHeight: 24,
          ).radius,
        );
        expect(
          control.recipe!.background,
          family == RaftFamily.brutal
              ? control.recipe!.tokens.colors['color-brutal-pink']
              : control.recipe!.tokens.colors['primary-soft'],
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('keyboard action and Escape use actual focus $themeName', (
      tester,
    ) async {
      var views = 0, closes = 0;
      await tester.pumpWidget(
        _host(
          RaftNotificationCenter(
            autofocus: true,
            onDismiss: () => closes++,
            entries: [
              RaftNotificationEntry(
                id: 'computer',
                kind: RaftNotificationKind.warning,
                title: 'Computer update available',
                actions: [
                  RaftNotificationAction(
                    label: 'View',
                    primary: true,
                    onPressed: () => views++,
                  ),
                ],
              ),
            ],
          ),
          family: family,
          dark: dark,
        ),
      );
      await tester.pump();
      // Original keyboard-open behavior focuses the first View immediately.
      final focusedControl = tester.widget<FocusableActionDetector>(
        find.descendant(
          of: _action('computer', 'View'),
          matching: find.byType(FocusableActionDetector),
        ),
      );
      expect(focusedControl.focusNode!.hasPrimaryFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(views, 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(closes, 1);
      expect(find.text('Computer update available'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'source status/header roles stay distinct from generic menus $themeName',
      (tester) async {
        await tester.pumpWidget(
          _host(
            const RaftNotificationCenter(entries: []),
            family: family,
            dark: dark,
          ),
        );
        final t = RaftTokens.of(
          tester.element(find.byType(RaftNotificationCenter)),
        );
        final r = RaftNotificationRecipe(t);
        expect(
          r.radius,
          BorderRadius.circular(family == RaftFamily.brutal ? 0 : 6),
        );
        expect(r.divider.width, family == RaftFamily.brutal ? 2 : 1);
        expect(r.background, family == RaftFamily.brutal ? t.panel : t.popover);
        expect(
          r.headerBackground,
          family == RaftFamily.brutal
              ? t.colors['brutal-cream']
              : dark
              ? Colors.transparent
              : t.panel,
        );
        if (dark) {
          expect(
            r.iconFill(RaftNotificationKind.error),
            const Color(0xffd33c30).withValues(alpha: .3),
          );
          expect(
            r.iconFill(RaftNotificationKind.warning),
            const Color(0xffac571d).withValues(alpha: .28),
          );
          expect(
            r.iconFill(RaftNotificationKind.info),
            const Color(0xff007592).withValues(alpha: .28),
          );
          expect(
            r.iconFill(RaftNotificationKind.success),
            const Color(0xff0c7d43).withValues(alpha: .28),
          );
        } else if (family == RaftFamily.brutal) {
          expect(
            r.iconFill(RaftNotificationKind.error),
            t.colors['color-brutal-orange'],
          );
          expect(
            r.iconFill(RaftNotificationKind.info),
            t.colors['color-brutal-yellow'],
          );
        } else {
          expect(
            r.iconFill(RaftNotificationKind.info),
            t.colors['info']!.withValues(alpha: .8),
          );
        }
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'mounted glyph override preserves generic status fill $themeName',
      (tester) async {
        await tester.pumpWidget(
          _host(
            Builder(
              builder: (context) {
                final t = RaftTokens.of(context);
                return RaftNotificationCenter(
                  entries: [
                    const RaftNotificationEntry(
                      id: 'generic',
                      kind: RaftNotificationKind.warning,
                      glyph: RaftGlyph.monitor,
                      title: 'Generic warning',
                    ),
                    RaftNotificationEntry(
                      id: 'mounted',
                      kind: RaftNotificationKind.warning,
                      glyph: RaftGlyph.monitor,
                      title: 'Mounted warning',
                      iconForeground: family == RaftFamily.brutal
                          ? t.ink
                          : t.strong,
                    ),
                  ],
                );
              },
            ),
            family: family,
            dark: dark,
          ),
        );
        final t = RaftTokens.of(
          tester.element(find.byType(RaftNotificationCenter)),
        );
        final r = RaftNotificationRecipe(t);
        for (final id in ['generic', 'mounted']) {
          final row = find.byKey(ValueKey('notification-entry-$id'));
          final glyph = tester.widget<RaftIcon>(
            find.descendant(of: row, matching: find.byType(RaftIcon)),
          );
          expect(
            glyph.color,
            id == 'generic'
                ? r.iconForeground(RaftNotificationKind.warning)
                : family == RaftFamily.brutal
                ? t.ink
                : t.strong,
          );
          final fill = tester
              .widgetList<Container>(
                find.descendant(of: row, matching: find.byType(Container)),
              )
              .firstWhere((widget) => widget.decoration is BoxDecoration);
          expect(
            (fill.decoration! as BoxDecoration).color,
            r.iconFill(RaftNotificationKind.warning),
          );
        }
        if (dark) {
          expect(
            t.strong,
            isNot(r.iconForeground(RaftNotificationKind.warning)),
          );
        }
        expect(tester.takeException(), isNull);
      },
    );

    for (final scale in [1.0, 1.3, 1.6, 2.0]) {
      testWidgets(
        'long localized content scrolls below a fixed header $themeName/$scale',
        (tester) async {
          var called = 0;
          await tester.pumpWidget(
            _host(
              RaftNotificationCenter(
                title: 'Workspace notifications and important information',
                countLabel: '12 items requiring attention',
                entries: List.generate(
                  12,
                  (i) => RaftNotificationEntry(
                    id: 'long-$i',
                    kind: RaftNotificationKind.warning,
                    title:
                        'Computer update available for a workstation with a long name $i',
                    body:
                        'An administrator can open the details and review the current status. '
                        '服务器与账号的提醒内容保持原始顺序。',
                    actions: [
                      RaftNotificationAction(
                        label: 'View computer and review the details',
                        primary: true,
                        onPressed: () => called++,
                      ),
                    ],
                  ),
                ),
              ),
              family: family,
              dark: dark,
              textScale: scale,
              density: RaftDensity.touch,
            ),
          );
          final header = find.byKey(const Key('notification-center-header'));
          final headerOrigin = tester.getTopLeft(header);
          final scrollable = find.descendant(
            of: find.byKey(const Key('notification-center-scroller')),
            matching: find.byType(Scrollable),
          );
          final state = tester.state<ScrollableState>(scrollable);
          expect(state.position.maxScrollExtent, greaterThan(0));
          await tester.drag(
            find.byKey(const Key('notification-center-scroller')),
            const Offset(0, -180),
          );
          await tester.pumpAndSettle();
          expect(state.position.pixels, greaterThan(0));
          expect(tester.getTopLeft(header), headerOrigin);
          expect(called, 0);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('mounted Elegant row matches measured source slot geometry', (
    tester,
  ) async {
    // Actual Web DOM receipt: popup-elegant-light-412x915.json.
    // This verifies source dimensions; it is not a pixel-parity assertion.
    // Widget tests otherwise use Ahem: its14px monospaced glyphs wrap both
    // lines and produce138px, unlike this measured production Geist fixture.
    await tester.runAsync(() async {
      ByteData bytes;
      try {
        // The full app suite bundles dependency assets under the package prefix.
        bytes = await rootBundle.load(
          'packages/raft_ui/assets/fonts/Geist.ttf',
        );
      } on FlutterError {
        // Running this package alone uses its local asset manifest instead.
        bytes = await rootBundle.load('assets/fonts/Geist.ttf');
      }
      final font = FontLoader('packages/raft_ui/Geist')
        ..addFont(Future.value(bytes));
      await font.load();
    });
    await tester.pumpWidget(
      _host(
        RaftNotificationCenter(
          entries: [
            RaftNotificationEntry(
              id: 'computers',
              kind: RaftNotificationKind.warning,
              glyph: RaftGlyph.monitor,
              title: 'Computers need attention',
              body: '1 needs upgrade · 1 offline',
              actions: [
                RaftNotificationAction(
                  label: 'View',
                  primary: true,
                  onPressed: () {},
                ),
                RaftNotificationAction(label: 'Dismiss', onPressed: () {}),
              ],
            ),
          ],
        ),
      ),
    );
    expect(
      tester.getSize(find.byKey(const Key('notification-center-header'))),
      const Size(320, 39),
    );
    expect(
      tester.getSize(find.byKey(const Key('notification-center-scroller'))),
      const Size(320, 249),
    );
    final row = find.byKey(const ValueKey('notification-entry-computers'));
    expect(tester.getSize(row), const Size(320, 98));
    final origin = tester.getTopLeft(row);
    expect(
      tester.getTopLeft(find.text('Computers need attention')) - origin,
      const Offset(46, 12),
    );
    expect(tester.getTopLeft(_action('computers', 'View')).dy - origin.dy, 62);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancelled pointer action does not activate a notification', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      _host(
        RaftNotificationCenter(
          entries: [
            RaftNotificationEntry(
              id: 'computer',
              kind: RaftNotificationKind.warning,
              title: 'Computer update available',
              actions: [
                RaftNotificationAction(
                  label: 'View',
                  primary: true,
                  onPressed: () => calls++,
                ),
              ],
            ),
          ],
        ),
      ),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(_action('computer', 'View')),
    );
    await gesture.moveTo(const Offset(5, 5));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(calls, 0);
    await tester.tap(_action('computer', 'View'));
    await tester.pump();
    expect(calls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('rich body and count overrides remain caller controlled', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const RaftNotificationCenter(
          countLabel: '1 announcement',
          entries: [
            RaftNotificationEntry(
              id: 'plan',
              kind: RaftNotificationKind.info,
              title: 'Plan changed',
              bodyContent: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: 'The '),
                    TextSpan(
                      text: 'Pro plan',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    TextSpan(text: ' has changed.'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
    expect(find.text('1 announcement'), findsOneWidget);
    expect(
      find.text('The Pro plan has changed.', findRichText: true),
      findsOneWidget,
    );
    expect(find.byType(RaftControl), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'attention mark is count controlled and uses theme attention color',
    (tester) async {
      for (final (family, dark) in _themes) {
        await tester.pumpWidget(
          _host(
            const RaftNotificationAttention(count: 0),
            family: family,
            dark: dark,
          ),
        );
        expect(
          tester.getSize(find.byType(RaftNotificationAttention)),
          Size.zero,
        );
        await tester.pumpWidget(
          _host(
            const RaftNotificationAttention(count: 4),
            family: family,
            dark: dark,
          ),
        );
        // Complete AnimatedTheme transitions before comparing final roles.
        await tester.pumpAndSettle();
        final mark = find.byType(RaftNotificationAttention);
        final t = RaftTokens.of(tester.element(mark));
        expect(tester.getSize(mark), const Size(10, 10));
        final container = tester.widget<Container>(
          find.descendant(of: mark, matching: find.byType(Container)),
        );
        expect(
          (container.decoration! as BoxDecoration).color,
          t.colors[family == RaftFamily.brutal ? 'accent-400' : 'primary-400'],
        );
        expect(
          find.descendant(of: mark, matching: find.byType(GestureDetector)),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      }
    },
  );
}
