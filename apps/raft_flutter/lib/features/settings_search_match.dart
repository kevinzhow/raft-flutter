import 'package:unorm_dart/unorm_dart.dart' as unorm;

/// Settings search's matching and order (Web
/// features/settings/search/settingsSearchMatch.ts; raft-design
/// settings.md#searching-settings), pure: the settings come in already in the
/// words of the display language, in the list's order, and only those the
/// person can see.

/// One row of the shared index (settingsSearch.v1.json) with the Web's words
/// for it. Names, descriptions and sections are English source text (the zh
/// catalog is keyed by it); the other words are per display language.
class SettingsSearchEntry {
  const SettingsSearchEntry({
    required this.id,
    required this.page,
    required this.name,
    required this.aliases,
    this.description,
    this.section,
    this.aliasesZh = const [],
  });

  /// The index id, and the setting's anchor on its page.
  final String id;

  /// The settings slug of the page it is on.
  final String page;
  final String name;
  final String? description, section;
  final List<String> aliases, aliasesZh;
}

/// One setting as the search sees it: its own words, where it is, and the
/// other words for it.
class SearchableSetting {
  const SearchableSetting({
    required this.id,
    required this.page,
    required this.name,
    required this.pageLabel,
    this.description,
    this.sectionLabel,
    this.aliases = const [],
  });

  /// The index id, and the setting's anchor on its page.
  final String id;

  /// The settings slug of the page it is on.
  final String page;
  final String name, pageLabel;
  final String? description;

  /// The section on the page; none where the page has no sections of its own.
  final String? sectionLabel;

  /// Other words for it: the display language's, then English.
  final List<String> aliases;
}

/// What the query matched, in result order: names, then other words, then
/// descriptions, then where it is.
enum SettingsSearchMatchField { name, alias, description, where }

class SettingsSearchResult {
  const SettingsSearchResult(this.setting, this.field, [this.alias]);
  final SearchableSetting setting;
  final SettingsSearchMatchField field;

  /// The other word that matched, when [field] is [SettingsSearchMatchField.alias].
  final String? alias;
}

/// The form both the query and the words are compared in: NFKC, so full-width
/// and half-width letters are the same ("Ｅｎｔｅｒ" is "Enter"); lower case;
/// one space for each run of white space, none at the ends.
String normalizeSettingsSearchText(String text) =>
    unorm.nfkc(text).toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

SettingsSearchResult? _match(SearchableSetting setting, String query) {
  bool has(String? text) =>
      text != null && normalizeSettingsSearchText(text).contains(query);
  if (has(setting.name)) {
    return SettingsSearchResult(setting, SettingsSearchMatchField.name);
  }
  final alias = setting.aliases.where(has).firstOrNull;
  if (alias != null) {
    return SettingsSearchResult(setting, SettingsSearchMatchField.alias, alias);
  }
  if (has(setting.description)) {
    return SettingsSearchResult(setting, SettingsSearchMatchField.description);
  }
  final where = setting.sectionLabel == null
      ? setting.pageLabel
      : '${setting.pageLabel} ${setting.sectionLabel}';
  if (has(where)) return SettingsSearchResult(setting, SettingsSearchMatchField.where);
  return null;
}

/// The settings that match the query, in result order: those whose name has
/// it first, then those with another word that has it, then descriptions,
/// then page and section; within each, the list's order. An empty query
/// finds nothing (the list shows its groups instead).
List<SettingsSearchResult> searchSettings(
  List<SearchableSetting> settings,
  String query,
) {
  final normalized = normalizeSettingsSearchText(query);
  if (normalized.isEmpty) return const [];
  final found = <(SettingsSearchResult, int)>[];
  for (var i = 0; i < settings.length; i++) {
    final result = _match(settings[i], normalized);
    if (result != null) found.add((result, i));
  }
  found.sort((a, b) {
    final byField = a.$1.field.index.compareTo(b.$1.field.index);
    return byField != 0 ? byField : a.$2.compareTo(b.$2);
  });
  return [for (final (result, _) in found) result];
}

/// The other words to search for one display locale: that locale's own, then
/// English, which is always searched; each word once.
List<String> settingsSearchAliases(
  SettingsSearchEntry entry, {
  required bool zh,
}) => {...(zh ? entry.aliasesZh : const <String>[]), ...entry.aliases}.toList();
