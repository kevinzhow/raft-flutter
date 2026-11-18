import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/cause_notice.dart';
import '../data/external_invite_api.dart';
import 'external_invite_page_frame.dart';

enum _Step {
  waysIn,
  guest,
  connect,
  approval,
  newServer,
  waiting,
  progress,
  connecting,
  joined,
}

const _errors = {
  'deployment_user_limit_reached': 'This Raft Community Edition deployment already has 5 people, the Raft License limit. To go above it, email contact@raft.build for a separate license.',
  'guest_unavailable': "{channel} is shared with other servers, so it can't take guests yet. Connect a server to join it.",
  'already_member': "You're already a member of {server}. Ask an admin there to add you to {channel}.",
  'guest_elsewhere': "You're already a guest in another channel, so you can't join {channel} as a guest. Connect or create a server instead.",
  'channel_full': '{channel} is full. Ask {inviter} to free a slot, then open this link again.',
  'invalid_server':
      "{target} can't be connected to {channel}. Choose another server.",
  'server_admin_required': 'Only an admin of {target} can connect it. Choose it again to ask an admin to approve.',
  'server_membership_required': "You're no longer a member of {target}.",
  'invalid_approver': 'Choose an admin of {target} to approve.',
  'guests_present':
      "{channel} has guests, so another server can't connect to it yet.",
  'joint_party_limit': '{channel} has too many guests for another server to connect. An external channel holds up to {max} servers and guests together. Ask {inviter} to remove some guests, then open this link again.',
  'already_connected': '{target} is already connected to {channel}. Ask one of its admins to add you.',
  'joint_server_limit': "{channel} can't take any more servers.",
  'connect_in_progress':
      "A server is being connected to {channel}. Try again once it's done.",
  'channel_archived': '{channel} was archived.',
  'channel_conversion_in_progress':
      '{channel} is being updated. Try again in a minute.',
  'free_external_limit':
      "{server} can't have another external channel right now. Ask {inviter}.",
  'joint_channel_free_limit_reached':
      "{server} can't have another external channel right now. Ask {inviter}.",
  'joint_channel_plan_limit_reached':
      "{server} can't have another external channel right now. Ask {inviter}.",
  'joint_free_server_limit': '{channel} already has as many free servers as it can take. Upgrade {target} to Pro to connect it.',
};

class ExternalInvitePage extends StatefulWidget {
  const ExternalInvitePage({
    super.key,
    required this.api,
    required this.token,
    required this.account,
    required this.onSignOut,
    required this.onClose,
    required this.onOpen,
    required this.onUpgrade,
  });

  final ExternalInviteApi api;
  final String token, account;
  final VoidCallback onSignOut, onClose;
  final OpenExternalChannel onOpen;
  final UpgradeExternalServer onUpgrade;

  @override
  State<ExternalInvitePage> createState() => _ExternalInvitePageState();
}

class _ExternalInvitePageState extends State<ExternalInvitePage> {
  ExternalJson? _invite;
  Object? _loadFailure;
  bool _busy = false, _polling = false;
  RaftForegroundPeriodic? _poll;
  String? _failedServer;
  _Step _step = _Step.waysIn;
  String? _target, _serverId, _channelId;
  late final _error = CauseNotice(scope: () => _step);
  ExternalJson _waiting = const {};
  List<ExternalJson> _progress = const [];
  final _picked = <String>{};
  final _approverIds = <String, String>{};
  final _name = TextEditingController(), _slug = TextEditingController();
  bool _slugEdited = false;
  final _nameError = CauseNotice(), _slugError = CauseNotice();
  String? _keptServer;
  String _search = '';

  ExternalJson get _options => externalObject(_invite?['options']);
  ExternalJson get _connect => externalObject(_options['connect']);
  List<ExternalJson> get _servers => externalRows(_connect['servers']);
  List<ExternalJson> get _selected => [
    for (final row in _servers)
      if (_picked.contains(row['id'])) row,
  ];
  List<ExternalJson> get _approval =>
      _selected.where((row) => row['needsApproval'] == true).toList();
  String get _token => widget.token;

  @override
  void initState() {
    super.initState();
    _read();
  }

  @override
  void dispose() {
    _poll?.dispose();
    _name.dispose();
    _slug.dispose();
    super.dispose();
  }

  Future<void> _read() async {
    try {
      final invite = await widget.api.invite(_token);
      if (!mounted) return;
      setState(() => _applyInvite(invite));
      _syncPoll();
    } catch (error) {
      if (mounted) setState(() => _loadFailure = error);
    }
  }

  void _applyInvite(ExternalJson invite) {
    _invite = invite;
    final accepted = externalObject(invite['accepted']);
    final pending = externalRows(invite['pendingRequests']);
    _waiting = pending.firstOrNull ?? externalObject(invite['pendingRequest']);
    _progress = externalRows(invite['servers']);
    _serverId = (accepted['serverId'] ?? invite['connectServerId']) as String?;
    _picked.removeWhere((id) => !_servers.any((row) => row['id'] == id));
    _channelId = accepted['channelId'] as String?;
    _step = switch (invite['status']) {
      'accepted' when accepted.isNotEmpty => _Step.joined,
      _ when _progress.length > 1 => _Step.progress,
      'awaiting_approval' => _Step.waiting,
      'connecting' => _Step.connecting,
      _ => _Step.waysIn,
    };
  }

  void _syncPoll() {
    final underway = const {
      'connecting',
      'awaiting_approval',
    }.contains(_invite?['status']);
    final runs =
        _loadFailure == null &&
        (_step == _Step.waiting ||
            _step == _Step.connecting ||
            (_step == _Step.progress && underway));
    if (runs) {
      _poll ??= RaftForegroundPeriodic(
        const Duration(seconds: 4),
        () => unawaited(_pollOnce()),
      );
    } else {
      _poll?.dispose();
      _poll = null;
    }
  }

  Future<void> _pollOnce() async {
    if (_busy || _polling) return;
    final before = _step;
    _polling = true;
    try {
      final fresh = await widget.api.invite(_token);
      if (!mounted || _busy || before != _step || _poll == null) return;
      if (before == _Step.progress) {
        final previous = {for (final row in _progress) row['serverId']: row};
        for (final row in externalRows(fresh['servers'])) {
          previous[row['serverId']] = {...?previous[row['serverId']], ...row};
        }
        setState(() {
          _invite = fresh;
          _progress = previous.values.toList();
        });
      } else if (fresh['status'] !=
          (before == _Step.waiting ? 'awaiting_approval' : 'connecting')) {
        final failed =
            before == _Step.connecting && fresh['status'] == 'pending';
        setState(() {
          _failedServer = failed ? _target ?? '' : null;
          _applyInvite(fresh);
        });
        final serverId = _serverId, channelId = _channelId;
        if (fresh['status'] == 'accepted' &&
            serverId != null &&
            channelId != null) {
          await openExternalChannelOrToast(
            context,
            widget.onOpen,
            serverId,
            channelId,
          );
        }
      }
    } on RaftApiException catch (error) {
      if (mounted &&
          !_busy &&
          _step == before &&
          before == _Step.connecting &&
          error.status == 404) {
        setState(() => _step = _Step.joined);
      }
    } finally {
      _polling = false;
      if (mounted) _syncPoll();
    }
  }

  String? _approverFor(ExternalJson server) =>
      _approverIds[server['id']] ??
      externalRows(server['approvers']).firstOrNull?['id'] as String?;

  void _go(_Step step) => setState(() {
    _step = step;
    _error.clear();
    _failedServer = null;
    _search = '';
    _syncPoll();
  });

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error.clear();
    });
    try {
      await action();
    } catch (error) {
      if (!mounted) return;
      final code = externalErrorCode(error);
      if (code == 'approval_in_progress' ||
          code == 'connect_in_progress' && _step != _Step.guest) {
        await _read();
        return;
      }
      setState(() {
        if (_step == _Step.newServer &&
            error is RaftApiException &&
            error.details['serverId'] is String) {
          _keptServer = error.details['serverId'] as String;
          _error.raise(_errors[code] ?? 'Something went wrong. Try again.');
        } else if (externalErrorStatus(error) == 404) {
          if (_invite != null) {
            _invite = {..._invite!, 'addressedToYou': false};
          } else {
            _loadFailure = error;
          }
        } else if (code == 'slug_taken' ||
            code == 'server_slug_taken' ||
            _step == _Step.newServer &&
                externalErrorStatus(error) == 409 &&
                code == null) {
          _slugError.raise('This slug is taken. Try another one.');
        } else {
          _error.raise(
            error is RaftApiException &&
                    code == 'free_external_limit' &&
                    error.details['limitSide'] == 'connecting'
                ? '{target} is already in a channel with external members. Upgrade to Pro to connect another.'
                : _errors[code] ??
                      (externalErrorStatus(error) == 429
                          ? 'Too many attempts. Wait a minute and try again.'
                          : 'Something went wrong. Try again.'),
          );
        }
      });
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _syncPoll();
      }
    }
  }

  Future<void> _joined(ExternalJson result) async {
    if (!mounted) return;
    final serverId = result['serverId'] as String? ?? _serverId;
    final channelId = result['channelId'] as String?;
    setState(() {
      _serverId = serverId;
      _channelId = channelId;
      _step = result['state'] == 'connecting' ? _Step.connecting : _Step.joined;
    });
    if (_step == _Step.joined && serverId != null && channelId != null) {
      await openExternalChannelOrToast(
        context,
        widget.onOpen,
        serverId,
        channelId,
      );
    }
  }

  Future<void> _connectSelected({bool confirmedApprovers = false}) async {
    final selected = _selected;
    if (selected.isEmpty) return;
    if (!confirmedApprovers && _approval.isNotEmpty) {
      _go(_Step.approval);
      return;
    }
    await _run(() async {
      if (selected.length > 1) {
        final result = await widget.api.connectServers(_token, [
          for (final row in selected)
            {
              'serverId': row['id'],
              if (row['needsApproval'] == true)
                'approverUserId': _approverFor(row),
            },
        ]);
        ExternalJson? fresh;
        try {
          fresh = await widget.api.invite(_token);
        } on RaftApiException {
          // The confirmed per-server outcomes are still useful if refresh fails.
        }
        if (!mounted) return;
        setState(() {
          if (fresh != null) _applyInvite(fresh);
          _progress = [
            for (final row in externalRows(result['servers']))
              {
                ..._progress.firstWhere(
                  (saved) => saved['serverId'] == row['serverId'],
                  orElse: () => const {},
                ),
                ...row,
                'serverName': selected.firstWhere(
                  (server) => server['id'] == row['serverId'],
                  orElse: () => const {},
                )['name'],
              },
          ];
          _step = _Step.progress;
        });
        return;
      }
      final server = selected.single;
      final id = server['id'] as String;
      _serverId = id;
      _target = externalString(server['name']);
      if (server['needsApproval'] == true) {
        final approver = _approverFor(server)!;
        await widget.api.ask(_token, id, approver);
        if (!mounted) return;
        setState(() {
          _waiting = {
            'serverId': id,
            'serverName': _target,
            'approverName': externalRows(server['approvers'])
                .firstWhere((person) => person['id'] == approver)['name'],
          };
          _step = _Step.waiting;
        });
      } else {
        await _joined(await widget.api.connect(_token, id));
      }
    });
  }

  Future<void> _cancel(ExternalJson row, {bool single = false}) async {
    final confirmed = await RaftConfirmDialog.show(
      context,
      RaftConfirmDialog(
        surfaceKey: const ValueKey('external-invite-cancel-dialog'),
        title: raftText(context, 'Cancel request?'),
        message: raftFormat(
          context,
          "{approver} won't be able to approve it. You can ask again later.",
          {'approver': externalString(row['approverName'])},
        ),
        confirmLabel: raftText(context, 'Cancel request'),
        cancelLabel: raftText(context, 'Keep request'),
      ),
    );
    if (confirmed != true || !mounted) return;
    await _run(() async {
      try {
        await widget.api.cancel(
          _token,
          single ? null : row['requestId'] as String?,
        );
      } on RaftApiException catch (error) {
        if (error.code != 'request_not_pending') rethrow;
      }
      await _read();
    });
  }

  Future<void> _create() async {
    final name = _name.text.trim();
    final slug = _slug.text;
    setState(() {
      _nameError.raise(name.isEmpty ? 'Enter a name for the server.' : null);
      _slugError.raise(switch (slug) {
        '' => 'Enter a slug.',
        _ when slug.length < 5 => 'Use at least {count} characters.',
        _ when !RegExp(r'^[a-z][a-z0-9-]*$').hasMatch(slug) => 'Start with a letter, and use only lowercase letters, numbers and hyphens.',
        _ => null,
      });
    });
    if (_nameError.isActive || _slugError.isActive || _keptServer != null) {
      return;
    }
    _target = name;
    await _run(
      () async => _joined(await widget.api.connectNew(_token, name, slug)),
    );
  }

  Widget _wayIn({
    required RaftGlyph glyph,
    required String title,
    required String description,
    required _Step step,
  }) => RaftListRow(
    key: ValueKey('external-invite-option-${step.name}'),
    onPressed: () => _go(step),
    children: [
      RaftIconTile(glyph: glyph, size: RaftIconTileSize.md),
      RaftListRowBody(
        children: [
          RaftListRowTitle(title),
          RaftListRowDescription(description, wrap: true),
        ],
      ),
      const RaftListRowChevron(),
    ],
  );

  @override
  Widget build(BuildContext context) {
    String tr(String copy) => raftText(context, copy);
    final accepted = externalObject(_invite?['accepted']);
    final channelName = externalString(
      accepted['channelName'] ?? _invite?['channelName'],
    );
    final values = {
      'channel': '#$channelName',
      'server': externalString(_invite?['serverName']),
      'inviter': externalString(_invite?['inviterName']),
      'target':
          _target ??
          externalString(
            _servers
                .where((row) => row['id'] == _serverId)
                .firstOrNull?['name'],
          ),
      'max': 30,
    };
    String format(String copy, [Map<String, Object> extra = const {}]) =>
        raftFormat(context, copy, {...values, ...extra});
    final signOut = Center(
      child: RaftAuthTextLink(label: tr('Sign out'), onTap: widget.onSignOut),
    );
    final failure = _error.message;
    final error = failure == null ? null : RaftAuthNote(format(failure));
    Widget frame(String title, String description, List<Widget> actions) =>
        ExternalInviteFrame(
          title: format(title),
          description: format(description),
          account: widget.account,
          actions: actions,
        );
    Widget back(_Step step) =>
        externalInviteButton(tr('Back'), _busy ? null : () => _go(step));
    Widget primary(String label, VoidCallback? action) => externalInviteButton(
      format(label),
      _busy ? null : action,
      primary: true,
    );
    Widget open(String id, String? channel, String target) => primary(
      format('Open {target}', {'target': target}),
      () => openExternalChannelOrToast(context, widget.onOpen, id, channel),
    );

    if (_loadFailure != null) {
      final invalid = externalErrorStatus(_loadFailure) == 404;
      return frame(
        invalid ? 'This invite link is not valid' : "Couldn't load this page",
        invalid
            ? 'It may have expired or been withdrawn. Ask the person who invited you for a new one.'
            : 'Check your connection and try again.',
        [
          if (invalid)
            externalInviteButton(tr('Go to Raft'), widget.onClose)
          else
            externalInviteButton(tr('Retry'), () {
              setState(() => _loadFailure = null);
              _read();
            }),
          signOut,
        ],
      );
    }
    if (_invite == null) {
      return ExternalInviteFrame(title: tr('Loading invite…'));
    }
    if (_invite?['addressedToYou'] == false) {
      final email = externalString(_invite?['invitedEmailMasked']);
      return frame(
        "This invite isn't for this account",
        email.isEmpty
            ? 'Sign in with the email address the invite was sent to. If you already have, the invite may have been withdrawn or expired.'
            : format(
                'This invite was sent to {email}. Sign in with that address to accept it.',
                {'email': email},
              ),
        [primary('Switch account', widget.onSignOut)],
      );
    }

    switch (_step) {
      case _Step.guest:
        return frame(
          'Join as a guest',
          "You'll join {channel} in {server} and work with the humans and agents there.",
          [
            ?error,
            primary(
              _busy ? 'Joining…' : 'Join',
              () => _run(() async => _joined(await widget.api.guest(_token))),
            ),
            back(_Step.waysIn),
          ],
        );
      case _Step.connect:
        final limit = _connect['slotsLeft'] as int?;
        final slots =
            limit != null &&
                _servers.where((row) => row['atLimit'] != true).length > limit
            ? (limit - _picked.length).clamp(0, limit)
            : null;
        return frame(
          'Connect a server',
          "Choose a server you're in. {channel} will show up there, and you can bring in your teammates and agents.",
          [
            if (slots != null)
              RaftAuthNote(
                slots == 0
                    ? format("{channel} can't take any more servers.")
                    : format('You can connect {count} more.', {'count': slots}),
              ),
            if (_servers.length > 5)
              RaftTextInput(
                hintText: tr('Search servers'),
                onChanged: (value) =>
                    setState(() => _search = value.toLowerCase()),
              ),
            for (final row in _servers)
              if (externalString(row['name'])
                  .toLowerCase()
                  .contains(_search)) ...[
                RaftCheckboxRow(
                  title: externalString(row['name']),
                  description: row['atLimit'] == true
                      ? tr('At external channel limit')
                      : row['needsApproval'] == true
                      ? tr('Needs approval')
                      : null,
                  value: _picked.contains(row['id']),
                  onChanged:
                      _busy ||
                          row['atLimit'] == true ||
                          slots == 0 && !_picked.contains(row['id'])
                      ? null
                      : (selected) => setState(() {
                          final id = row['id'] as String;
                          if (selected) {
                            _picked.add(id);
                          } else {
                            _picked.remove(id);
                          }
                        }),
                ),
                if (row['atLimit'] == true && row['canUpgrade'] == true)
                  externalInviteButton(
                    format('Upgrade {server}', {
                      'server': externalString(row['name']),
                    }),
                    () => upgradeExternalServerOrToast(
                      context,
                      widget.onUpgrade,
                      row['id'] as String,
                    ),
                  ),
              ],
            ?error,
            primary(
              _busy
                  ? 'Connecting…'
                  : _approval.isNotEmpty
                  ? 'Continue'
                  : _selected.length == 1
                  ? format('Connect {target}', {
                      'target': externalString(_selected.firstOrNull?['name']),
                    })
                  : 'Connect',
              _selected.isEmpty ? null : _connectSelected,
            ),
            back(_Step.waysIn),
          ],
        );
      case _Step.approval:
        final first = externalString(_approval.first['name']);
        return frame(
          _approval.length == 1
              ? format('Ask {target} to connect', {'target': first})
              : format('Ask {count} servers to connect', {
                  'count': _approval.length,
                }),
          _approval.length == 1
              ? format('Any admin of {target} can approve.', {'target': first})
              : 'An admin of each server can approve.',
          [
            for (final row in _approval) ...[
              RaftAuthNote(
                format('Admins of {target}', {
                  'target': externalString(row['name']),
                }),
              ),
              for (final person in externalRows(row['approvers']))
                RaftCheckboxRow(
                  title: externalString(person['name']),
                  value: _approverFor(row) == person['id'],
                  onChanged: _busy
                      ? null
                      : (_) => setState(
                          () => _approverIds[row['id'] as String] =
                              person['id'] as String,
                        ),
                ),
            ],
            ?error,
            primary(
              _busy
                  ? 'Sending…'
                  : _approval.length == 1
                  ? 'Send request'
                  : 'Send requests',
              _approval.any((row) => _approverFor(row) == null)
                  ? null
                  : () => _connectSelected(confirmedApprovers: true),
            ),
            back(_Step.connect),
          ],
        );
      case _Step.newServer:
        return frame(
          'Create a new server',
          "You'll own the new server, and it will connect to {channel} in {server}.",
          [
            RaftAuthField(
              label: tr('Server name'),
              error: _nameError.message == null
                  ? null
                  : tr(_nameError.message!),
              child: RaftTextInput(
                controller: _name,
                onChanged: (value) => setState(() {
                  _nameError.clear();
                  if (!_slugEdited) {
                    _slug.text = value
                        .trim()
                        .toLowerCase()
                        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
                        .replaceAll(RegExp(r'^-+|-+$'), '');
                  }
                }),
              ),
            ),
            RaftAuthField(
              label: tr('Slug'),
              error: _slugError.message == null
                  ? null
                  : format(_slugError.message!, {'count': 5}),
              child: RaftTextInput(
                controller: _slug,
                onChanged: (_) => setState(() {
                  _slugEdited = true;
                  _slugError.clear();
                }),
                onSubmitted: (_) => _create(),
              ),
            ),
            ?error,
            if (_keptServer case final String id) ...[
              RaftAuthNote(format('Your new server {target} was created.')),
              open(id, null, _name.text),
            ] else
              primary(_busy ? 'Creating…' : 'Create', _create),
            back(_Step.waysIn),
          ],
        );
      case _Step.waiting:
        return frame(
          'Waiting for approval',
          _waiting.isEmpty
              ? "Your request to connect a server to {channel} is waiting for approval. We'll email you when it's decided."
              : format(
                  "We've asked {approver} to connect {target}. We'll email you when they decide.",
                  {
                    'approver': externalString(_waiting['approverName']),
                    'target': externalString(_waiting['serverName']),
                  },
                ),
          [
            if (_waiting.isNotEmpty)
              RaftAuthNote(externalString(_waiting['serverName'])),
            ?error,
            if (_waiting.isNotEmpty)
              externalInviteButton(
                tr(_busy ? 'Canceling…' : 'Cancel request'),
                _busy ? null : () => _cancel(_waiting, single: true),
              ),
            signOut,
          ],
        );
      case _Step.progress:
        return frame(
          'Your servers',
          "Each server connects to {channel} on its own. We'll email you when a request is decided.",
          [
            for (final row in _progress) ...[
              RaftAuthNote(
                '${externalString(row['serverName'])} · ${tr(switch (row['state']) {
                  'connected' => 'Connected',
                  'connecting' => 'Connecting…',
                  'awaiting_approval' => 'Waiting for approval',
                  _ => 'Not connected',
                })}',
              ),
              if (row['state'] == 'connected' && row['serverId'] is String)
                open(
                  row['serverId'] as String,
                  row['channelId'] as String?,
                  externalString(row['serverName']),
                ),
              if (row['state'] == 'awaiting_approval' &&
                  row['requestId'] is String)
                externalInviteButton(
                  tr('Cancel request'),
                  _busy ? null : () => _cancel(row),
                ),
              if (row['state'] == 'refused')
                RaftAuthNote(
                  format(
                    _errors[row['code']] ?? 'Something went wrong. Try again.',
                    {'target': externalString(row['serverName'])},
                  ),
                ),
            ],
            ?error,
            if (_invite?['status'] == 'pending') back(_Step.waysIn),
            signOut,
          ],
        );
      case _Step.connecting:
        return frame(
          values['target'] == ''
              ? 'Connecting a server'
              : 'Connecting {target}',
          "We're connecting your server to {channel}. This can take a few minutes. We'll email you if it fails.",
          [
            if (_serverId case final String id)
              open(id, null, externalString(values['target'])),
            signOut,
          ],
        );
      case _Step.joined:
        return frame(
          '{channel} is ready',
          "You'll find it in the server you connected.",
          [
            if (_serverId case final String id)
              open(id, _channelId, externalString(values['channel'])),
            signOut,
          ],
        );
      case _Step.waysIn:
        final lastRequest = externalObject(_invite?['lastRequest']);
        return frame('Join {channel}', '{inviter} invited you from {server}.', [
          if (_failedServer case final String target)
            RaftAuthNote(
              target.isEmpty
                  ? tr(
                      "The server couldn't be connected. Try again, or choose another way to join.",
                    )
                  : format(
                      "{target} couldn't be connected. Try again, or choose another way to join.",
                      {'target': target},
                    ),
            )
          else if (lastRequest['status'] == 'rejected')
            RaftAuthNote(
              format(
                '{target} declined your request. You can still join another way.',
                {'target': externalString(lastRequest['serverName'])},
              ),
            ),
          if (_options['guest'] == true ||
              _servers.isNotEmpty ||
              _options['newServer'] == true)
            RaftListRowGroup(
              children: [
                if (_options['guest'] == true)
                  _wayIn(
                    glyph: RaftGlyph.userPlus,
                    title: tr('Join as a guest'),
                    description: tr(
                      'Join just this channel yourself to work with the humans and agents there.',
                    ),
                    step: _Step.guest,
                  ),
                if (_servers.isNotEmpty)
                  _wayIn(
                    glyph: RaftGlyph.server,
                    title: tr('Connect a server'),
                    description: tr(
                      "Bring your teammates and agents from a server you're in.",
                    ),
                    step: _Step.connect,
                  ),
                if (_options['newServer'] == true)
                  _wayIn(
                    glyph: RaftGlyph.plus,
                    title: tr('Create a new server'),
                    description: format(
                      'Start a server for you and your agents, and connect it to {channel}.',
                    ),
                    step: _Step.newServer,
                  ),
              ],
            )
          else
            RaftAuthNote(
              format(
                _invite?['channelFull'] == true
                    ? '{channel} is full. Ask {inviter} to free a slot, then open this link again.'
                    : "To join {channel}, you need to connect a server, and this account isn't in a server that can connect. Ask {inviter} for help.",
              ),
            ),
          signOut,
        ]);
    }
  }
}
