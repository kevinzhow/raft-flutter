import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/sos_resume_result.dart';
import '../data/user_error.dart';
import '../data/workspace_controller.dart';
import 'management_support.dart' show pageIdentity;

/// Channel SOS commands retain the guidance and report each missed agent.
Future<void> showChannelSos(
  BuildContext context,
  WorkspaceController w,
  RaftChannel channel,
) async {
  final identity = pageIdentity(w);
  List<String>? retryAgentIds;
  String? refused() =>
      identity != pageIdentity(w) || !w.can('controlAgentRuntime')
      ? 'You no longer have permission to control agents here.'
      : null;
  String failure(Object error, String fallback) =>
      userErrorText(error, fallback: fallback, where: 'channel SOS');
  await showRaftDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      String tr(String text) => raftText(dialogContext, text);
      return Center(
        child: RaftSosDialog(
          key: const ValueKey('channel-sos-dialog'),
          channelName: channel.name,
          onClose: () => Navigator.of(dialogContext).pop(),
          onStop: () async {
            final denied = refused();
            if (denied != null) return tr(denied);
            try {
              await w.command(
                'POST',
                '/channels/${channel.id}/stop-all-agents',
              );
              if (!dialogContext.mounted) return null;
              final denied = refused();
              return denied == null ? null : tr(denied);
            } catch (e) {
              if (!dialogContext.mounted) return null;
              return failure(e, tr('Agents could not be stopped. Try again.'));
            }
          },
          onResume: (guidance) async {
            final denied = refused();
            if (denied != null) return tr(denied);
            final prompt =
                '[SOS] The user has emergency-stopped all agents in #${channel.name} because they were going off-track. Here is the user\'s correction and new guidance:\n\n$guidance\n\nRead this carefully, acknowledge the correction, and adjust your approach accordingly. Use check_messages and read_history to understand the current state before taking any action.';
            try {
              final response = await w.command(
                'POST',
                '/channels/${channel.id}/resume-all-agents',
                data: {'prompt': prompt, 'agentIds': ?retryAgentIds},
              );
              if (!dialogContext.mounted) return null;
              final denied = refused();
              if (denied != null) return tr(denied);
              final result = SosResumeResult.parse(response);
              if (result.succeeded) return null;
              retryAgentIds = result.retryAgentIds ?? retryAgentIds;
              if (result.failures.isNotEmpty) {
                // Web SOSDialog `ResumeShortfall`: counts, not agent names.
                final starting = result.failures
                    .where((missed) => missed.reason == 'start_in_flight')
                    .length;
                return RaftSosShortfall(
                  starting: starting,
                  failed: result.failures.length - starting,
                );
              }
              return tr('Agents could not be resumed. Try again.');
            } catch (e) {
              if (!dialogContext.mounted) return null;
              return failure(e, tr('Agents could not be resumed. Try again.'));
            }
          },
        ),
      );
    },
  );
}
