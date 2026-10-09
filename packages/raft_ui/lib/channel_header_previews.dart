import 'package:flutter/material.dart';

import 'previews.dart';
import 'raft_ui.dart';

@RaftPreviews('Channel header', size: Size(390, 160))
Widget channelHeaderPreview() => const _ChannelHeaderPreview();

class _ChannelHeaderPreview extends StatefulWidget {
  const _ChannelHeaderPreview();
  @override
  State<_ChannelHeaderPreview> createState() => _ChannelHeaderPreviewState();
}

class _ChannelHeaderPreviewState extends State<_ChannelHeaderPreview> {
  String result = 'Ready';
  @override
  Widget build(BuildContext context) => Column(
    children: [
      RaftChannelHeader(
        name: 'Public channel',
        description: 'A public description can wrap without hiding the channel identity.',
        onBack: () => setState(() => result = 'Back'),
        onSearch: () => setState(() => result = 'Search channel'),
        onSettings: () => setState(() => result = 'Channel settings'),
      ),
      Text(result),
    ],
  );
}
