import 'dart:async';

import 'package:flutter/material.dart' show RawScrollbar;
import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/device_preferences.dart';
import '../data/machine_order.dart';
import '../data/workspace_controller.dart';
import 'agent_metadata_projection.dart' show agentRowAmbientDisplay;
import 'agent_profile_rules.dart';
import 'agent_token_usage_pane.dart';
import 'desktop_navigation_policy.dart';
import 'icu_message.dart';
import 'management_support.dart' show pageIdentity;
import 'members_page_entries.dart';
import 'pushed_server_page.dart' show pushedServerPageBackKey;

enum _Scope {
  all('All'),
  human('Humans'),
  agent('Agents');

  const _Scope(this.label);
  final String label;
}

enum _Grouping {
  none('No grouping'),
  creator('By creator'),
  computer('By computer');

  const _Grouping(this.label);
  final String label;

  static const storageKey = 'raft_members_agents_grouping';

  static _Grouping read() {
    final value = DevicePreferences.current?.get(storageKey);
    return values.firstWhere(
      (choice) => choice.name == value,
      orElse: () => none,
    );
  }
}

class MembersPage extends StatefulWidget {
  const MembersPage({
    super.key,
    required this.workspace,
    required this.humans,
    required this.agents,
    required this.computers,
    required this.showHumans,
    required this.loading,
    required this.failed,
    required this.mobile,
    required this.onRefresh,
    required this.onInvite,
    required this.onCreate,
    required this.onConnect,
    required this.buildEntry,
    required this.onOpenAgent,
    this.onBack,
  });

  final WorkspaceController workspace;
  final List<Map<String, dynamic>> humans, agents, computers;
  final bool showHumans, loading, failed, mobile;
  final Future<void> Function() onRefresh;
  final VoidCallback? onBack, onInvite, onCreate, onConnect;
  final ValueChanged<String> onOpenAgent;
  final Widget Function(
    MemberPageEntry entry,
    MembersEntryLayout layout,
    String? computerName, {
    bool showComputer,
    bool runtimeLine,
  })
  buildEntry;

  @override
  State<MembersPage> createState() => _MembersPageState();
}

class _MembersPageState extends State<MembersPage>
    with AgentUsageFlag<MembersPage> {
  _Scope _scope = _Scope.all;
  _Grouping _grouping = _Grouping.read();
  bool _usage = false;
  String _query = '';
  final _rosterScroll = ScrollController();
  late List<MemberPageEntry> humans, agents;
  late Map<Object?, Map<String, dynamic>> computers;
  _Grouping get grouping => !widget.showHumans && _grouping == _Grouping.creator
      ? _Grouping.computer
      : _grouping;

  @override
  WorkspaceController get usageWorkspace => widget.workspace;
  @override
  bool get mayReadUsage =>
      !widget.mobile &&
      agents.any(
        (agent) => canViewAgentPrivateSurfaces(
          agent.record,
          usageWorkspace.client.user?.id,
          usageWorkspace.can('editAgents'),
        ),
      );

  @override
  void initState() {
    super.initState();
    _project();
  }

  @override
  void dispose() {
    _rosterScroll.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(MembersPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.humans, widget.humans) ||
        !identical(oldWidget.agents, widget.agents) ||
        !identical(oldWidget.computers, widget.computers)) {
      _project();
    } else {
      checkUsageFlag();
    }
  }

  void _project() {
    final role = widget.workspace.server?.string('role');
    humans = memberPageEntries(widget.humans, DesktopContentKind.human)
        .where(
          (entry) => entry.record['role'] == 'guest'
              ? role == 'admin' || role == 'owner'
              : widget.showHumans,
        )
        .toList();
    agents = memberPageEntries(
      widget.agents,
      DesktopContentKind.agent,
    ).where((entry) => entry.record['deletedAt'] == null).toList();
    computers = {for (final row in widget.computers) row['id']: row};
    checkUsageFlag();
  }

  int count(_Scope scope) => switch (scope) {
    _Scope.human => humans.length,
    _Scope.agent => agents.length,
    _Scope.all => humans.length + agents.length,
  };

  void _setGrouping(_Grouping value) {
    setState(() => _grouping = value);
    unawaited(
      DevicePreferences.current?.setString(_Grouping.storageKey, value.name),
    );
  }

  Widget _toolbar(
    BuildContext context,
    _Scope scope,
    List<_Scope> scopes,
    bool showUsage,
    double segmentHeight,
    RaftFitItem? usageFilter,
    Widget? usageRange,
    List<RaftMenuEntry> usagePeriods,
  ) {
    final scopeOptions = [
      for (final value in scopes)
        RaftSegmentedOption(
          value: value,
          label: raftText(context, value.label),
          count: widget.loading ? null : '${count(value)}',
          itemKey: ValueKey('members-tab-${value.name}'),
        ),
    ];
    final groupChoices = [
      for (final value in _Grouping.values)
        if (value != _Grouping.creator || widget.showHumans)
          RaftSelectItem(value: value, label: raftText(context, value.label)),
    ];
    final canSwitch = scope == _Scope.agent && usageEnabled;
    final search = raftText(context, 'Search members');
    return RaftFitToolbar(
      wrap: showUsage,
      semanticLabel: raftText(context, 'Members'),
      children: [
        RaftFitGroup(
          firstLine: true,
          collapseOrder: 50,
          collapsed: RaftFitSelect(
            key: const ValueKey('members-scope-select'),
            label: raftText(context, scope.label),
            selection: scope,
            items: [
              for (final item in scopeOptions)
                RaftSelectItem(value: item.value, label: item.label),
            ],
            onChanged: (value) => setState(() => _scope = value),
          ),
          items: [
            RaftFitChild(
              child: RaftSegmentedControl(
                key: const ValueKey('members-tabs'),
                inFitToolbar: true,
                visualHeight: segmentHeight,
                value: scope,
                items: scopeOptions,
                onChanged: (value) => setState(() => _scope = value),
              ),
            ),
          ],
        ),
        RaftFitSearch(
          semanticLabel: search,
          hintText: search,
          fieldKey: const ValueKey('members-search'),
          collapseOrder: 70,
          onChanged: (value) => setState(() => _query = value.trim()),
        ),
        if (usageFilter != null)
          RaftFitGroup(wrapOrder: 30, scroll: true, items: [usageFilter]),
        RaftFitGroup(
          firstLine: showUsage,
          moreOrder: 60,
          moreItem: [
            if (canSwitch) ...[
              RaftMenuEntry.heading(raftText(context, 'View as')),
              for (final (label, value) in [
                ('Details', false),
                ('Usage', true),
              ])
                RaftMenuEntry(
                  label: raftText(context, label),
                  checked: showUsage == value,
                  onPressed: () => setState(() => _usage = value),
                ),
              const RaftMenuEntry.separator(),
            ],
            if (usagePeriods.isNotEmpty) ...[
              RaftMenuEntry.heading(raftText(context, 'Time range')),
              ...usagePeriods,
              const RaftMenuEntry.separator(),
            ],
            if (scope == _Scope.agent) ...[
              RaftMenuEntry.heading(raftText(context, 'Group')),
              for (final choice in groupChoices)
                RaftMenuEntry(
                  label: choice.label,
                  checked: grouping == choice.value,
                  onPressed: () => _setGrouping(choice.value),
                ),
              if (widget.onInvite != null) const RaftMenuEntry.separator(),
            ],
            if (widget.onInvite != null)
              RaftMenuEntry(
                label: raftText(context, 'Invite human'),
                glyph: RaftGlyph.userPlus,
                onPressed: widget.onInvite,
              ),
          ],
          items: [
            if (canSwitch)
              RaftFitChild(
                child: RaftSegmentedControl<bool>(
                  label: raftText(context, 'Agents view'),
                  iconsOnly: true,
                  inFitToolbar: true,
                  visualHeight: segmentHeight,
                  value: showUsage,
                  items: [
                    RaftSegmentedOption(
                      value: false,
                      label: raftText(context, 'Details'),
                      glyph: RaftGlyph.tableProperties,
                      itemKey: const ValueKey('members-view-details'),
                    ),
                    RaftSegmentedOption(
                      value: true,
                      label: raftText(context, 'Usage'),
                      glyph: RaftGlyph.chartColumn,
                      itemKey: const ValueKey('members-view-usage'),
                    ),
                  ],
                  onChanged: (value) => setState(() => _usage = value),
                ),
              ),
            if (usageRange != null) RaftFitChild(child: usageRange),
            if (scope == _Scope.agent)
              RaftFitSelect(
                key: const ValueKey('members-group-select'),
                label: raftText(context, grouping.label),
                glyph: RaftGlyph.tableProperties,
                labelOrder: 10,
                applied: grouping != _Grouping.none,
                selection: grouping,
                items: groupChoices,
                onChanged: _setGrouping,
              ),
            if (widget.onInvite != null)
              RaftFitButton(
                key: const ValueKey('desktop-directory-invite-human'),
                label: raftText(context, 'Invite human'),
                glyph: RaftGlyph.userPlus,
                variant: RaftButtonVariant.standard,
                labelOrder: 35,
                onPressed: widget.onInvite,
              ),
          ],
        ),
        RaftFitGroup(
          firstLine: true,
          items: [
            const RaftFitMore(
              key: ValueKey('members-toolbar-more'),
              kind: RaftMenuKind.dropdownMenu,
              width: 240,
            ),
            if (widget.onCreate != null && widget.onConnect != null)
              RaftFitSplitButton(
                mainKey: const ValueKey('desktop-directory-add-agent'),
                menuKey: const ValueKey('members-add-agent-options'),
                label: raftText(context, 'Create agent'),
                menuLabel: raftText(context, 'More ways to add an agent'),
                glyph: RaftGlyph.bot,
                plusOrder: 40,
                onPressed: widget.onCreate!,
                entries: [
                  RaftMenuEntry(
                    label: raftText(context, 'Connect an external agent'),
                    glyph: RaftGlyph.plug,
                    onPressed: widget.onConnect,
                  ),
                ],
              )
            else if (widget.onCreate != null)
              RaftFitButton(
                key: const ValueKey('desktop-directory-add-agent'),
                label: raftText(context, 'Create agent'),
                glyph: RaftGlyph.bot,
                collapsedGlyph: RaftGlyph.plus,
                variant: RaftButtonVariant.primary,
                labelOrder: 45,
                onPressed: widget.onCreate,
              )
            else if (widget.onConnect != null)
              RaftFitButton(
                key: const ValueKey('members-add-agent-options'),
                label: raftText(context, 'More ways to add an agent'),
                glyph: RaftGlyph.chevronDown,
                labelOrder: 1,
                menuEntries: [
                  RaftMenuEntry(
                    label: raftText(context, 'Connect an external agent'),
                    onPressed: widget.onConnect,
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final scope = !widget.showHumans && _scope == _Scope.human
          ? _Scope.all
          : _scope;
      final showUsage = scope == _Scope.agent && usageEnabled && _usage;
      final tokens = RaftTokens.of(context);
      final desktopToolbar =
          raftBreakpointWidth(context) >= RaftLayoutMetrics.desktopBreakpoint &&
          RaftInteraction.of(context).pointer;
      final toolbarAir = desktopToolbar
          ? RaftDesktopMetrics.headerAir
          : RaftSpace.x2;
      final scopes = [
        _Scope.all,
        if (widget.showHumans) _Scope.human,
        _Scope.agent,
      ];
      final layout = widget.mobile
          ? MembersEntryLayout.list
          : scope == _Scope.agent
          ? MembersEntryLayout.table
          : MembersEntryLayout.cards;
      Widget controls(
        RaftFitItem? usageFilter,
        Widget? usageRange,
        List<RaftMenuEntry> usagePeriods,
      ) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: tokens.ui.lineSeam)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: RaftSpace.x5)
                  .copyWith(
                    top: toolbarAir,
                    bottom: desktopToolbar
                        ? toolbarAir - RaftSpace.hairline
                        : toolbarAir,
                  ),
              child: _toolbar(
                context,
                scope,
                scopes,
                showUsage,
                desktopToolbar ? RaftDesktopMetrics.controlHeight : 32,
                usageFilter,
                usageRange,
                usagePeriods,
              ),
            ),
          ),
          if (widget.failed)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: RaftSpace.x5)
                  .copyWith(bottom: RaftSpace.x2),
              child: RaftCssText(
                raftText(context, 'Humans failed to load'),
                style: tokens.scale(
                  RaftTypeScale.footnote,
                  weight: FontWeight.w600,
                  color: tokens.ui['warning-strong'],
                ),
              ),
            ),
        ],
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RaftPanelHeaderBar(
            title: raftText(context, 'Members'),
            columnMargin: widget.mobile ? RaftSpace.x5 : null,
            backKey: pushedServerPageBackKey,
            onBack: widget.onBack,
            titleSuffix:
                widget.loading ||
                    widget.mobile ||
                    bounds.maxWidth < 360 ||
                    MediaQuery.sizeOf(context).width < 768
                ? null
                : RaftCssText(
                    icuText(
                      context,
                      '{working, plural, one {# agent working} other {# agents working}} · {members, plural, one {# member} other {# members}}',
                      {
                        'members': count(_Scope.all),
                        'working': agents
                            .where(
                              (entry) =>
                                  switch (agentRowAmbientDisplay(entry.record)
                                      .activity) {
                                    'working' || 'thinking' => true,
                                    _ => false,
                                  },
                            )
                            .length,
                      },
                    ),
                    style: tokens.scale(
                      RaftTypeScale.monoMeta,
                      mono: true,
                      color: tokens.ui.foregroundHint,
                    ),
                  ),
          ),
          if (!showUsage) controls(null, null, const []),
          Expanded(
            child: showUsage
                ? AgentTokenUsagePane(
                    key: ValueKey(pageIdentity(usageWorkspace)),
                    workspace: usageWorkspace,
                    agents: agents,
                    toolbar: controls,
                    agentGroups: _agentGroups(
                      context,
                      agents.where((entry) => entry.matches(_query)).toList(),
                    ),
                    onOpenAgent: widget.onOpenAgent,
                  )
                : _list(context, scope, layout, bounds.maxWidth),
          ),
        ],
      );
    },
  );

  Widget _list(
    BuildContext context,
    _Scope scope,
    MembersEntryLayout layout,
    double width,
  ) {
    final people = humans.where((entry) => entry.matches(_query)).toList();
    final bots = agents.where((entry) => entry.matches(_query)).toList();
    final groups = switch (scope) {
      _Scope.all => [
        if (people.isNotEmpty) (raftText(context, 'Humans'), people),
        if (bots.isNotEmpty) (raftText(context, 'Agents'), bots),
      ],
      _Scope.human => [if (people.isNotEmpty) ('', people)],
      _Scope.agent => _agentGroups(context, bots),
    };
    if (layout == MembersEntryLayout.table && groups.isNotEmpty) {
      return _agentTable(context, groups);
    }
    final columns = ((width - 40 + 12) / 252).floor().clamp(1, 8);
    final items = <WidgetBuilder>[
      if (groups.isEmpty && widget.loading)
        (_) => const Padding(
          padding: EdgeInsets.only(top: RaftSpace.x3),
          child: Column(
            spacing: RaftSpace.x2,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: RaftSpace.x5),
                child: SizedBox(
                  height: RaftSpace.x4 + RaftSpace.half,
                  child: Center(
                    widthFactor: 1,
                    child: RaftSkeleton(
                      width: 64,
                      variant: RaftSkeletonVariant.line,
                      fromRecipe: true,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: RaftSpace.x2),
                child: RaftSidebarRowsSkeleton(rows: 8),
              ),
            ],
          ),
        )
      else if (groups.isEmpty && (_query.isNotEmpty || !widget.failed))
        (_) => Padding(
          padding: const EdgeInsets.symmetric(
            vertical: RaftSpace.x3,
            horizontal: RaftSpace.x5,
          ),
          child: Text(
            _query.isEmpty
                ? raftText(context, 'No one here yet.')
                : raftFormat(context, 'No members match “{query}”.', {
                    'query': _query,
                  }),
            key: const ValueKey('members-empty'),
          ),
        ),
      for (final (heading, entries) in groups) ...[
        if (heading.isNotEmpty)
          (_) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: RaftSpace.x5)
                .copyWith(
                  top: layout == MembersEntryLayout.cards
                      ? RaftSpace.x4
                      : RaftSpace.x3,
                  bottom: RaftSpace.x2,
                ),
            child: RaftSectionHeader(label: heading, count: entries.length),
          ),
        if (heading.isEmpty) (_) => const SizedBox(height: RaftSpace.x2),
        if (layout == MembersEntryLayout.cards)
          for (var start = 0; start < entries.length; start += columns)
            _tileBand(entries, start, columns)
        else
          for (final (index, entry) in entries.indexed)
            (_) => Padding(
              padding: EdgeInsets.fromLTRB(
                RaftSpace.x2,
                index == 0
                    ? RaftSpace.hairline
                    : RaftLayoutMetrics.sidebarRowGap,
                RaftSpace.x2,
                0,
              ),
              child: widget.buildEntry(
                entry,
                layout,
                computers[entry.record['machineId']]?['name'] as String?,
                showComputer: grouping != _Grouping.computer,
                runtimeLine: scope == _Scope.agent,
              ),
            ),
        if (layout == MembersEntryLayout.list)
          (_) => const SizedBox(height: RaftSpace.x2),
      ],
    ];
    final touch = RaftInteraction.of(context).touch;
    Widget list = ListView.builder(
      key: const PageStorageKey('desktop-directory-list'),
      controller: layout == MembersEntryLayout.list ? _rosterScroll : null,
      physics: touch ? const AlwaysScrollableScrollPhysics() : null,
      padding: raftScrollPadding(
        context,
        const EdgeInsets.only(bottom: RaftSpace.x5),
      ),
      itemCount: items.length,
      itemBuilder: (context, index) => items[index](context),
    );
    if (layout == MembersEntryLayout.list) {
      list = RawScrollbar(
        controller: _rosterScroll,
        interactive: !touch,
        thumbColor: RaftTokens.of(context).ui.foreground.withValues(alpha: .42),
        thickness: 7,
        crossAxisMargin: 3,
        mainAxisMargin: 3,
        minThumbLength: 24,
        radius: const Radius.circular(5),
        timeToFade: const Duration(milliseconds: 600),
        fadeDuration: const Duration(milliseconds: 400),
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: list,
        ),
      );
    }
    return RaftPullToRefresh(
      enabled: touch,
      onRefresh: widget.onRefresh,
      child: list,
    );
  }

  Widget _agentTable(
    BuildContext context,
    List<(String, List<MemberPageEntry>)> groups,
  ) {
    final showComputer = grouping != _Grouping.computer;
    return RaftPullToRefresh(
      enabled: RaftInteraction.of(context).touch,
      onRefresh: widget.onRefresh,
      child: CustomScrollView(
        key: const PageStorageKey('desktop-directory-list'),
        physics: RaftInteraction.of(context).touch
            ? const AlwaysScrollableScrollPhysics()
            : null,
        slivers: [
          for (final (index, (heading, entries)) in groups.indexed) ...[
            SliverToBoxAdapter(
              child: MembersAgentColumns(
                name: heading.isEmpty
                    ? null
                    : RaftSectionEyebrow('$heading  ${entries.length}'),
                labels: index == 0
                    ? [
                        raftText(context, 'Status'),
                        raftText(context, 'Runtime'),
                        raftText(context, 'Model'),
                        if (showComputer) raftText(context, 'Computer'),
                      ]
                    : const [],
                header: true,
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: RaftSpace.x5),
              sliver: RaftListRowGroup.sliver(
                sliver: SliverList.builder(
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    return widget.buildEntry(
                      entry,
                      MembersEntryLayout.table,
                      computers[entry.record['machineId']]?['name'] as String?,
                      showComputer: showComputer,
                    );
                  },
                ),
              ),
            ),
          ],
          SliverPadding(
            padding: raftScrollPadding(
              context,
              const EdgeInsets.only(bottom: RaftSpace.x5),
            ),
          ),
        ],
      ),
    );
  }

  WidgetBuilder _tileBand(
    List<MemberPageEntry> entries,
    int start,
    int columns,
  ) => (_) {
    final stretch = columns > 2;
    final row = Row(
      spacing: RaftSpace.x3,
      crossAxisAlignment: stretch
          ? CrossAxisAlignment.stretch
          : CrossAxisAlignment.center,
      children: [
        for (var offset = 0; offset < columns; offset++)
          Expanded(
            child: start + offset < entries.length
                ? widget.buildEntry(
                    entries[start + offset],
                    MembersEntryLayout.cards,
                    null,
                  )
                : const SizedBox.shrink(),
          ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: RaftSpace.x5,
      ).copyWith(bottom: start + columns < entries.length ? RaftSpace.x3 : 0),
      child: stretch ? IntrinsicHeight(child: row) : row,
    );
  };

  List<(String, List<MemberPageEntry>)> _agentGroups(
    BuildContext context,
    List<MemberPageEntry> entries,
  ) {
    if (entries.isEmpty) return [];
    if (grouping == _Grouping.none) return [('', entries)];
    final groups = <Object?, (int, String, List<MemberPageEntry>)>{};
    final self = widget.workspace.client.user?.id;
    final names = {
      for (final entry in [...humans, ...agents]) entry.target.id: entry.name,
    };
    for (final entry in entries) {
      final record = entry.record;
      final id = grouping == _Grouping.computer
          ? record['machineId']
          : record['creatorId'];
      final creator = record['creator'];
      final machine = computers[id];
      final label = grouping == _Grouping.computer
          ? (machine?['name'])
          : ((creator is Map
                    ? creator['displayName'] ?? creator['name']
                    : null) ??
                names[id]);
      groups
          .putIfAbsent(
            label == null ? null : id,
            () => (
              label == null
                  ? 2
                  : (grouping == _Grouping.computer
                        ? machine != null && isMyComputer(machine, self)
                        : id == self && record['creatorType'] == 'user')
                  ? 0
                  : 1,
              label is String
                  ? label
                  : raftText(
                      context,
                      grouping == _Grouping.computer
                          ? 'External & cloud'
                          : 'No known creator',
                    ),
              [],
            ),
          )
          .$3
          .add(entry);
    }
    final sorted = groups.values.toList()
      ..sort((first, second) {
        final rank = first.$1.compareTo(second.$1);
        return rank != 0
            ? rank
            : first.$2.toLowerCase().compareTo(second.$2.toLowerCase());
      });
    return [for (final (_, label, rows) in sorted) (label, rows)];
  }
}
