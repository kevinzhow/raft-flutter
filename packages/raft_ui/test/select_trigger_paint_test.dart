import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

void main() {
  for (final id in raftThemeMatrix([
    raftThemePackId,
    elegantThemePackId,
    brutalThemePackId,
  ], look: raftLookOf)) {
    for (final dark in [false, true]) {
      testWidgets('$id/$dark Select preserves its source state colors', (
        t,
      ) async {
        var selections = 0;
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(pack: packForThemeId(id), dark: dark),
            home: Scaffold(
              body: Column(
                children: [
                  RaftSelectField<String>(
                    value: 'codex',
                    items: const [
                      RaftSelectItem(value: 'codex', label: 'Codex'),
                    ],
                    onChanged: (_) => selections++,
                  ),
                  const RaftSelectField<String>(
                    value: null,
                    items: [],
                    onChanged: null,
                  ),
                ],
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        final tokens = RaftTokens.of(t.element(find.text('Codex')));
        final native = id == raftThemePackId;
        final raised = id == brutalThemePackId && !dark;
        final foreground =
            tokens.colors[native
                ? 'foreground'
                : raised
                ? 'foreground-strong'
                : 'foreground-muted'];
        final background =
            tokens.colors[native
                ? 'layer-card'
                : dark
                ? 'fill-muted'
                : 'layer-panel'];
        expect(
          DefaultTextStyle.of(t.element(find.text('Codex'))).style.fontWeight,
          native
              ? FontWeight.w600
              : raised
              ? FontWeight.w700
              : FontWeight.w500,
        );
        expect(
          DefaultTextStyle.of(t.element(find.text('Select...')))
              .style
              .fontWeight,
          raised ? FontWeight.w700 : FontWeight.w500,
        );
        final fields = find.byType(RaftSelectField<String>);
        final enabled = t.widget<RaftRecipeBox>(
          find
              .descendant(
                of: fields.first,
                matching: find.byType(RaftRecipeBox),
              )
              .first,
        );
        final disabled = t.widget<RaftRecipeBox>(
          find
              .descendant(of: fields.last, matching: find.byType(RaftRecipeBox))
              .first,
        );
        expect(enabled.style.foreground(enabled.tokens), foreground);
        expect(
          enabled.style.backgroundColor?.resolve(enabled.tokens),
          background,
        );
        expect(disabled.style.opacity, native ? 1 : .4);
        expect(
          disabled.style.foreground(disabled.tokens),
          native ? tokens.colors['foreground-hint'] : foreground,
        );
        expect(
          disabled.style.backgroundColor?.resolve(disabled.tokens),
          native ? tokens.colors['fill-muted'] : background,
        );
        await t.tap(fields.last);
        await t.pump();
        expect(selections, 0);
        expect(find.text('Codex'), findsOneWidget);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
      });
    }
  }
}
