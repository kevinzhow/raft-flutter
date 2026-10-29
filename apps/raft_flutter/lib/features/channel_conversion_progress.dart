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
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          liveRegion: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (status == 'running' || status == 'pending')
                const RaftProgressBar(),
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
            ],
          ),
        ),
        // The banner is its own alert; Flutter forbids alert + live region on
        // one node, so it sits beside the live status, not inside it.
        if (error != null) RaftErrorBanner(error!, small: true),
      ],
    ),
  );
}
