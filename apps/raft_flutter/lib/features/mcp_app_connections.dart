import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/managed_mcp_apps.dart';
import '../data/workspace_controller.dart';
import 'management_support.dart';
import 'mcp_connection_fields.dart';
import 'mcp_web_sign_in.dart';

enum _ConnectionEdit { add, rename, replace }

class McpAppConnections extends StatefulWidget {
  const McpAppConnections({
    super.key,
    required this.app,
    required this.workspace,
    required this.onReload,
  });

  final ManagedMcpApp app;
  final WorkspaceController workspace;
  final Future<void> Function() onReload;

  @override
  State<McpAppConnections> createState() => _McpAppConnectionsState();
}

class _McpAppConnectionsState extends ManagementState<McpAppConnections> {
  @override
  WorkspaceController get w => widget.workspace;
  ManagedMcpApp get app => widget.app;
  late final String scope;
  late final api = ManagedMcpAppsApi(w.client);
  (_ConnectionEdit, McpConnection?)? edit;

  String get base => ManagedMcpAppsApi.app(app.id);
  bool get live => mounted && scope == authority;
  bool get canEdit =>
      app.canManage &&
      w.can('manageIntegrations') &&
      (app.auth != McpAuthKind.oauth || w.can('manageExternalAuth'));

  @override
  void initState() {
    super.initState();
    scope = authority;
    startManagement();
  }

  @override
  void clearData() {
    edit = null;
  }

  @override
  Future<void> loadData(int request, int generation) async {}

  Future<McpJson> _mutate(String method, String path, {McpJson? data}) {
    if (!live || !canEdit) {
      throw const RaftUserError('The active server changed. Reopen this form.');
    }
    return api.request(method, path, data: data);
  }

  String _name(McpConnection connection) =>
      connection.name ?? raftText(context, 'Unnamed connection');

  Future<void> _submit(
    _ConnectionEdit mode,
    McpConnection? connection,
    McpJson payload,
  ) async {
    if (app.auth == McpAuthKind.oauth && mode != _ConnectionEdit.rename) {
      if (!live || !canEdit) return;
      await _openWeb();
      return;
    }
    await run(() async {
      final path = '$base/connections';
      await _mutate(
        connection == null ? 'POST' : 'PATCH',
        connection == null
            ? path
            : '$path/${Uri.encodeComponent(connection.id)}',
        data: payload,
      );
      if (!live) return;
      setState(() => edit = null);
      await widget.onReload();
    }, refresh: false);
  }

  Future<void> _openWeb() => run(() => openMcpWebSignIn(w), refresh: false);

  Future<void> _setDefault(McpConnection connection) => run(() async {
    final impact = await api.request(
      'GET',
      '$base/default/impact',
      query: {'connectionId': connection.id},
    );
    if (!mounted || !live) return;
    final name = _name(connection);
    final count = impact['agentsChangingNow'] ?? 0;
    final changed = await confirm(
      raftFormat(context, 'Make {name} the server default?', {'name': name}),
      [
        if (count == 0)
          raftText(context, 'No Agent switches connection now.')
        else
          raftFormat(
            context,
            count == 1
                ? '{count} Agent follows the server default and will use {name} from now on.'
                : '{count} Agents follow the server default and will use {name} from now on.',
            {'count': count, 'name': name},
          ),
        raftFormat(
          context,
          'Not affected: {pinned} pinned Agents and {off} Agents with this App switched off. New Agents follow the default.',
          {
            'pinned': impact['pinnedUnchanged'] ?? 0,
            'off': impact['offUnchanged'] ?? 0,
          },
        ),
      ].join('\n\n'),
      () async {
        await _mutate(
          'PUT',
          '$base/default',
          data: {'connectionId': connection.id},
        );
      },
      submit: 'Make default',
    );
    if (changed && live) await widget.onReload();
  }, refresh: false);

  Future<void> _remove(McpConnection connection, {bool signOut = false}) =>
      run(() async {
        final title = raftFormat(
          context,
          signOut ? 'Sign out of {name}?' : 'Delete {name}?',
          {'name': _name(connection)},
        );
        final changed = await confirm(
          title,
          [
            raftText(
              context,
              signOut
                  ? 'The connection stays, but its sign-in is removed. Agents pinned to this connection are refused until someone signs in again with Reauthorize.'
                  : 'Agents pinned to this connection will be refused when they call this App. They do not fall back to the server default.',
            ),
            if (connection.isDefault)
              raftText(
                context,
                signOut
                    ? 'This is the server default: Agents that follow the default are refused too, until someone signs in again or you choose another default.'
                    : 'This is the server default: Agents that follow the default will be refused too, until you choose a new default.',
              ),
          ].join('\n\n'),
          () async {
            final id = Uri.encodeComponent(connection.id);
            await _mutate(
              'DELETE',
              '$base/connections/$id${signOut ? '/oauth' : ''}',
            );
          },
          submit: signOut ? 'Sign out' : 'Delete connection',
          destructive: true,
        );
        if (changed && live) await widget.onReload();
      }, refresh: false);

  @override
  Widget build(BuildContext context) {
    if (app.auth == McpAuthKind.none) {
      return const RaftAppEditorFootnote(
        'No connection needed: this server works without signing in.',
      );
    }
    if (!app.canManage) {
      return const RaftAppEditorFootnote(
        'Only people who manage integrations can see and change connections.',
      );
    }
    final defaultConnection = app.connections
        .where((item) => item.isDefault)
        .firstOrNull;
    final headerNames = app.headerNames.isNotEmpty
        ? app.headerNames
        : defaultConnection?.headerNames ?? const <String>[];
    final mayAdd =
        canEdit &&
        !busy &&
        (app.auth == McpAuthKind.oauth || headerNames.isNotEmpty);
    return RaftAppEditorStack(
      gap: RaftSpace.x3,
      children: [
        if (error case final failure?) RaftConnectedAppsError(failure),
        if (app.auth == McpAuthKind.oauth)
          RaftAppEditorFootnote(
            raftFormat(
              context,
              'Sign in on Raft Web. Open {name} from Apps to manage its connections.',
              {'name': app.name},
            ),
          ),
        if (defaultConnection != null)
          RaftAppEditorStack(
            gap: RaftSpace.x1,
            children: [
              Text(
                raftFormat(context, 'Server default: {name}', {
                  'name': _name(defaultConnection),
                }),
                style: RaftTokens.of(context)
                    .scale(RaftTypeScale.footnote, weight: FontWeight.w700),
              ),
              const RaftAppEditorFootnote(
                'Agents without a specific connection use this one and follow future changes to the server default.',
              ),
            ],
          )
        else if (app.connections.isNotEmpty)
          const RaftBanner(
            description: 'No server default is set. Agents following it need a default or a specific connection before they can use this App.',
            status: RaftBannerRecipeStatus.warning,
            size: RaftBannerRecipeSize.sm,
          )
        else if (edit?.$1 != _ConnectionEdit.add)
          const RaftAppEditorFootnote(
            'No connections yet. Add one and make it the server default, or assign it to individual agents.',
          ),
        for (final connection in app.connections) ...[
          _connectionRow(connection),
          if (edit case (final mode, final item?) when item.id == connection.id)
            _fields(mode, item, headerNames),
        ],
        if (edit case (_ConnectionEdit.add, null))
          _fields(_ConnectionEdit.add, null, headerNames)
        else if (canEdit)
          Align(
            alignment: Alignment.centerLeft,
            child: RaftButton(
              label: 'Add connection',
              glyph: RaftGlyph.plus,
              uiVariant: RaftButtonVariant.standard,
              onPressed: mayAdd
                  ? app.auth == McpAuthKind.oauth
                        ? _openWeb
                        : () =>
                              setState(() => edit = (_ConnectionEdit.add, null))
                  : null,
            ),
          ),
        if (app.auth == McpAuthKind.headers && app.headerNames.isEmpty)
          const RaftAppEditorFootnote(
            'This App has no recorded header names. Set them in MCP Server, then add the connection.',
            warning: true,
          ),
      ],
    );
  }

  Widget _fields(
    _ConnectionEdit mode,
    McpConnection? connection,
    List<String> headerNames,
  ) => McpConnectionFields(
    key: ValueKey((mode, connection?.id)),
    app: app,
    headerNames: connection != null && connection.headerNames.isNotEmpty
        ? connection.headerNames
        : headerNames,
    workspace: w,
    connection: connection,
    rename: mode == _ConnectionEdit.rename,
    busy: busy,
    onCancel: () => setState(() => edit = null),
    onSubmit: (payload) => _submit(mode, connection, payload),
  );

  Widget _connectionRow(McpConnection connection) {
    final name = _name(connection);
    final isOAuth = connection.auth == McpAuthKind.oauth;
    return RaftAppEditorBox(
      shadow: false,
      softBorder: true,
      child: RaftAppEditorActionRow(
        key: ValueKey('mcp-connection-${connection.id}'),
        title: name,
        description: [
          raftText(context, connection.statusLabel),
          if (connection.isDefault) raftText(context, 'Default'),
          ?connection.account,
        ].join(' · '),
        extra: connection.lastError,
        action: canEdit
            ? RaftDropdownMenu(
                key: ValueKey('mcp-connection-actions-${connection.id}'),
                label: raftFormat(context, 'More actions for {name}', {
                  'name': name,
                }),
                surfaceKey: const ValueKey('mcp-connection-menu'),
                triggerBuilder: (context, focus, press) => RaftButton(
                  glyph: RaftGlyph.ellipsis,
                  tooltip: raftFormat(context, 'More actions for {name}', {
                    'name': name,
                  }),
                  uiSize: RaftButtonSize.iconMd,
                  uiVariant: RaftButtonVariant.ghost,
                  focusNode: focus,
                  onPressed: press,
                ),
                align: RaftDropdownAlign.end,
                enabled: !busy,
                entries: [
                  if (!connection.isDefault && connection.status == 'ready')
                    RaftMenuEntry(
                      label: raftText(context, 'Make default'),
                      onPressed: () => _setDefault(connection),
                    ),
                  RaftMenuEntry(
                    label: raftText(context, 'Rename'),
                    onPressed: () => setState(
                      () => edit = (_ConnectionEdit.rename, connection),
                    ),
                  ),
                  RaftMenuEntry(
                    label: raftText(
                      context,
                      isOAuth ? 'Reauthorize' : 'Replace key',
                    ),
                    onPressed: isOAuth
                        ? _openWeb
                        : () => setState(
                            () => edit = (_ConnectionEdit.replace, connection),
                          ),
                  ),
                  if (isOAuth) ...[
                    RaftMenuEntry(
                      label: raftText(context, 'Configure OAuth client'),
                      onPressed: _openWeb,
                    ),
                    if (connection.status != 'needs_auth')
                      RaftMenuEntry(
                        label: raftText(context, 'Sign out'),
                        onPressed: () => _remove(connection, signOut: true),
                      ),
                  ],
                  RaftMenuEntry(
                    label: raftText(context, 'Delete'),
                    onPressed: () => _remove(connection),
                  ),
                ],
              )
            : null,
      ),
    );
  }
}
