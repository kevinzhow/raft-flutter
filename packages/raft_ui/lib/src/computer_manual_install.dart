// Web components/machine/ComputerManualInstall.tsx: the install command(s) for
// this machine's platform, each copyable, then the install guide link.
import 'package:flutter/material.dart';

import '../raft_ui.dart';

class RaftComputerManualInstall extends StatelessWidget {
  const RaftComputerManualInstall({
    super.key,
    required this.lines,
    this.onOpenInstallGuide,
  });
  final List<RaftComputerInstallLine> lines;
  final VoidCallback? onOpenInstallGuide;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final line in lines) ...[
          if (line.label != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                raftText(context, line.label!),
                style: RaftTypography.body(
                  t,
                  size: 12,
                  line: 16,
                  weight: FontWeight.w700,
                ),
              ),
            ),
          RaftCopyableCode(
            line.command,
            copyLabel: raftText(context, line.copyLabel),
          ),
          const SizedBox(height: 8),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: RaftUnderlineTextButton(
            key: const ValueKey('computer-manual-install-docs'),
            label: raftText(context, 'Install guide'),
            style: RaftTypography.body(
              t,
              size: 14,
              line: 20,
              weight: FontWeight.w700,
            ),
            onPressed: onOpenInstallGuide,
          ),
        ),
      ],
    );
  }
}
