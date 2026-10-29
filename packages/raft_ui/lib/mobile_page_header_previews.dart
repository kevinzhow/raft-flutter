import 'package:flutter/material.dart';

import 'previews.dart';
import 'raft_ui.dart';

@RaftPreviews('Mobile page navigation', size: Size(390, 600))
Widget mobilePageHeaderPreview() => const _MobileHeaderPreview();

class _MobileHeaderPreview extends StatefulWidget {
  const _MobileHeaderPreview();
  @override
  State<_MobileHeaderPreview> createState() => _MobileHeaderPreviewState();
}

class _MobileHeaderPreviewState extends State<_MobileHeaderPreview> {
  var backCount = 0;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      const RaftMobileRootHeader(title: 'Settings'),
      RaftMobilePageHeader(
        title: const Text('Account'),
        onBack: () => setState(() => backCount++),
        actions: [
          RaftButton.iconAction(
            onPressed: () {},
            tooltip: 'Search',
            icon: const Icon(Icons.search),
          ),
        ],
      ),
      RaftChannelHeader(
        name: 'general',
        description: 'Channel description',
        onBack: () => setState(() => backCount++),
      ),
      Text('Back pressed $backCount times'),
    ],
  );
}
