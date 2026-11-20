import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import 'resource_filters.dart';
import 'task_selection_filter.dart';

/// Source MessageSearchPage filter chips: From, Scope, Channel, Time, Sort and
/// "Clear all". The Search page and the Cmd/Ctrl+K overlay both render them
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
    this.channelOptions,
    this.channelGlyph,
    this.scopeConversation,
  });

  final ResourceFilters filters;
  final List<ResourceSender> senders;

  /// Channel and DM id -> label (`#name` / `@name`) the Channel filter lists.
  final Map<String, String> conversations;
  final List<RaftComboboxItem>? channelOptions;

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
  final RaftGlyph Function(String id)? channelGlyph;
  final String? scopeConversation;

  static const timeRanges = {
    'any': 'Any time',
    'today': 'Today',
    '7d': 'Last 7 days',
    '30d': 'Last 30 days',
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
      searchFilter: true,
      combobox: field == 'Channel',
      comboboxItems: field == 'Channel' ? channelOptions : null,
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
    ) {
      final sort = title == 'Sort Search Results';
      final localized = choiceLabel(context, label);
      return RaftDropdownMenu(
        key: ValueKey('$scope:$title'),
        label: localized,
        align: sort ? RaftDropdownAlign.end : RaftDropdownAlign.start,
        enabled: !sort || !queryIsEmpty,
        snapShadowToDevicePixels: true,
        triggerBuilder: (_, focusNode, press) => RaftPickerTriggerButton(
          label: localized,
          focusNode: focusNode,
          glyph: sort ? RaftGlyph.arrowDownUp : RaftGlyph.calendarRange,
          fitToolbar: true,
          snapToDevicePixels: true,
          selected: sort
              ? filters.searchSort != 'relevance'
              : filters.timeRange != 'any',
          onPressed: press,
        ),
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
    }

    final scrolling = <Widget>[
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
      if (scopeConversation case final conversation?)
        RaftBadge(
          label: raftFormat(context, 'In {conversation}', {
            'conversation': conversation,
          }),
          appearance: RaftBadgeRecipeAppearance.soft,
          variant: RaftBadgeRecipeVariant.information,
        )
      else if (filters.channelId != null && channelLabel != null)
        RaftTextButton(
          key: ValueKey('$scope:Channel'),
          label: channelLabel!(filters.channelId!),
          glyph: channelGlyph?.call(filters.channelId!) ?? RaftGlyph.hash,
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
    ];
    final sort = dropdown(
      'Sort Search Results',
      filters.searchSort == 'recent' ? 'Recent' : 'Relevant',
      sorts,
      (value) => filters.searchSort = value,
    );
    final active = [
      filters.sender != null,
      filters.scopes.isNotEmpty,
      scopeConversation == null && filters.channelId != null,
      filters.timeRange != 'any',
    ];
    final clearAll = RaftButton(
      label: 'Clear all',
      uiVariant: RaftButtonVariant.ghost,
      uiSize: RaftButtonSize.md,
      snapBorderToDevicePixels: true,
      onPressed: () {
        if (valid()) {
          final fixedChannel = scopeConversation == null
              ? null
              : filters.channelId;
          filters.clearSearchFilters();
          filters.channelId = fixedChannel;
          onChanged();
        }
      },
    );
    // Web SearchFilterBar: one FitToolbar line. The chips are a scroll group
    // with Clear all pinned at its end; Sort is its own first-line group.
    return RaftFitToolbar(
      semanticLabel: raftText(context, 'Search filters'),
      children: [
        RaftFitGroup(
          firstLine: true,
          scroll: true,
          showScrollbar: true,
          end:
              (scopeConversation == null
                  ? filters.hasSearchFilter
                  : filters.sender != null ||
                        filters.scopes.isNotEmpty ||
                        filters.timeRange != 'any')
              ? clearAll
              : null,
          items: [
            for (final (index, chip) in scrolling.indexed)
              RaftFitChild(active: active[index], child: chip),
          ],
        ),
        RaftFitGroup(firstLine: true, items: [RaftFitChild(child: sort)]),
      ],
    );
  }
}
