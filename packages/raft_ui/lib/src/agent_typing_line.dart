import 'package:flutter/material.dart';

import 'raft/ui_tokens.dart';
import 'theme.dart';
import 'tokens/tokens.dart' show RaftTypeScale;
import 'working_agents.dart';

// The agent typing line (Web 1.24 AgentTypingLine.tsx, raft-design 0042): who
// is about to post here. Up to three still 19px faces and one muted
// sentence. Nothing moves: no dots, no shimmer, no entrance.

/// The line's row height (`h-6`).
const raftAgentTypingLineHeight = 24.0;

/// The room the list keeps at its end while the line shows (`h-7.5`), so the
/// last message stays whole above the line.
const raftAgentTypingListEnd = 30.0;

/// The line over the bottom of a conversation's message list, on the
/// composer's 20px edge. Takes no space while [agents] is empty. The
/// sentence is announced to assistive technology as a live region.
class RaftAgentTypingLine extends StatelessWidget {
  const RaftAgentTypingLine({
    super.key,
    required this.agents,
    required this.sentence,
  });

  /// The typing agents, in the order they started.
  final List<RaftWorkingAgent> agents;

  /// "Niko is typing…" (empty when nobody is).
  final String sentence;

  @override
  Widget build(BuildContext context) {
    if (agents.isEmpty) return const SizedBox.shrink();
    final t = RaftTokens.of(context);
    return Semantics(
      key: const Key('agent-typing-line'),
      liveRegion: true,
      label: sentence,
      excludeSemantics: true,
      child: Container(
        height: raftAgentTypingLineHeight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        alignment: Alignment.centerLeft,
        child: _FacesAndSentence(
          agents: agents,
          sentence: sentence,
          style: t.scale(RaftTypeScale.footnote, color: t.ui.foregroundMuted),
        ),
      ),
    );
  }
}

class _FacesAndSentence extends StatelessWidget {
  const _FacesAndSentence({
    required this.agents,
    required this.sentence,
    required this.style,
  });
  final List<RaftWorkingAgent> agents;
  final String sentence;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      RaftWorkingFaces(
        agents: agents.take(raftWorkingFaceLimit).toList(),
        still: true,
      ),
      const SizedBox(width: 6),
      Flexible(
        child: Text(
          sentence,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          style: style,
        ),
      ),
    ],
  );
}
