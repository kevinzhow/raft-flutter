import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/recipes.dart'
    show
        RaftInputGroupRecipeSize,
        RaftSegmentedControlRecipe,
        RaftTasksPanelRecipe;

import '../../data/workspace_controller.dart';
import '../icu_message.dart';
import '../private_route_guard.dart';
import 'artifact_api.dart';
import 'artifact_dashboard_data.dart';
import 'artifact_dashboard_filter.dart';
import 'artifact_dashboard_rows.dart';
import 'artifact_models.dart';
import 'artifact_session.dart';
import 'artifact_viewer_page.dart';

class ArtifactDashboard extends StatefulWidget {
  const ArtifactDashboard({
    super.key,
    required this.workspace,
    this.onBack,
    this.clock,
  });

  final WorkspaceController workspace;
  final VoidCallback? onBack;
  final DateTime Function()? clock;

  @override
  State<ArtifactDashboard> createState() => _ArtifactDashboardState();
}

class _ArtifactDashboardState extends State<ArtifactDashboard> {
  static final _cache =
      Expando<
        ({String scope, int deletionRevision, ArtifactDashboardPage page})
      >();

  final search = TextEditingController();
  final focus = FocusNode();
  Timer? debounce;
  ArtifactDashboardPage? page;
  ArtifactDashboardQuery? answered;
  ArtifactDashboardPlace? author;
  ArtifactDashboardPlace? place;
  ArtifactDashboardSort sort = ArtifactDashboardSort.opened;
  late final ArtifactSession session = ArtifactSession.of(widget.workspace);
  late final api = ArtifactDashboardApi(widget.workspace.client);
  late ArtifactDashboardPreferences preferences;
  bool relevant = false;
  bool loading = true;
  bool failed = false;
  bool off = false;
  bool paging = false;
  bool moreFailed = false;
  int request = 0;
  late String scope;
  late bool enabled;
  ArtifactCard? openCard;
  FocusNode? opener;

  String get authority =>
      '${channelSearchPageAuthority(widget.workspace)}:${session.generation}';

  @override
  void initState() {
    super.initState();
    preferences = ArtifactDashboardPreferences.read();
    sort = preferences.sort;
    scope = authority;
    enabled = session.enabled;
    final cached = _cache[widget.workspace];
    if (enabled &&
        cached?.scope == scope &&
        cached?.deletionRevision == session.deletedArtifacts.value) {
      page = cached!.page;
    }
    session.addListener(sessionChanged);
    session.deletedArtifacts.addListener(refreshAfterDeletion);
    widget.workspace.addListener(sessionChanged);
    if (enabled) unawaited(read(keep: true));
  }

  @override
  void dispose() {
    session.removeListener(sessionChanged);
    session.deletedArtifacts.removeListener(refreshAfterDeletion);
    widget.workspace.removeListener(sessionChanged);
    debounce?.cancel();
    search.dispose();
    focus.dispose();
    super.dispose();
  }

  void refreshAfterDeletion() {
    if (scope == authority) unawaited(read(keep: true));
  }

  void sessionChanged() {
    if (!mounted || (scope == authority && enabled == session.enabled)) return;
    debounce?.cancel();
    setState(() {
      if (scope != authority) {
        scope = authority;
        author = null;
        place = null;
        relevant = false;
        search.clear();
      }
      enabled = session.enabled;
      page = null;
      openCard = null;
      opener = null;
      answered = null;
      loading = enabled;
      off = failed = paging = moreFailed = false;
      _cache[widget.workspace] = null;
      request++;
    });
    if (enabled) unawaited(read());
  }

  Future<void> read({bool keep = false}) async {
    if (!enabled) return;
    debounce?.cancel();
    final query = ArtifactDashboardQuery(
      home: place?.home == true ? place?.id : null,
      conversation: place?.home == false ? place?.id : null,
      author: author?.id,
      search: search.text.trim(),
      sort: sort,
      relevant: relevant,
    );
    final current = ++request;
    setState(() {
      if (!keep) page = null;
      loading = true;
      failed = off = paging = moreFailed = false;
    });
    try {
      final next = await api.read(query);
      if (!mounted || current != request || scope != authority) return;
      if (!query.narrowed) {
        _cache[widget.workspace] = (
          scope: scope,
          deletionRevision: session.deletedArtifacts.value,
          page: next,
        );
      }
      setState(() {
        page = next;
        answered = query;
        loading = false;
      });
    } catch (error) {
      if (!mounted || current != request || scope != authority) return;
      off = artifactErrorCode(error) == 'ARTIFACTS_NOT_ENABLED';
      _cache[widget.workspace] = null;
      setState(() {
        failed = !off;
        loading = false;
        if (off) page = null;
        if (keep && answered != null && sort != answered!.sort) {
          sort = answered!.sort;
          preferences = preferences.copyWith(sort: sort);
          preferences.remember();
        }
      });
    }
  }

  Future<void> loadMore() async {
    final older = page;
    final query = answered;
    final cursor = older?.nextCursor;
    if (older == null || query == null || cursor == null || loading || paging) {
      return;
    }
    final current = request;
    setState(() {
      paging = true;
      moreFailed = false;
    });
    try {
      final next = await api.read(query, cursor: cursor);
      if (!mounted || current != request || scope != authority) return;
      final ids = older.rows.map((row) => row.card.id).toSet();
      setState(() {
        page = ArtifactDashboardPage(
          [...older.rows, ...next.rows.where((row) => ids.add(row.card.id))],
          next.nextCursor,
          older.counts,
        );
        paging = false;
      });
    } catch (_) {
      if (!mounted || current != request || scope != authority) return;
      setState(() {
        paging = false;
        moreFailed = true;
      });
    }
  }

  void open(ArtifactCard card) {
    opener = FocusManager.instance.primaryFocus;
    setState(() {
      openCard = card;
    });
  }

  void closeViewer({bool refresh = true}) {
    if (openCard == null) return;
    final previousFocus = opener;
    setState(() {
      openCard = null;
      opener = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          openCard == null &&
          previousFocus?.context?.mounted == true) {
        previousFocus!.requestFocus();
      }
    });
    if (refresh) unawaited(read(keep: true));
  }

  void filter(ArtifactDashboardPlace? result, {required bool authors}) {
    if (scope != authority || !enabled) return;
    if (authors) {
      author = result;
    } else {
      place = result;
    }
    unawaited(read());
  }

  void clear({bool all = false}) {
    search.clear();
    if (all) {
      author = null;
      place = null;
      relevant = false;
    }
    unawaited(read());
  }

  @override
  Widget build(BuildContext context) {
    String text(String value) => raftText(context, value);
    final compact = RaftAdaptiveWorkspace.compactOf(context);
    final counts = page?.counts;
    final available = enabled && !off;
    final card = openCard;
    final tokens = RaftTokens.of(context);
    final countLabel = counts == null
        ? null
        : icuText(
            context,
            answered?.narrowed == true
                ? '{total, plural, one {{filtered} of # Artifact} other {{filtered} of # Artifacts}}'
                : '{total, plural, one {# Artifact} other {# Artifacts}}',
            {'filtered': counts.filtered, 'total': counts.total},
          );
    final collection = ColoredBox(
      color: tokens.ui.layerCanvas,
      child: Column(
        children: [
          RaftPanelHeaderBar(
            title: text('Artifacts'),
            inlineMeta: !compact,
            background: tokens.ui.layerCanvas,
            columnMargin: compact
                ? RaftArtifactCollectionLayout.columnMargin
                : null,
            subtitle: countLabel,
            metaSlot: compact && countLabel != null
                ? RaftArtifactCollectionLayout.headerCount(context, countLabel)
                : null,
            onBack: widget.onBack,
          ),
          if (available) toolbar(context, compact),
          Expanded(child: body(context, compact, available)),
        ],
      ),
    );
    return Stack(
      key: const Key('artifacts-dashboard'),
      fit: StackFit.expand,
      children: [
        ExcludeFocus(
          excluding: card != null,
          child: ExcludeSemantics(
            excluding: card != null,
            child: IgnorePointer(ignoring: card != null, child: collection),
          ),
        ),
        if (card != null)
          RaftBackDismiss(
            onDismiss: closeViewer,
            child: ArtifactWorkspaceViewer(
              key: ValueKey(card.id),
              session: session,
              target: ArtifactLinkTarget(card.id),
              seed: card,
              page: compact,
              inCollection: true,
              columnMargin: RaftArtifactCollectionLayout.columnMargin,
              onClose: closeViewer,
              onDeleted: () => closeViewer(refresh: false),
            ),
          ),
      ],
    );
  }

  Widget toolbar(BuildContext context, bool compact) {
    String tr(String value) => raftText(context, value);
    final tokens = RaftTokens.of(context);
    final recipe = RaftTasksPanelRecipe.resolve(
      states: tokens.recipeStates(responsive: true),
      tokens: tokens.recipeTokens,
    ).toolbar;
    final segmentedInset = RaftSegmentedControlRecipe.resolve(
      states: tokens.recipeStates(responsive: true),
      tokens: tokens.recipeTokens,
    ).root.padding.top;
    final desktop = !compact && tokens.desktop;
    final desktopAir = desktop
        ? RaftDesktopMetrics.headerAir - segmentedInset
        : segmentedInset;
    final gap = recipe.columnGap ?? RaftSpace.x2;
    final rowGap = compact ? recipe.rowGap ?? gap : 0.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final hideLabels = !compact && constraints.maxWidth < 1020;
        final shortSort = compact || constraints.maxWidth < 896;
        final filterScope = scope;
        final filters = [
          ArtifactDashboardFilter(
            key: ValueKey('artifact-conversation-filter-$filterScope'),
            api: api,
            authors: false,
            selection: place,
            serverName: widget.workspace.server?.name,
            labelHidden: hideLabels,
            onSelected: (choice) {
              if (scope == filterScope) filter(choice, authors: false);
            },
          ),
          ArtifactDashboardFilter(
            key: ValueKey('artifact-author-filter-$scope'),
            api: api,
            authors: true,
            selection: author,
            labelHidden: hideLabels,
            onSelected: (choice) => filter(choice, authors: true),
          ),
          RaftPickerTriggerButton(
            label: tr('Relevant to me'),
            labelHidden: hideLabels,
            tooltip: hideLabels ? tr('Relevant to me') : null,
            glyph: RaftGlyph.inbox,
            trailingGlyph: null,
            selected: relevant,
            value: (page?.counts?.relevant ?? 0) > 0
                ? '${page!.counts!.relevant}'
                : null,
            onPressed: () {
              relevant = !relevant;
              unawaited(read());
            },
          ),
          if (place != null && author != null)
            RaftButton(
              label: compact || hideLabels ? '' : tr('Clear all'),
              glyph: compact || hideLabels ? RaftGlyph.x : null,
              semanticLabel: tr('Clear all'),
              tone: RaftButtonRecipeVariant.ghost,
              size: compact || hideLabels
                  ? RaftButtonRecipeSize.iconMd
                  : RaftButtonRecipeSize.md,
              onPressed: () {
                author = null;
                place = null;
                relevant = false;
                unawaited(read());
              },
            ),
        ];
        final searchField = RaftInputGroup(
          size: RaftInputGroupRecipeSize.md,
          leading: const RaftInputGroupAddon.icon(RaftGlyph.search),
          controller: search,
          focusNode: focus,
          hintText: tr(compact ? 'Search' : 'Search titles'),
          clearLabel: tr('Clear search'),
          onClear: clear,
          onChanged: (_) {
            debounce?.cancel();
            debounce = Timer(
              const Duration(milliseconds: 300),
              () => unawaited(read()),
            );
          },
          onSubmitted: (_) => unawaited(read()),
        );
        final tools = [
          if (!relevant)
            RaftDropdownMenu(
              label: tr(sortLabel(sort)),
              kind: RaftMenuKind.dropdownMenu,
              align: RaftDropdownAlign.end,
              entries: [
                for (final option in ArtifactDashboardSort.values)
                  RaftMenuEntry(
                    label: tr(sortLabel(option)),
                    checked: sort == option,
                    onPressed: () {
                      if (sort == option) return;
                      sort = option;
                      preferences = preferences.copyWith(sort: option);
                      preferences.remember();
                      unawaited(read(keep: true));
                    },
                  ),
              ],
              triggerBuilder: (_, focus, onPressed) => RaftPickerTriggerButton(
                label: tr(sortLabel(sort)),
                glyph: RaftGlyph.arrowDownUp,
                inlineIndicator: true,
                labelHidden: shortSort,
                tooltip: shortSort ? tr(sortLabel(sort)) : null,
                focusNode: focus,
                onPressed: onPressed,
              ),
            ),
          RaftSegmentedControl<bool>(
            value: preferences.grid,
            iconsOnly: compact,
            visualHeight: desktop
                ? RaftDesktopMetrics.controlHeight
                : RaftSpace.x4 * 2,
            items: [
              RaftSegmentedOption(
                value: true,
                label: tr('Grid'),
                glyph: RaftGlyph.layoutGrid,
                tooltip: compact ? tr('Grid') : null,
                itemKey: const Key('artifacts-view-grid'),
              ),
              RaftSegmentedOption(
                value: false,
                label: tr('List'),
                glyph: RaftGlyph.list,
                tooltip: compact ? tr('List') : null,
                itemKey: const Key('artifacts-view-list'),
              ),
            ],
            onChanged: (next) {
              setState(() {
                preferences = preferences.copyWith(grid: next);
              });
              preferences.remember();
            },
          ),
        ];
        return DecoratedBox(
          decoration: recipe.decoration(tokens.recipeTokens),
          child: Padding(
            padding: compact
                ? recipe.padding.copyWith(
                    left: 0,
                    right: 0,
                    bottom: recipe.padding.bottom + recipe.borderWidth.bottom,
                  )
                : EdgeInsets.symmetric(
                    horizontal: desktop
                        ? RaftDesktopMetrics.pageInset
                        : RaftArtifactCollectionLayout.columnMargin,
                    vertical: desktopAir,
                  ),
            child: Column(
              key: const Key('artifacts-toolbar'),
              spacing: rowGap,
              children: [
                Padding(
                  padding: compact
                      ? recipe.padding.copyWith(top: 0, bottom: 0)
                      : EdgeInsets.zero,
                  child: Row(
                    spacing: gap,
                    children: [
                      if (compact)
                        Expanded(child: searchField)
                      else
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              spacing: gap,
                              children: [
                                SizedBox(
                                  width: hideLabels
                                      ? RaftArtifactCollectionLayout
                                            .narrowSearchWidth
                                      : RaftArtifactCollectionLayout
                                            .searchWidth,
                                  child: searchField,
                                ),
                                ...filters,
                              ],
                            ),
                          ),
                        ),
                      ...tools,
                    ],
                  ),
                ),
                if (compact)
                  Padding(
                    padding: EdgeInsets.only(
                      left: recipe.padding.left - RaftSpace.x1,
                      right: recipe.padding.right - RaftSpace.x1,
                    ),
                    child: RaftHorizontalScrollFade(
                      extent: tokens.size(
                        'css.fade-edge',
                        fallback: RaftSpace.x6,
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(
                          horizontal: RaftSpace.x1,
                        ),
                        child: Row(spacing: gap, children: filters),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  String sortLabel(ArtifactDashboardSort value) =>
      value == ArtifactDashboardSort.opened
      ? 'Recently opened'
      : 'Recently updated';

  Widget body(BuildContext context, bool compact, bool available) {
    final rows = page?.rows;
    if (available && rows != null && rows.isNotEmpty) {
      return ArtifactDashboardRows(
        rows: rows,
        clock: widget.clock,
        serverName: widget.workspace.server?.name,
        readerId: widget.workspace.client.user?.id,
        readCover: (card) => session.api.cover(card, compact: compact),
        compact: compact,
        preferences: preferences,
        onColumnResize: (column, width) => setState(() {
          preferences = preferences.copyWith(
            widths: {...preferences.widths, column: width},
          );
        }),
        onColumnResizeEnd: () => preferences.remember(),
        opened: answered?.sort == ArtifactDashboardSort.opened && !relevant,
        onOpen: open,
        footer: page?.nextCursor == null
            ? null
            : RaftButton(
                label: raftText(
                  context,
                  moreFailed ? "Couldn't load more. Try again." : 'Load more',
                ),
                onPressed: paging || loading ? null : loadMore,
                secondary: true,
              ),
      );
    }
    if (available && loading) {
      return ListView(
        padding: raftScrollPadding(
          context,
          const EdgeInsets.only(bottom: RaftSpace.x2),
        ),
        children: [
          for (int index = 0; index < 3; index++) const RaftListRowSkeleton(),
        ],
      );
    }
    final narrowed = answered?.narrowed == true;
    return RaftEmptyState(
      glyph: RaftGlyph.fileText,
      detail: '',
      title: raftText(
        context,
        !available
            ? "Artifacts aren't on for this server"
            : failed
            ? "Couldn't load your Artifacts"
            : search.text.trim().isNotEmpty
            ? 'No Artifacts match your search'
            : relevant
            ? 'Nothing here involves you yet'
            : narrowed
            ? 'No Artifacts match these filters'
            : 'No Artifacts yet',
      ),
      action: available && (failed || narrowed)
          ? RaftButton(
              label: raftText(
                context,
                failed ? 'Try again' : 'Clear search and filter',
              ),
              onPressed: failed ? read : () => clear(all: true),
            )
          : null,
    );
  }
}
