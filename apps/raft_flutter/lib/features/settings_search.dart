import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:unorm_dart/unorm_dart.dart' as unorm;

import 'resource_search.dart' show SearchHighlight;
import 'settings_search_index.dart';
import 'settings_search_match.dart';

/// Settings search (Web features/settings/search/SettingsSearch.tsx and
/// useSettingsSearchSettings.ts; raft-design settings.md#searching-settings):
/// the field pinned above the list of pages, the results that replace the list
/// while there is text, and the settings those results are drawn from.

/// What Settings search needs from the surface that hosts it.
class SettingsSearchHost {
  const SettingsSearchHost({
    required this.open,
    required this.searchEverywhere,
    this.shown = _everything,
    this.serverName = '',
    this.desktopApp = false,
  });

  static bool _everything(String id) => true;

  /// Opens the page of a result at its setting (`/settings/<page>#<id>`).
  /// [fromKeyboard]: Enter or Space started the jump, so focus follows it.
  final void Function(String page, String id, {required bool fromKeyboard})
  open;

  /// The "Search everywhere" button of an empty result: the global search with
  /// the typed query.
  final void Function(String query) searchEverywhere;

  /// Whether this person sees the setting `id` on its page: what a page
  /// leaves out for them (a flag that is off, a role that can't, SSO that
  /// isn't set up) is not searched (useSettingsSearchSettings `shown`).
  final bool Function(String id) shown;

  /// The current server's name, for the pages named after it.
  final String serverName;

  /// This is the desktop app: its notifications card is Desktop notifications.
  final bool desktopApp;
}

/// One page of the list the search reads: its row id (the settings slug) in
/// the list's order, and the title the list shows for it.
class SettingsSearchPage {
  const SettingsSearchPage(this.id, this.label);
  final String id, label;
}

/// The pages on the server, named after it as the list's rows are for a
/// screen reader (`SERVER_PAGE_TITLE_ID`).
const _serverPageTitle = {
  'theme': 'Theme on {serverName}',
  'server-notifications': 'Notifications on {serverName}',
};

/// The settings this person can find, in the words of the display language
/// and in the list's order: those on the pages the list shows them
/// ([pages]), less the ones a page leaves out for them
/// ([SettingsSearchHost.shown]).
List<SearchableSetting> searchableSettings(
  BuildContext context,
  SettingsSearchHost host,
  List<SettingsSearchPage> pages,
) {
  final zh = Localizations.maybeLocaleOf(context)?.languageCode == 'zh';
  final order = {for (var i = 0; i < pages.length; i++) pages[i].id: i};
  final labels = {for (final page in pages) page.id: page.label};
  final values = {'serverName': host.serverName};
  String text(String source) => raftFormat(context, source, values);
  final settings = <SearchableSetting>[];
  for (final entry in settingsSearchIndex) {
    if (!order.containsKey(entry.page) || !host.shown(entry.id)) continue;
    final desktopCard = host.desktopApp && entry.id == 'push-notifications';
    final serverPage = _serverPageTitle[entry.page];
    settings.add(
      SearchableSetting(
        id: entry.id,
        page: entry.page,
        name: text(desktopCard ? 'Desktop notifications' : entry.name),
        description: desktopCard || entry.description == null
            ? null
            : text(entry.description!),
        pageLabel: text(serverPage ?? labels[entry.page]!),
        sectionLabel: entry.section == null ? null : text(entry.section!),
        aliases: settingsSearchAliases(entry, zh: zh),
      ),
    );
  }
  // The list's order: by page as the list shows them, then the index's.
  final indexed = [for (var i = 0; i < settings.length; i++) (settings[i], i)]
    ..sort((a, b) {
      final byPage = order[a.$1.page]!.compareTo(order[b.$1.page]!);
      return byPage != 0 ? byPage : a.$2.compareTo(b.$2);
    });
  return [for (final (setting, _) in indexed) setting];
}

/// Whether [query] has anything to search for: the results then take the
/// list's place.
bool settingsSearching(String query) =>
    normalizeSettingsSearchText(query).isNotEmpty;

/// The search field, pinned above the list (`sticky top-0`, 8px above and 4px
/// below). Field keys (SettingsSearch.tsx handleFieldKeyDown): Down moves into
/// the results, Enter opens the first result as a keyboard jump, Escape clears
/// the query and, on an empty field, leaves it.
class SettingsSearchField extends StatelessWidget {
  const SettingsSearchField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onEnter,
    required this.onDown,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  /// Enter in the field: open the first result (a keyboard jump).
  final VoidCallback onEnter;

  /// Down in the field: focus the first result; true when there is one.
  final bool Function() onDown;

  /// The field itself (Web `settings-search-input`).
  static const fieldKey = Key('settings-search-input');

  /// The inline-end clear button (Web `settings-search-clear`).
  static const clearKey = Key('settings-search-clear');

  void _clear() {
    controller.clear();
    onChanged('');
    focusNode.requestFocus();
  }

  KeyEventResult _key(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent || controller.value.composing.isValid) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      return onDown() ? KeyEventResult.handled : KeyEventResult.ignored;
    }
    // Escape on a field with text is the input group's own (it clears and
    // stops); on an empty one the field is left.
    if (event.logicalKey == LogicalKeyboardKey.escape &&
        controller.text.isEmpty) {
      focusNode.unfocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final placeholder = raftText(context, 'Search settings');
    return Padding(
      key: const Key('settings-search'),
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onKeyEvent: _key,
        child: Semantics(
          container: true,
          label: placeholder,
          child: RaftInputGroup(
            leading: const RaftInputGroupAddon.icon(RaftGlyph.search),
            controller: controller,
            focusNode: focusNode,
            fieldKey: fieldKey,
            clearKey: clearKey,
            hintText: placeholder,
            semanticLabel: placeholder,
            onChanged: onChanged,
            onSubmitted: (_) => onEnter(),
            clearLabel: raftText(context, 'Clear search'),
            onClear: _clear,
            clearOnEscape: true,
          ),
        ),
      ),
    );
  }
}

/// The results of the query, a list of cells like the pages' rows. Up and
/// Down move through them, Up from the first and Escape return to the field
/// (handleResultsKeyDown). With nothing found it says so, and offers the
/// global search with the same words.
class SettingsSearchResults extends StatefulWidget {
  const SettingsSearchResults({
    super.key,
    required this.results,
    required this.query,
    required this.field,
    required this.isOpen,
    required this.onOpen,
    required this.onSearchEverywhere,
  });
  final List<SettingsSearchResult> results;
  final String query;

  /// The search field's focus node: Up from the first row goes back to it.
  final FocusNode field;

  /// Whether the setting is the one open (page and anchor): the open one
  /// stays selected, so the next can be opened from here.
  final bool Function(SearchableSetting setting) isOpen;
  final void Function(SearchableSetting setting, {required bool fromKeyboard})
  onOpen;
  final VoidCallback onSearchEverywhere;

  static const listKey = Key('settings-search-results');
  static const emptyKey = Key('settings-search-empty');
  static const everywhereKey = Key('settings-search-everywhere');
  static Key rowKey(String id) => Key('settings-search-result-$id');

  @override
  State<SettingsSearchResults> createState() => SettingsSearchResultsState();
}

class SettingsSearchResultsState extends State<SettingsSearchResults> {
  final _nodes = <String, FocusNode>{};

  FocusNode _node(String id) =>
      _nodes.putIfAbsent(id, () => FocusNode(debugLabel: 'settings-search-$id'));

  /// Focuses the first result; false when there is none.
  bool focusFirst() {
    final first = widget.results.firstOrNull;
    if (first == null) return false;
    _node(first.setting.id).requestFocus();
    return true;
  }

  @override
  void didUpdateWidget(SettingsSearchResults oldWidget) {
    super.didUpdateWidget(oldWidget);
    final live = {for (final r in widget.results) r.setting.id};
    for (final id in [..._nodes.keys]) {
      if (!live.contains(id)) _nodes.remove(id)?.dispose();
    }
  }

  @override
  void dispose() {
    for (final node in _nodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  KeyEventResult _key(FocusNode node, KeyEvent event) {
    final key = event.logicalKey;
    if (event is KeyUpEvent ||
        (key != LogicalKeyboardKey.arrowDown &&
            key != LogicalKeyboardKey.arrowUp &&
            key != LogicalKeyboardKey.escape)) {
      return KeyEventResult.ignored;
    }
    final ids = [for (final r in widget.results) r.setting.id];
    final at = ids.indexWhere((id) => _nodes[id]?.hasFocus ?? false);
    if (at < 0) return KeyEventResult.ignored;
    if (key == LogicalKeyboardKey.escape) {
      widget.field.requestFocus();
    } else if (key == LogicalKeyboardKey.arrowDown) {
      if (at + 1 < ids.length) _node(ids[at + 1]).requestFocus();
    } else if (at == 0) {
      widget.field.requestFocus();
    } else {
      _node(ids[at - 1]).requestFocus();
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.results.isEmpty) {
      return RaftEmptyState(
        key: SettingsSearchResults.emptyKey,
        glyph: RaftGlyph.search,
        title: raftFormat(context, 'No settings match "{query}"', {
          'query': widget.query.trim(),
        }),
        detail: raftText(
          context,
          'Try another word, or search everything for messages and people.',
        ),
        action: RaftButton(
          key: SettingsSearchResults.everywhereKey,
          label: raftText(context, 'Search everywhere'),
          uiVariant: RaftButtonVariant.outline,
          onPressed: widget.onSearchEverywhere,
        ),
      );
    }
    // Marks compare case-insensitively; NFKC makes a full-width query mark
    // half-width words.
    final markQuery = unorm.nfkc(widget.query);
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _key,
      child: Semantics(
        container: true,
        label: raftText(context, 'Search settings'),
        child: Column(
          key: SettingsSearchResults.listKey,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 2,
          children: [
            for (final result in widget.results)
              _row(context, result, markQuery),
          ],
        ),
      ),
    );
  }

  Widget _row(
    BuildContext context,
    SettingsSearchResult result,
    String markQuery,
  ) {
    final setting = result.setting;
    final where = setting.sectionLabel == null
        ? setting.pageLabel
        : '${setting.pageLabel} · ${setting.sectionLabel}';
    final subtitle = result.alias == null ? where : '$where · ${result.alias}';
    return RaftSettingsSearchResultRow(
      key: SettingsSearchResults.rowKey(setting.id),
      focusNode: _node(setting.id),
      selected: widget.isOpen(setting),
      semanticLabel: '${setting.name}, $subtitle',
      onOpen: (fromKeyboard) =>
          widget.onOpen(setting, fromKeyboard: fromKeyboard),
      title: (context, style) =>
          SearchHighlight(text: setting.name, query: markQuery, style: style),
      subtitle: (context, style) =>
          SearchHighlight(text: subtitle, query: markQuery, style: style),
    );
  }
}
