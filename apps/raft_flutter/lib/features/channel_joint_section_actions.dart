import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/external_invite_api.dart';
import '../data/workspace_controller.dart';
import '../platform/web_billing.dart' show openWebBilling;
import 'external_invite_channel_members.dart';
import 'external_invite_page_frame.dart';
import 'management_support.dart';
import 'workspace_web_billing.dart';

bool jointHostExternal(WorkspaceController workspace, RaftChannel channel) =>
    channel.type == 'joint' &&
    channel.string('jointRole') == 'host' &&
    cachedServerFlag(workspace, 'external_channels_v1') == true;

Future<bool?> confirmJointServerDisconnect(
  BuildContext context,
  WorkspaceController workspace,
  RaftChannel channel,
  String id,
  String name,
) => RaftConfirmDialog.show(
  context,
  RaftConfirmDialog(
    surfaceKey: const ValueKey('joint-disconnect-dialog'),
    title: raftFormat(context, 'Disconnect {server}?', {'server': name}),
    message: raftFormat(
      context,
      "{server}'s members and agents will leave #{channel}, and it will be removed from that server; everyone else keeps the channel and its history.",
      {'server': name, 'channel': channel.name},
    ),
    confirmLabel: raftFormat(context, 'Disconnect {server}', {'server': name}),
    confirmKey: const ValueKey(
      'channel-settings-joint-server-disconnect-confirm',
    ),
    loadingLabel: raftText(context, 'Disconnecting…'),
    initialFocusCancel: true,
    onConfirm: () async {
      try {
        await ExternalInviteApi(workspace.command).disconnect(channel.id, id);
      } on RaftApiException {
        if (!context.mounted) return;
        throw StateError(
          raftFormat(context, "Couldn't disconnect {server}. Try again.", {
            'server': name,
          }),
        );
      }
      try {
        await workspace.refreshChannel(channel.id);
      } on RaftApiException {
        // The server has also sent channel:updated to both sides.
      }
      if (context.mounted) {
        showRaftToast(
          context,
          raftFormat(context, 'Disconnected {server} from #{channel}', {
            'server': name,
            'channel': channel.name,
          }),
          tone: RaftToastRecipeTone.success,
        );
      }
    },
  ),
);

typedef JointConnectRow = ({RaftRecord server, bool connected, bool eligible});

List<JointConnectRow> jointConnectRows(WorkspaceController w, RaftChannel c) {
  if (c.archived || !c.flag('joined') || c.name == 'all') return const [];
  final rows = externalRows(c.json['jointServers']);
  if (c.type != 'private' &&
      (c.type != 'joint' || !rows.any((row) => row['status'] == 'active'))) {
    return const [];
  }
  final host =
      rows.where((row) => row['role'] == 'host').firstOrNull?['serverId'] ??
      w.server?.id;
  final connected = rows
      .where((row) => row['status'] == 'active')
      .map((row) => row['serverId'])
      .toSet();
  final result = <JointConnectRow>[
    for (final server in w.servers)
      if (server.id != host &&
          server.string('role') != 'guest' &&
          !const {'community', 'community-zh'}.contains(server.string('slug')))
        (
          server: server,
          connected: connected.contains(server.id),
          eligible:
              !connected.contains(server.id) &&
              const {'owner', 'admin'}.contains(server.string('role')),
        ),
  ];
  int rank(JointConnectRow row) => row.eligible
      ? 0
      : row.connected
      ? 1
      : 2;
  return result..sort((a, b) {
    final priority = rank(a).compareTo(rank(b));
    return priority == 0
        ? a.server.name.toLowerCase().compareTo(b.server.name.toLowerCase())
        : priority;
  });
}

class JointConnectMenu extends StatelessWidget {
  const JointConnectMenu({
    super.key,
    required this.workspace,
    required this.channel,
    required this.rows,
  });

  final WorkspaceController workspace;
  final RaftChannel channel;
  final List<JointConnectRow> rows;

  @override
  Widget build(BuildContext context) {
    final label = raftText(context, 'More actions');
    return RaftDropdownMenu(
      key: const ValueKey('channel-settings-joint-servers-menu'),
      label: label,
      align: RaftDropdownAlign.end,
      triggerBuilder: (context, focusNode, open) => RaftButton(
        glyph: RaftGlyph.ellipsisVertical,
        focusNode: focusNode,
        tooltip: label,
        semanticLabel: label,
        uiVariant: RaftButtonVariant.ghost,
        uiSize: RaftButtonSize.iconMd,
        onPressed: open,
      ),
      entries: [
        RaftMenuEntry(
          label: raftText(context, 'Connect your servers'),
          glyph: RaftGlyph.plug,
          onPressed: () =>
              showJointConnectDialog(context, workspace, channel, rows),
        ),
      ],
    );
  }
}

Future<void> showJointConnectDialog(
  BuildContext context,
  WorkspaceController workspace,
  RaftChannel channel,
  List<JointConnectRow> rows,
) async {
  final result = await showRaftForm<ExternalJson>(
    context,
    dismissible: false,
    dragDismissible: false,
    guardUnsaved: false,
    builder: (_) => _JointConnectDialog(workspace, channel, rows),
  );
  if (result != null && context.mounted) {
    showExternalConnectionOutcomes(context, result, workspace.servers);
  }
}

class _JointConnectDialog extends StatefulWidget {
  const _JointConnectDialog(this.workspace, this.channel, this.rows);

  final WorkspaceController workspace;
  final RaftChannel channel;
  final List<JointConnectRow> rows;

  @override
  State<_JointConnectDialog> createState() => _JointConnectDialogState();
}

class _JointConnectDialogState extends State<_JointConnectDialog> {
  late final _api = ExternalInviteApi(widget.workspace.command);
  final _selected = <String>{}, _done = <String>{};
  Map<String, ExternalJson> _limits = const {};
  bool _busy = false, _closed = false;
  List<String> _lines = const [];

  @override
  void initState() {
    super.initState();
    unawaited(_loadLimits());
  }

  Future<void> _loadLimits() async {
    try {
      final rows = await _api.memberServers(widget.channel.id);
      if (mounted) {
        setState(() {
          _limits = {for (final row in rows) externalString(row['id']): row};
          _selected.removeWhere((id) => _limits[id]?['atLimit'] == true);
        });
      }
    } on RaftApiException {
      // Older servers lack the precheck. The mutation still enforces limits.
    }
  }

  Future<void> _submit() async {
    if (_busy || _selected.isEmpty) return;
    setState(() {
      _busy = true;
      _lines = const [];
    });
    try {
      final result = await _api.connectMemberServers(
        widget.channel.id,
        _selected.toList(),
      );
      if (!mounted) return;
      final connected = externalRows(result['servers']);
      final refused = connected
          .where((row) => row['state'] == 'refused')
          .toList();
      final successes = connected
          .where((row) => row['state'] != 'refused')
          .toList();
      if (successes.isNotEmpty) unawaited(_refresh());
      if (refused.isEmpty ||
          refused.every((row) => row['code'] == 'already_connected')) {
        Navigator.of(context).pop(result);
      } else {
        setState(() {
          _done.addAll(successes.map((row) => externalString(row['serverId'])));
          _selected.removeAll(_done);
          _lines = [
            for (final row in refused)
              raftFormat(
                context,
                switch (row['code']) {
                  'already_connected' => '{target} is already connected.',
                  'server_admin_required' => "You're no longer an owner or admin of {target}, so it wasn't connected.",
                  'membership_changed' => 'Your membership in {channel} changed while this was open. Check the servers and connect again.',
                  _ => "{server} wasn't connected",
                },
                {
                  'target': _name(row['serverId']),
                  'server': _name(row['serverId']),
                  'channel': '#${widget.channel.name}',
                },
              ),
          ];
        });
      }
    } on RaftApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _closed = error.status == 403 || error.status == 404;
        _lines = [
          if (error.code == 'guest_has_computer')
            raftFormat(
              context,
              "You've connected a computer to {host}. Disconnect it there first, then connect your server.",
              {'host': _hostName},
            )
          else if (_closed)
            raftFormat(
              context,
              "You can't connect servers to {channel} anymore.",
              {'channel': '#${widget.channel.name}'},
            )
          else
            raftText(context, 'Something went wrong. Try again.'),
        ];
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refresh() async {
    try {
      await widget.workspace.refreshChannel(widget.channel.id);
    } on RaftApiException {
      // The channel update event can still reconcile the row.
    }
  }

  String get _hostName => externalString(
    externalRows(widget.channel.json['jointServers'])
            .where((row) => row['role'] == 'host')
            .firstOrNull?['serverName'] ??
        widget.workspace.server?.name,
  );
  String _name(Object? id) =>
      widget.rows
          .where((row) => row.server.id == id)
          .firstOrNull
          ?.server
          .name ??
      '';

  @override
  Widget build(BuildContext context) => RaftDialog.card(
    key: const ValueKey('member-connect-dialog'),
    title: raftText(context, 'Connect your servers'),
    description: raftFormat(
      context,
      "Servers where you're an owner or admin connect now. {host}, the host, isn't asked. A message in the channel says the server was connected.",
      {'host': _hostName},
    ),
    onClose: () => Navigator.of(context).maybePop(),
    actions: Wrap(
      spacing: RaftSpace.x2,
      children: [
        RaftButton(
          label: raftText(context, 'Cancel'),
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
        ),
        RaftButton(
          label: _busy
              ? raftText(context, 'Connecting…')
              : _selected.length < 2
              ? raftText(context, 'Connect')
              : raftFormat(context, 'Connect {count} servers', {
                  'count': _selected.length,
                }),
          tone: RaftButtonRecipeVariant.accent,
          onPressed: _busy || _closed || _selected.isEmpty ? null : _submit,
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final line in _lines) RaftErrorBanner(line),
        for (final row in widget.rows) ...[
          RaftCheckboxRow(
            title: row.server.name,
            description: raftText(
              context,
              _done.contains(row.server.id)
                  ? 'Connected just now'
                  : row.connected
                  ? 'Already connected'
                  : !row.eligible
                  ? 'Only an owner or admin can connect it'
                  : _limits[row.server.id]?['atLimit'] == true
                  ? 'Free · in another external channel'
                  : row.server.json['role'] == 'owner'
                  ? "You're the owner"
                  : "You're an admin",
            ),
            value: _selected.contains(row.server.id),
            onChanged:
                _busy ||
                    _closed ||
                    !row.eligible ||
                    _done.contains(row.server.id) ||
                    _limits[row.server.id]?['atLimit'] == true
                ? null
                : (value) => setState(() {
                    if (value) {
                      _selected.add(row.server.id);
                    } else {
                      _selected.remove(row.server.id);
                    }
                  }),
          ),
          if (_limits[row.server.id]?['atLimit'] == true)
            _limits[row.server.id]?['canUpgrade'] == true &&
                    row.server.string('role') == 'owner'
                ? externalInviteButton(
                    raftFormat(context, 'Upgrade {server}', {
                      'server': row.server.name,
                    }),
                    () => upgradeExternalServerOrToast(
                      context,
                      (id) => openWebBilling(
                        coordinator: widget.workspace.client.origin,
                        slug: row.server.string('slug'),
                        gate: WebBillingGate.externalChannelFreeLimit,
                      ),
                      row.server.id,
                    ),
                  )
                : RaftAuthNote(
                    raftFormat(context, 'Ask an owner of {server} to upgrade', {
                      'server': row.server.name,
                    }),
                  ),
        ],
        if (widget.channel.type == 'private')
          RaftAuthNote(
            raftFormat(
              context,
              '{channel} becomes a channel shared with other servers, and the servers you connect see its earlier messages.',
              {'channel': '#${widget.channel.name}'},
            ),
          ),
      ],
    ),
  );
}
