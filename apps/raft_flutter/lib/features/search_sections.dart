import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

const searchEntityPreviewCount = 5;
const searchEntityLimit = 50;
const searchHistoryDays = 30;
const searchTooBroadHint =
    'No message contains all of these words, and too many contain one of them to check each one. Try more specific words, or narrow the search to a channel or sender.';

class SearchRelevanceFallback extends StatelessWidget {
  const SearchRelevanceFallback({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = RaftTokens.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        start: RaftSpace.x5,
        end: RaftSpace.x5,
        bottom: RaftSpace.x1,
      ),
      child: Text(
        raftText(
          context,
          'Too many matches to rank by relevance, so these are sorted newest first. Try more specific words, or narrow the search to a channel or sender.',
        ),
        style: tokens.scale(
          RaftTypeScale.caption,
          color: tokens.ui.foregroundHint,
        ),
      ),
    );
  }
}

RaftGlyph searchChannelGlyph(Map<String, dynamic>? row) =>
    switch (row?['type']) {
      'private' => RaftGlyph.lock,
      'joint' => RaftGlyph.gitBranch,
      'public' when row?['publicPageLive'] == true => RaftGlyph.globe,
      _ => RaftGlyph.hash,
    };

List<RaftComboboxItem> searchChannelChoices(
  Iterable<Map<String, dynamic>> rows,
) => [
  for (final row in rows)
    if (row['id'] is String && row['type'] != 'thread' && row['type'] != 'dm')
      RaftComboboxItem(
        row['id'] as String,
        '${row['name'] ?? ''}',
        keywords: '${row['description'] ?? ''}',
        glyph: searchChannelGlyph(row),
      ),
];

int? searchHistoryWindow(String plan, DateTime now) {
  if (plan != 'free') return null;
  final start = DateTime.utc(2026, 4, 18);
  final end = DateTime.utc(2026, 6, 23, 12);
  return !now.isBefore(start) && now.isBefore(end) ? null : searchHistoryDays;
}

class SearchEntityExpansion {
  static final _owners = Expando<SearchEntityExpansion>();
  static SearchEntityExpansion of(Object owner) =>
      _owners[owner] ??= SearchEntityExpansion();

  String? _page;
  String? _overlay;

  bool isExpanded(String key, {bool overlay = false}) =>
      key == (overlay ? _overlay : _page);

  void toggle(String key, {bool overlay = false}) {
    final next = isExpanded(key, overlay: overlay) ? null : key;
    if (overlay) {
      _overlay = next;
    } else {
      _page = next;
    }
  }
}

class SearchEntityToggle extends StatelessWidget {
  const SearchEntityToggle({
    super.key,
    required this.count,
    required this.expanded,
    required this.onToggle,
  });

  final int count;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) => Semantics(
    expanded: expanded,
    child: Align(
      alignment: AlignmentDirectional.centerStart,
      child: RaftButton(
        label: expanded
            ? raftText(context, 'Show fewer')
            : raftFormat(context, 'Show all {count}', {'count': count}),
        glyph: expanded ? RaftGlyph.chevronUp : RaftGlyph.chevronDown,
        uiVariant: RaftButtonVariant.ghost,
        uiSize: RaftButtonSize.sm,
        onPressed: onToggle,
      ),
    ),
  );
}

class SearchHistoryWindowBanner extends StatelessWidget {
  const SearchHistoryWindowBanner({
    super.key,
    required this.days,
    required this.onUpgrade,
  });

  final int days;
  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: RaftSpace.x4),
    child: RaftBanner(
      key: const Key('search-history-limited'),
      status: RaftBannerRecipeStatus.info,
      size: RaftBannerRecipeSize.sm,
      live: false,
      glyph: RaftGlyph.history,
      description: raftFormat(
        context,
        'On the Free plan, search covers only the last {days} days of messages.',
        {'days': days},
      ),
      descriptionTail: (
        label: raftText(context, 'Upgrade to Pro'),
        onPressed: onUpgrade,
      ),
    ),
  );
}

class SearchEverywhereRow extends StatelessWidget {
  const SearchEverywhereRow({
    super.key,
    required this.query,
    required this.onPressed,
  });

  final String query;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final words = query.trim();
    final tokens = RaftTokens.of(context);
    final recipe = RaftSearchRecipe(tokens, mobile: true);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: RaftSpace.x2),
      child: RaftSearchResultSurface(
        key: const Key('search-everywhere'),
        pageLayout: true,
        entity: true,
        onPressed: onPressed,
        child: Row(
          spacing: RaftSpace.x3,
          children: [
            const RaftQuickSwitcherIconBox(
              RaftGlyph.search,
              searchEntity: true,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: recipe.entityContentGap(flat: true),
                children: [
                  RaftCssText(
                    words.isEmpty
                        ? raftText(context, 'Search everywhere')
                        : raftFormat(
                            context,
                            'Search everywhere for “{query}”',
                            {'query': words},
                          ),
                    style: recipe.flatEntityTitle,
                  ),
                  RaftCssText(
                    raftText(
                      context,
                      'Opens the Search tab with the same words',
                    ),
                    style: recipe.flatEntityDescription,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showSearchChannelMenu(
  BuildContext context, {
  required Offset at,
  required VoidCallback onOpen,
}) async {
  final focus = FocusNode(debugLabel: 'Search channel menu Open');
  try {
    await showRaftMessageContextMenu<void>(
      context: context,
      anchor: at,
      builder: (menuContext) {
        FocusScope.of(menuContext).autofocus(focus);
        return RaftMessageContextMenu(
          onDismiss: () => Navigator.of(menuContext).pop(),
          sections: [
            [
              RaftMessageContextMenuItem(
                key: const Key('quick-switcher-open'),
                label: raftText(context, 'Open'),
                icon: raftMessageMenuIcon(RaftGlyph.folderOpen),
                focusNode: focus,
                onPressed: () {
                  Navigator.of(menuContext).pop();
                  onOpen();
                },
              ),
            ],
          ],
        );
      },
    );
  } finally {
    focus.dispose();
  }
}
