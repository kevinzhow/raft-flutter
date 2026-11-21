import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/src/raft/fit_toolbar_plan.dart';

/// raft-ui 0.95.3 FitToolbar: the pure fit (order, batching, backtrack) and
/// the widget parts the Computers rack toolbar needs.

// The Web rack: display labels 10, filter labels 20, filters wrap 30, add plus
// 40, display More 60, search button 70.
List<RaftFitNodeSpec> _rack() => [
  const RaftFitSearchSpec(
    'search',
    minWidth: 120,
    buttonWidth: 34,
    collapseOrder: 70,
  ),
  const RaftFitGroupSpec(
    'filters',
    scroll: true,
    wrapOrder: 30,
    endWidth: 90,
    leaves: [
      RaftFitLeafSpec('status', full: 110, label: 50, labelOrder: 20),
      RaftFitLeafSpec('runtime', full: 120, label: 50, labelOrder: 20),
    ],
  ),
  const RaftFitGroupSpec(
    'display',
    firstLine: true,
    moreOrder: 60,
    leaves: [
      RaftFitLeafSpec('group', full: 90, label: 54, labelOrder: 10),
      RaftFitLeafSpec('sort', full: 90, label: 54, labelOrder: 10),
      RaftFitLeafSpec('view', full: 70),
    ],
  ),
  const RaftFitGroupSpec(
    'tail',
    firstLine: true,
    leaves: [
      RaftFitLeafSpec('more', full: 34, isMore: true),
      RaftFitLeafSpec('add', full: 130, plus: 34, plusOrder: 40),
    ],
  ),
];

RaftFitPlan _at(double w, {List<RaftFitNodeSpec>? nodes}) =>
    raftFit(nodes ?? _rack(), width: w, hasMore: true, allowWrap: true).plan;

String _steps(
  RaftFitPlan p,
) => (p.taken.entries.toList()..sort((a, b) => '${a.key}'.compareTo('${b.key}')))
    .map(
      (e) =>
          '${e.key}:${(e.value.map((s) => s.name).toList()..sort()).join('+')}',
    )
    .join(' ');

bool inField() =>
    FocusManager.instance.primaryFocus?.context
        ?.findAncestorWidgetOfExactType<EditableText>() !=
    null;

void main() {
  group('raftFitPlan', () {
    test('takes nothing while the toolbar fits', () {
      expect(_steps(_at(1400)), '');
    });

    test('the steps come in the Web rack order as the width falls', () {
      final firstSeen = <String>[];
      for (var w = 1400.0; w >= 60; w -= 2) {
        final p = _at(w);
        void seen(String name, bool taken) {
          if (taken && !firstSeen.contains(name)) firstSeen.add(name);
        }

        seen('labels10', p.has('group', RaftFitStep.label));
        seen('labels20', p.has('status', RaftFitStep.label));
        seen('wrap30', p.has('filters', RaftFitStep.wrap));
        seen('plus40', p.has('add', RaftFitStep.plus));
        seen('more60', p.has('display', RaftFitStep.more));
        seen('search70', p.has('search', RaftFitStep.collapse));
      }
      expect(firstSeen, [
        'labels10',
        'labels20',
        'wrap30',
        'plus40',
        'more60',
        'search70',
      ]);
    });

    test('a wrapped group gets back the labels its items gave before', () {
      // Labels 20 went first, then the filters wrapped; on line 2 they have
      // room again, so the backtrack returns them.
      RaftFitPlan? wrapped;
      for (var w = 700.0; w >= 300; w -= 2) {
        final p = _at(w);
        if (p.has('filters', RaftFitStep.wrap)) {
          wrapped = p;
          break;
        }
      }
      expect(wrapped, isNotNull);
      expect(wrapped!.has('status', RaftFitStep.label), isFalse);
      expect(wrapped.has('runtime', RaftFitStep.label), isFalse);
      expect(wrapped.has('group', RaftFitStep.label), isTrue);
    });

    test('the outcome depends on the width only, not on how it got there', () {
      final down = [for (var w = 900.0; w >= 300; w -= 25) _steps(_at(w))];
      final up = [for (var w = 300.0; w <= 900; w += 25) _steps(_at(w))];
      expect(up.reversed.toList(), down);
    });

    test('a tie goes to the last item first', () {
      const nodes = [
        RaftFitGroupSpec(
          'a',
          firstLine: true,
          leaves: [
            RaftFitLeafSpec('one', full: 100, label: 40, labelOrder: 10),
          ],
        ),
        RaftFitGroupSpec(
          'b',
          firstLine: true,
          leaves: [
            RaftFitLeafSpec('two', full: 100, label: 40, labelOrder: 10),
          ],
        ),
      ];
      // 100 + 8 + 100 = 208 does not fit 170; one label (-60) does: the last.
      final p = raftFit(nodes, width: 170).plan;
      expect(p.has('two', RaftFitStep.label), isTrue);
      expect(p.has('one', RaftFitStep.label), isFalse);
    });

    test('labels of the same group at the same number go together', () {
      const nodes = [
        RaftFitGroupSpec(
          'g',
          firstLine: true,
          leaves: [
            RaftFitLeafSpec('x', full: 100, label: 40, labelOrder: 10),
            RaftFitLeafSpec('y', full: 100, label: 40, labelOrder: 10),
          ],
        ),
      ];
      // One label would be enough (148), but the group's batch takes both.
      final p = raftFit(nodes, width: 160).plan;
      expect(p.has('x', RaftFitStep.label), isTrue);
      expect(p.has('y', RaftFitStep.label), isTrue);
    });

    test('an item in More is not stepped again, and More shows only then', () {
      final wide = raftFit(
        _rack(),
        width: 1400,
        hasMore: true,
        allowWrap: true,
      );
      final tail = wide.layout.lines.first.last;
      expect(tail.width, 130 + 8 + 0 - 8); // More hidden: the Add alone
      final narrow = _at(200);
      expect(narrow.more, ['display']);
    });

    test('without a More button the more step is skipped', () {
      final p = raftFit(_rack(), width: 200, allowWrap: true).plan;
      expect(p.more, isEmpty);
    });
  });

  group('widgets', () {
    Future<void> mount(
      WidgetTester t,
      Widget child, {
      Size size = const Size(1600, 600),
      TargetPlatform platform = TargetPlatform.linux,
      Locale? locale,
    }) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme().copyWith(platform: platform),
          locale: locale,
          home: Scaffold(
            body: Align(alignment: Alignment.topLeft, child: child),
          ),
        ),
      );
      await t.pump(const Duration(milliseconds: 300));
    }

    testWidgets('search fits the placeholder before cutting a word', (
      tester,
    ) async {
      final width = ValueNotifier<double>(150);
      addTearDown(width.dispose);
      await mount(
        tester,
        ValueListenableBuilder(
          valueListenable: width,
          builder: (_, width, child) => SizedBox(width: width, child: child),
          child: const RaftFitToolbar(
            children: [
              RaftFitSearch(
                semanticLabel: 'Search connected apps',
                hintText: 'Search apps…',
              ),
            ],
          ),
        ),
      );
      String? placeholder() =>
          tester.widget<TextField>(find.byType(TextField)).decoration!.hintText;
      expect(placeholder(), 'Search…');
      width.value = 300;
      await tester.pumpAndSettle();
      expect(placeholder(), 'Search apps…');
    });

    RaftFitToolbar toolbar({
      String query = '',
      ValueChanged<String>? onQuery,
      TextEditingController? controller,
      List<String>? log,
    }) => RaftFitToolbar(
      wrap: true,
      semanticLabel: 'Computers',
      children: [
        RaftFitSearch(
          controller: controller,
          hintText: 'Search computers',
          semanticLabel: 'Search computers',
          clearLabel: 'Clear search',
          collapseOrder: 70,
          onChanged: onQuery,
        ),
        RaftFitGroup(
          scroll: true,
          wrapOrder: 30,
          end: const Text('Clear all'),
          items: [
            RaftFitPicker(
              key: const ValueKey('status'),
              label: 'Status',
              glyph: RaftGlyph.circle,
              labelOrder: 20,
              onPressed: () => log?.add('status'),
            ),
            RaftFitPicker(
              label: 'Runtime',
              glyph: RaftGlyph.server,
              value: '2',
              labelOrder: 20,
              onPressed: () {},
            ),
          ],
        ),
        RaftFitGroup(
          firstLine: true,
          moreOrder: 60,
          moreItem: const [
            RaftMenuEntry(label: 'Group by status'),
            RaftMenuEntry(label: 'Sort by name'),
          ],
          items: [
            RaftFitPicker(
              label: 'Group',
              glyph: RaftGlyph.listFilter,
              labelOrder: 10,
              onPressed: () {},
            ),
            RaftFitPicker(
              key: const ValueKey('sort'),
              label: 'Sort',
              glyph: RaftGlyph.arrowUpDown,
              labelOrder: 10,
              onPressed: () {},
            ),
          ],
        ),
        RaftFitGroup(
          firstLine: true,
          items: [
            const RaftFitMore(),
            RaftFitButton(
              key: const ValueKey('add'),
              label: 'Add computer',
              glyph: RaftGlyph.plus,
              plusOrder: 40,
              variant: RaftButtonVariant.primary,
              onPressed: () => log?.add('add'),
            ),
          ],
        ),
      ],
    );

    testWidgets('wide: every label is shown, More is absent', (t) async {
      await mount(t, SizedBox(width: 1500, child: toolbar()));
      expect(find.text('Status'), findsOneWidget);
      expect(find.text('Group'), findsOneWidget);
      expect(find.text('Add computer'), findsOneWidget);
      expect(find.bySemanticsLabel('More'), findsNothing);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });

    testWidgets('narrow: a button that lost its label keeps its name', (
      t,
    ) async {
      final handle = t.ensureSemantics();
      await mount(t, SizedBox(width: 520, child: toolbar()));
      expect(find.text('Group'), findsNothing);
      expect(find.bySemanticsLabel('Group'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('narrow: Add becomes a + square with its name and tooltip', (
      t,
    ) async {
      final handle = t.ensureSemantics();
      await mount(t, SizedBox(width: 300, child: toolbar()));
      expect(find.text('Add computer'), findsNothing);
      expect(find.bySemanticsLabel('Add computer'), findsOneWidget);
      final size = t.getSize(find.byKey(const ValueKey('add')));
      expect(size.width, size.height);
      final mouse = await t.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(t.getCenter(find.byKey(const ValueKey('add'))));
      await t.pump(const Duration(seconds: 1));
      expect(find.text('Add computer'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('More lists the items it took and only then shows', (t) async {
      await mount(t, SizedBox(width: 250, child: toolbar()));
      expect(find.text('Group by status'), findsNothing);
      final handle = t.ensureSemantics();
      await t.tap(find.bySemanticsLabel('More'));
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text('Group by status'), findsOneWidget);
      expect(find.text('Sort by name'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('search collapses to a button that opens the field in place; '
        'Esc closes it', (t) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await mount(
        t,
        SizedBox(width: 200, child: toolbar(controller: controller)),
      );
      expect(find.byType(TextField), findsNothing);
      final handle = t.ensureSemantics();
      await t.tap(find.bySemanticsLabel('Search computers'));
      await t.pump(const Duration(milliseconds: 300));
      expect(find.byType(TextField), findsOneWidget);
      expect(inField(), isTrue, reason: 'opening the field focuses it');
      await t.enterText(find.byType(TextField), 'abc');
      await t.pump();
      // Esc with text clears it and keeps the field.
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pump();
      expect(controller.text, '');
      expect(find.byType(TextField), findsOneWidget);
      // Esc with an empty field closes it.
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pump(const Duration(milliseconds: 300));
      expect(find.byType(TextField), findsNothing);
      handle.dispose();
    });

    testWidgets('search with text never collapses', (t) async {
      final controller = TextEditingController(text: 'abc');
      addTearDown(controller.dispose);
      await mount(
        t,
        SizedBox(width: 200, child: toolbar(controller: controller)),
      );
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('the clear button shows only while there is text', (t) async {
      final handle = t.ensureSemantics();
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await mount(
        t,
        SizedBox(width: 1500, child: toolbar(controller: controller)),
      );
      expect(find.bySemanticsLabel('Clear search'), findsNothing);
      await t.enterText(find.byType(TextField), 'x');
      await t.pump();
      expect(find.bySemanticsLabel('Clear search'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('arrow keys walk the controls in reading order and loop', (
      t,
    ) async {
      final log = <String>[];
      await mount(
        t,
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 1500, child: toolbar(log: log)),
            TextButton(
              key: const ValueKey('after'),
              onPressed: () {},
              child: const Text('after'),
            ),
          ],
        ),
      );
      // Tab enters at the first control (the search field), Tab again leaves.
      await t.sendKeyEvent(LogicalKeyboardKey.tab);
      await t.pump();
      expect(inField(), isTrue);
      await t.sendKeyEvent(LogicalKeyboardKey.tab);
      await t.pump();
      expect(inField(), isFalse);
      expect(
        FocusManager.instance.primaryFocus?.context
            ?.findAncestorWidgetOfExactType<TextButton>()
            ?.key,
        const ValueKey('after'),
        reason: 'one Tab stop: the second Tab left the toolbar',
      );
    });

    testWidgets('Right and Left move over the controls and loop', (t) async {
      final log = <String>[];
      await mount(t, SizedBox(width: 1500, child: toolbar(log: log)));
      final status = find.byKey(const ValueKey('status'));
      final add = find.byKey(const ValueKey('add'));
      // Focus the Status picker, walk Right until Add, then once more: loops.
      await t.tap(status);
      await t.pump();
      for (var i = 0; i < 4; i++) {
        await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await t.pump();
      }
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.pump();
      expect(log.contains('add'), isTrue);
      await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await t.pump();
      // Looped to the first control: the search field.
      expect(inField(), isTrue);
      await t.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await t.pump();
      // Inside the (empty) field the arrow leaves at the caret edge: it went
      // back to the last control.
      expect(inField(), isFalse);
      expect(add, findsOneWidget);
    });

    testWidgets('a caret with room keeps the arrow key', (t) async {
      final controller = TextEditingController(text: 'abc');
      addTearDown(controller.dispose);
      await mount(
        t,
        SizedBox(width: 1500, child: toolbar(controller: controller)),
      );
      await t.tap(find.byType(TextField));
      await t.pump();
      controller.selection = const TextSelection.collapsed(offset: 1);
      await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await t.pump();
      expect(inField(), isTrue);
    });

    testWidgets('focus on an item that moves into More lands on More', (
      t,
    ) async {
      await mount(t, SizedBox(width: 1500, child: toolbar()));
      await t.tap(find.byKey(const ValueKey('sort')));
      await t.pump();
      await mount(t, SizedBox(width: 250, child: toolbar()));
      await t.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const ValueKey('sort')), findsNothing);
      final focused = FocusManager.instance.primaryFocus?.context;
      expect(
        focused?.findAncestorWidgetOfExactType<RaftDropdownMenu>()?.label,
        'More',
      );
    });

    group('control size by input, not by width', () {
      // Status (a filter, line 2) and Add as a + square, in a 300px toolbar.
      Future<(double, Size)> sizes(
        WidgetTester t,
        Size size,
        TargetPlatform platform,
      ) async {
        await mount(
          t,
          SizedBox(width: 300, child: toolbar()),
          size: size,
          platform: platform,
        );
        return (
          t.getSize(find.byKey(const ValueKey('status'))).height,
          t.getSize(find.byKey(const ValueKey('add'))),
        );
      }

      Future<void> expectControl(
        WidgetTester t,
        Size size,
        TargetPlatform platform,
        double control,
      ) async {
        final (status, add) = await sizes(t, size, platform);
        expect(status, control);
        expect(add, Size(control, control));
      }

      testWidgets('Linux mouse, 390x844 window: 32 (below 768)', (t) async {
        await expectControl(t, const Size(390, 844), TargetPlatform.linux, 32);
      });
      testWidgets('Linux mouse, wide window: 34', (t) async {
        await expectControl(t, const Size(1000, 800), TargetPlatform.linux, 34);
      });
      testWidgets('Android 856x944 (unfolded): 32 by touch', (t) async {
        await expectControl(
          t,
          const Size(856, 944),
          TargetPlatform.android,
          32,
        );
      });
      testWidgets('Android 944x856: 32 by touch', (t) async {
        await expectControl(
          t,
          const Size(944, 856),
          TargetPlatform.android,
          32,
        );
      });
    });
    testWidgets('an item that grows with no rebuild of the toolbar is fitted '
        'again (the fit follows the measured width, not the first one)', (
      t,
    ) async {
      final room = ValueNotifier<double>(10);
      addTearDown(room.dispose);
      await mount(
        t,
        SizedBox(
          width: 400,
          child: RaftFitToolbar(
            semanticLabel: 'x',
            children: [
              RaftFitGroup(
                firstLine: true,
                items: [
                  RaftFitChild(
                    child: ValueListenableBuilder<double>(
                      valueListenable: room,
                      builder: (_, w, _) => SizedBox(width: w, height: 20),
                    ),
                  ),
                  const RaftFitButton(
                    key: ValueKey('add'),
                    label: 'New task',
                    glyph: RaftGlyph.plus,
                    plusOrder: 40,
                  ),
                ],
              ),
            ],
          ),
        ),
      );
      final full = t.getSize(find.byKey(const ValueKey('add'))).width;
      room.value = 300;
      await t.pump();
      await t.pump();
      expect(find.byKey(const ValueKey('add')), findsOneWidget);
      expect(
        t.getSize(find.byKey(const ValueKey('add'))).width,
        lessThan(full),
      );
    });
  });
}
