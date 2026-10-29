import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

void main() {
  for (final (id, height, size, weight) in raftThemeMatrix([
    (raftThemePackId, 44.0, 15.0, FontWeight.w600),
    (elegantThemePackId, 32.0, 14.0, FontWeight.w500),
    (brutalThemePackId, 32.0, 14.0, FontWeight.w700),
  ], look: (v) => raftLookOf(v.$1))) {
    testWidgets(
      '$id select uses its source trigger metrics and honors caller height',
      (t) async {
        Future<void> mount([double? override]) => t.pumpWidget(
          MaterialApp(
            theme: raftTheme(pack: packForThemeId(id)),
            home: Scaffold(
              body: Column(
                children: [
                  RaftSelectField<String>(
                    height: override,
                    value: 'codex',
                    items: const [
                      RaftSelectItem(value: 'codex', label: 'Codex'),
                    ],
                    onChanged: (_) {},
                  ),
                ],
              ),
            ),
          ),
        );
        await mount();
        expect(t.getSize(find.byType(RaftSelectField<String>)).height, height);
        final style = DefaultTextStyle.of(t.element(find.text('Codex'))).style;
        expect(style.fontSize, size);
        expect(style.height! * size, 20);
        expect(style.fontWeight, weight);
        await mount(40);
        expect(t.getSize(find.byType(RaftSelectField<String>)).height, 40);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
      },
    );
  }
}
