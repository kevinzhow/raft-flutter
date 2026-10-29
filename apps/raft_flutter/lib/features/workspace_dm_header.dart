import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/raft_location.dart';
import '../data/workspace_controller.dart';
import 'agent_hosted_cindy_banner.dart';
import 'agent_metadata_projection.dart';
import 'resource_cards.dart' show resourceRelativeTime;

/// DM identity, activity and profile action, using the accepted peer projection.
/// The workspace owns selection and navigation; this widget adds no state.
class WorkspaceDmHeader extends StatelessWidget {
  const WorkspaceDmHeader({
    super.key,
    required this.headerKey,
    required this.controller,
    required this.channel,
    required this.agent,
    required this.name,
    required this.profile,
    required this.avatar,
    required this.selectionActive,
    required this.onSearch,
    required this.onSettings,
    this.onBack,
    this.backKey,
  });

  final Key headerKey;
  final WorkspaceController controller;
  final RaftChannel channel;
  final bool agent;
  final String name;
  final Map<String, dynamic>? profile;
  final Widget avatar;
  final bool Function() selectionActive;
  final VoidCallback onSearch, onSettings;
  final VoidCallback? onBack;
  final Key? backKey;

  @override
  Widget build(BuildContext context) {
    final display = !agent || profile == null
        ? null
        : agentRowAmbientDisplay(profile!);
    final activity = !agent
        ? null
        : switch (display?.activity) {
            'thinking' => RaftActivityTone.thinking,
            'working' => RaftActivityTone.working,
            'error' => RaftActivityTone.error,
            'offline' => RaftActivityTone.offline,
            'online' => RaftActivityTone.online,
            _ => RaftActivityTone.offline,
          };
    final peerId = channel.string('peerId');
    final header = RaftDmHeader(
      key: headerKey,
      name: name,
      avatar: avatar,
      activity: activity,
      external: agent && profile?['runtime'] == 'external',
      activityText: activity == null
          ? null
          : display == null
          ? raftText(context, 'Offline')
          : agentDisplayText(
              display,
              lastSeenAt: DateTime.tryParse('${profile?['lastSeenAt']}'),
              relativeTime: (seen) => resourceRelativeTime(
                seen.toIso8601String(),
                chinese: Localizations.localeOf(context).languageCode == 'zh',
              ),
              translate: (source, values) =>
                  raftFormat(context, source, values),
            ),
      muted: channel.flag('activityMuted'),
      mutedLabel: raftText(
        context,
        'Activity muted. Direct mentions can still notify you.',
      ),
      onBack: onBack,
      backKey: backKey,
      backLabel: raftText(
        context,
        selectionActive() ? 'Exit Selection' : 'Back',
      ),
      onSearch: onSearch,
      onSettings: onSettings,
      onAvatarTap: peerId.isEmpty
          ? null
          : () {
              if (selectionActive()) return;
              controller.openProfile(
                agent ? RaftProfileKind.agent : RaftProfileKind.human,
                peerId,
              );
            },
      searchLabel: raftText(context, 'Search This Channel'),
      settingsLabel: raftText(context, 'Channel Details and Settings'),
    );
    final cloud = profile;
    // A cloud Cindy that could not start says so under her header.
    if (!agent || cloud == null || !isHostedCindyCandidate(controller, cloud)) {
      return header;
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        HostedCindyFailedBanner(controller: controller, agent: cloud),
      ],
    );
  }
}
