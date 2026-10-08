import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/recipes.dart'
    show RaftBadgeRecipeVariant, RaftButtonRecipeVariant;

import '../data/workspace_controller.dart';
import 'management_support.dart';
import 'integrations_views.dart';

class AgentAppAccessView extends StatefulWidget {
  const AgentAppAccessView({
    super.key,
    required this.controller,
    required this.agentId,
  });
  final WorkspaceController controller;
  final String agentId;
  @override
  State<AgentAppAccessView> createState() => _AgentAppsState();
}

class _AgentAppsState extends ManagementState<AgentAppAccessView> {
  @override
  WorkspaceController get w => widget.controller;
  List<Map<String, dynamic>> access = [], apps = [], events = [];
  Map<String, dynamic> agent = {};
  String? nextCursor, filter;
  bool get manager =>
      w.can('manageIntegrations') ||
      (agent['creatorType'] == 'user' &&
          agent['creatorId'] == w.client.user?.id);
  String get base => '/integrations/agents/${widget.agentId}';
  @override
  void initState() {
    super.initState();
    startManagement();
  }

  @override
  void clearData() {
    access = [];
    apps = [];
    events = [];
    agent = {};
    nextCursor = null;
    filter = null;
  }

  @override
  Future<void> loadData(int request, int generation) async {
    final agentData = managementMap(
      await w.client.get('/agents/${widget.agentId}'),
    );
    if (!accepts(generation, request)) return;
    final manages =
        w.can('manageIntegrations') ||
        (agentData['creatorType'] == 'user' &&
            agentData['creatorId'] == w.client.user?.id);
    final results = await Future.wait([
      w.client.get(base),
      if (manages) w.client.get('$base/grantable-apps'),
      if (manages)
        w.client.get(
          '$base/events',
          query: {'limit': '25', if (filter != null) 'clientId': filter},
        ),
    ]);
    if (!accepts(generation, request)) return;
    agent = agentData;
    access = managementRows(results[0]);
    apps = manages ? managementRows(managementMap(results[1])['apps']) : [];
    final page = manages ? managementMap(results[2]) : <String, dynamic>{};
    events = managementRows(page['events']);
    nextCursor = page['nextCursor'];
  }

  Future<void> moreEvents() async {
    final cursor = nextCursor,
        generation = w.client.generation,
        sourceAuthority = authority;
    if (cursor == null) return;
    final page = managementMap(
      await w.client.get(
        '$base/events',
        query: {
          'limit': '25',
          'before': cursor,
          if (filter != null) 'clientId': filter,
        },
      ),
    );
    if (!accepts(generation) || sourceAuthority != authority) return;
    final ids = events.map((e) => e['id']).toSet();
    events = [
      ...events,
      ...managementRows(page['events']).where((e) => ids.add(e['id'])),
    ];
    nextCursor = page['nextCursor'];
    setState(() {});
  }

  Future<void> grant() async {
    if (apps.isEmpty) {
      throw StateError('No apps are available to grant to this agent.');
    }
    Map<String, dynamic>? selected;
    final picked = await form(
      'Choose app',
      [
        RaftFormField(
          'clientId',
          'App',
          choices: {for (final a in apps) '${a['clientId']}': '${a['name']}'},
        ),
      ],
      (v) async {
        selected = apps.firstWhere((a) => a['clientId'] == v['clientId']);
      },
      submit: 'Review permissions',
    );
    if (!picked || selected == null) return;
    final scopes = managementStrings(selected!['scopes']);
    await form(
      'Grant ${selected!['name']} access',
      [
        RaftFormField(
          'scopes',
          'Granted permissions',
          initial: scopes.join(', '),
          help: scopes
              .map((s) => '$s: ${integrationScopeLabels[s] ?? s}')
              .join('\n'),
          required: true,
          validator: (v) =>
              parseIntegrationScopes(v).any((s) => !scopes.contains(s))
              ? 'Select permissions requested by this app.'
              : null,
        ),
      ],
      (v) async {
        await w.client.post(
          '$base/grants',
          data: {
            'clientId': selected!['clientId'],
            'scopes': parseIntegrationScopes(v['scopes']!),
          },
        );
      },
      submit: 'Grant access',
      description: 'Allow this app to send the approved events or notifications to this agent.',
    );
  }

  Future<void> eventDetail(Map<String, dynamic> event) async {
    final generation = w.client.generation;
    final detail = managementMap(
      await w.client.get('$base/events/${event['id']}'),
    );
    if (!accepts(generation)) return;
    await scopedDialog<void>(
      (context) => AlertDialog(
        title: Text('${event['summary']}'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: SelectableText(
              const JsonEncoder.withIndent('  ').convert(detail['payload']),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _small(String label, VoidCallback? onPressed, {bool selected = false}) =>
      RaftRecipeTextButton(
        label: label,
        // `<Button size="sm" variant="outline"|"default" className="text-[11px]">`.
        variant: selected ? null : RaftButtonRecipeVariant.outline,
        text: RaftButtonText.px11,
        onPressed: onPressed,
      );

  /// AgentAppAccessTab.tsx: `flex-1 overflow-y-auto bg-layer-panel px-5
  /// py-4 space-y-6 theme-brutal:bg-white` with Applications and App events
  /// sections.
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final pending = access.where((i) => i['type'] == 'pending').toList();
    final active = access.where((i) => i['type'] != 'pending').toList();
    final empty = RaftPanelText.muted(t);
    return RaftPanelGroups(
      groups: [
        if (error != null) [RaftPanelError(error!)],
        if (pending.isNotEmpty)
          [
            RaftSectionHeader(
              label: raftText(context, 'Pending requests'),
              count: pending.length,
            ),
            for (final item in pending) _accessCard(context, item),
          ],
        [
          RaftDescribedSectionHeader(
            label: raftText(context, 'Applications'),
            description: raftText(context, 'Connected apps this agent can use.'),
            action: loading
                ? Text(
                    raftText(context, 'Loading…'),
                    style: RaftPanelText.caption(t),
                  )
                : manager
                ? _small(
                    raftText(context, 'Grant access'),
                    busy ? null : () => run(grant),
                  )
                : null,
          ),
          if (active.isEmpty)
            Text(raftText(context, 'No connected apps'), style: empty)
          else
            for (final item in active) _accessCard(context, item),
        ],
        if (manager)
          [
            RaftDescribedSectionHeader(
              label: raftText(context, 'App events'),
              description: raftText(
                context,
                "Events apps sent to this agent. They're kept for 30 days after they expire.",
              ),
              action: _small(
                raftText(context, loading ? 'Loading…' : 'Refresh'),
                busy || loading ? null : reload,
              ),
            ),
            if (apps.length > 1)
              RaftButtonWrap(
                children: [
                  _small(raftText(context, 'All apps'), () {
                    setState(() => filter = null);
                    reload();
                  }, selected: filter == null),
                  for (final app in apps)
                    _small('${app['name']}', () {
                      setState(() => filter = '${app['clientId']}');
                      reload();
                    }, selected: filter == app['clientId']),
                ],
              ),
            if (events.isEmpty && !loading)
              Text(raftText(context, 'No app events yet'), style: empty)
            else
              for (final event in events)
                RaftAccessCard(
                  title: '${event['summary']}',
                  subtitle:
                      '${managementMap(event['app'])['name']} · ${event['kind']} · ${event['status']}',
                  onTap: () => run(() => eventDetail(event), refresh: false),
                ),
            if (nextCursor != null)
              Align(
                alignment: Alignment.centerLeft,
                child: _small(
                  raftText(context, 'Load more'),
                  () => run(moreEvents, refresh: false),
                ),
              ),
          ],
      ],
    );
  }

  Widget _accessCard(BuildContext context, Map<String, dynamic> item) {
    final pending = item['type'] == 'pending';
    return RaftAccessCard(
      title: '${item['clientName']}',
      badge: RaftRecipeBadge(
        raftText(context, pending ? 'Pending' : 'Active'),
        variant: pending
            ? RaftBadgeRecipeVariant.warning
            : RaftBadgeRecipeVariant.success,
        uppercase: true,
      ),
      chips: [
        for (final scope in managementStrings(item['scopes']))
          integrationScopeLabels[scope] ?? scope,
      ],
      actions: [
        if (manager && pending) ...[
          _small(
            raftText(context, 'Approve'),
            () => run(() async {
              await w.client.post(
                '/integrations/requests/${item['id']}/approve',
                data: {'remember': true},
              );
            }),
            selected: true,
          ),
          _small(
            raftText(context, 'Deny'),
            () => run(() async {
              await w.client.post('/integrations/requests/${item['id']}/deny');
            }),
          ),
        ] else if (manager)
          _small(
            raftText(context, 'Revoke'),
            () => run(() async {
              await confirm(
                'Revoke app access?',
                'Disconnect ${item['clientName']} from this agent.',
                () async {
                  await w.client.post(
                    '/integrations/grants/${item['id']}/revoke',
                  );
                },
                submit: 'Revoke',
                destructive: true,
              );
            }),
          ),
      ],
    );
  }
}
