import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import 'channel_details_host.dart';
import 'channel_side_cards.dart';
import 'lounge_channel_presentation.dart' show loungeHeaderFor;
import 'management_support.dart' show managementLaunch;
import 'public_page_live.dart';
import 'channel_activity_badge.dart';

/// ChatPanel's header of an ordinary, private or joint channel: the name, the
/// Archived badge and the muted bell (`ActivityMutedBadge`) after it, the
/// description with its http(s) links tappable (`ChannelDescription`), and the
/// Search / Settings actions. The workspace owns selection and navigation;
/// this widget adds no state.
class WorkspaceChannelHeader extends StatelessWidget {
  const WorkspaceChannelHeader({
    super.key,
    required this.headerKey,
    required this.controller,
    required this.channel,
    required this.backLabel,
    required this.onSearch,
    required this.onSettings,
    this.onBack,
    this.backKey,
    this.workingAgents = const [],
    this.launch = managementLaunch,
  });
  final Key headerKey;
  final WorkspaceController controller;
  final RaftChannel channel;
  final String backLabel;
  final VoidCallback onSearch, onSettings;
  final VoidCallback? onBack;
  final Key? backKey;
  final List<RaftWorkingAgent> workingAgents;

  /// Opens a description link outside the app.
  final Future<void> Function(String url) launch;

  /// A link that cannot be opened is dropped silently, like a click on a dead
  /// anchor; the description text stays.
  Future<void> openLink(BuildContext context, String url) async {
    try {
      await launch(url);
    } catch (_) {
      if (context.mounted) {
        showRaftToast(context, 'Could not open this address.');
      }
    }
  }

  @override
  Widget build(BuildContext context) => channelActivityHeader(
    controller,
    channel,
    (context, suffix) => channelSideListener(
      controller,
      (context) => channelDetailsHeader(
        controller,
        channel,
        (context, pressed) =>
            loungeHeaderFor(context, this, settingsPressed: pressed) ??
            RaftChannelHeader(
              key: headerKey,
              name: channel.name,
              titleSuffix: suffix,
              description: channel.description,
              kind: channel.type,
              workingAgents: workingAgents,
              onBack: channelBackClosingSide(controller, onBack),
              backKey: backKey,
              backLabel: backLabel,
              onSearch: onSearch,
              onSettings: onSettings,
              settingsPressed: pressed,
              middleActions: channelSideToggles(context, controller),
              searchLabel: raftText(context, 'Search This Channel'),
              settingsLabel: raftText(context, 'Channel Details and Settings'),
              archivedLabel: channel.archived
                  ? raftText(context, 'Archived')
                  : null,
              mutedLabel: channel.flag('activityMuted')
                  ? raftText(
                      context,
                      'Activity muted. Direct mentions can still notify you.',
                    )
                  : null,
              onOpenLink: (url) => openLink(context, url),
              publicPage: channelOnPublicPage(controller, channel),
            ),
      ),
    ),
  );
}
