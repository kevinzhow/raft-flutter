// Create-channel dialog: the Web CreateChannelDialog
// (packages/web/src/components/channel/CreateChannelDialog.tsx) — DialogCard
// with Name, Description (optional), Visibility (Public/Private segmented
// control), Members (optional) search + AGENTS/HUMANS picker, Cancel/Create.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/cause_notice.dart';
import '../data/user_error.dart';

import '../data/workspace_controller.dart';
import 'slack_channel_pairing.dart';
import '../data/workspace_entity_directory.dart';
import 'channel_form_fields.dart';

/// One selectable member row of the picker (an agent or a human).
@immutable
class ChannelMemberCandidate {
  const ChannelMemberCandidate({
    required this.kind,
    required this.id,
    required this.name,
    this.displayName,
    this.description,
    this.avatarUrl,
  });
  final String kind; // 'agent' | 'human'
  final String id, name;
  final String? displayName, description, avatarUrl;
  String get label =>
      (displayName?.trim().isNotEmpty ?? false) ? displayName! : name;
  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return name.toLowerCase().contains(q) ||
        (displayName ?? '').toLowerCase().contains(q);
  }
}

/// Candidate rows from agent and member rows (the `/agents` and
/// `/servers/:id/members` payloads, or the workspace directory's copy of
/// them): agents that are not deleted, and server members other than the
/// signed-in user.
List<ChannelMemberCandidate> channelMemberCandidatesFrom(
  Iterable<Map<String, dynamic>> agents,
  Iterable<Map<String, dynamic>>? members,
  String? me,
) => [
  for (final a in agents)
    if (a['deletedAt'] == null)
      ChannelMemberCandidate(
        kind: 'agent',
        id: '${a['id']}',
        name: '${a['name'] ?? ''}',
        displayName: a['displayName'] as String?,
        description: a['description'] as String?,
        avatarUrl: a['avatarUrl'] as String?,
      ),
  if (members != null)
    for (final m in members)
      if ((m['userId'] ?? m['id']) != me)
        ChannelMemberCandidate(
          kind: 'human',
          id: '${m['userId'] ?? m['id']}',
          name: '${m['name'] ?? ''}',
          displayName: m['displayName'] as String?,
          description: m['description'] as String?,
          avatarUrl: m['avatarUrl'] as String?,
        ),
];

/// Agents (not deleted) and server members other than the signed-in user,
/// from the same endpoints the Web stores load (`/agents`,
/// `/servers/:id/members`).
Future<List<ChannelMemberCandidate>> loadChannelMemberCandidates(
  WorkspaceController w,
) async {
  final serverId = w.server?.id;
  final values = await Future.wait([
    w.query('/agents'),
    if (serverId != null) w.query('/servers/$serverId/members'),
  ]);
  List<Map<String, dynamic>> rows(dynamic v) => [
    for (final m in (v as List? ?? const []).whereType<Map>())
      Map<String, dynamic>.from(m),
  ];
  return channelMemberCandidatesFrom(
    rows(values[0]),
    values.length > 1 ? rows(values[1]) : null,
    w.client.user?.id,
  );
}

/// The picker candidates the workspace directory already holds (this session
/// or restored from the device); null while either list was never loaded.
List<ChannelMemberCandidate>? cachedChannelMemberCandidates(
  WorkspaceController w,
) {
  final d = w.services.entityDirectory;
  if (!d.state(WorkspaceEntityKind.agents).loaded ||
      !d.state(WorkspaceEntityKind.members).loaded) {
    return null;
  }
  return channelMemberCandidatesFrom(
    d.rows(WorkspaceEntityKind.agents),
    d.rows(WorkspaceEntityKind.members),
    w.client.user?.id,
  );
}

/// Live source of the member picker's candidates. It holds the workspace
/// directory's copy at once (no request is awaited before a surface opens),
/// revalidates it quietly, follows later directory changes in place, and only
/// asks the endpoints directly when the directory cannot provide them (a role
/// without directory access, or a failed read). Owners call [dispose].
class ChannelCandidateFeed extends ChangeNotifier {
  ChannelCandidateFeed(this.w) {
    w.services.entityDirectory.addListener(_sync);
    final cached = cachedChannelMemberCandidates(w);
    if (cached != null) {
      value = cached;
      ready = true;
      w.services.entityDirectory.ensure(_kinds);
    } else {
      unawaited(_cold());
    }
  }
  final WorkspaceController w;
  static const _kinds = [
    WorkspaceEntityKind.agents,
    WorkspaceEntityKind.members,
  ];
  List<ChannelMemberCandidate> value = const [];

  /// False until the first list (from the directory or the endpoints) landed.
  bool ready = false;
  bool _disposed = false;

  void _sync() {
    if (_disposed) return;
    final next = cachedChannelMemberCandidates(w);
    if (next == null) return;
    value = next;
    ready = true;
    notifyListeners();
  }

  Future<void> _cold() async {
    final d = w.services.entityDirectory;
    await Future.wait([for (final kind in _kinds) d.refresh(kind)]);
    if (_disposed || ready) return;
    try {
      final direct = await loadChannelMemberCandidates(w);
      if (_disposed || ready) return;
      value = direct;
      ready = true;
      notifyListeners();
    } catch (_) {}
  }

  @override
  void dispose() {
    _disposed = true;
    w.services.entityDirectory.removeListener(_sync);
    super.dispose();
  }
}

class CreateChannelDialog extends StatefulWidget {
  const CreateChannelDialog({
    super.key,
    required this.controller,
    this.prefilledName,
    this.prefilledDescription,
    this.prefilledVisibility = 'public',
    this.prefilledAgentIds = const [],
    this.prefilledHumanIds = const [],
    this.onCreated,
  });
  final WorkspaceController controller;
  final String? prefilledName, prefilledDescription;
  final String prefilledVisibility;
  final List<String> prefilledAgentIds, prefilledHumanIds;
  final Future<void> Function(RaftChannel channel)? onCreated;

  static Future<void> show(
    BuildContext context, {
    required WorkspaceController controller,
    Future<void> Function(RaftChannel channel)? onCreated,
  }) => showRaftForm<void>(
    context,
    builder: (_) =>
        CreateChannelDialog(controller: controller, onCreated: onCreated),
  );

  @override
  State<CreateChannelDialog> createState() => _CreateChannelDialogState();
}

class _CreateChannelDialogState extends State<CreateChannelDialog> {
  WorkspaceController get w => widget.controller;
  late final name = TextEditingController(text: widget.prefilledName ?? '');
  late final description = TextEditingController(
    text: widget.prefilledDescription ?? '',
  );
  final search = TextEditingController();
  late String visibility = widget.prefilledVisibility;
  late final Set<String> agentIds = {...widget.prefilledAgentIds};
  late final Set<String> humanIds = {...widget.prefilledHumanIds};
  late final ChannelCandidateFeed _feed = ChannelCandidateFeed(w);
  List<ChannelMemberCandidate> get candidates => _feed.value;
  bool submitting = false, unarchiving = false;

  /// Pair the new channel with a Slack channel (Web
  /// `useChannelSlackBridgeEditor`): only while the bridge is ready.
  late final SlackChannelPairing slack = SlackChannelPairing(w)
    ..addListener(_slackChanged);
  void _slackChanged() {
    if (mounted) setState(() {});
  }

  /// The channel created before the bridge failed: a retry only applies the
  /// pairing, it never creates a second channel.
  RaftChannel? createdForBridge;

  /// A failed create / unarchive (server text); the next submit clears it.
  // ignore: raft_lints/avoid_imperative_notice_state -- Cleared when the next submit starts; the dialog state is dropped when it closes.
  String? error;

  /// The name rule that rejected the last submit: it holds only while the
  /// name still breaks it.
  final nameInvalid = CauseNotice();
  Map<String, dynamic>? archivedCollision;

  @override
  void initState() {
    super.initState();
    search.addListener(() => setState(() {}));
    // The name rule is re-read on every edit, so its message ends with it.
    name.addListener(() => setState(() {}));
    _feed.addListener(() {
      if (mounted) setState(() {});
    });
    unawaited(slack.load(canManage: w.can('createChannels')));
  }

  @override
  void dispose() {
    slack.dispose();
    _feed.dispose();
    name.dispose();
    description.dispose();
    search.dispose();
    super.dispose();
  }

  void close() => Navigator.of(context).maybePop();

  Future<void> unarchiveCollision() async {
    final held = archivedCollision;
    if (held == null || unarchiving) return;
    setState(() => unarchiving = true);
    try {
      final result = await w.command(
        'POST',
        '/channels/${held['archivedChannelId']}/unarchive',
      );
      await w.refreshChannels();
      if (!mounted) return;
      Navigator.of(context).pop();
      await widget.onCreated?.call(
        RaftChannel(Map<String, dynamic>.from(result as Map)),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          archivedCollision = null;
          error = raftText(
            context,
            userErrorText(
              e,
              fallback: 'Failed to unarchive channel',
              where: 'create channel unarchive',
            ),
          );
        });
      }
    } finally {
      if (mounted) setState(() => unarchiving = false);
    }
  }

  Future<void> submit() async {
    if (submitting) return;
    final trimmed = name.text.trim();
    // `validateNameReason` + `formatNameValidationError`.
    final invalid = channelNameError(context, trimmed);
    if (invalid != null) {
      setState(() {
        error = null;
        nameInvalid.raise(
          invalid,
          whileTrue: () => channelNameError(context, name.text.trim()) != null,
        );
        archivedCollision = null;
      });
      return;
    }
    setState(() {
      submitting = true;
      error = null;
      nameInvalid.clear();
      archivedCollision = null;
    });
    try {
      final created =
          createdForBridge ??
          RaftChannel(
            Map<String, dynamic>.from(
              await w.command(
                'POST',
                '/channels',
                data: {
                  'name': trimmed,
                  if (description.text.trim().isNotEmpty)
                    'description': description.text.trim(),
                  'visibility': visibility,
                  'type': 'channel',
                  'agentIds': [...agentIds],
                  'userIds': [...humanIds],
                },
              ) as Map,
            ),
          );
      try {
        await slack.apply(created.id);
      } catch (_) {
        createdForBridge = created;
        await w.refreshChannels();
        if (mounted) {
          setState(
            () => error = raftText(
              context,
              'The channel was saved, but its Slack bridge was not enabled. Retry to finish the bridge setup.',
            ),
          );
        }
        return;
      }
      await w.refreshChannels();
      if (!mounted) return;
      Navigator.of(context).pop();
      await widget.onCreated?.call(created);
    } catch (e) {
      if (mounted) {
        final details = e is RaftApiException ? e.details : const {};
        setState(() {
          if (details['code'] == 'archived_name_collision' &&
              details['archivedChannelId'] != null) {
            archivedCollision = Map<String, dynamic>.from(details);
          } else {
            error = raftText(
              context,
              userErrorText(
                e,
                fallback: 'Failed to create channel',
                where: 'create channel',
              ),
            );
          }
        });
      }
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    RaftPickerItem item(ChannelMemberCandidate c) => RaftPickerItem(
      key: '${c.kind}:${c.id}',
      label: c.label,
      description: c.description,
      avatar: ChannelCandidateAvatar(
        candidate: c,
        avatarContext: RaftMountedAvatarContext.sidebarList,
        humanPlaceholder: true,
      ),
    );
    return RaftCreateChannelDialogView(
      name: name,
      description: description,
      search: search,
      visibility: visibility,
      onVisibilityChanged: (v) => setState(() => visibility = v),
      agents: [
        for (final c in candidates)
          if (c.kind == 'agent' && c.matches(search.text)) item(c),
      ],
      humans: [
        for (final c in candidates)
          if (c.kind == 'human' && c.matches(search.text)) item(c),
      ],
      hasCandidates: candidates.isNotEmpty,
      isSelected: (key) => key.startsWith('agent:')
          ? agentIds.contains(key.substring(6))
          : humanIds.contains(key.substring(6)),
      onToggle: (key) => setState(() {
        final set = key.startsWith('agent:') ? agentIds : humanIds;
        final id = key.substring(6);
        if (!set.remove(id)) set.add(id);
      }),
      onClose: close,
      onSubmit: submit,
      slackField: slack.available
          ? SlackChannelPairingField(
              pairing: slack,
              privacy: visibility,
              enabled: !submitting && createdForBridge == null,
              compact: true,
            )
          : null,
      error: error ?? nameInvalid.message,
      notice: archivedCollision == null
          ? null
          : RaftArchivedNameBanner(
              name: '${archivedCollision!['archivedChannelName']}',
              canUnarchive:
                  archivedCollision!['canUnarchiveArchivedChannel'] == true,
              busy: unarchiving,
              onUnarchive: unarchiveCollision,
              onChangeName: () => setState(() {
                archivedCollision = null;
                name.clear();
              }),
            ),
      submitting: submitting,
    );
  }
}

final _channelNameRegex = RegExp(r'^\p{L}[\p{L}\p{N}_-]*$', unicode: true);

/// `validateNameReason` + `formatNameValidationError` for a channel name.
String? channelNameError(BuildContext context, String value) {
  final label = raftText(context, 'Channel name');
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return raftFormat(context, '{label} is required', {'label': label});
  }
  if (trimmed.runes.length > 32) {
    return raftFormat(context, '{label} must be at most {max} characters', {
      'label': label,
      'max': 32,
    });
  }
  if (!_channelNameRegex.hasMatch(trimmed)) {
    return raftText(
      context,
      'Start with a letter, then letters, numbers, - or _',
    );
  }
  return null;
}
