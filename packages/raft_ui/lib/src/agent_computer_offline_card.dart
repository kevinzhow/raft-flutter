// Web `AgentComputerOfflineCard` (features/agent/AgentComputerOfflineCard.tsx):
// the profile's card while the agent's Computer is offline, in place of Start.
// Presentation only: the app adapter owns the Computer, the owner, the time
// and the command.
import 'package:flutter/material.dart';

import 'agent_profile.dart' show RaftGapColumn;
import 'card.dart' show RaftCard;
import 'copyable_code.dart';
import 'design_primitives.dart'
    show RaftTextLink, RaftTextLinkVariant, RaftTypography;
import 'raft/status.dart';
import 'theme.dart';

/// A sentence around one inserted piece: [before] + the piece + [after].
@immutable
class RaftAgentOfflineSentence {
  const RaftAgentOfflineSentence(this.before, [this.after = '']);
  final String before, after;
}

class RaftAgentComputerOfflineCard extends StatelessWidget {
  const RaftAgentComputerOfflineCard({
    super.key,
    required this.title,
    required this.computerName,
    required this.powerStep,
    required this.runStep,
    this.owner,
    this.command,
    this.copyLabel = 'Copy command',
    this.onOpenComputer,
  });

  /// "{computer} has been offline since {time}" split around the computer,
  /// which is a link to its page.
  final RaftAgentOfflineSentence title;
  final String computerName;
  final VoidCallback? onOpenComputer;

  /// "Turn on {owner}'s computer {computer} ..." split around the owner's name
  /// (semibold) when [owner] is known; else the whole sentence in `before`.
  final RaftAgentOfflineSentence powerStep;
  final String? owner;
  final String runStep;

  /// The Computer page's restart command, copyable; null hides it.
  final String? command;
  final String copyLabel;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final base = RaftTypography.body(t, size: 14, line: 20, color: t.strong);
    final strong = base.copyWith(fontWeight: FontWeight.w600);
    Widget step(int number, Widget child) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 20, child: Text('$number.', style: base)),
        Expanded(child: child),
      ],
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: RaftCard(
        key: const ValueKey('agent-computer-offline-card'),
        padding: const EdgeInsets.all(16),
        child: RaftGapColumn(
          gap: 12,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: RaftStatusDot(activity: RaftActivityTone.offline),
                ),
                const SizedBox(width: 8),
                Expanded(
                  // The computer is a link: a wrapping run (a window or a text
                  // size too narrow for one line moves it to the next).
                  child: LayoutBuilder(
                    builder: (context, box) => Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (title.before.isNotEmpty)
                          Text(title.before, style: strong),
                        ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: box.maxWidth),
                          child: RaftTextLink(
                            key: const ValueKey(
                              'agent-computer-offline-card-computer',
                            ),
                            label: computerName,
                            variant: RaftTextLinkVariant.strong,
                            textStyle: strong,
                            onPressed: onOpenComputer,
                          ),
                        ),
                        if (title.after.isNotEmpty)
                          Text(title.after, style: strong),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            step(
              1,
              Text.rich(
                TextSpan(
                  style: base,
                  children: [
                    TextSpan(text: powerStep.before),
                    if (owner != null)
                      TextSpan(
                        text: owner,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    TextSpan(text: powerStep.after),
                  ],
                ),
                key: const ValueKey('agent-computer-offline-step-power'),
              ),
            ),
            step(
              2,
              Column(
                key: const ValueKey('agent-computer-offline-step-run'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(runStep, style: base),
                  if (command != null) ...[
                    const SizedBox(height: 6),
                    RaftCopyableCode(
                      command!,
                      copyLabel: copyLabel,
                      codeKey: const ValueKey('agent-computer-offline-command'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
