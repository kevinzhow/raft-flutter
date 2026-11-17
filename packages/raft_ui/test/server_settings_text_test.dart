import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

Widget _host(Widget child) => MaterialApp(
  theme: raftTheme(),
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

TextStyle? _style(WidgetTester t, String text) {
  final rich = find.byWidgetPredicate(
    (w) => w is RichText && w.text.toPlainText() == text,
  );
  expect(rich, findsOneWidget, reason: text);
  return t.widget<RichText>(rich).text.style;
}

void main() {
  // PublicVisibilitySection.tsx:218 `mb-2 text-subhead font-semibold
  // text-foreground`: a heading, not the muted field eyebrow.
  testWidgets('"Channels visible to anyone" is a foreground subhead heading', (
    t,
  ) async {
    await t.pumpWidget(
      _host(
        RaftPublicVisibilityCard(
          publiclyVisible: false,
          onPublic: (_) {},
          channels: const [],
        ),
      ),
    );
    final s = _style(t, 'Channels visible to anyone');
    final tokens = RaftTokens.of(
      t.element(find.byType(RaftPublicVisibilityCard)),
    );
    expect(s?.fontWeight, FontWeight.w600);
    expect(s?.color, tokens.strong);
    expect(s?.fontSize, greaterThan(12));
    final title = _style(t, 'Make this server public');
    expect(title?.fontWeight, FontWeight.w600);
    expect(title?.fontSize, s?.fontSize);
  });

  // LabsSection.tsx:175 `text-footnote text-foreground-hint`: upright.
  testWidgets('the Labs empty line is upright hint text', (t) async {
    await t.pumpWidget(
      _host(
        const RaftServerLabsSection(
          status: RaftServerLabsStatus.ready,
          masterEnabled: true,
          canSetMaster: true,
        ),
      ),
    );
    final s = _style(t, 'No Labs available for this server');
    final tokens = RaftTokens.of(t.element(find.byType(RaftServerLabsSection)));
    expect(s?.fontStyle, isNot(FontStyle.italic));
    expect(s?.color, tokens.colors['foreground-hint']);
  });
}
