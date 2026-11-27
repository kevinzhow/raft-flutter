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

/// One channel's open external invites on its members page (Web
/// `useExternalInviteAccess`, `useChannelExternalInvites` and the
/// ExternalInviteRows actions). [ChannelMembers] owns one per channel; it
/// starts over when the page identity or the viewer's right to manage the
/// channel's invites changes, and notifies when what the page shows changes.
class ChannelExternalInvites extends ChangeNotifier {
  ChannelExternalInvites(this._workspace, this._initial) {
    _workspace.addListener(_workspaceChanged);
    _workspaceChanged();
  }

  final WorkspaceController _workspace;
  final RaftChannel _initial;
  late final _api = ExternalInviteApi(_workspace.command);

  RaftChannel get _channel =>
      _workspace.channels.where((row) => row.id == _initial.id).firstOrNull ??
      _initial;
  String get _snapshot => 'external-invites:${_initial.id}';

  /// The page identity and manage right the state below belongs to.
  (String, bool)? _scope;
  (bool, bool, String?)? _shown;
  int _epoch = 0, _readVersion = 0;
  bool _disposed = false, _enabled = false, _failed = false;
  bool _atLimit = false, _opening = false;
  List<ExternalJson> _invites = const [];
  final _busy = <String>{};

  bool get _manageable => _scope?.$2 ?? false;

  /// Web `externalInviteAccess`: may send invites (the footer button, Resend).
  bool get _canInvite => _manageable && _enabled;

  /// Web `useExternalInviteManagement`: sees the Invited group.
  bool get _canManage =>
      _manageable && (_enabled || _channel.hasExternalRelation == true);
  bool get _shouldCheckLimit =>
      _workspace.server?.string('plan') == 'free' &&
      !externalSlotHeldBy(_channel, _workspace.server?.id);
  bool _live(int epoch) =>
      !_disposed && epoch == _epoch && _scope?.$1 == pageIdentity(_workspace);

  void _workspaceChanged() {
    final scope = (
      pageIdentity(_workspace),
      externalInvitable(_workspace, _channel),
    );
    final restart = scope != _scope;
    if (restart) {
      _scope = scope;
      final epoch = ++_epoch;
      _enabled =
          cachedServerFlag(_workspace, RaftFeatureFlags.externalChannels) ??
          false;
      _invites = externalRows(
        readPageSnapshot(_workspace, _snapshot)?['invites'],
      );
      _failed = _atLimit = _opening = false;
      _busy.clear();
      if (scope.$2) unawaited(_start(epoch));
    }
    final shown = (_canInvite, _canManage, _workspace.server?.name);
    if (restart || shown != _shown) {
      final managed = _shown?.$2 ?? false;
      _shown = shown;
      if (!restart && !managed && _canManage) unawaited(_load());
      _changed();
    }
  }

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _start(int epoch) async {
    final enabled = await readExternalChannelFlag(_workspace);
    if (!_live(epoch)) return;
    _enabled = enabled;
    _shown = (_canInvite, _canManage, _workspace.server?.name);
    _changed();
    if (_canManage) unawaited(_load());
    if (_canInvite && _shouldCheckLimit) unawaited(_readLimit());
  }

  Future<bool> _readLimit() async {
    try {
      return _atLimit = await _api.atFreeLimit();
    } on RaftApiException {
      return _atLimit = false;
    }
  }

  Future<void> _load() async {
    final epoch = _epoch, version = ++_readVersion;
    final identity = pageIdentity(_workspace);
    try {
      final result = await _api.channelInvites(_initial.id);
      if (!_live(epoch) || version != _readVersion) return;
      final invites = externalRows(result['invites']);
      writePageSnapshot(_workspace, _snapshot, identity, {'invites': invites});
      _failed = false;
      _invites = invites;
      _changed();
    } catch (_) {
      if (_live(epoch) && version == _readVersion) {
        _failed = true;
        _changed();
      }
    }
  }

  Future<void> _open(BuildContext context) async {
    if (_opening) return;
    final epoch = _epoch;
    _opening = true;
    _changed();
    try {
      if (_shouldCheckLimit &&
          _atLimit &&
          await _readLimit() &&
          context.mounted &&
          _live(epoch)) {
        await showExternalChannelLimit(context, _workspace, _initial.id);
        return;
      }
      if (!context.mounted || !_live(epoch)) return;
      final result = await showExternalInviteDialog(
        context,
        _workspace,
        _channel,
      );
      if (!context.mounted || result == null || !_live(epoch)) return;
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
      if (_live(epoch)) {
        _opening = false;
        _changed();
      }
    }
  }

  Future<void> _manage(
    BuildContext context,
    ExternalJson row, {
    required bool withdraw,
  }) async {
    final id = externalString(row['id']), email = externalString(row['email']);
    if (_busy.contains(id)) return;
    final epoch = _epoch;
    Future<void> run() async {
      _busy.add(id);
      _changed();
      try {
        await (withdraw
            ? _api.revoke(_initial.id, id)
            : _api.resend(_initial.id, id));
        if (!context.mounted || !_live(epoch)) return;
        if (withdraw) {
          _invites = _invites.where((row) => row['id'] != id).toList();
          _changed();
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
        if (!context.mounted || !_live(epoch)) return;
        if (withdraw) throw StateError(externalChannelFailure(context, error));
        showRaftToast(context, externalChannelFailure(context, error));
      } finally {
        if (_live(epoch)) {
          _busy.remove(id);
          _changed();
        }
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

  /// The Invited group's rows (Web ExternalInviteRow).
  List<RaftMemberRowData> rows(BuildContext context) => [
    if (_canManage)
      for (final row in _invites) _row(context, row),
  ];

  /// The "Couldn't load the invites." banner's Retry, while none are known.
  VoidCallback? get retry =>
      _canManage && _failed && _invites.isEmpty ? _load : null;

  /// "Invite people outside {server}" under Add member.
  ({String server, VoidCallback? onPressed})? inviteOutside(
    BuildContext context,
  ) => _canInvite
      ? (
          server: _workspace.server?.name ?? '',
          onPressed: _opening ? null : () => unawaited(_open(context)),
        )
      : null;

  RaftMemberRowData _row(BuildContext context, ExternalJson row) {
    final id = externalString(row['id']), email = externalString(row['email']);
    final busy = _busy.contains(id);
    final connecting = row['connecting'] == true;
    final awaiting = row['awaitingApproval'] == true;
    final revocable = row['revocable'] != false;
    final expiry = DateTime.tryParse(externalString(row['expiresAt']));
    final days = expiry == null
        ? 1
        : (expiry.difference(DateTime.now()).inHours / 24).ceil().clamp(1, 365);
    return RaftMemberRowData(
      testId: 'external-invite-$id',
      label: email,
      searchText: email,
      human: true,
      avatar: const RaftIconTile(glyph: RaftGlyph.mail),
      titleNote: connecting
          ? raftText(context, 'Connecting a server')
          : awaiting
          ? raftText(context, 'Waiting for approval')
          : raftFormat(
              context,
              days == 1 ? '{count} day left' : '{count} days left',
              {'count': days},
            ),
      actions: [
        // A resend replaces a plain pending invite; one connecting a server or
        // waiting for an approver belongs to that flow.
        if (_canInvite && !connecting && !awaiting)
          RaftMemberRowAction(
            glyph: RaftGlyph.mail,
            tooltip: raftText(context, 'Resend invite'),
            semanticLabel: raftFormat(context, 'Resend the invite to {email}', {
              'email': email,
            }),
            onPressed: busy
                ? null
                : () => unawaited(_manage(context, row, withdraw: false)),
          ),
        RaftMemberRowAction(
          glyph: RaftGlyph.x,
          tooltip: raftText(
            context,
            revocable ? 'Withdraw invite' : 'You can withdraw this invite once its server finishes connecting.',
          ),
          semanticLabel: raftFormat(context, 'Withdraw the invite to {email}', {
            'email': email,
          }),
          onPressed: busy || !revocable
              ? null
              : () => unawaited(_manage(context, row, withdraw: true)),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _workspace.removeListener(_workspaceChanged);
    super.dispose();
  }
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
