import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import 'management_support.dart';

class AgentMcpView extends StatefulWidget {
  const AgentMcpView({super.key, required this.controller, this.agentId});
  final WorkspaceController controller;
  final String? agentId;
  @override
  State<AgentMcpView> createState() => _AgentMcpState();
}

class _AgentMcpState extends ManagementState<AgentMcpView> {
  @override
  WorkspaceController get w => widget.controller;
  List<Map<String, dynamic>> servers = [], recommendations = [];
  Map<String, dynamic> agent = {};
  bool get canAssign =>
      widget.agentId != null &&
      (w.can('editAgents') ||
          (agent['creatorType'] == 'user' &&
              agent['creatorId'] == w.client.user?.id));
  @override
  void initState() {
    super.initState();
    startManagement();
  }

  @override
  void clearData() {
    servers = [];
    recommendations = [];
    agent = {};
  }

  @override
  String get snapshotKey => 'mcp:${widget.agentId ?? ''}';
  @override
  Map<String, Object?> captureSnapshot() => {
    'servers': servers,
    'recommendations': recommendations,
    'agent': agent,
  };
  @override
  bool restoreSnapshot(Map<String, Object?> fields) {
    servers = fields['servers'] as List<Map<String, dynamic>>;
    recommendations = fields['recommendations'] as List<Map<String, dynamic>>;
    agent = fields['agent'] as Map<String, dynamic>;
    return true;
  }

  @override
  Future<void> loadData(int request, int generation) async {
    final results = await Future.wait([
      w.client.get(
        widget.agentId == null
            ? '/mcp/servers'
            : '/mcp/agents/${widget.agentId}',
      ),
      if (widget.agentId != null) w.client.get('/agents/${widget.agentId}'),
    ]);
    if (!accepts(generation, request)) return;
    final catalog = managementMap(results[0]);
    servers = managementRows(catalog['servers']);
    recommendations = managementRows(catalog['recommendations']);
    if (results.length > 1) agent = managementMap(results[1]);
  }

  Future<void> edit([Map<String, dynamic>? server]) async {
    final creating = server == null || server['id'] == null;
    await form(
      creating ? 'Add MCP connection' : 'Edit MCP connection',
      [
        RaftFormField(
          'name',
          'Connection name',
          initial: server?['name'] ?? '',
          required: true,
        ),
        RaftFormField(
          'description',
          'Description',
          initial: server?['description'] ?? '',
          multiline: true,
        ),
        RaftFormField(
          'endpointUrl',
          'Endpoint URL',
          initial: server?['endpointUrl'] ?? '',
          required: true,
          validator: (v) {
            final invalid = managementHttpUrl(v);
            if (invalid != null) return invalid;
            return Uri.parse(v).hasQuery
                ? 'Put credentials in encrypted headers, not the URL.'
                : null;
          },
        ),
        RaftFormField(
          'provider',
          'Provider',
          initial: server?['provider'] ?? 'custom',
          choices: const {
            'custom': 'Custom',
            'notion': 'Notion',
            'linear': 'Linear',
          },
        ),
        RaftFormField(
          'authMode',
          'Authentication',
          initial: server?['authMode'] ?? 'none',
          choices: const {
            'none': 'None',
            'headers': 'Encrypted headers',
            'oauth': 'OAuth',
          },
        ),
        const RaftFormField(
          'headerName',
          'Credential header name',
          help: 'For encrypted headers, for example Authorization.',
        ),
        const RaftFormField(
          'headerValue',
          'Credential header value',
          obscure: true,
          trim: false,
          help: 'Leave empty when editing to keep existing credentials.',
        ),
        // The Web editor lists stored headers with a remove control.
        if (!creating &&
            managementStrings(server['credentialHeaderNames']).isNotEmpty)
          RaftFormField(
            'removeHeader',
            'Remove a stored header',
            initial: '',
            choices: {
              '': 'Keep all stored headers',
              for (final name in managementStrings(
                server['credentialHeaderNames'],
              ))
                name: name,
            },
          ),
      ],
      (v) async {
        if ((v['headerName']!.isEmpty) != (v['headerValue']!.isEmpty)) {
          throw StateError('Enter both the credential header name and value.');
        }
        if (v['authMode'] != 'headers' && v['headerValue']!.isNotEmpty) {
          throw StateError(
            'Select encrypted headers to save a header credential.',
          );
        }
        final data = <String, dynamic>{
          for (final f in [
            'name',
            'description',
            'endpointUrl',
            'provider',
            'authMode',
          ])
            f: v[f],
          if (creating && v['headerValue']!.isNotEmpty)
            'headers': {v['headerName']: v['headerValue']}
          else if (!creating &&
              (v['headerValue']!.isNotEmpty ||
                  (v['removeHeader'] ?? '').isNotEmpty))
            'credentialPatch': {
              'upsertHeaders': {
                if (v['headerValue']!.isNotEmpty)
                  v['headerName']: v['headerValue'],
              },
              'removeHeaderNames': [
                if ((v['removeHeader'] ?? '').isNotEmpty) v['removeHeader'],
              ],
            },
        };
        if (creating) {
          await w.client.post('/mcp/servers', data: data);
        } else {
          await w.client.patch('/mcp/servers/${server['id']}', data: data);
        }
      },
      submit: creating ? 'Add' : 'Save',
    );
  }

  Future<void> removeHeader(Map<String, dynamic> server) async {
    final names = managementStrings(server['credentialHeaderNames']);
    if (names.isEmpty) return;
    await form(
      'Remove encrypted header',
      [
        RaftFormField(
          'header',
          'Credential header name',
          choices: {for (final name in names) name: name},
        ),
      ],
      (v) async {
        await w.client.patch(
          '/mcp/servers/${server['id']}',
          data: {
            'credentialPatch': {
              'upsertHeaders': <String, String>{},
              'removeHeaderNames': [v['header']],
            },
          },
        );
      },
      submit: 'Remove',
      destructive: true,
      description: 'Remove this stored header. Other saved credentials are preserved. To remove every credential, change authentication to None.',
    );
  }

  Future<void> testConfiguration([Map<String, dynamic>? server]) async {
    Map<String, dynamic> result = {};
    final tested = await form(
      'Test MCP configuration',
      [
        RaftFormField(
          'endpointUrl',
          'Endpoint URL',
          initial: server?['endpointUrl'] ?? '',
          required: true,
          validator: (v) =>
              managementHttpUrl(v) ??
              (Uri.tryParse(v)?.hasQuery == true
                  ? 'Put credentials in encrypted headers, not the URL.'
                  : null),
        ),
        RaftFormField(
          'authMode',
          'Authentication',
          initial: server?['authMode'] == 'headers' ? 'headers' : 'none',
          choices: const {'none': 'None', 'headers': 'Encrypted headers'},
        ),
        const RaftFormField('headerName', 'Credential header name'),
        const RaftFormField(
          'headerValue',
          'Credential header value',
          obscure: true,
          trim: false,
          help: 'Leave empty to use the saved credential when testing an existing connection.',
        ),
      ],
      (v) async {
        if (v['headerName']!.isEmpty != v['headerValue']!.isEmpty) {
          throw StateError('Enter both the header name and its credential.');
        }
        if (v['authMode'] != 'headers' && v['headerValue']!.isNotEmpty) {
          throw StateError('Select encrypted headers to test a credential.');
        }
        result = managementMap(
          await w.client.post(
            '/mcp/servers/test-configuration',
            data: {
              'endpointUrl': v['endpointUrl'],
              'authMode': v['authMode'],
              if (server != null) 'mcpServerId': server['id'],
              if (v['headerValue']!.isNotEmpty)
                if (server == null)
                  'headers': {v['headerName']: v['headerValue']}
                else
                  'credentialPatch': {
                    'upsertHeaders': {v['headerName']: v['headerValue']},
                    'removeHeaderNames': <String>[],
                  },
            },
          ),
        );
      },
      submit: 'Test',
      description:
          'Connect and list tools without saving these configuration changes.',
    );
    if (tested) {
      await scopedDialog<void>(
        (dialog) => AlertDialog(
          title: Text(raftText(context, 'Connection test succeeded')),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final tool in managementRows(result['tools']))
                    ListTile(
                      title: Text('${tool['name']}'),
                      subtitle: Text('${tool['description'] ?? ''}'),
                    ),
                  if (managementRows(result['tools']).isEmpty)
                    Text(
                      raftText(
                        context,
                        'This connection currently exposes no tools.',
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog),
              child: Text(raftText(context, 'Close')),
            ),
          ],
        ),
      );
    }
  }

  Future<void> assignment(Map<String, dynamic> server) async {
    final current = managementMap(server['assignment']);
    final names = managementRows(server['toolCatalog'])
        .map((t) => '${t['name']}')
        .toList();
    await form(
      'Agent tool access',
      [
        RaftFormField(
          'enabled',
          'Connection access',
          initial: current['enabled'] == true ? 'true' : 'false',
          choices: const {'true': 'Enabled', 'false': 'Disabled'},
        ),
        RaftFormField(
          'tools',
          'Allowed tools',
          initial: managementStrings(current['allowedTools']).join(', '),
          help:
              'Leave blank to allow all tools in this connection. Available: ${names.join(', ')}',
          validator: (v) {
            final chosen = v
                .split(RegExp(r'[,\s]+'))
                .where((t) => t.isNotEmpty);
            return chosen.any((t) => !names.contains(t))
                ? 'Choose tools from this connection catalog.'
                : null;
          },
        ),
      ],
      (v) async {
        await w.client.request(
          'PUT',
          '/mcp/agents/${widget.agentId}/assignments/${server['id']}',
          data: {
            'enabled': v['enabled'] == 'true',
            'allowedTools': v['tools']!.isEmpty
                ? null
                : v['tools']!
                      .split(RegExp(r'[,\s]+'))
                      .where((s) => s.isNotEmpty)
                      .toSet()
                      .toList(),
          },
        );
      },
      description: 'Allow this agent to invoke only the tools you approve.',
    );
  }

  /// Settings > MCP Servers (AgentMcpTab scope="server").
  Widget serverCatalog(BuildContext context) {
    final manage = w.can('manageIntegrations');
    return ListView(
      primary: false,
      padding: RaftSettingsPanelFrame.contentInset,
      children: [
        RaftMcpServersSection(
          loading: loading && servers.isEmpty,
          error: error == null
              ? null
              : raftText(context, 'Managed MCP request failed'),
          onAddServer: manage ? () => run(() => edit()) : null,
          servers: [
            for (final server in servers)
              () {
                final oauth = server['authMode'] == 'oauth';
                final connected = server['oauthStatus'] == 'connected';
                final ready = !oauth || connected;
                final name = '${server['name']}';
                return RaftMcpServerRow(
                  id: '${server['id']}',
                  name: name,
                  provider: '${server['provider'] ?? 'custom'}',
                  endpointUrl: '${server['endpointUrl'] ?? ''}',
                  enabled: server['enabled'] != false,
                  authMode: '${server['authMode'] ?? 'none'}',
                  oauthStatus: server['oauthStatus'] as String?,
                  hasCredentials: server['hasCredentials'] == true,
                  description: server['description'] as String?,
                  lastCheckError: server['lastCheckError'] as String?,
                  tools: [
                    for (final tool in managementRows(server['toolCatalog']))
                      RaftMcpTool(
                        '${tool['title'] ?? tool['name']}',
                        tool['description'] as String?,
                      ),
                  ],
                  actions: !manage
                      ? const []
                      : [
                          if (oauth && !connected)
                            RaftMcpAction(
                              glyph: RaftGlyph.link2,
                              tooltip: 'Connect $name',
                              variant: RaftButtonRecipeVariant.success,
                              onPressed: busy
                                  ? null
                                  : () => run(() async {
                                      final result = await w.client.post(
                                        '/mcp/servers/${server['id']}/oauth/start',
                                      );
                                      await launchManaged(
                                        result['authorizationUrl'],
                                      );
                                    }, refresh: false),
                            ),
                          if (oauth && connected)
                            RaftMcpAction(
                              glyph: RaftGlyph.unplug,
                              tooltip: 'Disconnect $name',
                              onPressed: busy
                                  ? null
                                  : () => run(() async {
                                      await confirm(
                                        'Disconnect account?',
                                        'This connection will no longer be authorized to access the provider account.',
                                        () async {
                                          await w.client.delete(
                                            '/mcp/servers/${server['id']}/oauth',
                                          );
                                        },
                                        submit: 'Disconnect',
                                        destructive: true,
                                      );
                                    }),
                            ),
                          RaftMcpAction(
                            glyph: RaftGlyph.flaskConical,
                            tooltip: 'Test and refresh tools',
                            onPressed: busy || !ready
                                ? null
                                : () => run(() async {
                                    await w.client.post(
                                      '/mcp/servers/${server['id']}/test',
                                    );
                                  }),
                          ),
                          RaftMcpAction(
                            glyph: RaftGlyph.pencil,
                            tooltip: 'Edit server',
                            onPressed: busy
                                ? null
                                : () => run(() => edit(server)),
                          ),
                          RaftMcpAction(
                            glyph: RaftGlyph.trash2,
                            tooltip: 'Delete server',
                            variant: RaftButtonRecipeVariant.danger,
                            onPressed: busy
                                ? null
                                : () => run(() async {
                                    await confirm(
                                      'Delete $name?',
                                      'Remove this connection and its agent tool assignments.',
                                      () async {
                                        await w.client.delete(
                                          '/mcp/servers/${server['id']}',
                                        );
                                      },
                                      submit: 'Delete',
                                      destructive: true,
                                    );
                                  }),
                          ),
                        ],
                );
              }(),
          ],
          recommendations: !manage
              ? const []
              : [
                  for (final r in recommendations)
                    RaftMcpRecommendation(
                      id: '${r['id']}',
                      name: '${r['name']}',
                      description: '${r['description'] ?? ''}',
                      added: servers.any((s) => s['provider'] == r['provider']),
                      onAdd: busy
                          ? null
                          : () => run(() => edit({...r, 'id': null})),
                    ),
                ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => widget.agentId == null
      ? serverCatalog(context)
      : page(
          'Agent MCP connections',
          [
            if (servers.isEmpty && !loading)
              const Text(
                'Add an MCP connection to make its tools available to agents.',
              ),
            if (recommendations.isNotEmpty) heading('Recommended connections'),
            for (final recommendation in recommendations)
              ListTile(
                title: Text('${recommendation['name']}'),
                subtitle: Text('${recommendation['description'] ?? ''}'),
                trailing: w.can('manageIntegrations')
                    ? action(
                        'Add ${recommendation['name']}',
                        () => run(() => edit({...recommendation, 'id': null})),
                      )
                    : null,
              ),
            for (final server in servers)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${server['name']}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (server['description'] != null)
                        Text('${server['description']}'),
                      SelectableText('${server['endpointUrl']}'),
                      Text(
                        '${server['enabled'] == true ? 'Enabled' : 'Disabled'} · ${server['authMode']} ${server['authMode'] == 'oauth' ? '· ${server['oauthStatus']}' : ''}',
                      ),
                      if (server['hasCredentials'] == true)
                        Text(
                          'Credential headers: ${managementStrings(server['credentialHeaderNames']).join(', ')}',
                        ),
                      if (server['lastCheckError'] != null)
                        Text(
                          'Connection check failed. Test the connection after reviewing its configuration.',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      if (server['lastCheckedAt'] != null)
                        Text('Last checked: ${server['lastCheckedAt']}'),
                      if (widget.agentId != null)
                        Text(
                          'Agent access: ${managementMap(server['assignment'])['enabled'] == true ? 'Enabled' : 'Disabled'}',
                        ),
                      if (server['usage'] is Map)
                        Text(
                          '${managementMap(server['usage'])['invocationCount']} admitted tool calls',
                        ),
                      for (final tool in managementRows(server['toolCatalog']))
                        ListTile(
                          dense: true,
                          leading: const Icon(Icons.handyman_outlined),
                          title: Text('${tool['name']}'),
                          subtitle: Text('${tool['description'] ?? ''}'),
                        ),
                      Wrap(
                        children: [
                          if (canAssign)
                            action(
                              'Tool access',
                              () => run(() => assignment(server)),
                            ),
                          if (w.can('manageIntegrations')) ...[
                            action(
                              'Edit connection',
                              () => run(() => edit(server)),
                            ),
                            if (managementStrings(
                              server['credentialHeaderNames'],
                            ).isNotEmpty)
                              action(
                                'Remove credential header',
                                () => run(() => removeHeader(server)),
                              ),
                            if (server['authMode'] != 'oauth')
                              action(
                                'Test configuration',
                                () => run(
                                  () => testConfiguration(server),
                                  refresh: false,
                                ),
                              ),
                            action(
                              'Test connection',
                              () => run(() async {
                                await w.client.post(
                                  '/mcp/servers/${server['id']}/test',
                                );
                              }),
                            ),
                            action(
                              server['enabled'] == true ? 'Disable' : 'Enable',
                              () => run(() async {
                                await w.client.patch(
                                  '/mcp/servers/${server['id']}',
                                  data: {'enabled': server['enabled'] != true},
                                );
                              }),
                            ),
                            action(
                              'Delete connection',
                              () => run(() async {
                                await confirm(
                                  'Delete ${server['name']}?',
                                  'Remove this connection and its agent tool assignments.',
                                  () async {
                                    await w.client.delete(
                                      '/mcp/servers/${server['id']}',
                                    );
                                  },
                                  submit: 'Delete',
                                  destructive: true,
                                );
                              }),
                            ),
                          ],
                          if (server['authMode'] == 'oauth' &&
                              w.can('manageExternalAuth')) ...[
                            action(
                              'Connect account',
                              () => run(() async {
                                final result = await w.client.post(
                                  '/mcp/servers/${server['id']}/oauth/start',
                                );
                                await launchManaged(result['authorizationUrl']);
                              }, refresh: false),
                            ),
                            if (server['hasCredentials'] == true)
                              action(
                                'Disconnect account',
                                () => run(() async {
                                  await confirm(
                                    'Disconnect account?',
                                    'This connection will no longer be authorized to access the provider account.',
                                    () async {
                                      await w.client.delete(
                                        '/mcp/servers/${server['id']}/oauth',
                                      );
                                    },
                                    submit: 'Disconnect',
                                    destructive: true,
                                  );
                                }),
                              ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
          actions: [
            if (w.can('manageIntegrations'))
              action(
                'Test unsaved connection',
                () => run(() => testConfiguration(), refresh: false),
              ),
            if (w.can('manageIntegrations'))
              action(
                'Add connection',
                () => run(() => edit()),
                glyph: RaftGlyph.plus,
                glyphSize: 13,
              ),
          ],
        );
}
