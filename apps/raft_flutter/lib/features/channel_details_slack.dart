import 'package:flutter/widgets.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import 'management_support.dart' show pageIdentity;
import 'slack_channel_pairing.dart';

class ChannelDetailsSlack extends StatelessWidget {
  const ChannelDetailsSlack({
    super.key,
    required this.channel,
    required this.pairing,
    required this.enabled,
  });

  final RaftChannel channel;
  final SlackChannelPairing pairing;
  final bool enabled;

  Future<void> open(BuildContext context) async {
    pairing.reset();
    final identity = pageIdentity(pairing.w);
    await showRaftDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _SlackPairingDialog(
        channel: channel,
        pairing: pairing,
        onConfirm: () async {
          if (identity != pageIdentity(pairing.w)) {
            throw const RaftUserError('The channel is no longer available.');
          }
          try {
            await pairing.apply(channel.id);
          } catch (_) {
            throw const RaftUserError(
              "The Slack channel wasn't connected. Try again.",
            );
          }
        },
      ),
    );
    if (context.mounted) pairing.reset();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: pairing,
    builder: (context, _) {
      if (!pairing.available) return const SizedBox.shrink();
      final connected = pairing.current.isNotEmpty;
      final name = pairing.currentName;
      return raftDetailsActionRow(
        key: const Key('channel-settings-slack'),
        title: raftText(context, 'Slack'),
        description: name != null
            ? raftFormat(context, '#{name} · Synced', {'name': name})
            : raftText(context, connected ? 'Connected' : 'Not connected'),
        action: RaftButton(
          key: const Key('channel-settings-slack-open'),
          label: raftText(context, connected ? 'Change' : 'Connect'),
          uiVariant: RaftButtonVariant.outline,
          onPressed: enabled ? () => open(context) : null,
        ),
      );
    },
  );
}

class _SlackPairingDialog extends StatefulWidget {
  const _SlackPairingDialog({
    required this.channel,
    required this.pairing,
    required this.onConfirm,
  });

  final RaftChannel channel;
  final SlackChannelPairing pairing;
  final Future<void> Function() onConfirm;

  @override
  State<_SlackPairingDialog> createState() => _SlackPairingDialogState();
}

class _SlackPairingDialogState extends State<_SlackPairingDialog> {
  final canConfirm = ValueNotifier(false);
  bool refreshing = false;

  SlackChannelPairing get pairing => widget.pairing;

  Future<void> refresh() async {
    setState(() => refreshing = true);
    try {
      await pairing.refresh();
    } catch (_) {
      if (mounted) {
        showRaftToast(
          context,
          'The Slack bridge operation failed. No setup state was assumed.',
        );
      }
    } finally {
      if (mounted) setState(() => refreshing = false);
    }
  }

  @override
  void dispose() {
    canConfirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: pairing,
    builder: (context, _) {
      final options = pairing.options(context, null);
      return RaftConfirmDialog(
        title: raftFormat(context, 'Connect #{channel} to Slack', {
          'channel': widget.channel.name,
        }),
        size: RaftDialogSize.md,
        plainMessage: true,
        confirmLabel: raftText(
          context,
          pairing.selected.isEmpty ? 'Save' : 'Connect',
        ),
        confirmKey: const Key('channel-settings-slack-confirm'),
        confirmVariant: RaftButtonRecipeVariant.accent,
        confirmEnabled: canConfirm,
        onConfirm: widget.onConfirm,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: RaftSpace.x3,
          children: [
            Text(
              raftText(
                context,
                "Pair this channel with one Slack channel. What's posted in either shows up in both.",
              ),
            ),
            RaftSelectField<String>(
              key: const Key('channel-slack-bridge-select'),
              label: raftText(context, 'Slack channel'),
              value: options.any((option) => option.value == pairing.selected)
                  ? pairing.selected
                  : null,
              items: [
                for (final option in options)
                  RaftSelectItem(
                    value: option.value,
                    label: option.label,
                    enabled: option.enabled,
                  ),
              ],
              onChanged: refreshing
                  ? null
                  : (value) {
                      if (value == null) return;
                      pairing.select(value);
                      canConfirm.value = pairing.dirty;
                    },
            ),
            Text(
              raftText(
                context,
                "Can't find a Slack channel? In Slack, open the channel, click its name, and add the Raft app under Agents & apps or Integrations. Then return here and click Refresh. Private channels appear only if both the Raft app and the Slack account that connected Raft have joined.",
              ),
            ),
            RaftButton(
              label: raftText(context, 'Refresh'),
              uiVariant: RaftButtonVariant.ghost,
              onPressed: refreshing ? null : refresh,
            ),
          ],
        ),
      );
    },
  );
}
