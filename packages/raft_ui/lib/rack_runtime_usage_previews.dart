import 'package:flutter/material.dart';

import 'previews.dart';
import 'raft_ui.dart';

/// The rack's usage cell in each state: a value, a warning with a model
/// line, a used-up limit with its attention pixel, a step, "—", pending.
@RaftPreviews('Rack runtime usage cells', size: Size(560, 240))
Widget rackRuntimeUsagePreview() => const _RackRuntimeUsagePreview();

class _RackRuntimeUsagePreview extends StatelessWidget {
  const _RackRuntimeUsagePreview();

  static const _cells = <RaftRackUsage>[
    RaftRackUsage(
      kind: RaftRackUsageKind.value,
      text: '62% used',
      used: 62,
      label: 'Claude account: 62% used',
    ),
    RaftRackUsage(
      kind: RaftRackUsageKind.value,
      text: '85% used',
      used: 85,
      warn: true,
      label: 'Codex account: 85% used',
      model: RaftRackModelLine(
        name: 'Opus',
        text: '40%',
        used: 40,
        label: 'Opus: 40% used',
      ),
    ),
    RaftRackUsage(
      kind: RaftRackUsageKind.value,
      text: 'Back in 3h',
      used: 100,
      warn: true,
      attention: true,
      label: 'Grok account: Used up',
    ),
    RaftRackUsage(
      kind: RaftRackUsageKind.step,
      text: 'Sign in',
      label: 'Kimi account: Sign in',
    ),
    RaftRackUsage(kind: RaftRackUsageKind.dash, label: 'Usage unavailable'),
    RaftRackUsage(kind: RaftRackUsageKind.pending, label: 'Loading…'),
  ];

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Wrap(
      spacing: 12,
      runSpacing: 16,
      children: [
        for (final c in _cells)
          SizedBox(
            width: raftRackUsageCellWidth,
            child: RaftRackUsageCell(usage: c),
          ),
        const RaftRackRuntimeHeading(
          shortName: 'Claude',
          fullName: 'Claude Code',
        ),
        const SizedBox(
          width: 320,
          child: RaftRackUsageCell(
            line: true,
            name: 'Claude',
            usage: RaftRackUsage(
              kind: RaftRackUsageKind.value,
              text: '62% used',
              used: 62,
              label: 'Claude account: 62% used',
            ),
          ),
        ),
      ],
    ),
  );
}
