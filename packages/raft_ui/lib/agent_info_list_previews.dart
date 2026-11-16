import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

import 'previews.dart';

// Web v1.24.0 features/agent/InfoRow.tsx: the profile's Info list, a raft-ui
// DescriptionList (horizontal) with one shared term column.

@RaftPreviews('Agent profile Info list', size: Size(390, 260))
Widget agentInfoListPreview() => Padding(
  padding: const EdgeInsets.all(16),
  child: RaftInfoList(
    children: [
      RaftInfoRow(label: 'Role', child: const RaftCssText('Member')),
      RaftInfoRow(
        label: 'Computer status',
        child: const RaftConnectionValue(online: true),
      ),
      RaftInfoRow(
        label: 'Computer version',
        child: Builder(
          builder: (context) =>
              RaftCssText('v0.0.48', style: RaftInfoRow.monoStyleOf(context)),
        ),
      ),
    ],
  ),
);
