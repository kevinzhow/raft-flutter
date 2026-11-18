import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/external_invite_api.dart';
import '../data/feature_flag_client_facts.dart';
import '../data/workspace_controller.dart';
import 'external_invite_channel_dialog.dart';
import 'management_support.dart';
import 'limit_notice.dart';
import 'workspace_web_billing.dart';

bool externalInvitable(WorkspaceController workspace, RaftChannel channel) =>
    const {'owner', 'admin'}.contains(workspace.server?.string('role')) &&
    workspace.server != null &&
    !channel.archived &&
    channel.name != 'all' &&
    (channel.string('serverId').isEmpty ||
        channel.string('serverId') == workspace.server?.id) &&
    (channel.type == 'joint'
        ? channel.string('jointRole') == 'host'
        : const {'channel', 'private'}.contains(channel.type));

bool externalSlotHeldBy(RaftChannel channel, String? serverId) =>
    !channel.archived &&
    (channel.string('serverId').isEmpty ||
        channel.string('serverId') == serverId) &&
    (channel.hasExternalRelation == true ||
        channel.type == 'joint' &&
            (channel.json['jointServers'] == null ||
                externalRows(channel.json['jointServers']).any(
                  (row) =>
                      row['status'] == 'active' && row['serverId'] != serverId,
                )));

Future<bool> readExternalChannelFlag(WorkspaceController w) async {
  final scope = pageIdentity(w), serverId = w.server?.id;
  if (serverId == null) return false;
  try {
    final answer = await w.command(
      'POST',
      '/feature-flags/evaluate',
      data: featureFlagEvaluateBody(
        keys: [RaftFeatureFlags.externalChannels],
        serverId: serverId,
      ),
    );
    final enabled = externalRows(externalObject(answer)['evaluations']).any(
      (row) =>
          row['key'] == RaftFeatureFlags.externalChannels &&
          row['enabled'] == true,
    );
    rememberServerFlag(w, RaftFeatureFlags.externalChannels, enabled, scope);
    return enabled;
  } on RaftApiException {
    return cachedServerFlag(w, RaftFeatureFlags.externalChannels) ?? false;
  }
}

class ChannelExternalInvites extends StatelessWidget {
  const ChannelExternalInvites({
    super.key,
    required this.workspace,
    required this.channel,
    this.search,
  });

  final WorkspaceController workspace;
  final RaftChannel channel;
  final TextEditingController? search;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: workspace,
    builder: (context, _) {
      final current =
          workspace.channels.where((row) => row.id == channel.id).firstOrNull ??
          channel;
      if (!externalInvitable(workspace, current)) {
        return const SizedBox.shrink();
      }
      return _ChannelExternalInvites(
        key: ValueKey((workspace, pageIdentity(workspace), current.id)),
        workspace: workspace,
        channel: current,
        search: search,
      );
    },
  );
}

class _ChannelExternalInvites extends StatefulWidget {
  const _ChannelExternalInvites({
    super.key,
    required this.workspace,
    required this.channel,
    this.search,
  });
  final WorkspaceController workspace;
  final RaftChannel channel;
  final TextEditingController? search;

  @override
  State<_ChannelExternalInvites> createState() =>
      _ChannelExternalInvitesState();
}

class _ChannelExternalInvitesState extends State<_ChannelExternalInvites> {
  WorkspaceController get _workspace => widget.workspace;
  String get _channelId => widget.channel.id;
  String get _snapshot => 'external-invites:$_channelId';
  late final _identity = pageIdentity(_workspace);
  late final _api = ExternalInviteApi(_workspace.command);
  late bool _enabled =
      cachedServerFlag(_workspace, RaftFeatureFlags.externalChannels) ?? false;
  late List<ExternalJson> _invites = externalRows(
    readPageSnapshot(_workspace, _snapshot)?['invites'],
  );
  bool _failed = false, _atLimit = false, _opening = false;
  int _readVersion = 0;
  final _busy = <String>{};

  bool get _current => mounted && _identity == pageIdentity(_workspace);
  bool get _canRead => _enabled || widget.channel.hasExternalRelation == true;
  bool get _shouldCheckLimit =>
      _workspace.server?.string('plan') == 'free' &&
      !externalSlotHeldBy(widget.channel, _workspace.server?.id);

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  Future<void> _start() async {
    final enabled = await readExternalChannelFlag(_workspace);
    if (!mounted || !_current) return;
    setState(() => _enabled = enabled);
    if (_canRead) unawaited(_load());
    if (_enabled && _shouldCheckLimit) unawaited(_readLimit());
  }

  Future<bool> _readLimit() async {
    try {
      return _atLimit = await _api.atFreeLimit();
    } on RaftApiException {
      return _atLimit = false;
    }
  }

  Future<void> _load() async {
    final version = ++_readVersion;
    try {
      final result = await _api.channelInvites(_channelId);
      if (!_current || version != _readVersion) return;
      final invites = externalRows(result['invites']);
      writePageSnapshot(_workspace, _snapshot, _identity, {'invites': invites});
      setState(() {
        _failed = false;
        _invites = invites;
      });
    } catch (_) {
      if (_current && version == _readVersion) setState(() => _failed = true);
    }
  }

  Future<void> _open() async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      if (_shouldCheckLimit &&
          _atLimit &&
          await _readLimit() &&
          mounted &&
          _current) {
        await showExternalChannelLimit(context, _workspace, _channelId);
        return;
      }
      if (!mounted || !_current) return;
      final result = await showExternalInviteDialog(
        context,
        _workspace,
        widget.channel,
      );
      if (!mounted || result == null || !_current) return;
      final sent = externalRows(result['sent']).length;
      final added = (result['added'] as List?)?.length ?? 0;
      if (sent > 0) {
        showRaftToast(
          context,
          raftFormat(
            context,
            sent == 1 ? 'Sent {count} invite' : 'Sent {count} invites',
            {'count': sent},
          ),
          tone: RaftToastRecipeTone.success,
        );
      }
      if (added > 0) {
        showRaftToast(
          context,
          raftFormat(
            context,
            added == 1
                ? 'Added {count} member to the channel'
                : 'Added {count} members to the channel',
            {'count': added},
          ),
          tone: RaftToastRecipeTone.success,
        );
      }
      if (result['serversFailed'] == true) {
        showRaftToast(
          context,
          "The invites were sent, but your servers weren't connected. Try connecting them again.",
        );
      }
      showExternalConnectionOutcomes(context, result, _workspace.servers);
      unawaited(_load());
    } finally {
      if (_current) setState(() => _opening = false);
    }
  }

  Future<void> _manage(ExternalJson row, {required bool withdraw}) async {
    final id = externalString(row['id']), email = externalString(row['email']);
    if (_busy.contains(id)) return;
    Future<void> run() async {
      setState(() => _busy.add(id));
      try {
        await (withdraw
            ? _api.revoke(_channelId, id)
            : _api.resend(_channelId, id));
        if (!mounted || !_current) return;
        if (withdraw) {
          setState(
            () => _invites = _invites.where((row) => row['id'] != id).toList(),
          );
        }
        showRaftToast(
          context,
          raftFormat(
            context,
            withdraw
                ? 'Withdrew the invite to {email}'
                : 'Sent a new invite to {email}',
            {'email': email},
          ),
          tone: RaftToastRecipeTone.success,
        );
        await _load();
      } catch (error) {
        if (!mounted || !_current) return;
        if (withdraw) throw StateError(externalChannelFailure(context, error));
        showRaftToast(context, externalChannelFailure(context, error));
      } finally {
        if (_current) setState(() => _busy.remove(id));
      }
    }

    if (withdraw) {
      await RaftConfirmDialog.show(
        context,
        RaftConfirmDialog(
          surfaceKey: const ValueKey('external-invite-withdraw-dialog'),
          title: raftText(context, 'Withdraw invite?'),
          message: raftFormat(
            context,
            'The invite link sent to {email} stops working. You can invite them again later.',
            {'email': email},
          ),
          confirmLabel: raftText(context, 'Withdraw'),
          loadingLabel: raftText(context, 'Withdrawing…'),
          confirmVariant: RaftButtonRecipeVariant.warning,
          onConfirm: run,
        ),
      );
    } else {
      await run();
    }
  }

  @override
  Widget build(BuildContext context) {
    final search = widget.search;
    return search == null
        ? _build(context, '')
        : ValueListenableBuilder(
            valueListenable: search,
            builder: (context, value, _) =>
                _build(context, value.text.trim().toLowerCase()),
          );
  }

  Widget _build(BuildContext context, String query) {
    if (!_canRead) return const SizedBox.shrink();
    final rows = _invites.where(
      (row) => externalString(row['email']).toLowerCase().contains(query),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_enabled)
          RaftButton(
            label: raftFormat(context, 'Invite people outside {server}', {
              'server': _workspace.server?.name ?? '',
            }),
            onPressed: _opening ? null : _open,
            tone: RaftButtonRecipeVariant.outline,
          ),
        if (_failed && _invites.isEmpty)
          RaftErrorBanner(
            raftText(context, "Couldn't load the invites."),
            onRetry: _load,
            retryLabel: 'Retry',
          ),
        if (rows.isNotEmpty)
          RaftDialogSectionEyebrow(raftText(context, 'Invited')),
        for (final row in rows) _inviteRow(context, row),
      ],
    );
  }

  Widget _inviteRow(BuildContext context, ExternalJson row) {
    final email = externalString(row['email']);
    final busy = _busy.contains(row['id']);
    final expiry = DateTime.tryParse(externalString(row['expiresAt']));
    final days = expiry == null
        ? 1
        : (expiry.difference(DateTime.now()).inHours / 24).ceil().clamp(1, 365);
    final subtitle = row['connecting'] == true
        ? raftText(context, 'Connecting a server')
        : row['awaitingApproval'] == true
        ? raftText(context, 'Waiting for approval')
        : raftFormat(
            context,
            days == 1 ? '{count} day left' : '{count} days left',
            {'count': days},
          );
    return Row(
      children: [
        Expanded(child: _ExternalInviteRowLabel(email, subtitle)),
        if (_enabled && row['connecting'] != true)
          RaftButton(
            glyph: RaftGlyph.refreshCw,
            uiSize: RaftButtonSize.iconMd,
            uiVariant: RaftButtonVariant.ghost,
            tooltip: raftText(context, 'Resend invite'),
            onPressed: busy ? null : () => _manage(row, withdraw: false),
          ),
        RaftButton(
          glyph: RaftGlyph.x,
          uiSize: RaftButtonSize.iconMd,
          uiVariant: RaftButtonVariant.ghost,
          tooltip: raftText(
            context,
            row['revocable'] == false
                ? 'You can withdraw this invite once its server finishes connecting.'
                : 'Withdraw invite',
          ),
          onPressed: busy || row['revocable'] == false
              ? null
              : () => _manage(row, withdraw: true),
        ),
      ],
    );
  }
}

class _ExternalInviteRowLabel extends StatelessWidget {
  const _ExternalInviteRowLabel(this.email, this.subtitle);

  final String email, subtitle;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [Text(email), RaftAuthNote(subtitle)],
  );
}

Future<void> showExternalChannelLimit(
  BuildContext context,
  WorkspaceController w,
  String exceptChannel,
) {
  const gate = WebBillingGate.externalChannelFreeLimit;
  final held = w.channels
      .where(
        (channel) =>
            channel.id != exceptChannel &&
            externalSlotHeldBy(channel, w.server?.id),
      )
      .toList();
  final copy = limitNoticeCopy(
    context,
    w,
    gate: gate,
    external: ExternalLimitNotice.slot(
      channel: held.length == 1 ? '#${held.single.name}' : null,
    ),
  );
  return showLimitNotice(
    context,
    w,
    gate: gate,
    title: copy.title,
    hint: copy.hint,
  );
}

void showExternalConnectionOutcomes(
  BuildContext context,
  ExternalJson result,
  List<RaftRecord> servers,
) {
  for (final row in externalRows(result['servers'])) {
    final id = row['serverId'];
    final name =
        servers.where((server) => server.id == id).firstOrNull?.name ?? '';
    final status = row['state'];
    final copy = switch (status) {
      'connected' => 'Connected {server}',
      'connecting' => 'Connecting {target}',
      _ => "{server} wasn't connected",
    };
    showRaftToast(
      context,
      raftFormat(context, copy, {'server': name, 'target': name}),
      tone: status == 'refused'
          ? RaftToastRecipeTone.error
          : RaftToastRecipeTone.success,
    );
  }
}
