import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import '../data/workspace_entity_directory.dart';
import 'management_support.dart';

class SidebarPreferencesView extends StatefulWidget {
  const SidebarPreferencesView({super.key, required this.controller});
  final WorkspaceController controller;
  @override
  State<SidebarPreferencesView> createState() => _SidebarPreferencesState();
}

class _SidebarPreferencesState extends ManagementState<SidebarPreferencesView> {
  @override
  WorkspaceController get w => widget.controller;
  Map<String, dynamic> prefs = {};
  List<Map<String, dynamic>> agents = [];
  final modes = const {
    'manual': 'Manual order',
    'recent': 'Recent activity',
    'az': 'Alphabetical',
  };
  List<Map<String, dynamic>> get sections =>
      managementRows(prefs['customSections']);
  List<Map<String, dynamic>> get placements =>
      managementRows(prefs['sectionPlacements']);
  String get path => '/servers/${w.server!.id}/sidebar-order';
  @override
  void initState() {
    super.initState();
    startManagement();
    if (loading) seedFromLocal();
  }

  /// A cold open (no page snapshot yet) still paints from what the workspace
  /// already holds: the sidebar order it loads for the rail and the agent
  /// directory. Both are the same projections the reads below return; if
  /// either is missing the page waits for the read instead of showing a
  /// partial view.
  void seedFromLocal() {
    final order = w.sidebarOrder;
    final directory = w.services.entityDirectory;
    final viewAgents = w.can('viewAgents');
    if (order.isEmpty ||
        (viewAgents && !directory.state(WorkspaceEntityKind.agents).loaded)) {
      return;
    }
    prefs = Map<String, dynamic>.from(order);
    agents = viewAgents ? directory.rows(WorkspaceEntityKind.agents) : [];
    loading = false;
  }

  @override
  void clearData() {
    prefs = {};
    agents = [];
  }

  @override
  String get snapshotKey => 'sidebar-preferences';
  @override
  Map<String, Object?> captureSnapshot() => {'prefs': prefs, 'agents': agents};
  @override
  bool restoreSnapshot(Map<String, Object?> fields) {
    prefs = fields['prefs'] as Map<String, dynamic>;
    agents = fields['agents'] as List<Map<String, dynamic>>;
    return true;
  }

  @override
  Future<void> loadData(int request, int generation) async {
    if (w.server == null) return;
    final responses = await Future.wait([
      w.query(path),
      if (w.can('viewAgents')) w.query('/agents'),
    ]);
    if (!accepts(generation, request)) return;
    prefs = managementMap(responses[0]);
    agents = responses.length > 1 ? managementRows(responses[1]) : [];
  }

  Future<void> save(
    Map<String, dynamic> values, {
    bool sectionChange = false,
  }) async {
    final generation = w.client.generation, scope = authority;
    try {
      final updated = await w.command(
        'PATCH',
        path,
        data: {
          ...values,
          if (sectionChange) 'sectionsVersion': prefs['sectionsVersion'],
        },
      );
      if (!accepts(generation) || scope != authority) return;
      prefs = managementMap(updated);
      saveSnapshot();
      await w.loadSidebar();
      if (mounted) setState(() {});
    } on RaftApiException catch (e) {
      if (e.status == 409) {
        await reload();
        throw const RaftUserError(
          'The sidebar changed on another client. Review the updated list and retry.',
        );
      }
      rethrow;
    }
  }

  List<RaftChannel> ordered(List<RaftChannel> rows, String key) {
    final ids = managementStrings(prefs[key]);
    final byId = {for (final row in rows) row.id: row};
    return [
      for (final id in ids)
        if (byId.containsKey(id)) byId.remove(id)!,
      ...byId.values,
    ];
  }

  Future<void> editSection([Map<String, dynamic>? existing]) async {
    final id =
        existing?['id'] ??
        'native-section-${DateTime.now().microsecondsSinceEpoch}';
    await form(
      existing == null ? 'Create Sidebar Section' : 'Edit Sidebar Section',
      [
        RaftFormField(
          'name',
          'Section name',
          initial: '${existing?['name'] ?? ''}',
          required: true,
          validator: (v) =>
              v.trim().length > 80 ? 'Use up to 80 characters.' : null,
        ),
        RaftFormField(
          'emoji',
          'Emoji',
          initial: '${existing?['emoji'] ?? ''}',
          validator: (v) => v.length > 16 ? 'Use one short emoji.' : null,
        ),
        RaftFormField(
          'sortMode',
          'Sort',
          initial: '${existing?['sortMode'] ?? 'manual'}',
          choices: modes,
        ),
      ],
      (values) async {
        final next = {
          'id': id,
          'name': values['name'],
          'emoji': values['emoji']!.isEmpty ? null : values['emoji'],
          'sortMode': values['sortMode'],
        };
        await save({
          'customSections': [
            for (final section in sections)
              if (section['id'] != id) section,
            next,
          ],
        }, sectionChange: true);
      },
    );
  }

  Future<void> deleteSection(Map<String, dynamic> section) async {
    await form(
      'Remove Sidebar Section',
      [],
      (_) async {
        await save({
          'customSections': sections
              .where((s) => s['id'] != section['id'])
              .toList(),
          'sectionPlacements': placements
              .where((p) => p['sectionId'] != section['id'])
              .toList(),
        }, sectionChange: true);
      },
      description: 'Conversations return to their normal sections. Messages and memberships remain available.',
      submit: 'Remove Section',
      cancel: 'Keep Section',
      destructive: true,
    );
  }

  Future<void> place(String kind, String id) async {
    final current = placements
        .where((p) => p['kind'] == kind && p['id'] == id)
        .firstOrNull?['sectionId'];
    await form(
      'Move to sidebar section',
      [
        RaftFormField(
          'section',
          'Section',
          initial: current?.toString() ?? '',
          localizeChoices: false,
          choices: {
            '': raftText(context, 'Default section'),
            for (final s in sections) '${s['id']}': '${s['name']}',
          },
        ),
      ],
      (values) async {
        final target = values['section'];
        await save({
          'sectionPlacements': [
            for (final p in placements)
              if (!(p['kind'] == kind && p['id'] == id)) p,
            if (target != null && target.isNotEmpty)
              {
                'kind': kind,
                'id': id,
                'sectionId': target,
                'position': placements
                    .where((p) => p['sectionId'] == target)
                    .length,
              },
          ],
        }, sectionChange: true);
      },
    );
  }

  Widget sortPicker(String label, String key) => RaftLabeledSelect<String>(
    fieldKey: ValueKey('$key:${prefs[key]}'),
    label: label,
    value: prefs[key] as String? ?? 'manual',
    items: [
      for (final mode in modes.entries)
        RaftSelectItem(value: mode.key, label: raftText(context, mode.value)),
    ],
    onChanged: busy ? null : (value) => run(() => save({key: value})),
  );

  Widget sectionOrderList() {
    final labels = {
      'system:pinned': raftText(context, 'Pinned'),
      'system:joint': raftText(context, 'Joint channels'),
      'system:channels': raftText(context, 'Channels'),
      'system:dms': raftText(context, 'Direct messages'),
      for (final section in sections)
        '${section['id']}': '${section['emoji'] ?? ''} ${section['name']}',
    };
    final ids = {
      ...managementStrings(prefs['sectionOrder']).where(labels.containsKey),
      ...labels.keys,
    }.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),
        Text(
          raftText(context, 'Section order'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        SizedBox(
          height: (ids.length * 56.0).clamp(80, 320),
          child: ReorderableListView.builder(
            itemCount: ids.length,
            onReorderItem: (from, to) => run(() async {
              final next = List<String>.from(ids);
              next.insert(to, next.removeAt(from));
              await save({'sectionOrder': next}, sectionChange: true);
            }),
            itemBuilder: (context, index) => RaftListRow(
              key: ValueKey('sidebar-section-${ids[index]}'),
              interactive: false,
              children: [
                RaftListRowBody(
                  children: [
                    RaftListRowTitle(
                      // ignore: raft_lints/avoid_render_index_assertion -- `labels` and `ids` are built together from the same section list.
                      labels[ids[index]]!,
                    ),
                  ],
                ),
                const RaftListRowIcon(RaftGlyph.gripVertical),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget pinnedOrderList() {
    final refs = managementRows(prefs['pinned']);
    String label(Map ref) {
      final id = '${ref['id']}';
      if (ref['kind'] == 'channel') {
        return [
              ...w.channels,
              ...w.dms,
            ].where((c) => c.id == id).firstOrNull?.name ??
            id;
      }
      if (ref['kind'] == 'agent') {
        final a = agents.where((a) => a['id'] == id).firstOrNull;
        if (a != null) return '${a['displayName'] ?? a['name']}';
      }
      return w.dms.where((c) => c.string('peerId') == id).firstOrNull?.name ??
          id;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),
        sortPicker('Pinned sort', 'pinnedSortMode'),
        if (refs.isNotEmpty)
          SizedBox(
            height: (refs.length * 56.0).clamp(80, 320),
            child: ReorderableListView.builder(
              itemCount: refs.length,
              onReorderItem: (from, to) => run(() async {
                final next = List<Map<String, dynamic>>.from(refs);
                next.insert(to, next.removeAt(from));
                await save({'pinned': next, 'pinnedSortMode': 'manual'});
              }),
              itemBuilder: (context, index) => RaftListRow(
                key: ValueKey(
                  'sidebar-pinned-${refs[index]['kind']}-${refs[index]['id']}',
                ),
                interactive: false,
                children: [
                  RaftListRowBody(
                    children: [RaftListRowTitle(label(refs[index]))],
                  ),
                  const RaftListRowIcon(RaftGlyph.gripVertical),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget channelList(
    String title,
    List<RaftChannel> rows,
    String orderKey,
    String sortKey, {
    bool dms = false,
  }) {
    final sorted = ordered(rows, orderKey),
        hidden = managementStrings(prefs['hiddenDmIds']).toSet();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),
        Text(
          raftText(context, title),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        sortPicker('Sort', sortKey),
        SizedBox(
          height: (sorted.length * 72.0).clamp(80, 320),
          child: ReorderableListView.builder(
            itemCount: sorted.length,
            onReorderItem: (from, to) => run(() async {
              final next = sorted.map((c) => c.id).toList();
              next.insert(to, next.removeAt(from));
              await save({orderKey: next, sortKey: 'manual'});
            }),
            itemBuilder: (context, index) {
              final c = sorted[index];
              return RaftListRow(
                key: ValueKey('sidebar-item-${c.id}'),
                onPressed: busy
                    ? null
                    : () => run(() => place('channel', c.id)),
                children: [
                  RaftListRowBody(children: [RaftListRowTitle(c.name)]),
                  if (dms)
                    RaftTooltip(
                      message: raftText(
                        context,
                        hidden.contains(c.id)
                            ? 'Show Direct Message'
                            : 'Hide Direct Message',
                      ),
                      child: RaftButton.iconAction(
                        icon: Icon(
                          hidden.contains(c.id)
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: busy
                            ? null
                            : () => run(() async {
                                if (!hidden.remove(c.id)) hidden.add(c.id);
                                await save({'hiddenDmIds': hidden.toList()});
                              }),
                      ),
                    )
                  else
                    const Padding(
                      padding: EdgeInsets.only(right: 24),
                      child: RaftListRowIcon(RaftGlyph.gripVertical),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => loading
      ? const Center(child: RaftSpinner())
      : ListView(
          key: const Key('sidebar-preferences'),
          padding: raftScrollPadding(context, const EdgeInsets.all(24)),
          children: [
            Text(
              raftText(context, 'Sidebar preferences'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            if (error != null) RaftErrorBanner(error!, small: true),
            Text(
              raftText(
                context,
                'Drag conversations to reorder them. Tap a conversation to choose its section.',
              ),
            ),
            channelList(
              'Channels',
              w.channels,
              'channelOrder',
              'channelSortMode',
            ),
            channelList(
              'Direct messages',
              w.dms,
              'dmOrder',
              'dmSortMode',
              dms: true,
            ),
            const SizedBox(height: 20),
            sortPicker('Joint channel sort', 'jointChannelSortMode'),
            pinnedOrderList(),
            sectionOrderList(),
            const SizedBox(height: 20),
            Text(
              raftText(context, 'Custom sections'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            for (final section in sections)
              RaftListRow(
                key: ValueKey('sidebar-custom-section-${section['id']}'),
                onPressed: busy ? null : () => run(() => editSection(section)),
                children: [
                  RaftListRowBody(
                    children: [
                      RaftListRowTitle(
                        '${section['emoji'] ?? ''} ${section['name']}',
                      ),
                      RaftListRowDescription(
                        raftText(
                          context,
                          modes[section['sortMode']] ?? 'Manual order',
                        ),
                      ),
                    ],
                  ),
                  RaftTooltip(
                    message: raftText(context, 'Remove Section'),
                    child: RaftButton.iconAction(
                      icon: const RaftIcon(RaftGlyph.trash2, size: 14),
                      onPressed: busy
                          ? null
                          : () => run(() => deleteSection(section)),
                    ),
                  ),
                ],
              ),
            RaftButton(
              label: raftText(context, 'Create Sidebar Section'),
              onPressed: busy || sections.length >= 50
                  ? null
                  : () => run(editSection),
            ),
            for (final agent in agents)
              RaftListRow(
                onPressed: busy
                    ? null
                    : () => run(() => place('agent', '${agent['id']}')),
                children: [
                  const RaftListRowIcon(RaftGlyph.bot),
                  RaftListRowBody(
                    children: [
                      RaftListRowTitle(
                        '${agent['displayName'] ?? agent['name']}',
                      ),
                    ],
                  ),
                ],
              ),
          ],
        );
}
