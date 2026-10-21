import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/sos_resume_result.dart';
import '../data/workspace_controller.dart';
import 'management_support.dart' show pageIdentity;

/// Channel SOS commands as Web SOSDialog runs them: no failure message, the
/// dialog stays where it is; only a resume shortfall is reported, by count.
Future<void> showChannelSos(
  BuildContext context,
  WorkspaceController w,
  RaftChannel channel,
) async {
  final identity = pageIdentity(w);
  List<String>? retryAgentIds;
  // The server, account or permission changed under the open dialog: send
  // nothing (Web has no such state; its dialog is unmounted instead).
  bool refused() =>
      identity != pageIdentity(w) || !w.can('controlAgentRuntime');
  await showRaftDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return Center(
        child: RaftSosDialog(
          key: const ValueKey('channel-sos-dialog'),
          channelName: channel.name,
          onClose: () => Navigator.of(dialogContext).pop(),
          onStop: () async {
            if (refused()) return RaftSosOutcome.retained;
            try {
              await w.command(
                'POST',
                '/channels/${channel.id}/stop-all-agents',
              );
              return null;
            } catch (_) {
              return RaftSosOutcome.retained;
            }
          },
          onResume: (guidance) async {
            if (refused()) return RaftSosOutcome.retained;
            final prompt =
                '[SOS] The user has emergency-stopped all agents in #${channel.name} because they were going off-track. Here is the user\'s correction and new guidance:\n\n$guidance\n\nRead this carefully, acknowledge the correction, and adjust your approach accordingly. Use check_messages and read_history to understand the current state before taking any action.';
            try {
              final response = await w.command(
                'POST',
                '/channels/${channel.id}/resume-all-agents',
                data: {'prompt': prompt, 'agentIds': ?retryAgentIds},
              );
              // Web SOSDialog: a response naming no missed agent closes the
              // dialog; a thrown request keeps the guidance without a message.
              final result = SosResumeResult.parse(response);
              if (result.missed.isEmpty) return null;
              retryAgentIds = result.retryAgentIds;
              return RaftSosShortfall(
                starting: result.starting,
                failed: result.failed,
              );
            } catch (_) {
              return RaftSosOutcome.retained;
            }
          },
        ),
      );
    },
  );
}
