import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

import 'previews.dart';

// Web AgentNowCard (v1.24.0): what the agent is doing now and, on the profile,
// its last turns one line each.

/// The overview's headline (`text-subhead font-bold`).
Widget _headline(String text) => Builder(
  builder: (context) {
    final t = RaftTokens.of(context);
    return RaftCssText(
      text,
      style: t.scale(
        RaftTypeScale.subhead,
        weight: FontWeight.w700,
        color: t.ui.foreground,
      ),
    );
  },
);

@RaftPreviews('Agent now card', size: Size(420, 520))
Widget agentNowCardPreview() => SingleChildScrollView(
  padding: const EdgeInsets.all(16),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 12,
    children: [
      RaftNowCard(
        otter: RaftOtterStatus.process,
        lead: _headline('Working · for 2m 14s'),
        step: 'Running npm test',
        focus: '@Remy · #deploy · ran 3 commands and read a file',
      ),
      RaftNowCard(
        otter: RaftOtterStatus.wait,
        lead: _headline('Idle · last turn ended 09:41'),
        focus: 'Last turn: DM from @xxchan · sent a message',
      ),
      RaftNowCard(
        otter: RaftOtterStatus.error,
        eyebrow: 'Recent activity',
        onOpenEyebrow: () {},
        lead: const RaftAgentStatusRow(
          text: 'Sign-in needed for Codex CLI',
          tone: RaftAgentStatusTone.warning,
          light: RaftAgentStatusLight.error,
        ),
        focus: 'Last turn: a DM · ran a command',
        rows: const [
          RaftNowTurnRow(
            time: '09:41',
            trigger: 'DM from @xxchan',
            actions: 'ran 3 commands and read a file',
          ),
          RaftNowTurnRow(
            time: '09:12',
            trigger: '@Remy · #deploy',
            actions: 'sent a message',
          ),
        ],
      ),
    ],
  ),
);
