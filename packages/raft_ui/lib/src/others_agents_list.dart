// Other people's agents on a Computer the person is deleting (Web v1.24
// features/computer/OthersAgentsOnComputerDialog.tsx, AgentOwnerNotifyActions
// .tsx). Presentation only: the app supplies the words, which actions are on
// and the callbacks. The Notify owner actions are drawn the same under Delete
// Account's rows, so they are their own component.
import 'package:flutter/widgets.dart';

import '../raft_ui.dart';
import 'tokens/raft_tokens.g.dart' show RaftTypeScale, RaftTypeStyle;

TextStyle _type(
  RaftTokens t,
  RaftTypeStyle s, {
  Color? color,
  FontWeight? weight,
}) => RaftTypography.body(
  t,
  size: s.fontSize,
  line: s.lineHeight,
  color: color,
).copyWith(fontWeight: weight);

/// Under one of other people's agents: Notify owner to move it (Remind again
/// after a reminder), when it was sent, when the next one is allowed, a
/// failure line, and who else can act if the owner never does.
class RaftAgentOwnerNotifyActions extends StatelessWidget {
  const RaftAgentOwnerNotifyActions({
    super.key,
    required this.agentId,
    required this.testIdPrefix,
    required this.buttonLabel,
    required this.busyLabel,
    required this.busy,
    required this.enabled,
    required this.contactLine,
    required this.onNotify,
    this.notifiedLine,
    this.reminderLine,
    this.errorLine,
  });

  final String agentId, testIdPrefix, buttonLabel, busyLabel, contactLine;
  final bool busy, enabled;

  /// "Notified · {time}", when an owner was reminded.
  final String? notifiedLine;

  /// "You can remind again {time}" while the daily limit holds.
  final String? reminderLine;

  /// The last call's failure ("Couldn't notify the owner. Try again.").
  final String? errorLine;
  final VoidCallback onNotify;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final muted = t.colors['foreground-muted']!;
    final hint = t.colors['foreground-hint'] ?? muted;
    final callout = _type(t, RaftTypeScale.callout, color: muted);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            RaftButton(
              key: ValueKey('$testIdPrefix-notify-$agentId'),
              label: buttonLabel,
              glyph: RaftGlyph.send,
              glyphSize: 14,
              tone: RaftButtonRecipeVariant.outline,
              busy: busy,
              loadingLabel: busyLabel,
              onPressed: enabled && !busy ? onNotify : null,
            ),
            if (notifiedLine != null)
              Row(
                key: ValueKey('$testIdPrefix-notified-$agentId'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  RaftIcon(
                    RaftGlyph.check,
                    size: 16,
                    color: t.colors['success-strong'] ?? muted,
                  ),
                  const SizedBox(width: 4),
                  Flexible(child: Text(notifiedLine!, style: callout)),
                ],
              ),
            if (reminderLine != null)
              Text(
                reminderLine!,
                key: ValueKey('$testIdPrefix-next-reminder-$agentId'),
                style: callout,
              ),
          ],
        ),
        if (errorLine != null)
          Semantics(
            liveRegion: true,
            child: Text(
              errorLine!,
              key: ValueKey('$testIdPrefix-notify-error-$agentId'),
              style: _type(
                t,
                RaftTypeScale.callout,
                color: t.colors['danger'] ?? muted,
              ),
            ),
          ),
        const SizedBox(height: 4),
        Text(
          contactLine,
          key: ValueKey('$testIdPrefix-others-agent-contact-$agentId'),
          style: _type(t, RaftTypeScale.footnote, color: hint),
        ),
      ],
    );
  }
}

/// One row of [RaftOthersAgentsList].
typedef RaftOthersAgentEntry = ({
  String id,
  String name,
  String ownerLine,
  Widget actions,
});

/// OthersAgentsOnComputerDialog's body: the message, then each agent with
/// its owner line and the notify actions.
class RaftOthersAgentsList extends StatelessWidget {
  const RaftOthersAgentsList({
    super.key,
    required this.message,
    required this.listLabel,
    required this.agents,
  });
  final String message, listLabel;
  final List<RaftOthersAgentEntry> agents;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final muted = t.colors['foreground-muted']!;
    return Column(
      key: const ValueKey('computer-others-agents-dialog'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(message, style: _type(t, RaftTypeScale.subhead, color: muted)),
        const SizedBox(height: 12),
        Semantics(
          label: listLabel,
          container: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (i, a) in agents.indexed) ...[
                if (i > 0) const SizedBox(height: 12),
                Row(
                  key: ValueKey('computer-others-agent-${a.id}'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: RaftIcon(RaftGlyph.bot, size: 16, color: muted),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            a.name,
                            style: _type(
                              t,
                              RaftTypeScale.body,
                              color: t.strong,
                              weight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            a.ownerLine,
                            style: _type(t, RaftTypeScale.callout, color: muted),
                          ),
                          a.actions,
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
