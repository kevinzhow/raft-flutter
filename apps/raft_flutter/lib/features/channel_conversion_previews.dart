import 'package:flutter/material.dart';
import 'package:raft_ui/previews.dart';
import 'package:raft_ui/raft_ui.dart';

import 'channel_conversion_progress.dart';

@RaftPreviews('Channel conversion', size: Size(420, 440))
@RaftPreviews('Channel conversion phone', size: Size(320, 600))
Widget channelConversionPreview() => const _ConversionPreview();

class _ConversionPreview extends StatefulWidget {
  const _ConversionPreview();
  @override
  State<_ConversionPreview> createState() => _ConversionPreviewState();
}

class _ConversionPreviewState extends State<_ConversionPreview> {
  String status = 'running';
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: RaftPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            raftText(context, 'Joint channel conversion'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          ChannelConversionProgress(
            status: status,
            phase: status == 'done' ? 'done' : 'prepare',
            error: status == 'failed'
                ? 'Verification needs attention. Retry or cancel eligible work.'
                : null,
          ),
          Wrap(
            spacing: 8,
            children: [
              for (final choice in ['running', 'failed', 'done', 'canceled'])
                ChoiceChip(
                  label: Text(choice),
                  selected: status == choice,
                  onSelected: (_) => setState(() => status = choice),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (status == 'failed')
            TextButton(
              onPressed: () => setState(() => status = 'running'),
              child: Text(raftText(context, 'Retry conversion')),
            ),
          if (status == 'running' || status == 'failed')
            TextButton(
              onPressed: () => setState(() => status = 'canceled'),
              child: Text(raftText(context, 'Cancel conversion')),
            ),
        ],
      ),
    ),
  );
}
