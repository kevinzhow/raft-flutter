// Web ProfilePreviewCardContent.tsx / MentionHoverActivityPreview.tsx /
// ExternalIdentityPreviewCard.tsx adapters: resolve the hovered agent or
// member from the server-level entity directory and project it into
// raft_ui RaftProfilePreviewCard inside a RaftHoverCard.
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import '../data/workspace_entity_directory.dart';
import 'agent_detail_view.dart' show agentTimeFormatter;
import 'agent_metadata_catalog.dart';
import 'agent_trajectory_log.dart';
import 'computer_detail_view.dart' show computerAgentActivityText;

/// shared runtimeCatalog display names, with the deprecated status suffix
/// (formatRuntimeLabelWithStatus).
const _runtimeNames = <String, String>{
  'claude': 'Claude Code',
  'codex': 'Codex CLI',
  'grok': 'Grok Build',
  'builtin': 'Built-in Pi',
  'antigravity': 'Antigravity CLI',
  'kimi-sdk': 'Kimi Code',
  'kimi': 'Kimi CLI',
  'copilot': 'Copilot CLI',
  'cursor': 'Cursor CLI',
  'gemini': 'Gemini CLI',
  'opencode': 'OpenCode',
  'pi': 'Pi',
};
const _deprecatedRuntimes = {'antigravity', 'kimi', 'gemini'};

/// shared REASONING_EFFORT_RUNTIMES.
const _reasoningRuntimes = {
  'builtin',
  'claude',
  'codex',
  'grok',
  'copilot',
  'pi',
  'kimi-sdk',
};

String runtimeLabelWithStatus(BuildContext context, String runtime) {
  final name = _runtimeNames[runtime] ?? runtime;
  return _deprecatedRuntimes.contains(runtime)
      ? '$name${raftText(context, ' (deprecated)')}'
      : name;
}

RaftActivityTone activityTone(Object? activity) => switch (activity) {
  'online' => RaftActivityTone.online,
  'thinking' => RaftActivityTone.thinking,
  'working' => RaftActivityTone.working,
  'error' => RaftActivityTone.error,
  _ => RaftActivityTone.offline,
};

/// shared toolDisplay.ts getToolLogLabel / shouldHideToolStartInActivityLog.
const _toolLogLabels = <String, String>{
  'send_message': 'Sending message',
  'check_messages': 'Checking messages',
  'wait_for_message': 'Waiting for messages',
  'receive_message': 'Checking messages',
  'read_history': 'Reading history',
  'search_messages': 'Searching messages',
  'list_server': 'Listing server',
  'list_tasks': 'Listing tasks',
  'create_tasks': 'Creating tasks',
  'claim_tasks': 'Claiming tasks',
  'unclaim_task': 'Unclaiming task',
  'update_task_status': 'Updating task status',
  'add_channel_member': 'Adding channel member',
  'join_channel': 'Joining channel',
  'leave_channel': 'Leaving channel',
  'upload_file': 'Uploading file',
  'view_file': 'Viewing file',
  'read_file': 'Reading file',
  'write_file': 'Writing file',
  'edit_file': 'Editing file',
  'bash': 'Running command',
  'glob': 'Searching files',
  'grep': 'Searching code',
  'web_fetch': 'Fetching web',
  'web_search': 'Searching web',
  'todo_write': 'Updating tasks',
  'schedule_reminder': 'Scheduling reminder',
  'list_reminders': 'Listing reminders',
  'cancel_reminder': 'Canceling reminder',
  'collab_tool_call': 'Collaborating',
};
const _toolAliases = <String, String>{
  'Read': 'read_file',
  'ReadFile': 'read_file',
  'file_read': 'read_file',
  'Write': 'write_file',
  'WriteFile': 'write_file',
  'file_write': 'write_file',
  'Edit': 'edit_file',
  'EditFile': 'edit_file',
  'file_change': 'edit_file',
  'StrReplaceFile': 'edit_file',
  'Bash': 'bash',
  'shell': 'bash',
  'Shell': 'bash',
  'command_execution': 'bash',
  'run_shell_command': 'bash',
  'run_terminal_command': 'bash',
  'Glob': 'glob',
  'search_files': 'glob',
  'Grep': 'grep',
  'WebFetch': 'web_fetch',
  'fetch_url': 'web_fetch',
  'FetchURL': 'web_fetch',
  'WebSearch': 'web_search',
  'SearchWeb': 'web_search',
  'TodoWrite': 'todo_write',
  'SetTodoList': 'todo_write',
};

String? _toolSemantic(String name) {
  var normalized = name;
  for (final prefix in const ['mcp__chat__', 'mcp_chat_']) {
    if (normalized.startsWith(prefix)) {
      normalized = normalized.substring(prefix.length);
      break;
    }
  }
  final semantic = _toolAliases[normalized] ?? normalized;
  return _toolLogLabels.containsKey(semantic) ? semantic : null;
}

String _toolLogLabel(String name) {
  final semantic = _toolSemantic(name);
  if (semantic != null) return _toolLogLabels[semantic]!;
  var normalized = name;
  for (final prefix in const ['mcp__chat__', 'mcp_chat_']) {
    if (normalized.startsWith(prefix)) {
      normalized = normalized.substring(prefix.length);
      break;
    }
  }
  return normalized.replaceFirst(RegExp(r'^mcp__\w+__'), '');
}

/// MentionHoverActivityPreview getRecentActivityPreviewRows: the last five
/// visible trajectory entries, oldest first.
List<RaftProfilePreviewActivity> recentActivityRows(
  BuildContext context,
  WorkspaceController w,
  List<Map<String, dynamic>> entries,
) {
  final f = agentTimeFormatter(context, w);
  final visible = [
    for (final row in entries)
      if (row['entry'] is Map &&
          !((row['entry'] as Map)['kind'] == 'tool_start' &&
              _toolSemantic('${(row['entry'] as Map)['toolName']}') ==
                  'send_message'))
        row,
  ];
  return [
    for (final row in visible.skip(visible.length > 5 ? visible.length - 5 : 0))
      () {
        final entry = row['entry'] as Map;
        final kind = entry['kind'];
        String text(Object? value, String fallback) =>
            value is String && value.isNotEmpty
            ? value
            : raftText(context, fallback);
        final status = '${entry['activityKind'] ?? entry['activity'] ?? ''}';
        return RaftProfilePreviewActivity(
          time: f.clock(row['timestamp'], seconds: true),
          activity: switch (kind) {
            'thinking' => RaftActivityTone.thinking,
            'compaction_finished' => RaftActivityTone.online,
            'status' => activityTone(status),
            _ => RaftActivityTone.working,
          },
          text: switch (kind) {
            'thinking' => text(entry['text'], 'Thinking'),
            // shared getToolLogLabel is locale-free on Web too.
            'tool_start' => _toolLogLabel('${entry['toolName'] ?? ''}'),
            'text' => text(entry['text'], 'Output'),
            'compaction_started' => raftText(
              context,
              'Context Compaction Started',
            ),
            'compaction_finished' => raftText(
              context,
              'Context Compaction Finished',
            ),
            'status' => () {
              final display = agentTrajectoryStatusDisplay(
                status,
                '${entry['detail'] ?? ''}',
                entry['detailKind'] as String?,
              );
              return display.secondary.isEmpty
                  ? raftText(context, display.primary)
                  : display.secondary;
            }(),
            _ => '${entry['title'] ?? ''}',
          }.replaceAll('\n', ' '),
        );
      }(),
  ];
}

class _HoverActivity {
  List<Map<String, dynamic>> entries = [];
  bool requested = false;
}

/// Web PreviewCard on an agent / member avatar or @mention: delay 200,
/// closeDelay 120, `w-[280px]`, sideOffset 6, collisionPadding 6.
class ProfilePreviewHoverCard extends StatelessWidget {
  const ProfilePreviewHoverCard({
    super.key,
    required this.controller,
    required this.agent,
    required this.id,
    required this.child,
    this.avatar,
    this.fallbackLabel,
    this.fallback,
    this.onOpenActivity,
    this.enabled = true,
  });
  final WorkspaceController controller;

  /// Agent (true) or member/user (false) profile.
  final bool agent;
  final String id;
  final Widget child;

  /// Avatar artwork for the card (`mention-card` slot); default resolves
  /// from the directory row.
  final Widget? avatar;

  /// Handle from the mention token for an entity outside the directory.
  final String? fallbackLabel;

  /// Profile carried by the hovered surface (message sender projection).
  final Map<String, dynamic>? fallback;
  final ValueChanged<String>? onOpenActivity;
  final bool enabled;

  @override
  Widget build(BuildContext context) => RaftHoverCard(
    enabled: enabled,
    card: (_) => ProfilePreviewContent(
      controller: controller,
      agent: agent,
      id: id,
      avatar: avatar,
      fallbackLabel: fallbackLabel,
      fallback: fallback,
      onOpenActivity: onOpenActivity,
    ),
    child: child,
  );
}

class ProfilePreviewContent extends StatefulWidget {
  const ProfilePreviewContent({
    super.key,
    required this.controller,
    required this.agent,
    required this.id,
    this.avatar,
    this.fallbackLabel,
    this.fallback,
    this.onOpenActivity,
  });
  final WorkspaceController controller;
  final bool agent;
  final String id;
  final Widget? avatar;
  final String? fallbackLabel;
  final Map<String, dynamic>? fallback;
  final ValueChanged<String>? onOpenActivity;
  @override
  State<ProfilePreviewContent> createState() => _ProfilePreviewContentState();
}

class _ProfilePreviewContentState extends State<ProfilePreviewContent> {
  WorkspaceController get w => widget.controller;
  StreamSubscription<RaftEvent>? events;
  Map<String, dynamic>? fetched;
  bool fetching = false;
  _HoverActivity? activity;

  @override
  void initState() {
    super.initState();
    w.entityDirectory.addListener(changed);
    events = w.client.events.listen(event);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) load();
    });
  }

  @override
  void dispose() {
    events?.cancel();
    w.entityDirectory.removeListener(changed);
    super.dispose();
  }

  void changed() {
    if (mounted) setState(() {});
  }

  Map<String, dynamic>? get profile => widget.agent
      ? w.entityDirectory.agent(widget.id) ?? fetched ?? widget.fallback
      : w.entityDirectory.member(widget.id) ?? widget.fallback;

  /// canViewAgentPrivateSurfaces: agent editors, or the human creator.
  bool get private {
    final a = profile;
    if (!widget.agent || a == null) return false;
    if (w.can('editAgents')) return true;
    final me = w.client.user?.id;
    return me != null && a['creatorType'] == 'user' && a['creatorId'] == me;
  }

  Future<void> load() async {
    final id = widget.id, owner = w;
    // ensureAgentProfile: only a signed-in viewer reaches for a profile the
    // directory does not hold.
    if (widget.agent &&
        profile == null &&
        !fetching &&
        w.client.user != null &&
        w.can('viewAgents')) {
      fetching = true;
      try {
        final out = await w.query('/agents/$id');
        if (!mounted || !identical(owner, w) || id != widget.id) return;
        final row = out is Map && out['agent'] is Map ? out['agent'] : out;
        if (row is Map) {
          setState(() => fetched = Map<String, dynamic>.from(row));
        }
      } catch (_) {
        // The card keeps its graceful "Profile unavailable" body.
      }
    }
    if (!mounted || !private) return;
    final cache = w.agentTabCache.putIfAbsent(
      'hover-activity/$id',
      _HoverActivity.new,
    ) as _HoverActivity;
    setState(() => activity = cache);
    if (cache.requested) return;
    cache.requested = true;
    try {
      final result = await w.query(
        '/agents/$id/activity-log',
        query: {'limit': '5'},
      );
      cache.entries = mergeAgentTrajectoryLog(
        cache.entries,
        admittedAgentTrajectoryRows(result),
      );
      if (mounted) setState(() {});
    } catch (_) {
      // Web keeps an empty log on a failed read.
    }
  }

  void event(RaftEvent e) {
    final cache = activity;
    if (cache == null ||
        e.name != 'agent:activity' ||
        e.payload is! Map ||
        (e.payload as Map)['agentId'] != widget.id) {
      return;
    }
    final payload = e.payload as Map;
    final raw = payload['entries'];
    if (payload['isHeartbeat'] == true ||
        payload['isRefreshOnly'] == true ||
        raw is! List ||
        raw.isEmpty ||
        payload['timestamp'] is! num ||
        (payload['sourceServerId'] != null &&
            payload['sourceServerId'] != w.server?.id)) {
      return;
    }
    cache.entries = mergeAgentTrajectoryLog(
      cache.entries,
      admittedAgentTrajectoryRows([
        for (final entry in raw.whereType<Map>())
          {
            'timestamp': payload['timestamp'],
            'entry': entry,
            for (final key in ['serverSeq', 'launchId', 'clientSeq', 'probeId'])
              if (payload[key] != null) key: payload[key],
          },
      ]),
    );
    if (mounted) setState(() {});
  }

  Widget avatar(Map<String, dynamic>? row) =>
      widget.avatar ??
      RaftAvatarSlot(
        name: '${row?['displayName'] ?? row?['name'] ?? ''}',
        agent: widget.agent,
        avatarUrl: row?['avatarUrl'] as String?,
        slot: RaftAvatarSlotContext.mentionCard,
      );

  @override
  Widget build(BuildContext context) {
    final row = profile;
    if (row == null) {
      final handle = widget.fallbackLabel;
      return RaftProfilePreviewCard(
        avatar: avatar(null),
        name: handle != null && handle.isNotEmpty
            ? '@${handle.replaceFirst(RegExp('^@'), '')}'
            : raftText(context, widget.agent ? 'Agent' : 'Member'),
        subtitle: raftText(context, 'Profile unavailable'),
      );
    }
    final name = '${row['displayName'] ?? ''}'.isNotEmpty
        ? '${row['displayName']}'
        : '${row['name'] ?? ''}';
    final description = row['description'] is String
        ? row['description'] as String
        : null;
    if (!widget.agent) {
      return RaftProfilePreviewCard(
        avatar: avatar(row),
        name: name,
        subtitle: '@${row['name'] ?? ''}',
        description: description,
      );
    }
    final config = row['runtimeConfig'] is Map
        ? row['runtimeConfig'] as Map
        : null;
    final runtime = '${config?['runtime'] ?? row['runtime'] ?? 'unknown'}';
    final model = '${config?['model'] ?? row['model'] ?? ''}';
    final external = row['external'] == true || runtime == 'external';
    final activityValue = '${row['activity'] ?? 'offline'}';
    final statusText = private
        ? computerAgentActivityText(row)
        : computerAgentActivityText({'activity': activityValue});
    final machineId = row['machineId'];
    final computers = w.entityDirectory.state(WorkspaceEntityKind.computers);
    final machine = machineId is String
        ? w.entityDirectory.computer(machineId)
        : null;
    final String? computer = external
        ? raftText(context, 'External runtime')
        : machine != null
        ? '${machine['name'] ?? ''}'
        : machineId is String && !computers.loaded
        ? null
        : raftText(context, 'No computer assigned');
    final reasoning = _reasoningRuntimes.contains(runtime)
        ? (config?['reasoningEffort'] is String &&
                  (config!['reasoningEffort'] as String).isNotEmpty
              ? config['reasoningEffort'] as String
              : raftText(context, 'Default'))
        : null;
    return RaftProfilePreviewCard(
      avatar: avatar(row),
      name: name,
      subtitle: '@${row['name'] ?? ''}',
      status: RaftProfilePreviewStatus(
        activity: activityTone(activityValue),
        external: external && row['online'] != true,
        text: raftText(context, statusText),
      ),
      facts: row['profileProjection'] == 'channel_summary'
          ? null
          : [
              if (computer != null)
                RaftProfilePreviewFact(raftText(context, 'Computer'), computer),
              RaftProfilePreviewFact(
                raftText(context, 'Runtime'),
                runtimeLabelWithStatus(context, runtime),
              ),
              RaftProfilePreviewFact(
                raftText(context, 'Model'),
                model.isEmpty || model == 'default'
                    ? raftText(context, 'Default')
                    : sourceRuntimeModelLabels[runtime]?[model] ?? model,
              ),
              if (reasoning != null)
                RaftProfilePreviewFact(
                  raftText(context, 'Reasoning'),
                  reasoning,
                  capitalize: true,
                ),
            ],
      description: description,
      activity: activity == null
          ? const []
          : recentActivityRows(context, w, activity!.entries),
      onOpenActivity: widget.onOpenActivity == null
          ? null
          : () => widget.onOpenActivity!(widget.id),
    );
  }
}

/// Web ExternalIdentityPreviewCard: the hover card on an external
/// (Slack-projected) sender avatar.
class ExternalIdentityHoverCard extends StatelessWidget {
  const ExternalIdentityHoverCard({
    super.key,
    required this.displayName,
    required this.avatar,
    required this.child,
    this.provider,
    this.workspaceName,
    this.actorKind,
  });
  final String displayName;
  final String? provider, workspaceName, actorKind;
  final Widget avatar, child;

  @override
  Widget build(BuildContext context) => RaftHoverCard(
    card: (context) {
      final kind = raftText(context, switch (actorKind) {
        'human' => 'Human',
        'guest' => 'Guest',
        'remote' => 'Remote participant',
        'bot' => 'Bot',
        _ => 'External participant',
      });
      final providerLabel = provider == 'slack' ? 'Slack' : null;
      return RaftProfilePreviewCard(
        key: const ValueKey('external-identity-preview'),
        avatar: avatar,
        name: displayName,
        subtitle: providerLabel == null ? kind : '$providerLabel · $kind',
        notes: [
          if (workspaceName != null && workspaceName!.isNotEmpty)
            raftFormat(context, 'From {workspace}', {
              'workspace': workspaceName!,
            }),
          raftText(context, 'External identity'),
        ],
      );
    },
    child: child,
  );
}

/// MessageItem SenderAvatar: the sender's hover card around [child] (the
/// avatar). Agents and members open the profile card; external senders the
/// external identity card. [content] is the avatar artwork already resolved
/// for the row, reused at the card's `mention-card` size.
Widget senderProfileHoverCard({
  required WorkspaceController controller,
  required RaftMessage message,
  required RaftAvatarContent content,
  required Widget child,
}) {
  final type = message.string('senderType');
  final id = message.string('senderId');
  if (type == 'external_projection' || message.json['externalAuthor'] is Map) {
    final author = message.json['externalAuthor'] is Map
        ? message.json['externalAuthor'] as Map
        : const {};
    return ExternalIdentityHoverCard(
      displayName: message.author,
      provider: author['provider'] as String?,
      workspaceName: author['workspaceName'] as String?,
      actorKind: author['actorKind'] as String?,
      avatar: RaftAvatarSlot(
        name: message.author,
        slot: RaftAvatarSlotContext.mentionCard,
        agent: false,
        content: content,
      ),
      child: child,
    );
  }
  if (id.isEmpty || (type != 'agent' && type != 'user')) return child;
  return ProfilePreviewHoverCard(
    controller: controller,
    agent: type == 'agent',
    id: id,
    fallbackLabel: message.string('senderName'),
    avatar: RaftAvatarSlot(
      name: message.author,
      slot: RaftAvatarSlotContext.mentionCard,
      agent: type == 'agent',
      content: content,
    ),
    child: child,
  );
}
