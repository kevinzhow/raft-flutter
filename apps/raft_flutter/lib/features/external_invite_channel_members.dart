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

/// The pinned "Invite people outside {server}" entry of the members page.
/// Web keeps it in the footer bar beside Add member, never in the roster
/// scroll area (ChannelMembers.tsx:1205-1217, `member-page-invite-outside`,
/// Mail icon, `size="lg" variant="outline" className="w-full"`).
///
/// It reads only the cached flag: [ChannelExternalInvites] owns the one
/// `/feature-flags/evaluate` call and reports the answer through
/// `onEnabledChanged`, so splitting the two surfaces adds no round trip.
class ChannelExternalInviteEntry extends StatefulWidget {
  const ChannelExternalInviteEntry({
    super.key,
    required this.workspace,
    required this.channel,
    this.onSent,
  });

  final WorkspaceController workspace;
  final RaftChannel channel;

  /// Invites were sent or members added: the Invited group reloads.
  final VoidCallback? onSent;

  @override
  State<ChannelExternalInviteEntry> createState() =>
      _ChannelExternalInviteEntryState();
}

class _ChannelExternalInviteEntryState
    extends State<ChannelExternalInviteEntry> {
  WorkspaceController get _w => widget.workspace;
  late final _identity = pageIdentity(_w);
  late final _api = ExternalInviteApi(_w.command);
  bool _atLimit = false, _opening = false;

  bool _limitRead = false;

  bool get _current => mounted && _identity == pageIdentity(_w);
  bool get _shouldCheckLimit =>
      _w.server?.string('plan') == 'free' &&
      !externalSlotHeldBy(widget.channel, _w.server?.id);

  /// The entry only renders once the flag is cached, so the first limit read
  /// is kicked off from build rather than initState.
  void _ensureLimitRead() {
    if (_limitRead || !_shouldCheckLimit) return;
    _limitRead = true;
    unawaited(_readLimit());
  }

  Future<bool> _readLimit() async {
    try {
      return _atLimit = await _api.atFreeLimit();
    } on RaftApiException {
      return _atLimit = false;
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
        await showExternalChannelLimit(context, _w, widget.channel.id);
        return;
      }
      if (!mounted || !_current) return;
      final result = await showExternalInviteDialog(
        context,
        _w,
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
      showExternalConnectionOutcomes(context, result, _w.servers);
      widget.onSent?.call();
    } finally {
      if (_current) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _w,
    builder: (context, _) {
      final current =
          _w.channels.where((row) => row.id == widget.channel.id).firstOrNull ??
          widget.channel;
      final enabled =
          cachedServerFlag(_w, RaftFeatureFlags.externalChannels) ?? false;
      if (!enabled || !externalInvitable(_w, current)) {
        return const SizedBox.shrink();
      }
      _ensureLimitRead();
      return RaftButton(
        key: const ValueKey('member-page-invite-outside'),
        label: raftFormat(context, 'Invite people outside {server}', {
          'server': _w.server?.name ?? '',
        }),
        glyph: RaftGlyph.mail,
        glyphSize: 14,
        uiVariant: RaftButtonVariant.outline,
        uiSize: RaftButtonSize.lg,
        expand: true,
        onPressed: _opening ? null : _open,
      );
    },
  );
}

class ChannelExternalInvites extends StatelessWidget {
  const ChannelExternalInvites({
    super.key,
    required this.workspace,
    required this.channel,
    this.search,
    this.revision = 0,
    this.onEnabledChanged,
  });

  final WorkspaceController workspace;
  final RaftChannel channel;
  final TextEditingController? search;

  /// Bumped by the page when the entry sent invites: the group reloads.
  final int revision;

  /// Reports the resolved `external_channels_v1` answer to the page so the
  /// footer entry can render from the cache.
  final ValueChanged<bool>? onEnabledChanged;

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
        revision: revision,
        onEnabledChanged: onEnabledChanged,
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
    this.revision = 0,
    this.onEnabledChanged,
  });
  final WorkspaceController workspace;
  final RaftChannel channel;
  final TextEditingController? search;
  final int revision;
  final ValueChanged<bool>? onEnabledChanged;

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
  bool _failed = false;
  int _readVersion = 0;
  final _busy = <String>{};

  bool get _current => mounted && _identity == pageIdentity(_workspace);
  bool get _canRead => _enabled || widget.channel.hasExternalRelation == true;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  @override
  void didUpdateWidget(_ChannelExternalInvites old) {
    super.didUpdateWidget(old);
    // The footer entry sent invites: pick the new ones up in place.
    if (widget.revision != old.revision && _canRead) unawaited(_load());
  }

  Future<void> _start() async {
    final enabled = await readExternalChannelFlag(_workspace);
    if (!mounted || !_current) return;
    setState(() => _enabled = enabled);
    widget.onEnabledChanged?.call(enabled);
    if (_canRead) unawaited(_load());
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
        // Web shows a failed read above the group, in its own `p-3` box
        // (ChannelMembers.tsx:729-743, :1119).
        if (_failed && _invites.isEmpty)
          Padding(
            padding: const EdgeInsets.all(12),
            child: RaftErrorBanner(
              raftText(context, "Couldn't load the invites."),
              onRetry: _load,
              retryLabel: 'Retry',
            ),
          ),
        // `MemberPageSection kind="invited"` (ChannelMembers.tsx:1120-1128).
        if (rows.isNotEmpty)
          RaftDialogSectionEyebrow(
            raftText(context, 'Invited'),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          ),
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
    // Web renders an invite as a ChannelMemberRow: a Mail IconTile, the email
    // with its state on the same baseline in hint ink, then the actions
    // (ExternalInviteRows.tsx:146-164). The row therefore carries the member
    // row's px-4 / gap-3 / min-h-16 geometry (channel_members_view.dart:1167).
    // A minimum, not a fixed height: the row grows with the text scale.
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 64),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            const RaftIconTile(glyph: RaftGlyph.mail),
            const SizedBox(width: 12),
            Expanded(child: _ExternalInviteRowLabel(email, subtitle)),
            // Web: a resend is a fresh send, so an invite that is connecting or
            // awaiting approval has none (ExternalInviteRows.tsx:52).
            if (_enabled &&
                row['connecting'] != true &&
                row['awaitingApproval'] != true)
              RaftButton(
                glyph: RaftGlyph.mail,
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
        ),
      ),
    );
  }
}

class _ExternalInviteRowLabel extends StatelessWidget {
  const _ExternalInviteRowLabel(this.email, this.subtitle);

  final String email, subtitle;

  /// Web puts the state after the email on one line
  /// (ExternalInviteRows.tsx:157-162: `flex items-baseline gap-1.5`, the
  /// state `text-caption font-normal text-foreground-hint`).
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final grows = RaftScaled.grows(context);
    final name = Text(
      email,
      maxLines: grows ? null : 1,
      overflow: grows ? TextOverflow.clip : TextOverflow.ellipsis,
      style: t.scale(RaftTypeScale.subhead, color: t.ui.foreground),
    );
    final state = Text(
      subtitle,
      style: t.scale(RaftTypeScale.caption, color: t.ui.foregroundHint),
    );
    // Side by side at the default size, stacked once the text grows, so the
    // email keeps the row's full width instead of wrapping one letter a line.
    if (grows) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [name, state],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Flexible(child: name),
        const SizedBox(width: 6),
        state,
      ],
    );
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
