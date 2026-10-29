import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/web_error.dart';
import '../data/workspace_controller.dart';
import 'management_support.dart';
import 'mcp_server_editor.dart';

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

  /// AgentMcpTab `messageFor(error, agent.mcp.errorRequestFailed)`: the
  /// server's `error` text, else the managed-MCP failure message.
  static const _failed = 'Managed MCP request failed';

  @override
  Future<void> run(
    Future<void> Function() action, {
    bool refresh = true,
    String? fallback,
  }) => super.run(
    () => withWebError(fallback ?? _failed, action, where: 'managed mcp'),
    refresh: refresh,
    fallback: fallback ?? _failed,
  );

  @override
  Future<bool> form(
    String title,
    List<RaftFormField> fields,
    Future<void> Function(Map<String, String>) save, {
    String submit = 'Save',
    String cancel = 'Cancel',
    String? description,
    bool destructive = false,
  }) => super.form(
    title,
    fields,
    (values) => withWebError(_failed, () => save(values), where: 'managed mcp'),
    submit: submit,
    cancel: cancel,
    description: description,
    destructive: destructive,
  );

  @override
  Future<void> loadData(int request, int generation) => withWebError(
    _failed,
    () => _loadData(request, generation),
    where: 'managed mcp',
  );

  Future<void> _loadData(int request, int generation) async {
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
    final generation = w.client.generation, sourceAuthority = authority;
    Future<V> guarded<V>(
      BuildContext dialog,
      Future<V> Function() action,
    ) async {
      if (!accepts(generation) ||
          sourceAuthority != authority ||
          !w.can('manageIntegrations')) {
        throw const RaftUserError(
          'The active server changed. Reopen this form.',
        );
      }
      try {
        return await withWebError(_failed, action, where: 'managed mcp');
      } catch (e) {
        if (accepts(generation) &&
            sourceAuthority == authority &&
            invalidateDeniedMutation(e) &&
            dialog.mounted &&
            ModalRoute.of(dialog)?.isCurrent == true) {
          Navigator.of(dialog).pop(false);
        }
        rethrow;
      }
    }

    final saved = await scopedRaftModal<bool>(
      form: true,
      dialogMaxWidth: McpServerEditor.dialogMaxWidth,
      (dialog) => McpServerEditor(
        server: server,
        onSave: (data) => guarded(dialog, () async {
          if (server?['id'] == null) {
            await w.client.post('/mcp/servers', data: data);
          } else {
            await w.client.patch('/mcp/servers/${server!['id']}', data: data);
          }
        }),
        onTest: (data) => guarded(dialog, () async {
          final result = managementMap(
            await w.client.post('/mcp/servers/test-configuration', data: data),
          );
          return managementRows(result['tools']).length;
        }),
      ),
    );
    if (saved == true && accepts(generation) && sourceAuthority == authority) {
      await reload();
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
    return RaftMcpServersSection(
      scrollable: true,
      loading: loading && servers.isEmpty,
      error: error == null ? null : raftText(context, error!),
      onAddServer: manage ? () => edit() : null,
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
                                    'Disconnect Account',
                                    'This connection will no longer be authorized to access the provider account.',
                                    () async {
                                      await w.client.delete(
                                        '/mcp/servers/${server['id']}/oauth',
                                      );
                                    },
                                    submit: 'Disconnect Account',
                                    cancel: 'Cancel',
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
                        onPressed: busy ? null : () => edit(server),
                      ),
                      RaftMcpAction(
                        glyph: RaftGlyph.trash2,
                        tooltip: 'Delete server',
                        variant: RaftButtonRecipeVariant.danger,
                        onPressed: busy
                            ? null
                            : () => run(() async {
                                await confirm(
                                  'Delete MCP server',
                                  raftFormat(
                                    context,
                                    'Delete {name}? This removes it from every Agent runtime and usage view.',
                                    {'name': name},
                                  ),
                                  () async {
                                    await w.client.delete(
                                      '/mcp/servers/${server['id']}',
                                    );
                                  },
                                  submit: 'Delete server',
                                  cancel: 'Cancel',
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
                  onAdd: busy ? null : () => edit({...r, 'id': null}),
                ),
            ],
    );
  }

  /// AgentMcpTab scope="agent": the read-only usage list (only servers this
  /// Agent has called), in the tab's `px-5 py-4` scroll column.
  Widget agentUsage(BuildContext context) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    String used(String? iso) {
      final at = DateTime.tryParse(iso ?? '')?.toLocal();
      return at == null
          ? ''
          : '${DateFormat.yMMMd(locale).format(at)} ${DateFormat('hh:mm a', locale).format(at)}';
    }

    return ListView(
      primary: false,
      padding: raftScrollPadding(
        context,
        const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
      children: [
        RaftMcpServersSection(
          usage: true,
          loading: loading && servers.isEmpty,
          error: error == null ? null : raftText(context, error!),
          servers: [
            for (final server in servers)
              if (server['usage'] is Map)
                RaftMcpServerRow(
                  id: '${server['id']}',
                  name: '${server['name']}',
                  provider: '${server['provider'] ?? 'custom'}',
                  endpointUrl: '${server['endpointUrl'] ?? ''}',
                  enabled: server['enabled'] != false,
                  authMode: '${server['authMode'] ?? 'none'}',
                  oauthStatus: server['oauthStatus'] as String?,
                  hasCredentials: server['hasCredentials'] == true,
                  description: server['description'] as String?,
                  lastCheckError: server['lastCheckError'] as String?,
                  usageCalls: () {
                    final n =
                        (server['usage']['invocationCount'] as num?)?.toInt() ??
                        0;
                    return '$n ${n == 1 ? 'call' : 'calls'}';
                  }(),
                  usageLastUsed: used(server['usage']['lastInvokedAt']),
                  usageLastTool: '${server['usage']['lastToolName']}',
                  tools: [
                    for (final tool in managementRows(server['toolCatalog']))
                      RaftMcpTool(
                        '${tool['title'] ?? tool['name']}',
                        tool['description'] as String?,
                      ),
                  ],
                ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) =>
      widget.agentId == null ? serverCatalog(context) : agentUsage(context);
}
