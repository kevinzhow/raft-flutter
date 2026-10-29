import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_theme/raft_theme.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

BoxDecoration face(WidgetTester tester, Finder item) =>
    tester
            .widget<DecoratedBox>(
              find
                  .descendant(of: item, matching: find.byType(DecoratedBox))
                  .first,
            )
            .decoration
        as BoxDecoration;

Widget host(
  Widget child, {
  RaftThemePack? pack,
  bool dark = false,
  double scale = 1,
}) => MaterialApp(
  theme: raftTheme(pack: pack, dark: dark),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: RaftTextScaling(child: child!),
  ),
  home: Scaffold(
    body: Align(alignment: Alignment.topLeft, child: child),
  ),
);

RaftThemePack separatePack() => RaftThemePack(
  id: 'custom-separate-segment',
  name: {'en': 'Custom separate segment'},
  version: '1.0.0',
  extendsId: 'raft',
  light: const RaftModeValues(
    options: {'segmented.frame': 'separate'},
    geometry: {'radius.control': 13, 'radius.chip': 5, 'space.segmentGap': 7},
  ).mergedWith(builtInRaftTheme.light),
  dark: const RaftModeValues(
    options: {'segmented.frame': 'separate'},
    geometry: {'radius.control': 13, 'radius.chip': 5, 'space.segmentGap': 7},
  ).mergedWith(builtInRaftTheme.dark),
);

RaftSegmentedControl<String> separateSegment({
  required ValueChanged<String> onChanged,
  bool disabled = false,
}) => RaftSegmentedControl<String>(
  value: 'a',
  disabled: disabled,
  items: const [
    RaftSegmentedOption(
      value: 'a',
      label: 'Alpha',
      count: '3',
      itemKey: ValueKey('a'),
    ),
    RaftSegmentedOption(
      value: 'b',
      label: 'Beta',
      count: '5',
      itemKey: ValueKey('b'),
    ),
  ],
  onChanged: onChanged,
);

void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    testWidgets(
      'custom separate segments omit the track and keep their gap dark=$dark',
      (t) async {
        addTearDown(() => t.pumpWidget(const SizedBox.shrink()));
        final selected = <String>[];
        final pack = separatePack();
        final tokens = RaftTokens.theme(pack: pack, dark: dark);
        expect(tokens.isRaftLook, isTrue);
        expect(tokens.option('segmented.frame', or: 'framed'), 'separate');
        await t.pumpWidget(
          host(
            separateSegment(onChanged: selected.add),
            pack: pack,
            dark: dark,
          ),
        );
        final boxes = t
            .widgetList<DecoratedBox>(
              find.descendant(
                of: find.byType(RaftSegmentedControl<String>),
                matching: find.byType(DecoratedBox),
              ),
            )
            .map((box) => box.decoration)
            .whereType<BoxDecoration>()
            .where((decoration) => decoration.borderRadius != null);
        expect(
          boxes,
          hasLength(2),
          reason: 'A separate custom pack paints only the two items.',
        );
        expect(
          t.getRect(find.byKey(const ValueKey('b'))).left -
              t.getRect(find.byKey(const ValueKey('a'))).right,
          7,
        );
        expect(t.getSize(find.byType(RaftSegmentedTrack)).height, 32);
        await t.tap(find.text('Beta'));
        expect(selected, ['b']);
        expect(t.takeException(), isNull);
      },
    );

    testWidgets(
      'custom separate chip radius survives disabled and large text dark=$dark',
      (t) async {
        addTearDown(() => t.pumpWidget(const SizedBox.shrink()));
        final selected = <String>[];
        final pack = separatePack();
        for (final scale in [1.0, 3.1]) {
          await t.pumpWidget(
            host(
              separateSegment(onChanged: selected.add, disabled: true),
              pack: pack,
              dark: dark,
              scale: scale,
            ),
          );
          expect(
            face(t, find.byKey(const ValueKey('a'))).borderRadius,
            BorderRadius.circular(5),
            reason: 'Separate items bind radius.chip, not radius.control.',
          );
          expect(
            face(t, find.byKey(const ValueKey('b'))).borderRadius,
            BorderRadius.circular(5),
          );
          if (scale > 1) {
            expect(
              t.getSize(find.byType(RaftSegmentedTrack)).height,
              greaterThan(32),
            );
          }
          await t.tap(find.text('Beta'));
          expect(selected, isEmpty);
          expect(t.takeException(), isNull);
        }
      },
    );

    testWidgets('custom segment radius survives recipe migration dark=$dark', (
      t,
    ) async {
      addTearDown(() => t.pumpWidget(const SizedBox.shrink()));
      final pack = RaftThemePack(
        id: 'custom-segment-geometry',
        name: {'en': 'Custom segment geometry'},
        version: '1.0.0',
        extendsId: 'raft',
        light: const RaftModeValues(geometry: {'radius.control': 13})
            .mergedWith(builtInRaftTheme.light),
        dark: const RaftModeValues(geometry: {'radius.control': 13})
            .mergedWith(builtInRaftTheme.dark),
      );
      await t.pumpWidget(
        host(
          RaftSegmentedControl<String>(
            value: 'a',
            items: const [
              RaftSegmentedOption(
                value: 'a',
                label: 'A',
                itemKey: ValueKey('a'),
              ),
              RaftSegmentedOption(value: 'b', label: 'B'),
            ],
            onChanged: (_) {},
          ),
          pack: pack,
          dark: dark,
        ),
      );
      expect(
        face(t, find.byKey(const ValueKey('a'))).borderRadius,
        BorderRadius.circular(13),
      );
      expect(
        face(t, find.byType(RaftSegmentedTrack)).borderRadius,
        BorderRadius.circular(16),
      );
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('segment arrow navigation skips a disabled option dark=$dark', (
      t,
    ) async {
      addTearDown(() => t.pumpWidget(const SizedBox.shrink()));
      final selected = <String>[];
      await t.pumpWidget(
        host(
          RaftSegmentedControl<String>(
            value: 'all',
            items: const [
              RaftSegmentedOption(value: 'all', label: 'All'),
              RaftSegmentedOption(
                value: 'disabled',
                label: 'Disabled',
                enabled: false,
              ),
              RaftSegmentedOption(value: 'unread', label: 'Unread'),
            ],
            onChanged: selected.add,
          ),
          dark: dark,
        ),
      );
      await t.sendKeyEvent(LogicalKeyboardKey.tab);
      await t.pump();
      await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      expect(selected, ['unread']);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox.shrink());
    });
  }
}
