import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/external_invite_api.dart';
import '../data/workspace_controller.dart';
import 'external_invite_page_frame.dart';
import 'management_support.dart' show pageIdentity;
import 'workspace_web_billing.dart';

Future<ExternalJson?> showExternalInviteDialog(
  BuildContext context,
  WorkspaceController workspace,
  RaftChannel channel,
) => showRaftForm<ExternalJson>(
  context,
  dismissible: false,
  dragDismissible: false,
  guardUnsaved: false,
  builder: (_) => _ExternalInviteDialog(workspace, channel),
);

Future<ExternalJson?> showNewExternalChannelInvites(
  BuildContext context,
  WorkspaceController workspace,
  Future<RaftChannel> Function() createChannel, {
  String? channelName,
  Widget? members,
}) => showRaftForm<ExternalJson>(
  context,
  dismissible: false,
  dragDismissible: false,
  guardUnsaved: false,
  builder: (_) => _ExternalInviteDialog(
    workspace,
    null,
    createChannel: createChannel,
    channelName: channelName,
    members: members,
  ),
);

String externalChannelFailure(BuildContext context, Object error) {
  final copy = switch (externalErrorCode(error)) {
    'daily_cap' => 'This server has sent as many external invites as it can today. Try again tomorrow.',
    'free_external_limit' => 'On the Free plan, a server can share one channel with people outside it. Upgrade to Pro to invite people to more.',
    'channel_full' => 'This channel is full. Withdraw an open invite or remove a guest to make room.',
    'external_members_keep_private' => 'This channel has guests, guest servers or pending invites, so it has to stay private.',
    'channel_membership_required' => 'Join this channel first. Inviting people outside the server makes it private, and only its members can do that.',
    'make_private_required' =>
      'Make the channel private before you invite people outside the server.',
    'channel_archived' => 'This channel is archived.',
    'channel_not_invitable' => 'People outside the server can be invited only to regular channels and external channels this server hosts.',
    'forbidden' => 'Only server admins can invite people outside the server.',
    'connecting' =>
      "A server is being connected to this channel. Try again once it's done.",
    'invite_not_pending' =>
      'This invite was already accepted, withdrawn or has expired.',
    'invalid_input' => 'Enter between 1 and {max} email addresses.',
    'not_found' => "This channel can't take external invites right now.",
    _ => switch (externalErrorStatus(error)) {
      429 => 'This server has sent as many external invites as it can today. Try again tomorrow.',
      404 => "This channel can't take external invites right now.",
      403 => 'Only server admins can invite people outside the server.',
      _ => 'Something went wrong. Try again.',
    },
  };
  return raftFormat(context, copy, {'max': 20});
}

class _ExternalInviteDialog extends StatefulWidget {
  const _ExternalInviteDialog(
    this.workspace,
    this.channel, {
    this.createChannel,
    this.channelName,
    this.members,
  });

  final WorkspaceController workspace;
  final RaftChannel? channel;
  final Future<RaftChannel> Function()? createChannel;
  final String? channelName;
  final Widget? members;

  @override
  State<_ExternalInviteDialog> createState() => _ExternalInviteDialogState();
}

class _ExternalInviteDialogState extends State<_ExternalInviteDialog> {
  late final _api = ExternalInviteApi(widget.workspace.command);
  late final _serverName = widget.workspace.server?.name ?? '';
  late final String _scope;
  late final _makePrivate = widget.channel?.type == 'channel';
  late RaftChannel? _channel = widget.channel;
  final _emails = TextEditingController();
  final _selectedServers = <String>{};
  List<ExternalJson> _servers = const [];
  bool _busy = false;
  ExternalJson? _preview;
  String _serverSearch = '';
  Object? _error;

  List<String> get _entries => _emails.text
      .trim()
      .split(RegExp(r'[,;\s]+'))
      .where((e) => e.isNotEmpty)
      .toList();

  @override
  void initState() {
    super.initState();
    _scope = pageIdentity(widget.workspace);
    unawaited(_readServers());
  }

  @override
  void dispose() {
    _emails.dispose();
    super.dispose();
  }

  Future<void> _readServers() async {
    try {
      final rows = await _api.ownServers();
      final connected = externalRows(_channel?.json['jointServers'])
          .where((row) => row['status'] == 'active')
          .map((row) => row['serverId'])
          .toSet();
      if (mounted) {
        setState(
          () => _servers = rows
              .where((row) => !connected.contains(row['id']))
              .toList(),
        );
      }
    } on RaftApiException {
      // The dialog can still send email when the optional list is unavailable.
    }
  }

  Future<void> _perform(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_scope != pageIdentity(widget.workspace)) {
        throw const RaftUserError('Server access changed. Reopen this form.');
      }
      await action();
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _review() async {
    final entries = _entries;
    if (entries.length > 20 || entries.isEmpty && _selectedServers.isEmpty) {
      return;
    }
    await _perform(() async {
      final preview = entries.isEmpty
          ? <String, dynamic>{}
          : await _api.previewEmails(_channel?.id, entries);
      if (mounted) setState(() => _preview = preview);
    });
  }

  List<String> _addresses(String key) =>
      (_preview?[key] as List?)?.whereType<String>().toList() ?? const [];

  Future<void> _send() => _perform(() async {
    final addresses = [..._addresses('valid'), ..._addresses('alreadyMembers')];
    _channel ??= await widget.createChannel!();
    final channelId = _channel!.id;
    final result = addresses.isEmpty
        ? <String, dynamic>{}
        : await _api.sendEmails(
            channelId,
            addresses,
            makePrivate: _makePrivate,
          );
    if (_scope != pageIdentity(widget.workspace)) {
      throw const RaftUserError('Server access changed. Reopen this form.');
    }
    if (_selectedServers.isNotEmpty) {
      try {
        final connected = await _api.connectOwn(
          channelId,
          _selectedServers.toList(),
          makePrivate: _makePrivate,
        );
        result['servers'] = connected['servers'];
      } catch (_) {
        result['serversFailed'] = true;
      }
    }
    if (mounted) Navigator.of(context).pop(result);
  });

  @override
  Widget build(BuildContext context) {
    String tr(String copy) => raftText(context, copy);
    String fmt(String copy, Map<String, Object> values) =>
        raftFormat(context, copy, values);
    final review = _preview != null;
    final count = _entries.length;
    final inviteCount = _addresses('valid').length;
    final slots = _preview?['slotsLeft'] as int?;
    final overSlots =
        slots != null && inviteCount + _selectedServers.length > slots;
    final hasActions =
        inviteCount +
            _addresses('alreadyMembers').length +
            _selectedServers.length >
        0;
    final enabled =
        !_busy &&
        (review
            ? !overSlots && hasActions
            : count <= 20 && (count > 0 || _selectedServers.isNotEmpty));
    final error = _error;
    final creating = widget.createChannel != null && _channel == null;
    const statuses = {
      'valid': 'Will be invited',
      'alreadyPending': 'Already invited · no new invite',
      'alreadyMembers': 'Already in {server} · added directly, no invite',
      'alreadyInChannel': 'Already in this channel · no invite',
      'duplicates': 'Listed more than once · one invite',
      'invalid': 'Not a valid email · no invite',
    };
    return PopScope(
      canPop: !_busy,
      child: RaftDialog.card(
        key: ValueKey(
          widget.createChannel == null
              ? 'add-external-member-dialog'
              : 'create-external-channel-invites',
        ),
        title: !review && widget.channelName != null
            ? fmt('Add people to #{name}', {'name': widget.channelName!})
            : fmt('Invite people outside {server}', {'server': _serverName}),
        onClose: () {
          if (!_busy) Navigator.of(context).maybePop();
        },
        actions: Wrap(
          alignment: WrapAlignment.end,
          spacing: RaftSpace.x2,
          runSpacing: RaftSpace.x2,
          children: [
            RaftButton(
              label: tr(
                review || widget.createChannel != null ? 'Back' : 'Cancel',
              ),
              onPressed: _busy
                  ? null
                  : () {
                      if (!review) {
                        Navigator.of(context).pop(
                          creating ? <String, dynamic>{'back': true} : null,
                        );
                      } else {
                        setState(() {
                          _preview = null;
                          _error = null;
                        });
                      }
                    },
              tone: RaftButtonRecipeVariant.ghost,
            ),
            if (widget.createChannel != null && review)
              RaftButton(
                label: tr('Skip'),
                onPressed: _busy ? null : () => Navigator.of(context).pop(),
                tone: RaftButtonRecipeVariant.ghost,
              ),
            RaftButton(
              label: tr(
                review
                    ? (_busy
                          ? 'Sending…'
                          : creating
                          ? 'Create and invite'
                          : 'Invite')
                    : (_busy
                          ? 'Checking…'
                          : creating
                          ? 'Create and invite'
                          : 'Next'),
              ),
              tone: RaftButtonRecipeVariant.accent,
              onPressed: enabled ? (review ? _send : _review) : null,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_makePrivate)
              RaftAuthNote(
                tr(
                  'Inviting people from outside makes this channel private. Only its members will see it.',
                ),
              ),
            if (widget.createChannel != null && _channel != null)
              RaftAuthNote(
                fmt(
                  "#{name} was created, but the invites weren't sent. Try again, or skip and invite people later.",
                  {'name': _channel!.name},
                ),
              ),
            if (!review) ...[
              RaftAuthField(
                label: tr('Invite by email'),
                helper: fmt(
                  'Separate emails with commas, spaces or new lines. Up to {max}.',
                  {'max': 20},
                ),
                error: count <= 20
                    ? null
                    : fmt('Up to {max} emails at a time. Remove {count}.', {
                        'max': 20,
                        'count': count - 20,
                      }),
                child: RaftTextarea(
                  rows: 4,
                  fieldKey: const ValueKey('external-invite-emails'),
                  controller: _emails,
                  hintText: tr('name@example.com, name@example.org'),
                  enabled: !_busy,
                  onChanged: (_) => setState(() => _error = null),
                ),
              ),
              if (_servers.isNotEmpty) ...[
                RaftAuthNote(tr('Connect your servers')),
                RaftTextInput(
                  hintText: tr('Search servers'),
                  leadingGlyph: RaftGlyph.search,
                  enabled: !_busy,
                  onChanged: (value) => setState(
                    () => _serverSearch = value.trim().toLowerCase(),
                  ),
                ),
                for (final row in _servers)
                  if (externalString(row['name'])
                      .toLowerCase()
                      .contains(_serverSearch))
                    RaftCheckboxRow(
                      title: externalString(row['name']),
                      description: row['atLimit'] == true
                          ? tr('At external channel limit')
                          : null,
                      value: _selectedServers.contains(row['id']),
                      onChanged: row['atLimit'] == true || _busy
                          ? null
                          : (selected) => setState(() {
                              final id = row['id'] as String;
                              if (selected) {
                                _selectedServers.add(id);
                              } else {
                                _selectedServers.remove(id);
                              }
                            }),
                    ),
              ],
              if (creating && widget.members != null)
                IgnorePointer(ignoring: _busy, child: widget.members),
            ] else ...[
              if (inviteCount > 0)
                RaftAuthNote(
                  fmt(
                    'The invite link works for {days} days. People can join as a guest, or connect their server to bring in their agents and teammates.',
                    {'days': 14},
                  ),
                ),
              for (final row in statuses.entries)
                for (final address in _addresses(row.key))
                  _ExternalReviewRow(
                    address,
                    fmt(row.value, {'server': _serverName}),
                  ),
              for (final row in externalRows(_preview?['guestsElsewhere']))
                _ExternalReviewRow(
                  externalString(row['email']),
                  row['channelName'] is String
                      ? fmt("Guest in {channel} · can't be invited", {
                          'channel': '#${row['channelName']}',
                        })
                      : tr("Guest in another channel · can't be invited"),
                ),
              for (final row in _servers)
                if (_selectedServers.contains(row['id']))
                  RaftAuthNote(
                    fmt('{server} connects now · no invite needed', {
                      'server': externalString(row['name']),
                    }),
                  ),
              if (overSlots)
                RaftErrorBanner(
                  tr(
                    'This channel is full. Withdraw an open invite or remove a guest to make room.',
                  ),
                ),
              if (!hasActions)
                RaftAuthNote(
                  tr(
                    'No one on this list can be invited. Go back to change it.',
                  ),
                ),
            ],
            if (error != null) ...[
              RaftErrorBanner(externalChannelFailure(context, error)),
              if (externalErrorCode(error) == 'free_external_limit')
                RaftButton(
                  label: tr('Upgrade'),
                  onPressed: () => openWebBillingOrToast(
                    context,
                    widget.workspace,
                    gate: WebBillingGate.externalChannelFreeLimit,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ExternalReviewRow extends StatelessWidget {
  const _ExternalReviewRow(this.address, this.status);

  final String address, status;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: RaftSpace.x1),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [Text(address), RaftAuthNote(status)],
    ),
  );
}
