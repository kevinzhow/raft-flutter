import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import 'slack_bridge_contract.dart';

class SlackBridgeRecovery extends StatelessWidget {
  const SlackBridgeRecovery({
    super.key,
    required this.bridge,
    required this.canManage,
    required this.busy,
    required this.onRetry,
    required this.onReplay,
    required this.onRefresh,
    required this.showOutbound,
  });

  final SlackBridgeProjection bridge;
  final bool canManage, busy, showOutbound;
  final ValueChanged<Map<String, dynamic>> onRetry, onReplay;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    String tr(String text) => raftText(context, text);
    String name(Map<String, dynamic> row) =>
        bridge
                .rows('raftChannels')
                .where((channel) => channel['id'] == row['raftChannelId'])
                .firstOrNull?['name']
            as String? ??
        tr('Raft channel');
    final deliveries = bridge.healthRows('outboundDeliveries');
    final bindings = bridge.healthRows('bindings');
    final events = bridge.healthRows('inboundIsolated');
    final groups = bridge.healthRows('inboundIsolatedGroups');
    final summary = bridge.health['inboundIsolatedSummary'];
    final blocks = bridge.healthRows('outboundPairBlocks');
    final attachments = bridge.healthRows('attachmentSourceIssues');
    final notices = bridge.healthRows('cardEditNotices');
    Widget retryButton(String label, VoidCallback? action) => RaftButton(
      label: tr(label),
      tone: RaftButtonRecipeVariant.outline,
      onPressed: busy ? null : action,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: RaftSpace.x3,
      children: [
        if (showOutbound && blocks.isNotEmpty)
          RaftBanner(
            title: tr('Slack sync is waiting to resume'),
            description: tr(
              'Messages stay in order and resume automatically when the connection is restored.',
            ),
            footer: _lines([
              for (final row in blocks) '${name(row)}: ${tr(_waiting(row))}',
            ]),
          ),
        if (showOutbound && attachments.isNotEmpty)
          RaftBanner(
            title: tr('Attachment source unavailable'),
            footer: _lines([
              for (final row in attachments)
                raftFormat(
                  context,
                  row['reason'] == 'size_mismatch'
                      ? 'A file in {channel} has an unexpected size. The message is waiting while the source is checked.'
                      : 'Files in {channel} could not be prepared. Check the file source or Slack access; the message is waiting and will retry automatically.',
                  {'channel': name(row)},
                ),
            ]),
          ),
        if (showOutbound && notices.isNotEmpty)
          RaftBanner(
            title: tr('Card updates in Slack'),
            footer: _lines([
              for (final row in notices)
                raftFormat(context, _cardNotice(row['kind']), {
                  'channel': name(row),
                  'reason': tr(_waiting(row)),
                }),
            ]),
          ),
        if (showOutbound && deliveries.isNotEmpty)
          RaftBanner(
            title: tr('Outgoing messages are waiting for recovery.'),
            description: tr(
              'Restore the Raft app’s access to the Slack channel, then retry the stalled message in place. If Slack accepted an earlier attempt, retrying may create a duplicate. Slack’s retry delay is respected. Later messages keep their order.',
            ),
            footer: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: RaftSpace.x2,
              children: [
                if (canManage)
                  for (final delivery in deliveries)
                    Wrap(
                      spacing: RaftSpace.x2,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text('#${name(delivery)}'),
                        retryButton(
                          delivery['retryRequested'] == true
                              ? 'Retry requested'
                              : 'Retry stalled message',
                          delivery['retryRequested'] == true ||
                                  !bindings.any(
                                    (binding) =>
                                        binding['id'] ==
                                            delivery['bindingId'] &&
                                        binding['bindingEpoch'] ==
                                            delivery['bindingEpoch'] &&
                                        binding['state'] == 'active',
                                  )
                              ? null
                              : () => onRetry(delivery),
                        ),
                      ],
                    ),
                retryButton('Refresh and recheck', onRefresh),
              ],
            ),
          ),
        if (events.isNotEmpty || (summary is Map && summary['count'] != 0))
          RaftBanner(
            title: tr('Messages need attention'),
            description: tr(
              'These messages are saved safely while later messages continue. Retry after the issue is resolved; a retried message keeps its original time and may appear before later messages.',
            ),
            footer: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: RaftSpace.x2,
              children: [
                if (summary is Map)
                  Text(
                    raftFormat(
                      context,
                      'Total: {count}; {undisplayed} not shown.',
                      {
                        'count': summary['count'],
                        'undisplayed': summary['undisplayed'],
                      },
                    ),
                  ),
                for (final row in [...(canManage ? groups : []), ...events])
                  Wrap(
                    spacing: RaftSpace.x2,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        '${name(row)}: ${tr(_inboundReason(row['reason']))}'
                        '${row['count'] == null ? '' : ' (${row['count']})'}',
                      ),
                      if (canManage)
                        retryButton(
                          row['eventId'] != null
                              ? 'Retry message'
                              : 'Retry up to 100',
                          () => onReplay(row),
                        ),
                    ],
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _lines(List<String> lines) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [for (final line in lines) Text(line)],
  );
}

String _inboundReason(Object? reason) => switch (reason) {
  'bot_sync_disabled' => 'Waiting for bot message sync to be enabled',
  'bot_outbound_pending' => 'Waiting for an outgoing message result',
  'bot_identity_pending' ||
  'actor_identity_pending' => 'Sender identity is unavailable',
  _ => 'Message format could not be processed',
};

String _waiting(Map<String, dynamic> row) {
  if (row['action'] == 'workspace_admin') {
    return 'Ask a Slack workspace administrator to allow this app in the channel or workspace.';
  }
  return switch (row['detail'] ?? row['reason']) {
    'history_limited' => "Can't confirm an earlier message reached Slack, because this channel's Slack history doesn't go back far enough. New messages wait until then; retrying every 15 minutes.",
    'metadata_missing' => "Can't confirm an earlier message reached Slack, because Raft can't recognize its own earlier messages in this channel. New messages wait until then; retrying every 15 minutes.",
    'marker_unconfirmed' => 'Confirming an earlier message reached Slack; new messages wait until then. Retrying every 15 minutes.',
    'invite_app' => 'Invite the Raft app back to the Slack channel.',
    'reauthorize' => 'Reauthorize the Slack app to restore its permissions.',
    'unarchive' =>
      'The Slack channel is archived. Unarchive it to resume automatically.',
    'check_channel' => 'Slack cannot find the channel. Check whether it was deleted or made private.',
    'connection' => 'Waiting for the connection or channel pairing',
    'credentials' => 'Waiting for Slack access to be restored',
    _ => 'Waiting for the channel configuration to be restored',
  };
}

String _cardNotice(Object? kind) => switch (kind) {
  'not_confirmed' =>
    "{channel}: a card's latest update is not confirmed in Slack.",
  'latest_update_not_shown' =>
    "{channel}: a card's latest update could not be shown in Slack.",
  'updates_cannot_be_shown' =>
    "{channel}: a card's updates can't be shown in Slack.",
  _ => '{channel}: card updates are waiting to reach Slack. {reason}',
};
