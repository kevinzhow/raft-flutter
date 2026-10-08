import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

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

  @override
  Widget build(BuildContext context) => page(
    'Agent app access',
    [
      if (access.isEmpty && !loading)
        const Text('No apps have access to this agent.'),
      for (final item in access)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item['clientName']}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  item['type'] == 'pending'
                      ? 'Approval requested'
                      : 'Access granted',
                ),
                for (final scope in managementStrings(item['scopes']))
                  Text('• ${integrationScopeLabels[scope] ?? scope}'),
                if (manager)
                  Wrap(
                    children: [
                      if (item['type'] == 'pending') ...[
                        action(
                          'Approve',
                          () => run(() async {
                            await form(
                              'Approve app access',
                              [
                                const RaftFormField(
                                  'remember',
                                  'Future requests',
                                  initial: 'false',
                                  choices: {
                                    'false': 'Approve this request',
                                    'true': 'Remember access',
                                  },
                                ),
                              ],
                              (v) async {
                                await w.client.post(
                                  '/integrations/requests/${item['id']}/approve',
                                  data: {'remember': v['remember'] == 'true'},
                                );
                              },
                              submit: 'Approve',
                              description: 'Allow the app to access this agent with the listed permissions.',
                            );
                          }),
                        ),
                        action(
                          'Deny',
                          () => run(() async {
                            await w.client.post(
                              '/integrations/requests/${item['id']}/deny',
                            );
                          }),
                        ),
                      ] else
                        action(
                          'Revoke',
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
                  ),
              ],
            ),
          ),
        ),
      if (manager) ...[
        heading('Recent app events'),
        DropdownButtonFormField<String>(
          initialValue: filter ?? '',
          decoration: const InputDecoration(labelText: 'Filter by app'),
          items: [
            const DropdownMenuItem(value: '', child: Text('All apps')),
            for (final app in apps)
              DropdownMenuItem(
                value: app['clientId'],
                child: Text(app['name']),
              ),
          ],
          onChanged: busy
              ? null
              : (v) {
                  setState(() => filter = v == '' ? null : v);
                  reload();
                },
        ),
        if (events.isEmpty && !loading)
          const Text('No app events have arrived.'),
        for (final event in events)
          ListTile(
            title: Text('${event['summary']}'),
            subtitle: Text(
              '${managementMap(event['app'])['name']} · ${event['kind']}\n${event['createdAt']}',
            ),
            isThreeLine: true,
            trailing: Text('${event['status']}'),
            onTap: () => run(() => eventDetail(event), refresh: false),
          ),
        if (nextCursor != null)
          action('Load older events', () => run(moreEvents, refresh: false)),
      ],
    ],
    actions: [
      if (manager)
        action('Grant app access', () => run(grant), icon: Icons.add),
    ],
  );
}
