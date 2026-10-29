// The joint-channel block of the settings drawer (Web EditChannelDialog
// `channel-settings-joint-section`): connected servers with plan and status,
// Resend Invite, and the invitation form to connect another server, including
// the RFC 075 section 4.5 same-admin direct connection. The channel row
// (`jointServers`, `jointPendingInvites`) is the source of truth; every
// mutation refreshes it.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/user_error.dart';
import '../data/workspace_controller.dart';
import 'create_joint_channel_dialog.dart' show maxJointChannelServers;
import 'joint_same_admin.dart';

/// The servers a joint channel row lists: `jointServers`, else the single
/// legacy peer (`jointPeer*`), else none.
List<Map<String, dynamic>> jointServerRows(RaftChannel channel) {
  final listed = channel.json['jointServers'];
  if (listed is List && listed.isNotEmpty) {
    return [for (final row in listed.whereType<Map>()) Map.from(row).cast()];
  }
  final peerId = channel.string('jointPeerServerId');
  final peerSlug = channel.string('jointPeerServerSlug');
  if (peerId.isEmpty && peerSlug.isEmpty) return const [];
  return [
    {
      'serverId': peerId.isEmpty ? peerSlug : peerId,
      'serverName': channel.firstNonEmpty(const [
        'jointPeerServerName',
        'jointPeerServerSlug',
      ], 'Connected server'),
      'serverSlug': peerSlug,
      'status': channel.string('jointPeerStatus') == 'pending'
          ? 'pending'
          : 'active',
    },
  ];
}

/// Whether this server still has invitations out for [channel]
/// (`hasCurrentServerPendingJointInvites`).
bool jointHasPendingInvites(RaftChannel channel) {
  final pending = channel.json['jointPendingInvites'];
  if (pending is List) {
    return pending.any(
      (i) => i is Map && i['fromServerId'] == channel.string('serverId'),
    );
  }
  return channel.string('jointPeerStatus') == 'pending';
}

class ChannelJointSection extends StatefulWidget {
  const ChannelJointSection({
    super.key,
    required this.controller,
    required this.channelId,
    this.onDraftChanged,
  });
  final WorkspaceController controller;
  final String channelId;

  /// Whether an unsent invitation is being typed: the drawer then guards its
  /// dismissal (Web `hasInviteDraft`).
  final ValueChanged<bool>? onDraftChanged;
  @override
  State<ChannelJointSection> createState() => ChannelJointSectionState();
}

class ChannelJointSectionState extends State<ChannelJointSection> {
  WorkspaceController get w => widget.controller;
  RaftChannel? get channel =>
      w.channels.where((c) => c.id == widget.channelId).firstOrNull;

  final slug = TextEditingController(), people = TextEditingController();
  bool touchedSlug = false, touchedPeople = false;
  bool inviteBusy = false, resendBusy = false, resendDone = false;
  // ignore: raft_lints/avoid_imperative_notice_state -- Each is cleared when the field it describes is edited, on the next send or resend, on Discard, and when the section is dropped with the drawer.
  String? slugServerError, peopleServerError, submitError, status, resendError;

  /// The (slug, people) the direct-connection box was ticked for; editing
  /// either asks again.
  (String, String)? confirmedFor;
  Timer? resendTimer;
  bool _hadDraft = false;

  bool get hasDraft => slug.text.isNotEmpty || people.text.isNotEmpty;

  @override
  void initState() {
    super.initState();
    slug.addListener(_edited);
    people.addListener(_edited);
  }

  String _lastSlug = '', _lastPeople = '';
  void _edited() {
    final slugEdited = slug.text != _lastSlug;
    final peopleEdited = people.text != _lastPeople;
    _lastSlug = slug.text;
    _lastPeople = people.text;
    if (!mounted) return;
    setState(() {
      if (slugEdited) slugServerError = null;
      if (peopleEdited) peopleServerError = null;
      if (slugEdited || peopleEdited) {
        submitError = null;
        status = null;
      }
    });
    if (hasDraft != _hadDraft) {
      _hadDraft = hasDraft;
      widget.onDraftChanged?.call(_hadDraft);
    }
  }

  /// The drawer's Discard: empties the unsent invitation.
  void discardDraft() {
    slug.clear();
    people.clear();
    setState(() {
      touchedSlug = touchedPeople = false;
      confirmedFor = null;
      submitError = slugServerError = peopleServerError = null;
    });
  }

  @override
  void dispose() {
    resendTimer?.cancel();
    slug.dispose();
    people.dispose();
    super.dispose();
  }

  String? get _slugValidation {
    final value = slug.text.trim();
    if (value.isEmpty) return 'Invite server slug is required';
    if (!RegExp(r'^[a-z][a-z0-9-]*$').hasMatch(value)) {
      return 'Server slug must start with a lowercase letter and contain only lowercase letters, numbers, and hyphens';
    }
    return null;
  }

  RaftRecord? get _sameAdminTarget => findSameAdminJointTarget(
    servers: w.servers,
    currentServerSlug: w.server?.string('slug'),
    user: jointSelf(w.client.user),
    targetServerSlug: slug.text,
    invitedPeople: jointPeople(people.text),
  );

  bool get _confirmed => confirmedFor == (slug.text, people.text);

  String _text(String source) => raftText(context, source);

  String _failure(Object e, String fallback) => raftText(
    context,
    userErrorText(e, fallback: fallback, where: 'channel joint section'),
  );

  Future<void> resend() async {
    final c = channel;
    if (c == null || resendBusy) return;
    resendTimer?.cancel();
    setState(() {
      resendBusy = true;
      resendDone = false;
      resendError = null;
    });
    try {
      await w.command('POST', '/channels/${c.id}/joint-invite/resend');
      if (!mounted) return;
      setState(() => resendDone = true);
      resendTimer = Timer(const Duration(milliseconds: 1500), () {
        if (mounted) setState(() => resendDone = false);
      });
    } catch (e) {
      if (mounted) {
        setState(
          () => resendError = _failure(
            e,
            'Failed to resend joint channel invite',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => resendBusy = false);
    }
  }

  Future<void> sendInvite() async {
    final c = channel;
    if (c == null || inviteBusy) return;
    setState(() {
      touchedSlug = touchedPeople = true;
      status = null;
      submitError = slugServerError = peopleServerError = null;
    });
    final invited = jointPeople(people.text);
    if (_slugValidation != null || invited.isEmpty) return;
    if (jointServerRows(c).length >= maxJointChannelServers) {
      setState(
        () => submitError = raftFormat(
          context,
          'Joint channels support a maximum of {max} servers.',
          {'max': maxJointChannelServers},
        ),
      );
      return;
    }
    final target = _sameAdminTarget;
    if (target != null && !_confirmed) {
      setState(
        () => submitError = _text(
          'Confirm the direct connection, or remove yourself from the invited people.',
        ),
      );
      return;
    }
    setState(() => inviteBusy = true);
    try {
      final reply = await w.command(
        'POST',
        '/channels/${c.id}/joint-invites',
        data: {
          'targetServerSlug': slug.text.trim(),
          'invitedPeople': invited,
          if (target != null) 'sameAdmin': true,
        },
      );
      unawaited(w.refreshChannels());
      // The server falls back to email if the direct accept fails, so read the
      // outcome from the returned server list instead of assuming it.
      final servers = reply is Map ? reply['jointServers'] : null;
      final direct =
          target != null &&
          servers is List &&
          servers.any(
            (s) =>
                s is Map &&
                s['serverSlug'] == target.string('slug') &&
                s['status'] == 'active',
          );
      if (!mounted) return;
      final emailed = direct ? invited.length - 1 : invited.length;
      final message = [
        if (direct)
          raftFormat(context, 'Connected {server} directly.', {
            'server': target.name,
          }),
        if (emailed > 0)
          emailed == 1
              ? _text('Invite email sent.')
              : raftFormat(context, '{count} invite emails sent.', {
                  'count': emailed,
                }),
      ].join(' ');
      slug.clear();
      people.clear();
      setState(() {
        confirmedFor = null;
        touchedSlug = touchedPeople = false;
        status = message;
      });
    } catch (e) {
      if (!mounted) return;
      final details = e is RaftApiException ? e.details : const {};
      final code = details['code'];
      final message = switch (code) {
        'joint_free_server_limit' => _text(
          'This Joint Channel already has 2 free servers. Upgrade either side to Pro, or have a free server leave, to continue (30 servers max).',
        ),
        'joint_server_limit' => raftFormat(
          context,
          'Joint Channels are limited to {max} servers. To request a higher limit, send feedback from Settings.',
          {'max': maxJointChannelServers},
        ),
        _ => _failure(e, 'Failed to invite server'),
      };
      setState(() {
        if (code == 'joint_free_server_limit' || code == 'joint_server_limit') {
          submitError = message;
        } else if (RegExp(
          r'target server|current server|server slug|already in this joint channel',
          caseSensitive: false,
        ).hasMatch(message)) {
          slugServerError = message;
        } else if (RegExp(
          r'invited person|invitee|target server admin',
          caseSensitive: false,
        ).hasMatch(message)) {
          peopleServerError = message;
        } else {
          submitError = message;
        }
      });
    } finally {
      if (mounted) setState(() => inviteBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: w,
    builder: (context, _) {
      final c = channel;
      if (c == null || c.type != 'joint') return const SizedBox.shrink();
      final rows = jointServerRows(c);
      final manage = w.can('federateChannels', resource: c) && !c.archived;
      final target = _sameAdminTarget;
      final slugInvalid = _slugValidation;
      final invited = jointPeople(people.text);
      return RaftChannelJointSectionView(
        servers: [
          for (final s in rows)
            RaftJointServerRow(
              name: '${s['serverName'] ?? ''}',
              slug: '${s['serverSlug'] ?? ''}',
              active: s['status'] == 'active',
              isCurrent: s['isCurrentServer'] == true,
              plan: s['plan'] is String ? s['plan'] as String : null,
            ),
        ],
        showInvite: manage,
        showResend: jointHasPendingInvites(c),
        resendBusy: resendBusy,
        resendDone: resendDone,
        resendError: resendError,
        onResend: () => unawaited(resend()),
        limitReached: rows.length >= maxJointChannelServers,
        maxServers: maxJointChannelServers,
        slug: slug,
        people: people,
        slugError:
            slugServerError ??
            (touchedSlug && slugInvalid != null ? _text(slugInvalid) : null),
        peopleError:
            peopleServerError ??
            (touchedPeople && invited.isEmpty
                ? _text('At least one invited person is required')
                : null),
        sameAdminNotice: target == null
            ? null
            : RaftSameAdminJointNotice(
                sourceServerName: w.server?.name ?? '',
                targetServerName: target.name,
                confirmed: _confirmed,
                onConfirmedChange: inviteBusy
                    ? null
                    : (value) => setState(() {
                        confirmedFor = value ? (slug.text, people.text) : null;
                        submitError = null;
                      }),
              ),
        inviteBusy: inviteBusy,
        canSend: slugInvalid == null && invited.isNotEmpty,
        submitError: submitError,
        status: status,
        onSendInvite: () => unawaited(sendInvite()),
      );
    },
  );
}
