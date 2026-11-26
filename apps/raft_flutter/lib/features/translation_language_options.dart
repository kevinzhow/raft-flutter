import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/display_translation_names.g.dart';
import '../data/message_translation_store.dart';

/// Web translationStore `getTranslationLanguageOptions`: "Same as display
/// language" first, then every translation language named in the UI language
/// (CLDR names, as `Intl.DisplayNames` gives them) in that language's order.
const _namesEn = <String, String>{
  'en': 'English',
  'fr': 'French',
  'de': 'German',
  'it': 'Italian',
  'ja': 'Japanese',
  'ko': 'Korean',
  'pt-br': 'Brazilian Portuguese',
  'ru': 'Russian',
  'zh-cn': 'Simplified Chinese',
  'es': 'Spanish',
  'zh-tw': 'Traditional Chinese',
};

const _namesZh = <String, String>{
  'pt-br': '巴西葡萄牙语',
  'de': '德语',
  'ru': '俄语',
  'fr': '法语',
  'zh-tw': '繁体中文',
  'ko': '韩语',
  'zh-cn': '简体中文',
  'ja': '日语',
  'es': '西班牙语',
  'it': '意大利语',
  'en': '英语',
};

/// The translation-target choices for the UI language of [context].
List<RaftLanguageOption> translationTargetOptions(BuildContext context) {
  final language = raftDisplayLanguageId(Localizations.maybeLocaleOf(context));
  final names = switch (language) {
    'en' => _namesEn,
    'zh-cn' => _namesZh,
    _ => null,
  };
  final choices = [
    if (names != null)
      for (final entry in names.entries) (entry.key, entry.value)
    else
      ...displayTranslationNames[language]!,
  ];
  assert(
    choices
            .map((option) => option.$1)
            .toSet()
            .containsAll(messageTranslationLanguages.keys) &&
        choices.length == messageTranslationLanguages.length,
    'a translation language has no name',
  );
  return [
    (
      followDisplayLanguageTarget,
      raftText(context, 'Same as display language'),
    ),
    ...choices,
  ];
}
