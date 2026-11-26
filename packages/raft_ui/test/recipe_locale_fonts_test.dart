import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/language_settings_previews.dart';
import 'package:raft_ui/raft_ui.dart';

import '../../../tool/testing/text_scale_audit.dart';

/// The display-language picker lists every language in its own script,
/// whatever the UI language is, so each endonym has to reach a font that has
/// that script. Those labels come from the select recipe, and a declaration
/// only names the Latin families Web needs plus a generic; a browser resolves
/// the rest through fontconfig and Flutter has to name them. So the locale's
/// own coverage must survive into the label's chain.
void main() {
  testWidgets('every picker endonym reaches the locale script coverage', (
    tester,
  ) async {
    await loadAuditFonts(tester, AuditFonts.real);
    const endonyms = {'한국어', '日本語', '简体中文', '繁體中文', 'Русский'};
    for (final id in ['en', 'ru', 'ja', 'ko', 'zh-tw']) {
      final locale = raftDisplayLanguages[id]!.$1;
      final tokens = raftTheme(
        locale: locale,
        textLocale: locale,
      ).extension<RaftTokens>()!;
      final seen = <String>{};
      final report = await auditSurface(
        tester,
        surface: 'recipe-fonts',
        build: languageSettingsReferencePreview,
        theme: raftTheme(locale: locale, textLocale: locale),
        mode: AuditMode(id, locale: locale),
        truncationBaseline: {},
        after: (t) async {
          await t.tap(find.byKey(const ValueKey('display-language-select')));
          await t.pumpAndSettle();
          for (final paragraph
              in find
                  .byType(RichText)
                  .evaluate()
                  .map((e) => e.renderObject)
                  .whereType<RenderParagraph>()) {
            final text = paragraph.text.toPlainText();
            if (!endonyms.contains(text)) continue;
            seen.add(text);
            final style = paragraph.text.style;
            final chain = [
              if (style?.fontFamily != null) style!.fontFamily!,
              ...?style?.fontFamilyFallback,
            ];
            expect(
              chain,
              containsAll(tokens.fontFallback),
              reason:
                  '$id picker option "$text" lost the locale coverage: $chain',
            );
          }
        },
      );
      expect(seen, endonyms, reason: '$id picker did not list every endonym');
      expect(report.failures, isEmpty, reason: report.failures.join('\n'));
    }
  });
}
