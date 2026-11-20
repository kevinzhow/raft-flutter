// Web components/channel/CreateChannelDialog.tsx ordinary channel adapter.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/cause_notice.dart';
import '../data/external_invite_api.dart';
import '../data/feature_flag_client_facts.dart' show RaftFeatureFlags;
import '../data/user_error.dart';

import '../data/workspace_controller.dart';
import 'slack_channel_pairing.dart';
import 'search_ranking.dart';
import '../data/workspace_entity_directory.dart';
import 'channel_form_fields.dart';
import 'external_invite_channel_dialog.dart' show showNewExternalChannelInvites;
import 'external_invite_channel_members.dart' show showExternalChannelLimit;
import 'management_support.dart'
    show cachedServerFlag, managementMap, pageIdentity;

typedef ArchivedChannelNameCollision = ({
  String id,
  String name,
  String type,
  bool canUnarchive,
});

ArchivedChannelNameCollision? parseArchivedChannelNameCollision(
  Object error, {
  Set<String> types = const {'channel', 'private', 'joint'},
}) {
  if (error is! RaftApiException) return null;
  final details = error.details;
  if (details['code'] != 'archived_name_collision') return null;
  final id = details['archivedChannelId'];
  final name = details['archivedChannelName'];
  final type = details['archivedChannelType'];
  if (id is! String ||
      id.isEmpty ||
      name is! String ||
      name.isEmpty ||
      type is! String ||
      !types.contains(type)) {
    return null;
  }
  return (
    id: id,
    name: name,
    type: type,
    canUnarchive: details['canUnarchiveArchivedChannel'] == true,
  );
}

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
    this.sourceServerLabel,
    this.managedByAppInstallId,
    this.managedByAppName,
  });
  final String kind; // 'agent' | 'human'
  final String id, name;
  final String? displayName, description, avatarUrl, sourceServerLabel;
  final String? managedByAppInstallId, managedByAppName;
  String get label =>
      (displayName?.trim().isNotEmpty ?? false) ? displayName! : name;
  bool matches(String query) =>
      searchChannelMemberCandidates(query, [this]).isNotEmpty;
}

List<ChannelMemberCandidate> searchChannelMemberCandidates(
  String query,
  List<ChannelMemberCandidate> candidates,
) => rankSearchEntries(query, [
  for (final candidate in candidates)
    SearchRankEntry(candidate, [
      (text: candidate.name, priority: 0),
      (text: candidate.displayName ?? '', priority: 1),
      (text: candidate.description ?? '', priority: 3),
      (text: candidate.sourceServerLabel ?? '', priority: 4),
    ]),
]);

Widget? channelCandidateAppBadge(
  BuildContext context,
  ChannelMemberCandidate candidate,
) {
  if (candidate.managedByAppInstallId == null) return null;
  final app = candidate.managedByAppName;
  final badge = RaftBadge(
    key: const ValueKey('app-bot-badge'),
    label: app == null || app.isEmpty || app == candidate.label
        ? raftText(context, 'App')
        : raftFormat(context, 'App · {app}', {'app': app}),
    appearance: RaftBadgeRecipeAppearance.soft,
    variant: RaftBadgeRecipeVariant.muted,
  );
  return app == null || app.isEmpty
      ? badge
      : RaftTooltip(
          message: raftFormat(context, 'Created by the {app} app', {
            'app': app,
          }),
          child: badge,
        );
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
    if (a['deletedAt'] == null &&
        a['inMemberLists'] != false &&
        (a['assistantOwnerUserId'] == null || a['assistantOwnerUserId'] == ''))
      ChannelMemberCandidate(
        kind: 'agent',
        id: '${a['id']}',
        name: '${a['name'] ?? ''}',
        displayName: a['displayName'] as String?,
        description: a['description'] as String?,
        avatarUrl: a['avatarUrl'] as String?,
        managedByAppInstallId: a['managedByAppInstallId'] as String?,
        managedByAppName: a['managedByApp'] is Map
            ? (a['managedByApp'] as Map)['name'] as String?
            : null,
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
          sourceServerLabel: (m['serverName'] ?? m['serverSlug']) as String?,
          avatarUrl: m['avatarUrl'] as String?,
        ),
];

/// Agents and server members from the same endpoints the Web stores load
/// (`/agents`, `/servers/:id/members`).
Future<List<ChannelMemberCandidate>> loadChannelMemberCandidates(
  WorkspaceController w, {
  bool includeSelf = false,
}) async {
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
    includeSelf ? null : w.client.user?.id,
  );
}

/// The picker candidates the workspace directory already holds (this session
/// or restored from the device); null while either list was never loaded.
List<ChannelMemberCandidate>? cachedChannelMemberCandidates(
  WorkspaceController w, {
  bool includeSelf = false,
}) {
  final d = w.services.entityDirectory;
  if (!d.state(WorkspaceEntityKind.agents).loaded ||
      !d.state(WorkspaceEntityKind.members).loaded) {
    return null;
  }
  return channelMemberCandidatesFrom(
    d.rows(WorkspaceEntityKind.agents),
    d.rows(WorkspaceEntityKind.members),
    includeSelf ? null : w.client.user?.id,
  );
}

/// Live source of the member picker's candidates. It holds the workspace
/// directory's copy at once (no request is awaited before a surface opens),
/// revalidates it quietly, follows later directory changes in place, and only
/// asks the endpoints directly when the directory cannot provide them (a role
/// without directory access, or a failed read). Owners call [dispose].
class ChannelCandidateFeed extends ChangeNotifier {
  ChannelCandidateFeed(this.w, {this.includeSelf = false}) {
    w.services.entityDirectory.addListener(_sync);
    final cached = cachedChannelMemberCandidates(w, includeSelf: includeSelf);
    if (cached != null) {
      value = cached;
      ready = true;
      w.services.entityDirectory.ensure(_kinds);
    } else {
      unawaited(_cold());
    }
  }
  final WorkspaceController w;
  final bool includeSelf;
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
    final next = cachedChannelMemberCandidates(w, includeSelf: includeSelf);
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
      final direct = await loadChannelMemberCandidates(
        w,
        includeSelf: includeSelf,
      );
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
    String prefilledVisibility = 'public',
  }) => showRaftForm<void>(
    context,
    builder: (_) => CreateChannelDialog(
      controller: controller,
      onCreated: onCreated,
      prefilledVisibility: prefilledVisibility,
    ),
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
  final _problem = GlobalKey();
  late String visibility = widget.prefilledVisibility;
  late final authority = pageIdentity(w);
  late final twoStep =
      cachedServerFlag(w, RaftFeatureFlags.externalChannels) == true ||
      widget.prefilledVisibility == 'external';
  bool get externalAvailable =>
      twoStep && const {'owner', 'admin'}.contains(w.server?.string('role'));
  bool? externalAtLimit;
  bool people = false;
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
  ArchivedChannelNameCollision? archivedCollision;

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
    if (externalAvailable) unawaited(_readExternalAvailability());
  }

  Future<void> _readExternalAvailability() async {
    final scope = authority;
    try {
      final atLimit = await ExternalInviteApi(w.command).atFreeLimit();
      if (mounted && pageIdentity(w) == scope) {
        setState(() => externalAtLimit = atLimit);
      }
    } on RaftApiException catch (failure) {
      if (mounted && pageIdentity(w) == scope) {
        setState(() {
          if (visibility == 'external') visibility = 'private';
          error = userErrorText(
            failure,
            fallback: 'Failed to check external channel availability',
            where: 'create channel',
          );
        });
      }
    }
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

  void openCollision() {
    final held = archivedCollision;
    if (held == null || unarchiving) return;
    final id = held.id;
    final channel =
        w.channels.where((c) => c.id == id).firstOrNull ??
        RaftChannel({
          'id': id,
          'name': held.name,
          'type': held.type,
          'archivedAt': 'archived',
        });
    Navigator.of(context).pop();
    unawaited(w.selectChannel(channel));
  }

  Future<void> unarchiveCollision() async {
    final held = archivedCollision;
    if (held == null || unarchiving) return;
    setState(() => unarchiving = true);
    try {
      final result = await w.command('POST', '/channels/${held.id}/unarchive');
      await w.refreshChannels();
      if (!mounted) return;
      Navigator.of(context).pop();
      await w.selectChannel(
        RaftChannel(Map<String, dynamic>.from(result as Map)),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
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
    if (pageIdentity(w) != authority) {
      setState(() => error = 'Server access changed. Reopen this form.');
      return;
    }
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
        people = false;
      });
      return;
    }
    if (twoStep && !people) {
      if (visibility == 'external' && externalAtLimit != false) return;
      setState(() {
        error = null;
        nameInvalid.clear();
        archivedCollision = null;
        people = visibility != 'external';
      });
      if (visibility == 'external') await _submitExternal(trimmed);
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
        if (pageIdentity(w) == authority) w.putSharedChannelRow(created);
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
      if (pageIdentity(w) == authority) w.putSharedChannelRow(created);
      if (!mounted || pageIdentity(w) != authority) return;
      Navigator.of(context).pop();
      await widget.onCreated?.call(created);
    } catch (e) {
      if (mounted) {
        final collision = parseArchivedChannelNameCollision(
          e,
          types: const {'channel', 'private'},
        );
        setState(() {
          if (collision != null) {
            archivedCollision = collision;
            people = false;
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

  Future<void> _submitFromForm() async {
    await submit();
    if (!mounted || !RaftFormFrame.sheetOf(context)) return;
    // The header action stays visible after the fields scroll. Bring a new
    // validation error or archived-name notice back into view under it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _problem.currentContext;
      if (target != null) {
        unawaited(Scrollable.ensureVisible(target, alignment: .25));
      }
    });
  }

  Future<void> _submitExternal(String channelName) async {
    RaftChannel? created;
    setState(() => submitting = true);
    try {
      final result = await showNewExternalChannelInvites(
        context,
        w,
        () async {
          if (pageIdentity(w) != authority ||
              !const {'owner', 'admin'}.contains(w.server?.string('role')) ||
              !w.can('createChannels')) {
            throw const RaftUserError(
              'Server access changed. Reopen this form.',
            );
          }
          final result = await w.command(
            'POST',
            '/channels',
            data: {
              'name': channelName,
              if (description.text.trim().isNotEmpty)
                'description': description.text.trim(),
              'visibility': 'private',
              'type': 'channel',
              'agentIds': [...agentIds],
              'userIds': [...humanIds],
            },
          );
          final channel = RaftChannel(managementMap(result));
          created = channel;
          if (pageIdentity(w) == authority) w.putSharedChannelRow(channel);
          if (pageIdentity(w) != authority) {
            throw const RaftUserError(
              'Server access changed. Reopen this form.',
            );
          }
          return channel;
        },
        channelName: channelName,
        members: _externalMembers(),
      );
      if (!mounted || pageIdentity(w) != authority || result?['back'] == true) {
        return;
      }
      if (result?['serversFailed'] == true) {
        showRaftToast(
          context,
          "The invites were sent, but your servers weren't connected. Try connecting them again.",
        );
      }
      Navigator.of(context).pop();
      if (created != null) await widget.onCreated?.call(created!);
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  RaftPickerItem _memberItem(BuildContext context, ChannelMemberCandidate c) =>
      RaftPickerItem(
        key: '${c.kind}:${c.id}',
        label: c.label,
        description: c.description,
        badge: channelCandidateAppBadge(context, c),
        avatar: ChannelCandidateAvatar(
          candidate: c,
          avatarContext: RaftMountedAvatarContext.sidebarList,
          humanPlaceholder: true,
        ),
      );

  bool _memberSelected(String key) => key.startsWith('agent:')
      ? agentIds.contains(key.substring(6))
      : humanIds.contains(key.substring(6));

  void _toggleMember(String key) {
    final set = key.startsWith('agent:') ? agentIds : humanIds;
    final id = key.substring(6);
    if (!set.remove(id)) set.add(id);
  }

  Widget _externalMembers() => StatefulBuilder(
    builder: (context, update) => ListenableBuilder(
      listenable: Listenable.merge([_feed, search]),
      builder: (context, _) => RaftProductFormField(
        label: raftFormat(context, '{server} members', {
          'server': w.server?.name ?? '',
        }),
        optional: true,
        child: RaftMemberPickerContent(
          search: search,
          agents: [
            for (final candidate in candidates)
              if (candidate.kind == 'agent') _memberItem(context, candidate),
          ],
          humans: [
            for (final candidate in candidates)
              if (candidate.kind == 'human') _memberItem(context, candidate),
          ],
          matchedKeys: [
            for (final candidate in searchChannelMemberCandidates(
              search.text,
              candidates,
            ))
              '${candidate.kind}:${candidate.id}',
          ],
          hasCandidates: candidates.isNotEmpty,
          isSelected: _memberSelected,
          onToggle: (key) => update(() => _toggleMember(key)),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final matching = searchChannelMemberCandidates(search.text, candidates);
    return RaftCreateChannelDialogView(
      name: name,
      description: description,
      search: search,
      visibility: visibility,
      externalAvailable: externalAvailable,
      twoStep: twoStep,
      people: people,
      externalReady: externalAtLimit != null,
      canContinue: visibility != 'external' || externalAtLimit == false,
      onBack: createdForBridge == null
          ? () => setState(() {
              people = false;
              error = null;
            })
          : null,
      visibilityHint: switch ((visibility, externalAtLimit)) {
        ('external', true) => raftFormat(
          context,
          'Free plan: {server} already has a channel with people outside it.',
          {'server': w.server?.name ?? ''},
        ),
        ('external', false) => raftFormat(
          context,
          'Work with people outside {server} in one channel. Only people you add can see it, including {server} members.',
          {'server': w.server?.name ?? ''},
        ),
        _ => null,
      },
      visibilityNotice: visibility == 'external' && externalAtLimit == true
          ? RaftTextLink(
              label: 'Upgrade for more',
              variant: RaftTextLinkVariant.strong,
              onPressed: () => showExternalChannelLimit(context, w, ''),
            )
          : null,
      onVisibilityChanged: (v) => setState(() => visibility = v),
      agents: [
        for (final c in candidates)
          if (c.kind == 'agent') _memberItem(context, c),
      ],
      humans: [
        for (final c in candidates)
          if (c.kind == 'human') _memberItem(context, c),
      ],
      hasCandidates: candidates.isNotEmpty,
      matchedMemberKeys: [for (final c in matching) '${c.kind}:${c.id}'],
      isSelected: _memberSelected,
      onToggle: (key) => setState(() => _toggleMember(key)),
      onClose: close,
      onSubmit: _submitFromForm,
      problemKey: _problem,
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
              name: archivedCollision!.name,
              canUnarchive: archivedCollision!.canUnarchive,
              busy: unarchiving,
              onUnarchive: unarchiveCollision,
              onOpen: openCollision,
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
