import 'dart:convert';

/// The legacy phrase and repetition rules (Web `raftbench/model.ts`): manual
/// matching only, no AI interpretation. The same messages and rules always
/// produce the same cues.

const raftbenchRuleVersion = 'raftbench-rules-0.1.0';

/// The minimal receiver-visible message the rules read.
class RaftbenchEvidenceMessage {
  const RaftbenchEvidenceMessage({
    required this.id,
    required this.channelId,
    required this.senderType,
    required this.senderId,
    required this.content,
    required this.createdAt,
    this.senderName,
    this.messageType,
  });
  final String id, channelId, senderType, senderId, content, createdAt;
  final String? senderName, messageType;

  int get time => DateTime.tryParse(createdAt)?.millisecondsSinceEpoch ?? 0;
}

enum RaftbenchSignal { frustration, negative, repetition }

enum RaftbenchReview { needsReview, confirmed, dismissed }

class RaftbenchFinding {
  const RaftbenchFinding(this.id, this.kind, this.evidence);
  final String id;
  final RaftbenchSignal kind;
  final List<RaftbenchEvidenceMessage> evidence;
}

class RaftbenchSentiment {
  const RaftbenchSentiment({
    this.positive = 0,
    this.negative = 0,
    this.mixed = 0,
    this.unscored = 0,
  });
  final int positive, negative, mixed, unscored;
}

class RaftbenchEvaluation {
  const RaftbenchEvaluation(this.findings, this.sentiment, this.messages);
  final List<RaftbenchFinding> findings;
  final RaftbenchSentiment sentiment;
  final List<RaftbenchEvidenceMessage> messages;
  static const empty = RaftbenchEvaluation([], RaftbenchSentiment(), []);
}

RegExp _re(String source) =>
    RegExp(source, caseSensitive: false, unicode: true);

final _frustration = _re(
  r"\b(frustrat(?:ed|ing)|annoy(?:ed|ing)|wast(?:ed|ing) (?:my )?time|stop asking|already told you|why (?:do|are) you keep|this (?:still )?(?:doesn.?t|does not) work|you.?re not listening)\b|烦死|别再问|说了好几遍|怎么又|浪费时间|你没听懂|还是不行|一直重复",
);
final _negative = _re(
  r"\b(disappoint(?:ed|ing)|unhelpful|terrible|awful|not helpful|not working)\b|不好用|没用|不满意|失望",
);
final _positive = _re(
  r"\b(thank you|thanks|excellent|great work|works perfectly|love it)\b|谢谢|太好了|搞定了|很好",
);

int _compareMessages(RaftbenchEvidenceMessage a, RaftbenchEvidenceMessage b) {
  final byTime = a.time.compareTo(b.time);
  return byTime != 0 ? byTime : a.id.compareTo(b.id);
}

/// Web `evaluateMessages`. [minimum] (2..20) is the repeat threshold.
RaftbenchEvaluation evaluateRaftbenchMessages(
  Iterable<RaftbenchEvidenceMessage> messages, {
  int minimum = 3,
}) {
  if (minimum < 2 || minimum > 20) {
    throw ArgumentError.value(minimum, 'minimum', 'Invalid repeat threshold');
  }
  final ordered = [...messages]..sort(_compareMessages);
  final findings = <RaftbenchFinding>[];
  var positive = 0, negative = 0, mixed = 0, unscored = 0;
  void add(
    RaftbenchSignal kind,
    List<RaftbenchEvidenceMessage> evidence,
  ) => findings.add(
    RaftbenchFinding(
      '$raftbenchRuleVersion:${kind.name}:${evidence.first.id}:${evidence.last.id}',
      kind,
      evidence,
    ),
  );
  final repetitions = <String, List<RaftbenchEvidenceMessage>>{};
  for (final message in ordered) {
    if (message.messageType == 'system') continue;
    if (message.senderType == 'user') {
      final f = _frustration.hasMatch(message.content);
      final n = _negative.hasMatch(message.content);
      final p = _positive.hasMatch(message.content);
      if (p && (f || n)) {
        mixed++;
      } else if (p) {
        positive++;
      } else if (f || n) {
        negative++;
      } else {
        unscored++;
      }
      if (f) {
        add(RaftbenchSignal.frustration, [message]);
      } else if (n) {
        add(RaftbenchSignal.negative, [message]);
      }
    } else if (message.senderType == 'agent') {
      final text = message.content
          .toLowerCase()
          .replaceAll(RegExp(r'\s+', unicode: true), ' ')
          .trim();
      if (text.length < 16) continue;
      final key = jsonEncode([message.channelId, message.senderId, text]);
      var group = repetitions[key] ?? <RaftbenchEvidenceMessage>[];
      if (group.isNotEmpty && message.time - group.first.time > 15 * 60000) {
        if (group.length >= minimum) add(RaftbenchSignal.repetition, group);
        group = [];
      }
      group.add(message);
      repetitions[key] = group;
    }
  }
  for (final group in repetitions.values) {
    if (group.length >= minimum) add(RaftbenchSignal.repetition, group);
  }
  findings.sort((a, b) {
    final byEnd = b.evidence.last.createdAt.compareTo(
      a.evidence.last.createdAt,
    );
    return byEnd != 0 ? byEnd : a.id.compareTo(b.id);
  });
  return RaftbenchEvaluation(
    findings,
    RaftbenchSentiment(
      positive: positive,
      negative: negative,
      mixed: mixed,
      unscored: unscored,
    ),
    ordered,
  );
}
