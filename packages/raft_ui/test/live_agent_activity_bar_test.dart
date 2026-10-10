import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

Widget _host(
  RaftFamily family, {
  bool dark = false,
  double width = 240,
  String text = 'Tool finished',
  RaftActivityTone activity = RaftActivityTone.working,
}) => MaterialApp(
  theme: raftTheme(family, dark: dark),
  home: Scaffold(
    body: Align(
      alignment: Alignment.bottomLeft,
      child: SizedBox(
        width: width,
        child: RaftLiveAgentActivityBar(
          agentName: 'Cindy',
          text: text,
          activity: activity,
          avatarContent: const RaftAvatarContent(
            name: 'Cindy',
            kind: RaftAvatarContentKind.agent,
            pixelKey: 'robot',
          ),
        ),
      ),
    ),
  ),
);

BoxDecoration _decoration(WidgetTester t, Finder f) {
  final box = t.widget<Container>(
    find.descendant(of: f, matching: find.byType(Container)).first,
  );
  return box.decoration! as BoxDecoration;
}

void main() {
  testWidgets('elegant: rounded bordered card, 36px avatar, 10px dot', (
    t,
  ) async {
    await t.pumpWidget(_host(RaftFamily.elegant));
    final bar = find.byKey(RaftLiveAgentActivityBar.barKey);
    // 1 border + 8 padding + 36 avatar + 8 padding + 1 border.
    expect(t.getSize(bar), const Size(240, 54));
    final decoration = _decoration(t, bar);
    expect(decoration.borderRadius, BorderRadius.circular(8));
    expect(decoration.border!.top.width, 1);
    expect(decoration.boxShadow, isNull);
    expect(
      t.getSize(find.byKey(const Key('live-agent-activity-status'))),
      const Size(10, 10),
    );
    expect(t.getSize(find.byType(RaftMountedAvatarFrame)), const Size(36, 36));
    // avatar | 8 | dot | 8 | text, inside 1 + 12px inset.
    final left = t.getTopLeft(bar).dx;
    expect(t.getTopLeft(find.byType(RaftMountedAvatarFrame)).dx - left, 13);
    expect(
      t.getTopLeft(find.byKey(const Key('live-agent-activity-status'))).dx -
          left,
      13 + 36 + 8,
    );
    expect(
      t.getTopLeft(find.byKey(const Key('live-agent-activity-text'))).dx - left,
      13 + 36 + 8 + 10 + 8,
    );
  });

  testWidgets('brutal: flat top rule, px-3 inset, 6px dot to text gap', (
    t,
  ) async {
    await t.pumpWidget(_host(RaftFamily.brutal));
    final bar = find.byKey(RaftLiveAgentActivityBar.barKey);
    // 2 top rule + 8 + 36 + 8.
    expect(t.getSize(bar), const Size(240, 54));
    final decoration = _decoration(t, bar);
    expect(decoration.borderRadius, anyOf(isNull, BorderRadius.zero));
    expect(decoration.border!.top.width, 2);
    expect(decoration.border!.top.color, Colors.black);
    final left = t.getTopLeft(bar).dx;
    expect(t.getTopLeft(find.byType(RaftMountedAvatarFrame)).dx - left, 12);
    expect(
      t.getTopLeft(find.byKey(const Key('live-agent-activity-text'))).dx - left,
      12 + 36 + 8 + 10 + 6,
    );
  });

  for (final theme in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    testWidgets('busy dot colour follows the Web status variant $theme', (
      t,
    ) async {
      for (final tone in [
        RaftActivityTone.working,
        RaftActivityTone.thinking,
      ]) {
        await t.pumpWidget(_host(theme.$1, dark: theme.$2, activity: tone));
        final tokens = RaftTokens.theme(theme.$1, dark: theme.$2);
        final dot = _decoration(
          t,
          find.byKey(const Key('live-agent-activity-status')),
        );
        // Brutal keeps the fixed busy yellow; elegant takes the semantic
        // warning colour (orange), never the other way round.
        expect(
          dot.color,
          theme.$1 == RaftFamily.brutal
              ? tokens.product.statusBusy
              : tokens.semantic.warning,
        );
        expect(dot.border, theme.$1 == RaftFamily.brutal ? isNotNull : isNull);
      }
    });
  }

  testWidgets('text is one truncated line with the theme font', (t) async {
    await t.pumpWidget(
      _host(RaftFamily.elegant, text: 'Reading ${'very long path/' * 12}'),
    );
    final text = t.widget<Text>(
      find.byKey(const Key('live-agent-activity-text')),
    );
    expect(text.maxLines, 1);
    expect(text.overflow, TextOverflow.ellipsis);
    expect(text.style!.fontSize, 13);
    expect(t.getSize(find.byKey(RaftLiveAgentActivityBar.barKey)).height, 54);
    await t.pumpWidget(
      _host(RaftFamily.brutal, text: 'Reading ${'very long path/' * 12}'),
    );
    await t.pumpAndSettle();
    expect(
      t
          .widget<Text>(find.byKey(const Key('live-agent-activity-text')))
          .style!
          .fontSize,
      14,
    );
    expect(t.takeException(), isNull);
  });

  testWidgets('announces "<agent>: <text>" as a polite live region', (t) async {
    final handle = t.ensureSemantics();
    await t.pumpWidget(_host(RaftFamily.elegant));
    final node = t.getSemantics(find.byKey(RaftLiveAgentActivityBar.barKey));
    expect(node.label, contains('Cindy: Tool finished'));
    expect(node.flagsCollection.isLiveRegion, isTrue);
    handle.dispose();
  });
}
