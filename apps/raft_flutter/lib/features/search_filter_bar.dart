import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import 'resource_filters.dart';
import 'task_selection_filter.dart';

/// Source MessageSearchPage filter chips: From, Scope, Channel, Time, Sort and
/// "Clear All". The Search page and the Cmd/Ctrl+K overlay both render them
/// (Source shows the same component in both); each owns the surrounding row
/// and what a change does. The widget mutates [filters] in place, then calls
/// [onChanged].
class SearchFilterBar extends StatelessWidget {
  const SearchFilterBar({
    super.key,
    required this.filters,
    required this.senders,
    required this.conversations,
    required this.menus,
    required this.queryIsEmpty,
    required this.scope,
    required this.valid,
    required this.onChanged,
    this.channelLabel,
  });

  final ResourceFilters filters;
  final List<ResourceSender> senders;

  /// Channel and DM id -> label (`#name` / `@name`) the Channel filter lists.
  final Map<String, String> conversations;

  /// Open filter menus; the owner closes them with its dialogs, and opening
  /// one closes the others.
  final Set<MenuController> menus;

  /// Sort needs a query (Source disables the chip without one).
  final bool queryIsEmpty;

  /// Identity of the data the chips act on; a stale scope is ignored.
  final String scope;
  final bool Function() valid;
  final VoidCallback onChanged;

  /// Label of the chip that replaces the Channel picker once a channel is
  /// chosen (Source: `#name` with an X; a click clears it).
  final String Function(String id)? channelLabel;

  static const timeRanges = {
    'any': 'Any Time',
    'today': 'Today',
    '7d': 'Last 7 Days',
    '30d': 'Last 30 Days',
  };
  static const sorts = {'relevance': 'Relevant', 'recent': 'Recent'};

  /// Web `search.sortRecent` is 最新; the shared "Recent" catalog entry is the
  /// other 最近.
  static String choiceLabel(BuildContext context, String source) =>
      source == 'Recent'
      ? raftTextZh(context, source, '最新')
      : raftText(context, source);

  @override
  Widget build(BuildContext context) {
    final senderOptions = {
      for (final sender in senders)
        sender.key:
            '${sender.label} · ${raftText(context, sender.type == 'user' ? 'Human' : 'Agent')}',
    };
    Widget picker(
      String field,
      String tooltip,
      Map<String, String> options,
      Set<String> selected,
      void Function(String) toggle,
      VoidCallback clear, {
      String? label,
      RaftGlyph? glyph,
      bool single = false,
    }) => TaskSelectionFilter(
      key: ValueKey('$scope:$field'),
      field: field,
      tooltip: tooltip,
      label: label,
      glyph: glyph,
      options: options,
      selection: selected,
      valid: valid,
      closeOnSelect: single,
      picker: true,
      combobox: field == 'Channel',
      onToggle: (key) {
        if (!valid()) return;
        toggle(key);
        onChanged();
      },
      onClear: () {
        if (!valid()) return;
        clear();
        onChanged();
      },
      beforeOpen: (menu) {
        for (final other in menus) {
          if (!identical(menu, other) && other.isOpen) other.close();
        }
      },
      onController: (menu, add) {
        add ? menus.add(menu) : menus.remove(menu);
      },
    );
    Widget dropdown(
      String title,
      String label,
      Map<String, String> choices,
      void Function(String) changed,
    ) => RaftDropdownMenu(
      key: ValueKey('$scope:$title'),
      tooltip: raftText(context, title),
      label: choiceLabel(context, label),
      glyph: title == 'Search Date Range'
          ? RaftGlyph.calendarRange
          : RaftGlyph.arrowDownUp,
      trailingGlyph: RaftGlyph.chevronDown,
      triggerStyle: RaftDropdownTriggerStyle.picker,
      minimumTargetSize: RaftMetrics.buttonSm,
      // activeFilterClass when the value differs from the default.
      selected: title == 'Search Date Range'
          ? filters.timeRange != 'any'
          : filters.searchSort != 'relevance',
      enabled: title != 'Sort Search Results' || !queryIsEmpty,
      entries: [
        for (final entry in choices.entries)
          RaftMenuEntry(
            label: choiceLabel(context, entry.value),
            onPressed: () {
              if (valid()) {
                changed(entry.key);
                onChanged();
              }
            },
          ),
      ],
    );
    return RaftSearchFilterWrap(
      children: [
        picker(
          'From',
          'Filter by Sender',
          senderOptions,
          {if (filters.sender != null) filters.sender!.key},
          (key) => filters.selectSender(
            senders.where((s) => s.key == key).firstOrNull,
          ),
          () => filters.selectSender(null),
          single: true,
          label: filters.sender == null
              ? raftText(context, 'From')
              : '${raftText(context, 'From')}: ${filters.sender!.label}',
          glyph: RaftGlyph.userCircle2,
        ),
        picker(
          'Scope',
          'Search Scope',
          const {
            'mentioned': 'Mentions Me',
            'humans': 'Humans',
            'agents': 'Agents',
          },
          filters.scopes,
          filters.toggleScope,
          filters.scopes.clear,
          glyph: RaftGlyph.atSign,
        ),
        if (filters.channelId != null && channelLabel != null)
          RaftTextButton(
            key: ValueKey('$scope:Channel'),
            label: channelLabel!(filters.channelId!),
            glyph: RaftGlyph.hash,
            trailingGlyph: RaftGlyph.x,
            variant: RaftControlVariant.primary,
            selected: true,
            visualHeight: RaftMetrics.buttonSm,
            onPressed: () {
              if (valid()) {
                filters.channelId = null;
                onChanged();
              }
            },
          )
        else
          picker(
            'Channel',
            'Filter by Channel',
            conversations,
            {if (filters.channelId != null) filters.channelId!},
            (id) => filters.channelId = id,
            () => filters.channelId = null,
            single: true,
            glyph: RaftGlyph.hash,
          ),
        dropdown(
          'Search Date Range',
          // ignore: raft_lints/avoid_render_index_assertion -- timeRange is validated when restored (search_memory.dart) and only set from this dropdown.
          timeRanges[filters.timeRange]!,
          timeRanges,
          (value) => filters.timeRange = value,
        ),
        dropdown(
          'Sort Search Results',
          filters.searchSort == 'recent' ? 'Recent' : 'Relevant',
          sorts,
          (value) => filters.searchSort = value,
        ),
        if (filters.hasSearchFilter)
          // Button ghost xs "Clear All".
          RaftTextButton(
            label: 'Clear All',
            variant: RaftControlVariant.ghost,
            visualHeight: RaftMetrics.buttonXs,
            minimumTargetSize: RaftMetrics.buttonXs,
            onPressed: () {
              if (valid()) {
                filters.clearSearchFilters();
                onChanged();
              }
            },
          ),
      ],
    );
  }
}
