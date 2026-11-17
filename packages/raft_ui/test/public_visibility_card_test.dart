import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

Widget _host(Widget child) => MaterialApp(
  theme: raftTheme(),
  home: Scaffold(
    body: SingleChildScrollView(
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    ),
  ),
);

void main() {
  testWidgets(
    'switch rows centre the switch against their text (v1.24 items-center)',
    (t) async {
      await t.pumpWidget(
        _host(
          RaftPublicVisibilityCard(
            publiclyVisible: true,
            onPublic: (_) {},
            searchEngines: true,
            onSearchEngines: (_) {},
            channels: const [],
          ),
        ),
      );
      for (final key in const [
        'public-visibility-switch',
        'public-search-switch',
      ]) {
        final s = find.byKey(ValueKey(key));
        if (s.evaluate().isEmpty) continue;
        final row = t.widget<Row>(
          find.ancestor(of: s, matching: find.byType(Row)).first,
        );
        expect(row.crossAxisAlignment, CrossAxisAlignment.center, reason: key);
      }
    },
  );

  testWidgets('an empty channel list is a dashed hairline box with no fill', (
    t,
  ) async {
    await t.pumpWidget(_host(const RaftPublicChannelList(channels: [])));
    final text = find.text('No channels visible to visitors yet');
    expect(text, findsOneWidget);
    final paint = t.widget<CustomPaint>(
      find.ancestor(of: text, matching: find.byType(CustomPaint)).first,
    );
    final painter = paint.foregroundPainter;
    expect(painter, isA<RaftDashedBorderPainter>());
    final t0 = RaftTokens.of(t.element(text));
    expect(
      (painter! as RaftDashedBorderPainter).color,
      t0.colors['line-hairline'] ?? t0.colors['line-muted'],
    );
    final boxes = find.ancestor(of: text, matching: find.byType(Container));
    for (final e in boxes.evaluate()) {
      final d = (e.widget as Container).decoration;
      if (d is BoxDecoration) expect(d.color, isNull);
    }
  });

  testWidgets('the empty channel line is centred in the full-width box', (
    t,
  ) async {
    await t.pumpWidget(
      _host(
        const SizedBox(width: 600, child: RaftPublicChannelList(channels: [])),
      ),
    );
    final text = find.text('No channels visible to visitors yet');
    final box = find
        .ancestor(of: text, matching: find.byType(CustomPaint))
        .first;
    expect(t.getSize(box).width, 600);
    expect(t.getCenter(text).dx, closeTo(t.getCenter(box).dx, 1));
  });
}
