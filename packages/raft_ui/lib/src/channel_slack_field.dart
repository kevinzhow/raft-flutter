// Web ChannelSlackBridgeField (components/channel/ChannelSlackBridgeField.tsx):
// the channel's Slack Bridge pick as a section: a heading with the provider
// badge, a line on what it does, then the Slack channel select. The app adapter
// owns the provisioning snapshot and applies the choice with the channel.
import 'package:flutter/material.dart';

import 'dialog_card.dart';
import 'indicators.dart';
import 'localization.dart';
import 'select_field.dart';
import 'theme.dart';

/// One entry of the Slack channel select; [value] is the Slack channel id, or
/// '' for "Do not connect to Slack".
@immutable
class RaftSlackChannelOption {
  const RaftSlackChannelOption({
    required this.value,
    required this.label,
    this.enabled = true,
  });
  final String value, label;

  /// False for a Slack channel that is paired already or that the Raft app has
  /// not joined.
  final bool enabled;
}

class RaftChannelSlackField extends StatelessWidget {
  const RaftChannelSlackField({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.compact = false,
  });
  final List<RaftSlackChannelOption> options;
  final String value;
  final ValueChanged<String> onChanged;
  final bool enabled;

  /// A host that is not a run of sections (the create dialog): no top rhythm.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return Padding(
      key: const ValueKey('channel-slack-bridge-field'),
      padding: EdgeInsets.only(top: compact ? 0 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              RaftBadge(
                key: const ValueKey('channel-slack-bridge-provider-badge'),
                label: raftText(context, 'Slack'),
                appearance: RaftBadgeRecipeAppearance.outline,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  raftText(context, 'Connect to Slack'),
                  style: raftCssTextStyle(
                    family: t.bodyFont,
                    step: RaftTextSteps.base,
                    weight: FontWeight.w700,
                    color: t.strong,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            raftText(
              context,
              'Optionally pair this Raft channel with one available Slack channel.',
            ),
            style: raftCssTextStyle(
              family: t.bodyFont,
              step: RaftTextSteps.xs,
              color: t.colors['foreground-muted'],
            ),
          ),
          const SizedBox(height: 12),
          RaftProductFormField(
            label: 'Slack channel',
            labelWeight: FontWeight.w500,
            family: t.bodyFont,
            child: RaftSelectField<String>(
              key: const ValueKey('channel-slack-bridge-select'),
              label: raftText(context, 'Slack channel'),
              value: options.any((o) => o.value == value) ? value : null,
              items: [
                for (final option in options)
                  RaftSelectItem(
                    value: option.value,
                    enabled: option.enabled,
                    label: option.label,
                  ),
              ],
              onChanged: enabled
                  ? (next) {
                      if (next != null) onChanged(next);
                    }
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}
