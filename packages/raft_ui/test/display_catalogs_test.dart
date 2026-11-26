import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart' show raftChinese, raftDisplayLanguages;
import 'package:raft_ui/src/l10n/display_catalogs.g.dart'
    show displayCatalogs, displayEnglishFallbacks;

void main() {
  test('each display catalog translates or lists every English source key', () {
    final catalogKeys = raftChinese.keys.toSet();
    expect(
      displayCatalogs.keys,
      raftDisplayLanguages.keys.where(
        (language) => language != 'en' && language != 'zh-cn',
      ),
    );
    for (final language in displayCatalogs.keys) {
      final translated = displayCatalogs[language]!.keys.toSet();
      final fallbacks = displayEnglishFallbacks[language]!;
      expect(translated.intersection(fallbacks), isEmpty, reason: language);
      expect({...translated, ...fallbacks}, catalogKeys, reason: language);
    }
  });
}
