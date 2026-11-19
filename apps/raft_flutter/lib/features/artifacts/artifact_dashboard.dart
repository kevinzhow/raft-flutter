import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import '../../data/workspace_controller.dart';
import '../private_route_guard.dart';
import 'artifact_api.dart';
import 'artifact_dashboard_data.dart';
import 'artifact_dashboard_filter.dart';
import 'artifact_dashboard_rows.dart';
import 'artifact_models.dart';
import 'artifact_session.dart';
import 'artifact_viewer_page.dart';

class ArtifactDashboard extends StatefulWidget {
  const ArtifactDashboard({super.key, required this.workspace, this.onBack});

  final WorkspaceController workspace;
  final VoidCallback? onBack;

  @override
  State<ArtifactDashboard> createState() => _ArtifactDashboardState();
}

class _ArtifactDashboardState extends State<ArtifactDashboard> {
  static final _cache = Expando<({String scope, ArtifactDashboardPage page})>();

  final search = TextEditingController();
  final focus = FocusNode();
  Timer? debounce;
  ArtifactDashboardPage? page;
  ArtifactDashboardQuery? answered;
  ArtifactDashboardChoice? author;
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
    if (enabled && cached?.scope == scope) page = cached!.page;
    session.addListener(sessionChanged);
    widget.workspace.addListener(sessionChanged);
    if (enabled) unawaited(read(keep: true));
  }

  @override
  void dispose() {
    session.removeListener(sessionChanged);
    widget.workspace.removeListener(sessionChanged);
    debounce?.cancel();
    search.dispose();
    focus.dispose();
    super.dispose();
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
        _cache[widget.workspace] = (scope: scope, page: next);
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

  Future<void> open(ArtifactCard card) async {
    final previousScope = scope;
    final opener = FocusManager.instance.primaryFocus;
    await openWorkspaceArtifact(
      context,
      widget.workspace,
      ArtifactLinkTarget(card.id),
      seed: card,
    );
    if (!mounted || previousScope != authority) return;
    if (opener?.context != null) opener?.requestFocus();
    await read(keep: true);
  }

  Future<void> filter({required bool authors}) async {
    final previousScope = scope;
    final result = await showArtifactDashboardFilter(
      context,
      api,
      authors: authors,
      selected: authors ? author?.id : place?.id,
    );
    if (!mounted || previousScope != authority || result == null) return;
    setState(() {
      if (authors) {
        author = result.id.isEmpty
            ? null
            : (id: result.id, label: result.label);
      } else {
        place = result.id.isEmpty ? null : result;
      }
    });
    await read();
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
    return ColoredBox(
      color: RaftTokens.of(context).panel,
      child: Column(
        key: const Key('artifacts-dashboard'),
        children: [
          RaftPanelHeaderBar(
            title: text('Artifacts'),
            subtitle: counts == null ? null : '${counts.filtered}',
            onBack: widget.onBack,
          ),
          if (available)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: RaftSpace.x5,
                vertical: RaftSpace.x2,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RaftSearchInput(
                    controller: search,
                    focusNode: focus,
                    hint: text('Search titles'),
                    clearLabel: text('Clear search'),
                    onClear: () => clear(),
                    onChanged: (_) {
                      debounce?.cancel();
                      debounce = Timer(
                        const Duration(milliseconds: 300),
                        () => unawaited(read()),
                      );
                    },
                    onSubmitted: (_) => unawaited(read()),
                  ),
                  const SizedBox(height: RaftSpace.x2),
                  Wrap(
                    spacing: RaftSpace.x2,
                    runSpacing: RaftSpace.x2,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      RaftButton(
                        label: place?.label ?? text('By conversation'),
                        secondary: true,
                        onPressed: () => unawaited(filter(authors: false)),
                      ),
                      RaftButton(
                        label: author?.label ?? text('Author'),
                        secondary: true,
                        onPressed: () => unawaited(filter(authors: true)),
                      ),
                      RaftButton(
                        label: text(relevant ? 'See all' : 'Relevant to me'),
                        secondary: true,
                        onPressed: () {
                          relevant = !relevant;
                          unawaited(read());
                        },
                      ),
                      if (!relevant)
                        SizedBox(
                          width: sortControlWidth(context),
                          child: RaftSelectField<ArtifactDashboardSort>(
                            value: sort,
                            items: [
                              for (final value in ArtifactDashboardSort.values)
                                RaftSelectItem(
                                  value: value,
                                  label: text(
                                    value == ArtifactDashboardSort.opened
                                        ? 'Recently opened'
                                        : 'Recently updated',
                                  ),
                                ),
                            ],
                            onChanged: (next) {
                              if (next == null || next == sort) return;
                              sort = next;
                              preferences = preferences.copyWith(sort: next);
                              preferences.remember();
                              unawaited(read(keep: true));
                            },
                          ),
                        ),
                      if (!compact)
                        RaftSegmentedControl<bool>(
                          value: preferences.grid,
                          items: [
                            RaftSegmentedOption(
                              value: true,
                              label: text('Grid'),
                            ),
                            RaftSegmentedOption(
                              value: false,
                              label: text('List'),
                            ),
                          ],
                          onChanged: (next) {
                            setState(() {
                              preferences = preferences.copyWith(grid: next);
                            });
                            preferences.remember();
                          },
                        ),
                    ],
                  ),
                ],
              ),
            ),
          Expanded(child: body(context, compact, available)),
        ],
      ),
    );
  }

  double sortControlWidth(BuildContext context) {
    final base = RaftSpace.x4 * 11;
    final scaled = MediaQuery.textScalerOf(context).scale(base);
    return scaled.clamp(base, MediaQuery.sizeOf(context).width);
  }

  Widget body(BuildContext context, bool compact, bool available) {
    final rows = page?.rows;
    if (available && rows != null && rows.isNotEmpty) {
      return ArtifactDashboardRows(
        rows: rows,
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
