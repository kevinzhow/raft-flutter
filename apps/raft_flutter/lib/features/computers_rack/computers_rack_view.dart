// The Computers page (Web v1.24 features/computer/ComputersRackOverview.tsx,
// ComputersRackList.tsx, ComputersRackToolbar.tsx, ComputersRackCounts.tsx,
// ComputersAttentionSummary.tsx; components/machine/MobileComputersPanel.tsx
// for the phone). Desktop: a full page beside the rail, a computer opens in
// the panel beside it. Phone: the same toolbar and list, narrow; a computer
// opens its own page.
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

import '../../data/workspace_controller.dart';
import '../../data/workspace_entity_directory.dart';
import '../add_computer_dialog.dart';
import '../agent_avatar_projection.dart' show agentRowPresence;
import '../computer_detail_view.dart'
    show computerAvailableVersion, computerDiskLow, computerRunLabel;
import '../computer_readiness_copy.dart';
import '../page_layout.dart';
import '../resource_cards.dart' show resourceRelativeTime;
import '../sender_avatar_projection.dart' show projectSenderAvatar;
import 'computer_attention_seen.dart';
import 'computers_rack_actions.dart';
import 'computers_rack_glyphs.dart';
import 'rack_move_dialog.dart';
import 'computers_rack_model.dart';
import 'computers_rack_preferences.dart';

class ComputersRackView extends StatefulWidget {
  const ComputersRackView({
    super.key,
    required this.controller,
    required this.onOpenComputer,
    this.phone = false,
    this.selectedId,
    this.onBack,
    this.now,
  });
  final WorkspaceController controller;
  final ValueChanged<Map<String, dynamic>> onOpenComputer;
  final bool phone;
  final String? selectedId;
  final VoidCallback? onBack;
  final DateTime Function()? now;

  @override
  State<ComputersRackView> createState() => _ComputersRackViewState();
}

class _ComputersRackViewState extends State<ComputersRackView> {
  WorkspaceController get w => widget.controller;
  WorkspaceEntityDirectory get directory => w.services.entityDirectory;
  final prefs = ComputersRackPreferences.instance;

  /// The agent being dragged (a valid drop target lights up while it is).
  Map<String, dynamic>? dragAgent;
  Map<String, Map<String, dynamic>> _machineById = const {};
  late final search = TextEditingController(text: prefs.query);

  /// Folded groups and the Offline section's choice, on this server only.
  String? foldScope;
  Set<String> folded = {};
  ({String scope, bool open})? offlineChoice;

  @override
  void initState() {
    super.initState();
    _bind(w);
    prefs.addListener(_changed);
  }

  void _bind(WorkspaceController c) {
    c.addListener(_changed);
    c.services.entityDirectory.addListener(_changed);
    if (c.server != null && c.client.user != null) {
      c.services.entityDirectory.ensure([
        WorkspaceEntityKind.computers,
        WorkspaceEntityKind.agents,
      ], retryFailed: true);
    }
  }

  void _unbind(WorkspaceController c) {
    c.removeListener(_changed);
    c.services.entityDirectory.removeListener(_changed);
  }

  @override
  void didUpdateWidget(ComputersRackView old) {
    super.didUpdateWidget(old);
    if (!identical(old.controller, w)) {
      _unbind(old.controller);
      _bind(w);
    }
  }

  @override
  void dispose() {
    _unbind(w);
    prefs.removeListener(_changed);
    search.dispose();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  String tr(String s) => raftText(context, s);
  String fmt(String s, Map<String, Object?> v) => raftFormat(context, s, v);

  Future<void> retry() =>
      directory.refresh(WorkspaceEntityKind.computers, force: true);

  List<Map<String, dynamic>> get agents => [
    for (final a in directory.rows(WorkspaceEntityKind.agents))
      if (a['deletedAt'] == null) a,
  ];

  @override
  Widget build(BuildContext context) {
    final serverId = w.server?.id;
    final userId = w.client.user?.id;
    prefs.adoptServer(serverId);
    if (search.text != prefs.query) search.text = prefs.query;
    if (foldScope != serverId) {
      foldScope = serverId;
      folded = {};
    }
    final machines = orderRackMachines(
      serverId == null || userId == null
          ? const []
          : directory.rows(WorkspaceEntityKind.computers),
      userId,
    );
    _machineById = {for (final m in machines) '${m['id']}': m};
    final state = directory.state(WorkspaceEntityKind.computers);
    final loading = !directory.settled(WorkspaceEntityKind.computers);
    final loaded = state.loaded && !loading;
    final failed = !loading && state.error != null && machines.isEmpty;
    final agentsByMachine = <String, List<Map<String, dynamic>>>{};
    for (final a in agents) {
      final id = a['machineId'];
      if (id is String) (agentsByMachine[id] ??= []).add(a);
    }
    final guest = w.server?.string('role') == 'guest';
    // Open, every current attention pair counts as seen (the rail dot).
    if (loaded) {
      markComputerAttentionSeen(
        userId: userId,
        serverId: serverId,
        guest: guest,
        loaded: true,
        machines: machines,
      );
    }
    final counts = rackCounts(
      machines,
      (m) => agentsByMachine[m['id']]?.length ?? 0,
    );
    final countsText = [
      rackComputerCount(context, counts.computers),
      fmt('{count} online', {'count': counts.online}),
      rackAgentCount(context, counts.agents),
      if (counts.attention != null)
        fmt('{count} need attention', {'count': counts.attention}),
    ].join(' · ');
    final columns = rackRuntimeColumns(machines);
    final options = runtimeFilterOptions(columns);
    final runtimes = effectiveRuntimeFilter(prefs.runtimes, options);
    final sort = effectiveRackSort(prefs.sort, columns);
    // The phone's page header is the workspace shell's (title and Back); the
    // counts Web puts beside the title sit on their own line under it.
    final header = widget.phone
        ? (machines.isEmpty
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.only(
                    left: RaftSpace.x4,
                    right: RaftSpace.x4,
                    top: RaftSpace.x2,
                  ),
                  child: RaftRackCounts(countsText),
                ))
        : RaftPageHeader(
            title: tr('Computers'),
            subtitle: machines.isEmpty ? null : countsText,
            height: raftPageHeaderHeight(context),
            mobile: widget.phone,
            onBack: widget.onBack,
            backKey: const Key('computers-rack-back'),
          );
    final body = failed
        ? RaftEmptyState(
            title: tr("Couldn't load computers"),
            detail: tr('Check your connection and try again.'),
            glyph: RaftGlyph.monitor,
            action: RaftButton(
              key: const ValueKey('computers-rack-retry'),
              label: tr('Retry'),
              glyph: RaftGlyph.refreshCw,
              secondary: true,
              onPressed: retry,
            ),
          )
        : loaded && machines.isEmpty
        ? RaftEmptyState(
            title: tr('No computers yet'),
            detail: tr('Connect a machine to run agents from here.'),
            glyph: RaftGlyph.monitor,
          )
        : _list(
            context,
            machines: machines,
            columns: columns,
            runtimes: runtimes,
            sort: sort,
            loading: loading && machines.isEmpty,
            loaded: loaded,
            agentsByMachine: agentsByMachine,
          );
    return Column(
      key: const ValueKey('computers-rack-overview'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        _toolbar(context, columns, options, runtimes, sort),
        if (!widget.phone) ?_summary(context, machines, loading, loaded),
        if (!loading && state.error != null && machines.isNotEmpty)
          RaftBanner(
            key: const ValueKey('computers-refresh-error'),
            status: RaftBannerRecipeStatus.warning,
            size: RaftBannerRecipeSize.sm,
            description: tr(
              "Couldn't refresh computers. Showing saved results.",
            ),
            action: RaftButton(
              label: tr('Retry'),
              glyph: RaftGlyph.refreshCw,
              secondary: true,
              onPressed: retry,
            ),
          ),
        Expanded(child: body),
      ],
    );
  }

  // ---------------------------------------------------------------- toolbar

  Widget _toolbar(
    BuildContext context,
    RackRuntimeColumns columns,
    List<String> options,
    List<String> runtimes,
    RackSort? sort,
  ) {
    String statusLabel(RackStatusFilter s) => tr(switch (s) {
      RackStatusFilter.all => 'All statuses',
      RackStatusFilter.online => 'Online',
      RackStatusFilter.offline => 'Offline',
      RackStatusFilter.attention => 'Needs attention',
    });
    String runtimeLabel(String r) =>
        r == 'other' ? tr('Other') : rackProviderNames[r] ?? r;
    String groupLabel(RackGroupBy g) => tr(switch (g) {
      RackGroupBy.none => 'No grouping',
      RackGroupBy.provider => 'Provider',
      RackGroupBy.prefix => 'Name prefix',
    });
    String sortLabel(String key) {
      final provider = parseRemainingSortKey(key);
      if (provider != null) {
        return fmt('{runtime} remaining', {
          'runtime': rackProviderNames[provider],
        });
      }
      return tr(switch (key) {
        'name' => 'Name',
        'disk' => 'Disk used',
        'memory' => 'Memory used',
        _ => 'Mine first',
      });
    }

    String directionLabel(String key, RackSortDirection d) {
      final desc = d == RackSortDirection.desc;
      if (key == 'name') return tr(desc ? 'Z to A' : 'A to Z');
      if (parseRemainingSortKey(key) != null) {
        return tr(desc ? 'Most remaining first' : 'Least remaining first');
      }
      return tr(desc ? 'Most used first' : 'Least used first');
    }

    final check = const RaftIcon(RaftGlyph.check, size: 14);
    final status = prefs.status;
    final statusValue = statusLabel(status);
    final runtimeValue = runtimes.isEmpty
        ? tr('Runtime')
        : runtimes.length == 1
        ? runtimeLabel(runtimes.first)
        : '${tr('Runtime')} ${runtimes.length}';
    final filtered =
        prefs.query.trim().isNotEmpty ||
        status != RackStatusFilter.all ||
        runtimes.isNotEmpty;
    final filters = <Widget>[
      RaftDropdownMenu(
        key: const ValueKey('computers-rack-status'),
        label: statusValue,
        tooltip: fmt('{filter}: {value}', {
          'filter': tr('Status'),
          'value': statusValue,
        }),
        glyph: rackGlyphCircleDot,
        trailingGlyph: RaftGlyph.chevronDown,
        triggerStyle: RaftDropdownTriggerStyle.picker,
        minimumTargetSize: RaftMetrics.buttonSm,
        selected: status != RackStatusFilter.all,
        entries: [
          for (final s in RackStatusFilter.values)
            RaftMenuEntry(
              label: statusLabel(s),
              trailing: s == status ? check : null,
              onPressed: () => prefs.setStatus(s),
            ),
        ],
      ),
      if (options.isNotEmpty)
        RaftDropdownMenu(
          key: const ValueKey('computers-rack-runtime'),
          label: runtimeValue,
          tooltip: fmt('{filter}: {value}', {
            'filter': tr('Runtime'),
            'value': runtimes.isEmpty
                ? tr('All')
                : runtimes.map(runtimeLabel).join(', '),
          }),
          glyph: rackGlyphCpu,
          trailingGlyph: RaftGlyph.chevronDown,
          triggerStyle: RaftDropdownTriggerStyle.picker,
          minimumTargetSize: RaftMetrics.buttonSm,
          selected: runtimes.isNotEmpty,
          entries: [
            for (final r in options)
              RaftMenuEntry(
                label: runtimeLabel(r),
                trailing: runtimes.contains(r) ? check : null,
                onPressed: () => prefs.toggleRuntime(r),
              ),
          ],
        ),
      if (filtered)
        RaftButton(
          key: const ValueKey('computers-rack-clear'),
          label: tr('Clear all'),
          tone: RaftButtonRecipeVariant.ghost,
          size: RaftButtonRecipeSize.sm,
          onPressed: prefs.clearFilters,
        ),
    ];
    final sortChoice = sort?.key ?? 'default';
    final display = <Widget>[
      RaftDropdownMenu(
        key: const ValueKey('computers-rack-group'),
        label: groupLabel(prefs.groupBy),
        tooltip: fmt('Group: {group}', {'group': groupLabel(prefs.groupBy)}),
        glyph: rackGlyphRows3,
        trailingGlyph: RaftGlyph.chevronDown,
        triggerStyle: RaftDropdownTriggerStyle.picker,
        minimumTargetSize: RaftMetrics.buttonSm,
        selected: prefs.groupBy != RackGroupBy.none,
        entries: [
          for (final g in RackGroupBy.values)
            RaftMenuEntry(
              label: groupLabel(g),
              trailing: g == prefs.groupBy ? check : null,
              onPressed: () => prefs.setGroupBy(g),
            ),
        ],
      ),
      RaftDropdownMenu(
        key: const ValueKey('computers-rack-sort'),
        label: sortLabel(sortChoice),
        tooltip: fmt('Sort: {sort}', {'sort': sortLabel(sortChoice)}),
        glyph: RaftGlyph.arrowDownUp,
        trailingGlyph: RaftGlyph.chevronDown,
        triggerStyle: RaftDropdownTriggerStyle.picker,
        minimumTargetSize: RaftMetrics.buttonSm,
        selected: sort != null,
        entries: [
          for (final (i, section) in sortMenuSections(columns).indexed) ...[
            if (i > 0) const RaftMenuEntry.separator(),
            for (final key in section)
              RaftMenuEntry(
                label: sortLabel(key),
                trailing: key == sortChoice ? check : null,
                onPressed: () => prefs.setSort(chooseRackSortKey(key)),
              ),
          ],
          if (sort != null) ...[
            const RaftMenuEntry.separator(),
            for (final d
                in sort.key == 'name'
                    ? const [RackSortDirection.asc, RackSortDirection.desc]
                    : const [RackSortDirection.desc, RackSortDirection.asc])
              RaftMenuEntry(
                label: directionLabel(sort.key, d),
                trailing: d == sort.direction ? check : null,
                onPressed: () => prefs.setSort(RackSort(sort.key, d)),
              ),
          ],
        ],
      ),
      RaftSegmentedControl<RackView>(
        key: const ValueKey('computers-rack-view'),
        label: tr('Computers view'),
        value: prefs.view,
        onChanged: prefs.setView,
        items: [
          RaftSegmentedOption(
            value: RackView.cards,
            label: tr('Cards'),
            glyph: RaftGlyph.layoutGrid,
            itemKey: const ValueKey('computers-rack-view-cards'),
          ),
          RaftSegmentedOption(
            value: RackView.list,
            label: tr('List'),
            glyph: RaftGlyph.layoutList,
            itemKey: const ValueKey('computers-rack-view-list'),
          ),
        ],
      ),
    ];
    return RaftRackToolbar(
      search: RaftInputGroup(
        key: const ValueKey('computers-rack-search'),
        controller: search,
        leading: const RaftInputGroupAddon.icon(RaftGlyph.search),
        hintText: tr('Search computers'),
        semanticLabel: tr('Search computers by name, hostname or owner'),
        onChanged: prefs.setQuery,
        clearLabel: tr('Clear all'),
        onClear: prefs.query.isEmpty ? null : () => prefs.setQuery(''),
      ),
      filters: filters,
      display: display,
      add: w.can('registerMachines')
          ? RaftButton(
              key: const ValueKey('computers-rack-add'),
              label: tr('Add computer'),
              glyph: RaftGlyph.plus,
              onPressed: () => showAddComputerDialog(
                context,
                w,
                onOpenComputer: (id) {
                  final row = directory
                      .rows(WorkspaceEntityKind.computers)
                      .where((m) => m['id'] == id)
                      .firstOrNull;
                  if (row != null) widget.onOpenComputer(row);
                },
              ),
            )
          : null,
    );
  }

  // ---------------------------------------------------------------- summary

  /// ComputersAttentionSummary: what needs a person and what is waiting,
  /// from the server's per-Computer summary; nothing from an older server.
  Widget? _summary(
    BuildContext context,
    List<RackMachine> machines,
    bool loading,
    bool loaded,
  ) {
    final userId = w.client.user?.id, serverId = w.server?.id;
    final summarized = [
      for (final m in machines)
        if (m['attention'] is Map) m,
    ];
    final flagged = [
      for (final m in summarized)
        if (serverNeedsAttention(m) == true) m,
    ];
    var waitingAgents = 0;
    int? waitingUntil;
    for (final m in summarized) {
      final a = m['attention'] as Map;
      final waiting = a['waitingAgents'];
      if (waiting is num) waitingAgents += waiting.toInt();
      final until = a['waitingUntil'];
      if (until is num && (waitingUntil == null || until < waitingUntil)) {
        waitingUntil = until.toInt();
      }
    }
    if (loaded) {
      ComputersRackRemembered.write(
        userId,
        serverId,
        'attentionLines',
        (flagged.isNotEmpty ? 1 : 0) + (waitingAgents > 0 ? 1 : 0),
      );
    }
    if (loading) {
      final lines = ComputersRackRemembered.read(
        userId,
        serverId,
        'attentionLines',
      );
      return lines == null || lines == 0
          ? null
          : RaftRackAttentionSummarySkeleton(lines: lines);
    }
    if (summarized.isEmpty || (flagged.isEmpty && waitingAgents == 0)) {
      return null;
    }
    void showAttention() => prefs.setStatus(RackStatusFilter.attention);
    List<Widget>? attentionLine;
    final items = flagged.length == 1 && flagged.first['attention'] is Map
        ? (flagged.first['attention'] as Map)['items']
        : null;
    if (items is List && items.length == 1 && items.first is Map) {
      final machine = flagged.first;
      final item = items.first as Map;
      final (:title, :who) = formatAttentionItem(context, item);
      final agentCount = item['agentCount'] is num
          ? (item['agentCount'] as num).toInt()
          : 0;
      attentionLine = [
        RaftTextLink(
          key: const ValueKey('computers-attention-filter'),
          label: fmt('{title} on {computer}', {
            'title': title,
            'computer': machine['name'],
          }),
          onPressed: showAttention,
        ),
        if (agentCount > 0)
          Text(
            item['code'] != null
                ? rackAgentCount(context, agentCount)
                : fmt(
                    agentCount == 1
                        ? "{count} agent can't run"
                        : "{count} agents can't run",
                    {'count': agentCount},
                  ),
          ),
        if (item['code'] != null)
          RaftTextLink(
            key: const ValueKey('computers-attention-action'),
            label: readinessDoLabel(context, item['action']),
            onPressed: () => widget.onOpenComputer(machine),
          )
        else if (who != null)
          Text(who),
      ];
    } else if (flagged.isNotEmpty) {
      attentionLine = [
        RaftTextLink(
          key: const ValueKey('computers-attention-filter'),
          label: fmt(
            flagged.length == 1
                ? '{count} computer needs attention'
                : '{count} computers need attention',
            {'count': flagged.length},
          ),
          onPressed: showAttention,
        ),
      ];
    }
    final now = (widget.now?.call() ?? DateTime.now()).millisecondsSinceEpoch;
    final backIn = formatWaitBackIn(context, waitingUntil, now);
    return RaftRackAttentionSummary(
      lines: [
        ?attentionLine,
        if (waitingAgents > 0)
          [
            Text(
              fmt(
                waitingAgents == 1
                    ? '{count} agent waiting'
                    : '{count} agents waiting',
                {'count': waitingAgents},
              ),
              key: const ValueKey('computers-waiting-line'),
            ),
            if (backIn != null) Text(backIn),
          ],
      ],
    );
  }

  // ---------------------------------------------------------------- list

  Widget _list(
    BuildContext context, {
    required List<RackMachine> machines,
    required RackRuntimeColumns columns,
    required List<String> runtimes,
    required RackSort? sort,
    required bool loading,
    required bool loaded,
    required Map<String, List<Map<String, dynamic>>> agentsByMachine,
  }) {
    final view = prefs.view;
    final layout = view == RackView.cards
        ? RaftRackLayout.card
        : widget.phone
        ? RaftRackLayout.phone
        : RaftRackLayout.list;
    final userId = w.client.user?.id, serverId = w.server?.id;
    if (loading) {
      final count =
          ComputersRackRemembered.read(userId, serverId, 'rows') ??
          ComputersRackRemembered.fallbackRows;
      return _scroll(layout, [
        for (var i = 0; i < count; i++) RaftRackRowSkeleton(layout: layout),
      ]);
    }
    final filtered = filterRackMachines(
      machines,
      query: prefs.query,
      status: prefs.status,
      runtimes: runtimes,
    );
    final sorted = sort == null ? filtered : sortRackMachines(filtered, sort);
    if (machines.isNotEmpty && sorted.isEmpty) {
      return RaftEmptyState(
        key: const ValueKey('computers-rack-empty-filters'),
        title: tr('No computers match'),
        detail: tr('Try another search, or clear the filters.'),
        glyph: rackGlyphSearchX,
        action: RaftButton(
          key: const ValueKey('computers-rack-empty-clear'),
          label: tr('Clear all'),
          secondary: true,
          onPressed: prefs.clearFilters,
        ),
      );
    }
    // Offline computers wait in one folded section at the end (open when
    // nothing else is online); with Status: Offline they are the list.
    final offlineSection = prefs.status != RackStatusFilter.offline;
    final online = [
      for (final m in sorted)
        if (!offlineSection || m['status'] == 'online') m,
    ];
    final offline = [
      for (final m in sorted)
        if (offlineSection && m['status'] != 'online') m,
    ];
    final offlineDefaultOpen = online.isEmpty;
    final offlineScope = '${serverId ?? ''}\u0000$offlineDefaultOpen';
    final offlineOpen = offlineChoice?.scope == offlineScope
        ? offlineChoice!.open
        : offlineDefaultOpen;
    final grouped = prefs.groupBy != RackGroupBy.none;
    final rankOf = {for (final (i, m) in online.indexed) m['id']: i};
    final groups = groupRackMachines(
      online,
      prefs.groupBy,
      personalLabel: tr('Personal computers'),
      otherLabel: tr('Other'),
      rank: sort != null && sort.key != 'name'
          ? (m) => rackSortValue(m, sort.key, null) == null
                ? null
                : rankOf[m['id']]
          : sort == null
          ? (m) => rackMachineTier(m, userId) == 2 ? null : 1
          : null,
    );
    // Remembered from the list as it opens (no search, filter or fold).
    final opensAsDrawn =
        prefs.status == RackStatusFilter.all &&
        runtimes.isEmpty &&
        prefs.query.trim().isEmpty &&
        folded.isEmpty &&
        offlineOpen == offlineDefaultOpen;
    if (loaded && opensAsDrawn) {
      ComputersRackRemembered.write(
        userId,
        serverId,
        'rows',
        online.length + (offlineOpen ? offline.length : 0),
      );
    }
    Widget row(RackMachine m) => _row(context, m, layout, agentsByMachine);
    Widget title(
      String key,
      String text,
      int count,
      bool collapsed,
      VoidCallback toggle,
    ) => RaftRackGroupTitle(
      key: ValueKey('rack-group-$key'),
      title: text,
      counts: rackComputerCount(context, count),
      collapsed: collapsed,
      cards: layout == RaftRackLayout.card,
      semanticLabel: fmt(
        collapsed ? 'Expand {group}, {count}' : 'Collapse {group}, {count}',
        {'group': text, 'count': rackComputerCount(context, count)},
      ),
      onToggle: toggle,
    );
    final children = <Widget>[
      if (grouped)
        for (final g in groups) ...[
          title(g.key, g.title, g.machines.length, folded.contains(g.key), () {
            setState(() {
              folded = {...folded};
              if (!folded.remove(g.key)) folded.add(g.key);
            });
          }),
          if (!folded.contains(g.key)) ...g.machines.map(row),
        ]
      else
        ...online.map(row),
      if (offline.isNotEmpty) ...[
        title('offline', tr('Offline'), offline.length, !offlineOpen, () {
          setState(
            () => offlineChoice = (scope: offlineScope, open: !offlineOpen),
          );
        }),
        if (offlineOpen) ...offline.map(row),
      ],
    ];
    return _scroll(
      layout,
      children,
      header: layout == RaftRackLayout.list
          ? RaftRackListHeader(
              computerLabel: tr('Computer'),
              agentsLabel: tr('Agents'),
              diskLabel: tr('Disk'),
              memoryLabel: tr('Memory'),
              sortedKey: sort?.key,
              descending: sort?.direction == RackSortDirection.desc,
              onSort: (key) {
                final current = prefs.sort;
                prefs.setSort(
                  current?.key == key
                      ? RackSort(
                          key,
                          current!.direction == RackSortDirection.asc
                              ? RackSortDirection.desc
                              : RackSortDirection.asc,
                        )
                      : chooseRackSortKey(key),
                );
              },
            )
          : null,
    );
  }

  /// The page's one scroller. Cards go in rows of at least 250px; group
  /// titles span the row. The desktop list scrolls sideways rather than
  /// squeezing its fixed columns.
  Widget _scroll(
    RaftRackLayout layout,
    List<Widget> children, {
    Widget? header,
  }) => RaftRackScroller(
    key: const ValueKey('computers-rack'),
    layout: layout,
    header: header,
    children: children,
  );

  Widget _row(
    BuildContext context,
    RackMachine m,
    RaftRackLayout layout,
    Map<String, List<Map<String, dynamic>>> agentsByMachine,
  ) {
    final id = '${m['id']}';
    final on = agentsByMachine[id] ?? const <Map<String, dynamic>>[];
    final latest = directory.latestComputerVersion;
    final available = computerAvailableVersion(m, latest);
    final reconnect = directory.upgradeReconnect(m);
    final offline = m['status'] != 'online';
    final belowFloor = m['isComputer'] == true && m['versionGate'] is Map;
    final attention = m['attention'] is Map
        ? (m['attention'] as Map)['count']
        : null;
    final dot = reconnect.reconnecting
        ? RaftRackDot.upgrading
        : (attention is num && attention > 0) || available != null || belowFloor
        ? RaftRackDot.upgrade
        : offline
        ? RaftRackDot.offline
        : RaftRackDot.online;
    final dotLabel = attention is num && attention > 0
        ? attentionItemLines(context, m['attention']).join('; ')
        : reconnect.reconnecting
        ? tr('Updating…')
        : available != null
        ? fmt(
            offline
                ? 'Update available: v{version} · Offline'
                : 'Update available: v{version}',
            {'version': available},
          )
        : tr(offline ? 'Offline' : 'Online');
    final String facts;
    if (offline) {
      final seen = m['lastHeartbeat'];
      final iso = seen is num
          ? DateTime.fromMillisecondsSinceEpoch(seen.toInt()).toIso8601String()
          : seen is String
          ? seen
          : null;
      final when = iso == null
          ? ''
          : resourceRelativeTime(
              iso,
              now: widget.now?.call(),
              chinese:
                  Localizations.maybeLocaleOf(context)?.languageCode == 'zh',
            );
      facts = when.isEmpty
          ? tr('Offline')
          : '${tr('Offline')} · ${fmt('last seen {time}', {'time': when})}';
    } else {
      final version = m['computerVersion'];
      final versionText =
          m['isComputer'] == true && version is String && version.isNotEmpty
          ? fmt('v{version}', {'version': version})
          : tr(computerRunLabel(m).$1);
      final os = rackOsName(m);
      facts = os == null ? versionText : '$os · $versionText';
    }
    final owner = m['ownerUserId'] != null ? m['owner'] : null;
    final ownerName = owner is Map
        ? ('${owner['displayName'] ?? ''}'.isNotEmpty
              ? '${owner['displayName']}'
              : '${owner['name'] ?? ''}')
        : null;
    final disk = computerDiskLow(m);
    final diskStatus = liveResourceStatus(m, 'diskStatus');
    final memoryStatus = liveResourceStatus(m, 'memoryStatus');
    RaftRackMeter meter(String label, Map? status, {bool warn = false}) {
      final used = rackUsedRatio(status);
      return RaftRackMeter(
        label: label,
        used: used,
        warn: warn,
        text: used == null
            ? '—'
            : fmt('{percent}% used', {'percent': (used * 100).round()}),
      );
    }

    final canManage = canManageComputer(w, m);
    final step = rackNextStep(
      w,
      m,
      canManage: canManage,
      availableVersion: belowFloor ? null : available,
    );
    final computer = RaftRackComputer(
      id: id,
      name: '${m['name'] ?? ''}',
      dot: dot,
      glyph: rackDeviceGlyph(m),
      dotLabel: dotLabel,
      offline: offline,
      facts: facts,
      availableVersion: !belowFloor && available != null
          ? '→ v$available'
          : null,
      factNote: belowFloor ? tr('Update required') : null,
      owner: ownerName == null
          ? tr('Public (no owner)')
          : fmt('Owner: {name}', {'name': ownerName}),
      diskLowLabel: disk == null ? null : tr('Low disk'),
      diskLowTitle: disk == null
          ? null
          : fmt('{free} free of {total}', {'free': disk.$1, 'total': disk.$2}),
      disk: meter(tr('Disk'), diskStatus, warn: disk != null),
      memory: meter(tr('Memory'), memoryStatus),
      agentCount: on.length,
      agents: [for (final a in on) _slot(a)],
      otherRuntimes: [
        for (final r in rackOtherRuntimes(m, rackRuntimeColumns([m]).other))
          rackRuntimeDisplayName(r),
      ],
      selected: widget.selectedId == id,
    );
    final row = RaftRackRow(
      computer: computer,
      layout: layout,
      onOpen: () => widget.onOpenComputer(m),
      noAgentsLabel: tr('No agents on this computer yet'),
      otherRuntimesLabel: tr('Other runtimes'),
      action: step == null
          ? null
          : RackRowAction(
              step: step,
              desktop: !widget.phone,
              machineId: id,
              onOpenComputer: () => widget.onOpenComputer(m),
              onUpgrade: () {
                final s = step;
                if (s is RackOneClick) {
                  unawaited(
                    confirmComputerUpgrade(
                      context,
                      w,
                      m,
                      version: s.version,
                      agentCount: on.length,
                    ),
                  );
                }
              },
            ),
      menu: layout == RaftRackLayout.phone
          ? null
          : RackRowMenu(
              controller: w,
              machine: m,
              agents: on,
              canManage: canManage,
              upgrading: step is RackUpgrading,
            ),
    );
    // The keys the Computers list has always been reached by (the phone list's
    // and the desktop directory's); on desktop the row also takes a dragged agent.
    final key = ValueKey(
      widget.phone ? 'fleet-$id' : 'desktop-directory-computer-$id',
    );
    if (widget.phone) return KeyedSubtree(key: key, child: row);
    return KeyedSubtree(
      key: key,
      child: RaftRackDropTarget<Map<String, dynamic>>(
        accepts: (agent) => isRackDropTarget(m, agent),
        onDrop: (agent) {
          setState(() => dragAgent = null);
          unawaited(
            showRackMoveDialog(
              context,
              w,
              agent: agent,
              targetId: '${m['id']}',
            ),
          );
        },
        child: row,
      ),
    );
  }

  /// AgentRackSlot: the agent's avatar with its light.
  Widget _slot(Map<String, dynamic> a) {
    final id = '${a['id']}';
    final display = '${a['displayName'] ?? ''}';
    final name = display.isNotEmpty ? display : '${a['name'] ?? ''}';
    final avatar = projectSenderAvatar(
      origin: w.client.origin,
      senderId: id,
      senderType: 'agent',
      agents: [a],
      members: const [],
      currentUser: w.client.user?.json,
    );
    final slot = RaftTooltip(
      message: name,
      child: RaftAvatar(
        key: ValueKey('rack-slot-$id'),
        name: name,
        presence: agentRowPresence(a),
        mountedContext: RaftMountedAvatarContext.compactList,
        kind: RaftAvatarKind.agent,
        content: RaftAvatarContent(
          name: name,
          kind: RaftAvatarContentKind.agent,
          uploadedUrl: avatar.uploadedUrl,
          pixelKey: avatar.pixelKey,
          fallback: const RaftMountedAvatarFallback(
            avatarContext: RaftMountedAvatarContext.compactList,
            identity: RaftMountedAvatarIdentity.agent,
          ),
        ),
      ),
    );
    if (widget.phone || !canDragRackAgent(w, a, _machineById)) return slot;
    // Web AgentRackSlot `draggable`: desktop only, for agents the viewer manages.
    return Draggable<Map<String, dynamic>>(
      data: a,
      onDragStarted: () => setState(() => dragAgent = a),
      onDragEnd: (_) {
        if (mounted) setState(() => dragAgent = null);
      },
      onDraggableCanceled: (_, _) {
        if (mounted) setState(() => dragAgent = null);
      },
      feedback: Opacity(opacity: .8, child: slot),
      child: slot,
    );
  }
}

/// utils/computerDevice.ts computerOsName: the Linux release, or macOS /
/// Windows, which report none.
String? rackOsName(Map m) {
  final release = '${m['osRelease'] ?? ''}'.trim();
  if (release.isNotEmpty) return release;
  final platform = '${m['os'] ?? ''}'.trim().toLowerCase();
  if (platform.startsWith('darwin')) return 'macOS';
  if (platform.startsWith('win')) return 'Windows';
  return null;
}

/// The device glyph for a computer (Web ComputerDeviceIcon).
RaftGlyph rackDeviceGlyph(Map m) => switch (computerDeviceShape(m)) {
  'laptop' => RaftGlyph.laptop,
  'server' => RaftGlyph.server,
  'cloud' => RaftGlyph.cloud,
  _ => RaftGlyph.monitor,
};
