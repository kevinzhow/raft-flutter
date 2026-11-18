import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/cause_notice.dart';
import '../data/external_invite_api.dart';
import 'external_invite_page_frame.dart';

const _ended = {
  'approved': (
    'Already approved',
    '{target} is connected to {channel}, or will be shortly.',
  ),
  'rejected': (
    'Already declined',
    "We've let {requester} know. They can still join another way.",
  ),
  'cancelled': (
    'This request was canceled',
    '{requester} can ask again from their invite.',
  ),
  'request_expired': (
    'This request has expired',
    "{requester}'s invite expired, so this request expired too. {requester} can ask for a new invite.",
  ),
  'expired': (
    'This request has expired',
    "{requester}'s invite expired, so this request expired too. {requester} can ask for a new invite.",
  ),
  'approver_lost_role': (
    'You can no longer approve this request',
    "You're no longer an admin of {target}. {requester} has been told to ask someone else.",
  ),
  'requester_left': (
    '{requester} is no longer in {target}',
    'The request was canceled, and {requester} has been told.',
  ),
  'channel_archived': (
    '{channel} was archived',
    'This request can no longer be approved.',
  ),
  'already_connected': (
    'Already connected',
    '{target} is already connected to {channel}.',
  ),
  'connected': (
    '{target} is connected',
    '{requester} can now take part in {channel} from {target}.',
  ),
  'connecting': (
    'Connecting {target}',
    "{target} is connecting to {channel}. This takes a few minutes, and we've let {requester} know.",
  ),
  'declined': (
    'Request declined',
    "We've let {requester} know. They can still join another way.",
  ),
};

const _errorCopy = {
  'guests_present':
      "{channel} has guests, so another server can't connect to it yet.",
  'connect_in_progress':
      'A server is being connected to {channel}. Try again once it\'s done.',
  'channel_full': "{channel} can't take any more servers.",
  'joint_server_limit': "{channel} can't take any more servers.",
  'free_external_limit':
      '{host} can\'t have another external channel right now.',
  'joint_free_server_limit': '{channel} already has as many free servers as it can take. Upgrade {target} to Pro to connect it.',
  'channel_busy': '{channel} is being updated. Try again in a minute.',
};

class ExternalInviteApproval extends StatefulWidget {
  const ExternalInviteApproval({
    super.key,
    required this.api,
    required this.id,
    required this.account,
    required this.onSignOut,
    required this.onOpen,
    required this.onUpgrade,
  });

  final ExternalInviteApi api;
  final String id, account;
  final VoidCallback onSignOut;
  final OpenExternalChannel onOpen;
  final UpgradeExternalServer onUpgrade;

  @override
  State<ExternalInviteApproval> createState() => _ExternalInviteApprovalState();
}

class _ExternalInviteApprovalState extends State<ExternalInviteApproval> {
  late Future<ExternalJson> _request = widget.api.approval(widget.id);
  String? _busy, _endedWith, _channelId;
  final _error = CauseNotice();
  bool _invalid = false;

  Future<void> _decide(bool approve) async {
    if (_busy != null) return;
    setState(() {
      _busy = approve ? 'approve' : 'decline';
      _error.clear();
    });
    try {
      final result = await (approve
          ? widget.api.approve(widget.id)
          : widget.api.reject(widget.id));
      if (!mounted) return;
      setState(() {
        _endedWith = approve ? externalString(result['state']) : 'declined';
        _channelId = result['channelId'] as String?;
      });
    } catch (error) {
      if (!mounted) return;
      final code = externalErrorCode(error);
      setState(() {
        if (externalErrorStatus(error) == 404) {
          _invalid = true;
        } else if (code == 'request_not_pending') {
          _request = widget.api.approval(widget.id);
        } else if (_ended.containsKey(code)) {
          _endedWith = code;
        } else {
          _error.raise(
            _errorCopy[code] ??
                (externalErrorStatus(error) == 429
                    ? 'Too many attempts. Wait a minute and try again.'
                    : 'Something went wrong. Try again.'),
          );
        }
      });
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<ExternalJson>(
    future: _request,
    builder: (context, snapshot) {
      String tr(String text) => raftText(context, text);
      final signOut = Center(
        child: RaftAuthTextLink(label: tr('Sign out'), onTap: widget.onSignOut),
      );
      if (snapshot.connectionState != ConnectionState.done) {
        return ExternalInviteFrame(title: tr('Loading request…'));
      }
      final invalid = _invalid || externalErrorStatus(snapshot.error) == 404;
      if (invalid || snapshot.hasError || !snapshot.hasData) {
        return ExternalInviteFrame(
          title: tr(
            invalid
                ? 'This request link is not valid'
                : "Couldn't load this page",
          ),
          description: tr(
            invalid
                ? 'Only the person it was sent to can open it. Sign in with that account to review it.'
                : 'Check your connection and try again.',
          ),
          account: widget.account,
          actions: [
            if (!invalid)
              externalInviteButton(tr('Retry'), () {
                setState(() => _request = widget.api.approval(widget.id));
              }),
            signOut,
          ],
        );
      }
      final request = snapshot.data!;
      final target = externalObject(request['targetServer']);
      final targetId = externalString(target['id']);
      final targetName = externalString(target['name']);
      final channelLabel = '#${externalString(request['channelName'])}';
      final channelId = _channelId ?? request['targetChannelId'] as String?;
      final values = {
        'channel': channelLabel,
        'target': targetName,
        'host': externalString(request['hostServerName']),
        'requester': externalString(
          externalObject(request['requester'])['name'],
        ),
      };
      String format(String copy) => raftFormat(context, copy, values);

      final status = _endedWith ?? externalString(request['status']);
      if (_ended[status] case (final title, final description)) {
        return ExternalInviteFrame(
          title: format(title),
          description: format(description),
          account: widget.account,
          actions: [
            if (const {
              'approved',
              'already_connected',
              'connected',
            }.contains(status))
              externalInviteButton(
                raftFormat(context, 'Open {target}', {
                  'target': channelId == null ? targetName : channelLabel,
                }),
                () => openExternalChannelOrToast(
                  context,
                  widget.onOpen,
                  targetId,
                  channelId,
                ),
                primary: true,
              ),
            signOut,
          ],
        );
      }

      final limited = target['atLimit'] == true;
      final canUpgrade = limited && target['canUpgrade'] == true;
      final canApprove = request['canApprove'] != false;
      return ExternalInviteFrame(
        title: format('Connect {target} to {channel}?'),
        description: format('{requester} asked. {host} hosts this channel.'),
        account: widget.account,
        actions: [
          RaftAuthNote(targetName),
          if (limited)
            RaftAuthNote(
              format(
                canUpgrade
                    ? "{target}'s Free plan allows 1 external channel. Upgrade to approve."
                    : "{target}'s Free plan allows 1 external channel. An owner of {target} needs to upgrade first.",
              ),
            ),
          if (_error.message case final String error)
            RaftAuthNote(format(error)),
          if (canApprove)
            externalInviteButton(
              canUpgrade
                  ? raftFormat(context, 'Upgrade {server}', {
                      'server': targetName,
                    })
                  : tr(_busy == 'approve' ? 'Approving…' : 'Approve'),
              _busy != null || limited && !canUpgrade
                  ? null
                  : canUpgrade
                  ? () => upgradeExternalServerOrToast(
                      context,
                      widget.onUpgrade,
                      targetId,
                    )
                  : () => _decide(true),
              primary: true,
            ),
          externalInviteButton(
            tr(_busy == 'decline' ? 'Declining…' : 'Decline'),
            _busy == null ? () => _decide(false) : null,
          ),
          signOut,
        ],
      );
    },
  );
}
