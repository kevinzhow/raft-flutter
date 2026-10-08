import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import 'channel_conversion_contract.dart';

class ChannelConversionProgress extends StatelessWidget {
  const ChannelConversionProgress({
    super.key,
    required this.status,
    required this.phase,
    this.error,
  });
  final String status, phase;
  final String? error;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (status == 'running' || status == 'pending')
            const LinearProgressIndicator(),
          Text(
            raftText(
              context,
              status == 'done'
                  ? 'Conversion complete'
                  : status == 'canceled'
                  ? 'Conversion canceled'
                  : status == 'failed'
                  ? 'Conversion needs attention'
                  : conversionPhaseLabel(phase),
            ),
          ),
          if (error != null)
            Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
    ),
  );
}
