import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

Widget _app(Widget child) => MaterialApp(
  theme: raftTheme(),
  home: Scaffold(
    body: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(width: 300, child: child),
    ),
  ),
);

void main() {
  testWidgets('without hintBuilder the hint is the plain text it was', (
    t,
  ) async {
    await t.pumpWidget(
      _app(
        const RaftStableField(
          label: 'Model',
          hint: 'Plain hint',
          child: SizedBox(height: 20),
        ),
      ),
    );
    expect(find.text('Plain hint'), findsOneWidget);
    expect(find.byKey(const ValueKey('custom-hint')), findsNothing);
  });

  testWidgets('hintBuilder draws the hint in the description style', (t) async {
    TextStyle? seen;
    await t.pumpWidget(
      _app(
        RaftStableField(
          label: 'Model',
          hint: 'Plain hint',
          hintBuilder: (context, style) {
            seen = style;
            return Text(
              'Linked hint',
              key: const ValueKey('custom-hint'),
              style: style,
            );
          },
          child: const SizedBox(height: 20),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('custom-hint')), findsOneWidget);
    expect(find.text('Plain hint'), findsNothing);
    expect(seen, isNotNull);
    // Same style the plain hint used.
    await t.pumpWidget(
      _app(
        const RaftStableField(
          label: 'Model',
          hint: 'Plain hint',
          child: SizedBox(height: 20),
        ),
      ),
    );
    expect(
      t.widget<Text>(find.text('Plain hint')).style!.fontSize,
      seen!.fontSize,
    );
  });

  testWidgets('an error replaces the built hint', (t) async {
    await t.pumpWidget(
      _app(
        RaftStableField(
          label: 'Model',
          hint: 'Plain hint',
          error: 'Broken',
          hintBuilder: (context, style) => Text('Linked hint', style: style),
          child: const SizedBox(height: 20),
        ),
      ),
    );
    expect(find.text('Broken'), findsOneWidget);
    expect(find.text('Linked hint'), findsNothing);
  });

  testWidgets('RaftField takes the same option', (t) async {
    await t.pumpWidget(
      _app(
        RaftField(
          label: 'Model',
          hint: 'Plain hint',
          hintBuilder: (context, style) => Text('Linked hint', style: style),
          child: const SizedBox(height: 20),
        ),
      ),
    );
    expect(find.text('Linked hint'), findsOneWidget);
  });
}
