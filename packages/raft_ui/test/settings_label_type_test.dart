import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

/// Settings section eyebrow and field label.
///
/// Web v1.21.23: SectionHeader composes SectionEyebrow (`text-footnote
/// font-bold`, 13/18); the settings FormField is `size="compact"`: raft-ui label
/// step `sm`, 12/16 600 (`foreground-field-label`). The a57b9dab looks keep the
/// callsite 12/16 for both, with the recipe's weight and colour on the label.
Widget _host(RaftThemePack pack) => MaterialApp(
  theme: raftTheme(pack: pack),
  home: const Scaffold(
    body: Column(
      children: [
        RaftSettingsSectionHeader(label: 'Account'),
        RaftSettingsField(label: 'Display Name', child: SizedBox(height: 10)),
      ],
    ),
  ),
);

/// The style a text paints with (a field label is a rich text: its span carries the style).
TextStyle _style(WidgetTester t, String text) {
  final finder = find.text(text, findRichText: true);
  final rich = t.widgetList(finder).first;
  if (rich is Text) return rich.style ?? rich.textSpan!.style!;
  return (rich as RichText).text.style!;
}

void main() {
  for (final (id, size, line, weight) in [
    (raftThemePackId, 13.0, 18.0, FontWeight.w600),
    (elegantThemePackId, 12.0, 16.0, null),
    (brutalThemePackId, 12.0, 16.0, null),
  ]) {
    testWidgets('$id eyebrow $size/$line and field label', (t) async {
      addTearDown(() => t.pumpWidget(const SizedBox()));
      await t.pumpWidget(_host(packForThemeId(id)));
      await t.pump(const Duration(seconds: 1));
      final eyebrow = _style(t, 'Account');
      expect(eyebrow.fontSize, size);
      expect(eyebrow.height! * eyebrow.fontSize!, closeTo(line, .001));
      final label = _style(t, 'Display Name');
      expect(label.fontSize, 12);
      expect(label.height! * label.fontSize!, closeTo(16, .001));
      if (weight != null) expect(label.fontWeight, weight);
    });
  }
}
