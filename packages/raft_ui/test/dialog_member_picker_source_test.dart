import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

Widget host(
  Widget child, {
  bool dark = false,
  String? legacy,
  double scale = 1,
}) => MaterialApp(
  theme: raftTheme(
    dark: dark,
    pack: legacy == null ? null : packForThemeId(legacy),
  ),
  home: MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(scale)),
    child: Scaffold(
      body: Align(alignment: Alignment.topLeft, child: child),
    ),
  ),
);

const items = [
  RaftPickerItem(
    key: 'agent-a',
    label: 'Agent A',
    avatar: SizedBox.square(dimension: 20),
  ),
  RaftPickerItem(
    key: 'agent-b',
    label: 'Agent B',
    avatar: SizedBox.square(dimension: 20),
  ),
  RaftPickerItem(
    key: 'human-a',
    label: 'Human A',
    avatar: SizedBox.square(dimension: 20),
  ),
];

RaftMemberPickerContent picker(
  TextEditingController search, {
  ValueChanged<String>? toggle,
}) => RaftMemberPickerContent(
  search: search,
  agents: items.take(2).toList(),
  humans: items.skip(2).toList(),
  hasCandidates: true,
  isSelected: (key) => key != 'agent-b',
  onToggle: toggle ?? (_) {},
);

void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    testWidgets('source recipe segment track is 3 + 32 + 3 ($dark)', (t) async {
      await t.pumpWidget(
        host(
          RaftRecipeSegmentedControl<String>(
            value: 'public',
            items: const [
              ('public', RaftGlyph.hash, 'Public'),
              ('private', RaftGlyph.lock, 'Private'),
            ],
            onChanged: (_) {},
          ),
          dark: dark,
        ),
      );
      // Actual raft-ui0.7 source h-8, root p-[3px], saved Web computed DOM38px.
      expect(
        t.getSize(find.byType(RaftRecipeSegmentedControl<String>)).height,
        38,
      );
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox.shrink());
    });

    testWidgets(
      'member picker follows upstream card, row and group geometry ($dark)',
      (t) async {
        final search = TextEditingController();
        addTearDown(search.dispose);
        await t.pumpWidget(
          host(SizedBox(width: 408, child: picker(search)), dark: dark),
        );
        // Actual Web: card p1.5+border, two30px headers, three36px rows =182px.
        expect(t.getSize(find.byType(RaftCard)).height, 182);
        final agents = t.widget<Text>(find.text('Agents'));
        expect(agents.style!.fontSize, 13);
        expect(agents.style!.height, 18 / 13);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox.shrink());
      },
    );

    testWidgets(
      'member selection is a leading shared checkbox and retains toggle ($dark)',
      (t) async {
        final search = TextEditingController();
        addTearDown(search.dispose);
        final toggled = <String>[];
        await t.pumpWidget(
          host(
            SizedBox(width: 408, child: picker(search, toggle: toggled.add)),
            dark: dark,
          ),
        );
        final indicators = find.byType(RaftCheckboxIndicator);
        expect(indicators, findsNWidgets(3));
        expect(
          t.widgetList<RaftCheckboxIndicator>(indicators).map((w) => w.checked),
          [true, false, true],
        );
        expect(
          t.getRect(indicators.first).left,
          lessThan(t.getRect(find.text('Agent A')).left),
        );
        await t.tap(indicators.first);
        expect(toggled, ['agent-a']);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('source segment height remains a minimum under large text', (
    t,
  ) async {
    await t.pumpWidget(
      host(
        RaftRecipeSegmentedControl<String>(
          value: 'public',
          items: const [('public', null, 'Public')],
          onChanged: (_) {},
        ),
        scale: 3.1,
      ),
    );
    expect(
      t.getSize(find.byType(RaftRecipeSegmentedControl<String>)).height,
      greaterThan(38),
    );
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('member list stays scrollable inside the source card maximum', (
    t,
  ) async {
    final search = TextEditingController();
    addTearDown(search.dispose);
    String? selected;
    await t.pumpWidget(
      host(
        SizedBox(
          width: 408,
          child: RaftMemberPickerContent(
            search: search,
            agents: List.generate(
              20,
              (i) => RaftPickerItem(
                key: 'agent-$i',
                label: 'Agent $i',
                avatar: const SizedBox.square(dimension: 20),
              ),
            ),
            humans: const [],
            hasCandidates: true,
            isSelected: (_) => false,
            onToggle: (key) => selected = key,
          ),
        ),
      ),
    );
    expect(t.getSize(find.byType(RaftCard)).height, 192);
    await t.ensureVisible(find.text('Agent 19'));
    await t.pumpAndSettle();
    await t.tap(find.text('Agent 19'));
    expect(selected, 'agent-19');
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('an empty filtered picker uses the source hint typography', (
    t,
  ) async {
    final search = TextEditingController(text: 'missing');
    addTearDown(search.dispose);
    await t.pumpWidget(
      host(
        SizedBox(
          width: 408,
          child: RaftMemberPickerContent(
            search: search,
            agents: const [],
            humans: const [],
            hasCandidates: true,
            isSelected: (_) => false,
            onToggle: (_) {},
          ),
        ),
      ),
    );
    final text = t.widget<Text>(find.text('No matches for "missing"'));
    expect(text.style!.fontSize, 14);
    expect(text.style!.height, 20 / 14);
    expect(find.byType(RaftCheckboxIndicator), findsNothing);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox.shrink());
  });

  for (final (id, look) in [
    (elegantThemePackId, raftLookElegant),
    (brutalThemePackId, raftLookBrutal),
  ]) {
    testWidgets(
      'frozen $look picker keeps its legacy selection implementation',
      (t) async {
        final search = TextEditingController();
        addTearDown(search.dispose);
        await t.pumpWidget(
          host(SizedBox(width: 408, child: picker(search)), legacy: id),
        );
        expect(find.byType(RaftCheckboxIndicator), findsNothing);
        expect(find.text('Agent A'), findsOneWidget);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox.shrink());
      },
      skip: raftLookSkip(look),
    );
  }
}
