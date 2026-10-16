import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../entity_model.dart';
import '../marks.dart';
import '../spotlight.dart';
import 'hf_basics.dart';
import 'hf_blocks.dart';
import 'hf_describe.dart';
import 'hf_entity.dart';
import 'hf_scope.dart';
import 'hf_tokens.dart';

/// What a message is.
enum HfMessageKind {
  /// Something a person or an Agent said: a bubble.
  chat,

  /// A note of the system (someone joined, a setting changed): a small
  /// centered line, never a bubble.
  system,

  /// A reminder of the system: drawn like a system note.
  reminder,

  /// A task was created, claimed, moved or deleted: a centered task chip.
  taskEvent,
}

/// A file on a message.
@immutable
class HfAttachmentData {
  const HfAttachmentData({
    this.id,
    required this.name,
    this.isImage = false,
    this.bytes,
  });
  final String? id;
  final String name;
  final bool isImage;
  final int? bytes;

  /// "1.2 MB"; null when the size is not known.
  String? get sizeLabel {
    final b = bytes;
    if (b == null || b < 0) return null;
    String one(double v) => v < 10 ? v.toStringAsFixed(1) : v.toStringAsFixed(0);
    if (b < 1024) return '$b B';
    if (b < 1024 * 1024) return '${one(b / 1024)} KB';
    return '${one(b / (1024 * 1024))} MB';
  }

  Map<String, Object?> toJson() => {
    if (id != null) 'id': id,
    'name': name,
    if (isImage) 'image': true,
    if (bytes != null) 'bytes': bytes,
  };

  factory HfAttachmentData.fromJson(Map<String, Object?> j) => HfAttachmentData(
    id: j['id'] as String?,
    name: '${j['name'] ?? ''}',
    isImage: j['image'] == true,
    bytes: (j['bytes'] as num?)?.toInt(),
  );
}

/// An emoji and how many people reacted with it.
@immutable
class HfReactionData {
  const HfReactionData(this.emoji, this.count, {this.mine = false});
  final String emoji;
  final int count;

  /// The person reacted with it too.
  final bool mine;

  Map<String, Object?> toJson() => {
    'emoji': emoji,
    'count': count,
    if (mine) 'mine': true,
  };

  factory HfReactionData.fromJson(Map<String, Object?> j) => HfReactionData(
    '${j['emoji'] ?? ''}',
    (j['count'] as num?)?.toInt() ?? 0,
    mine: j['mine'] == true,
  );
}

/// The message another one quotes or answers.
@immutable
class HfQuoteData {
  const HfQuoteData({required this.author, required this.text, this.id});
  final String author, text;

  /// The id of the quoted message.
  final String? id;

  Map<String, Object?> toJson() => {
    'author': author,
    'text': text,
    if (id != null) 'id': id,
  };

  factory HfQuoteData.fromJson(Map<String, Object?> j) => HfQuoteData(
    author: '${j['author'] ?? ''}',
    text: '${j['text'] ?? ''}',
    id: j['id'] as String?,
  );
}

/// A task as a small chip: number, title, status, who has it.
@immutable
class HfTaskChipData {
  const HfTaskChipData({
    this.number,
    required this.title,
    this.status,
    this.claimant,
  });
  final int? number;
  final String title;

  /// `todo`, `in_progress`, `in_review`, `done` or `closed`; null when the
  /// message does not say.
  final String? status;
  final String? claimant;

  /// The status in words.
  String? get statusLabel =>
      status == null ? null : (agentTaskStatusLabels[status] ?? status);

  /// "Cindy 负责".
  String? get claimantLabel =>
      claimant == null || claimant!.isEmpty ? null : '$claimant 负责';

  Map<String, Object?> toJson() => {
    if (number != null) 'number': number,
    'title': title,
    if (status != null) 'status': status,
    if (claimant != null) 'claimant': claimant,
  };

  factory HfTaskChipData.fromJson(Map<String, Object?> j) => HfTaskChipData(
    number: (j['number'] as num?)?.toInt(),
    title: '${j['title'] ?? ''}',
    status: j['status'] as String?,
    claimant: j['claimant'] as String?,
  );
}

/// One message of a conversation, as plain data: what the phone sends to a TV
/// as JSON and the TV draws again.
@immutable
class HfMessageData {
  const HfMessageData({
    required this.id,
    this.kind = HfMessageKind.chat,
    this.senderId = '',
    this.senderName = '',
    this.isMine = false,
    this.isAgent = false,
    required this.time,
    this.text = '',
    this.attachments = const [],
    this.reactions = const [],
    this.replyCount = 0,
    this.quote,
    this.task,
    this.edited = false,
    this.deleted = false,
  });

  final String id;
  final HfMessageKind kind;
  final String senderId, senderName;

  /// Said by the person: drawn on the right.
  final bool isMine;

  /// Said by an Agent: wears the Agent badge.
  final bool isAgent;
  final DateTime time;

  /// The words, as written: a fenced block is code, lines starting with `>`
  /// are a quote (see [HfConversation.bodyOf]).
  final String text;
  final List<HfAttachmentData> attachments;
  final List<HfReactionData> reactions;

  /// How many replies the message has in its thread.
  final int replyCount;
  final HfQuoteData? quote;

  /// The task this message is (a chat message) or is about (a task event).
  final HfTaskChipData? task;
  final bool edited, deleted;

  bool get isChat => kind == HfMessageKind.chat;

  Map<String, Object?> toJson() => {
    'id': id,
    if (kind != HfMessageKind.chat) 'kind': kind.name,
    if (senderId.isNotEmpty) 'senderId': senderId,
    if (senderName.isNotEmpty) 'senderName': senderName,
    if (isMine) 'isMine': true,
    if (isAgent) 'isAgent': true,
    'time': time.toIso8601String(),
    if (text.isNotEmpty) 'text': text,
    if (attachments.isNotEmpty)
      'attachments': [for (final a in attachments) a.toJson()],
    if (reactions.isNotEmpty)
      'reactions': [for (final r in reactions) r.toJson()],
    if (replyCount > 0) 'replyCount': replyCount,
    if (quote != null) 'quote': quote!.toJson(),
    if (task != null) 'task': task!.toJson(),
    if (edited) 'edited': true,
    if (deleted) 'deleted': true,
  };

  static List<T> _list<T>(Object? v, T Function(Map<String, Object?>) make) => [
    for (final e in (v as List?) ?? const [])
      if (e is Map) make(Map<String, Object?>.from(e)),
  ];

  factory HfMessageData.fromJson(Map<String, Object?> j) => HfMessageData(
    id: '${j['id'] ?? ''}',
    kind: HfMessageKind.values.firstWhere(
      (k) => k.name == j['kind'],
      orElse: () => HfMessageKind.chat,
    ),
    senderId: '${j['senderId'] ?? ''}',
    senderName: '${j['senderName'] ?? ''}',
    isMine: j['isMine'] == true,
    isAgent: j['isAgent'] == true,
    time: DateTime.tryParse('${j['time']}') ?? DateTime.fromMillisecondsSinceEpoch(0),
    text: '${j['text'] ?? ''}',
    attachments: _list(j['attachments'], HfAttachmentData.fromJson),
    reactions: _list(j['reactions'], HfReactionData.fromJson),
    replyCount: (j['replyCount'] as num?)?.toInt() ?? 0,
    quote: j['quote'] is Map
        ? HfQuoteData.fromJson(Map<String, Object?>.from(j['quote'] as Map))
        : null,
    task: j['task'] is Map
        ? HfTaskChipData.fromJson(Map<String, Object?>.from(j['task'] as Map))
        : null,
    edited: j['edited'] == true,
    deleted: j['deleted'] == true,
  );

  @override
  bool operator ==(Object other) =>
      other is HfMessageData &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;
}

/// A piece of the words of a message.
enum HfBodyKind { text, quote, code }

class HfBodySegment {
  const HfBodySegment(this.kind, this.text, {this.title});
  final HfBodyKind kind;
  final String text;

  /// The language written after the opening fence of a code block.
  final String? title;
}

/// One thing the conversation lists, in order. The screen draws the parts and
/// the description of the conversation reads them, so the two lists are the
/// same list and cannot drift apart.
sealed class HfConversationPart {
  const HfConversationPart();

  /// What the part says, in words, for the voice model.
  HfDescription describe(HfDescribeEnv env);

  /// The part is the message the person opened the conversation from.
  bool get highlighted => false;
}

/// "更早的消息未显示" on top.
class HfMoreAbovePart extends HfConversationPart {
  const HfMoreAbovePart();
  static const text = '更早的消息未显示';
  @override
  HfDescription describe(HfDescribeEnv env) => const HfDescription([text]);
}

/// A day ("昨天") or a gap in time ("14:30") between two messages.
class HfSeparatorPart extends HfConversationPart {
  const HfSeparatorPart(this.label, {required this.day});
  final String label;
  final bool day;
  @override
  HfDescription describe(HfDescribeEnv env) => HfDescription([label]);
}

/// "这里还没有消息".
class HfEmptyPart extends HfConversationPart {
  const HfEmptyPart();
  static const text = '这里还没有消息';
  @override
  HfDescription describe(HfDescribeEnv env) => const HfDescription([text]);
}

/// A chat message: a bubble. [n] is its number on the screen, from 1; [head]
/// says it opens a group of one sender (the avatar and the name are drawn).
class HfMessagePart extends HfConversationPart {
  const HfMessagePart(
    this.message,
    this.n, {
    required this.head,
    this.highlighted = false,
  });
  final HfMessageData message;
  final int n;
  final bool head;
  @override
  final bool highlighted;

  /// "来自 Agent Cindy · 14:32".
  String get byline {
    final m = message;
    final who = m.isMine
        ? '我发的'
        : m.isAgent
        ? '来自 Agent ${m.senderName}'
        : '来自 ${m.senderName}';
    return '$who · ${HfConversation.clock(m.time)}';
  }

  @override
  HfDescription describe(HfDescribeEnv env) {
    final m = message;
    return HfDescription(
      [
        byline,
        if (highlighted) HfConversation.openedFrom,
        if (m.deleted)
          HfConversation.deletedText
        else ...[
          if (m.quote != null) '引用 ${m.quote!.author}：${m.quote!.text}',
          ..._bodyLines(env, m.text),
          ..._attachmentLines(m),
          if (m.task != null) _taskLine(m.task!),
        ],
        if (!m.deleted && m.reactions.isNotEmpty)
          '回应：${[for (final r in m.reactions) '${r.emoji} ${r.count}${r.mine ? '（含我）' : ''}'].join('、')}',
        if (!m.deleted && m.replyCount > 0) HfConversation.repliesLabel(m.replyCount),
        if (m.edited) HfConversation.editedText,
      ],
      index: n,
      block: true,
    );
  }
}

/// A system or reminder note that stands alone.
class HfNotePart extends HfConversationPart {
  const HfNotePart(this.message, {this.highlighted = false});
  final HfMessageData message;
  @override
  final bool highlighted;

  @override
  HfDescription describe(HfDescribeEnv env) => HfDescription([
    '${message.kind == HfMessageKind.reminder ? '提醒' : '系统消息'} · '
        '${HfConversation.clock(message.time)}',
    if (highlighted) HfConversation.openedFrom,
    message.text,
  ], block: true);
}

/// Two or more adjacent system notes folded to one line.
class HfNoteGroupPart extends HfConversationPart {
  const HfNoteGroupPart(this.messages);
  final List<HfMessageData> messages;

  /// "3 条系统更新：2 条系统消息、1 条提醒".
  String get summary {
    final system = messages.where((m) => m.kind == HfMessageKind.system).length;
    final reminder = messages.length - system;
    if (reminder == 0) return '$system 条系统消息';
    if (system == 0) return '$reminder 条提醒';
    return '${messages.length} 条系统更新：$system 条系统消息、$reminder 条提醒';
  }

  @override
  HfDescription describe(HfDescribeEnv env) => HfDescription([
    summary,
    for (final m in messages) '${HfConversation.clock(m.time)} ${m.text}',
  ], block: true);
}

/// A task event: what happened, and the task as a chip.
class HfTaskEventPart extends HfConversationPart {
  const HfTaskEventPart(this.message, {this.highlighted = false});
  final HfMessageData message;
  @override
  final bool highlighted;

  @override
  HfDescription describe(HfDescribeEnv env) => HfDescription([
    '任务事件 · ${HfConversation.clock(message.time)}',
    if (highlighted) HfConversation.openedFrom,
    if (message.text.isNotEmpty) message.text,
    if (message.task != null) _taskLine(message.task!),
  ], block: true);
}

String _taskLine(HfTaskChipData t) => hfKept([
  '任务${t.number == null ? '' : ' #${t.number}'}',
  t.title,
  t.statusLabel,
  t.claimantLabel,
]).join(' · ');

List<String> _bodyLines(HfDescribeEnv env, String text) {
  final out = <String>[];
  for (final s in HfConversation.bodyOf(text)) {
    switch (s.kind) {
      case HfBodyKind.text:
        out.add(s.text);
      case HfBodyKind.quote:
        out.add('引用：${s.text}');
      case HfBodyKind.code:
        out.addAll(['代码', ...HfConversation.codeOf(s).describe(env).lines]);
    }
  }
  return out;
}

List<String> _attachmentLines(HfMessageData m) => [
  for (final a in m.attachments)
    a.isImage
        ? '图片：${a.name}'
        : hfKept(['文件：${a.name}', a.sizeLabel == null ? null : '（${a.sizeLabel}）']).join(),
];

/// Draws the picture of an image attachment in a box of [size]; the app
/// supplies the real one (the component loads nothing itself).
typedef HfImageBuilder =
    Widget Function(BuildContext context, HfAttachmentData image, Size size);

/// Puts something around a numbered message (the app's pointer tag).
typedef HfMessageWrapper = Widget Function(String focusId, Widget child);

/// A channel as a conversation: bubbles with the sender's avatar and name,
/// one side for the person and the other for the rest, grouped by sender,
/// with time separators. System notes are small centered lines, tasks are
/// chips, files and pictures are tiles, code and quotes are drawn as such.
///
/// Oldest at the top, newest at the bottom. It is a plain column: the page it
/// sits in is the only scroll. The numbered messages (the real ones, from 1,
/// top to bottom) can be pointed at ("回复第 3 条"): with a [focusPrefix]
/// each is an [AgentFocusable] with id `prefix#n`, so the spotlight scrolls
/// the page to it. The [highlightId] message is highlighted and scrolled into
/// view when the conversation is first built (without one, the newest message
/// is, when [revealLatest]).
class HfConversation extends StatefulWidget implements HfDescribed {
  const HfConversation({
    super.key,
    required this.messages,
    this.highlightId,
    this.hasMoreAbove = false,
    this.focusPrefix,
    this.onTapMessage,
    this.imageBuilder,
    this.itemWrapper,
    this.now,
    this.revealLatest = true,
  });

  /// Oldest first.
  final List<HfMessageData> messages;
  final String? highlightId;
  final bool hasMoreAbove;

  /// Makes every numbered message an [AgentFocusable] with id `prefix#n`.
  final String? focusPrefix;

  /// A message was tapped, with its number (never on a TV, never null-safe to
  /// call for notes: only numbered messages are tappable).
  final void Function(int n, HfMessageData message)? onTapMessage;
  final HfImageBuilder? imageBuilder;

  /// Wraps each numbered message (and its focus id), e.g. the app's tag that
  /// points the voice at it.
  final HfMessageWrapper? itemWrapper;

  /// Today, for "今天" and "昨天"; defaults to the clock.
  final DateTime? now;

  /// Scroll to the newest message when nothing is highlighted.
  final bool revealLatest;

  static const openedFrom = '你是从这一条打开的';
  static const deletedText = '此消息已删除';
  static const editedText = '已编辑';
  static String repliesLabel(int n) => '$n 条回复';

  /// Gaps in time from this long get a time separator.
  static const gapSeparator = Duration(minutes: 30);

  /// Messages of one sender closer than this are one group.
  static const groupGap = Duration(minutes: 5);

  static String _two(int n) => n.toString().padLeft(2, '0');

  /// "14:32".
  static String clock(DateTime t) => '${_two(t.hour)}:${_two(t.minute)}';

  /// "今天", "昨天", "10月3日", "2025年10月3日".
  static String dayLabel(DateTime day, DateTime now) {
    final d = DateTime(day.year, day.month, day.day);
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(d).inDays;
    if (diff == 0) return '今天';
    if (diff == 1) return '昨天';
    if (d.year == today.year) return '${d.month}月${d.day}日';
    return '${d.year}年${d.month}月${d.day}日';
  }

  /// The words of a message cut into text, quotes (lines starting with `>`)
  /// and fenced code.
  static List<HfBodySegment> bodyOf(String text) {
    final lines = text.replaceAll('\r\n', '\n').split('\n');
    final out = <HfBodySegment>[];
    final buf = <String>[];
    HfBodyKind? kind;
    void flush() {
      if (kind != null && buf.isNotEmpty) {
        final joined = buf.join('\n').trim();
        if (joined.isNotEmpty) out.add(HfBodySegment(kind!, joined));
      }
      buf.clear();
      kind = null;
    }

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final t = line.trimLeft();
      if (t.startsWith('```')) {
        flush();
        final title = t.substring(3).trim();
        final code = <String>[];
        i++;
        while (i < lines.length && !lines[i].trimLeft().startsWith('```')) {
          code.add(lines[i++]);
        }
        while (code.isNotEmpty && code.last.trim().isEmpty) {
          code.removeLast();
        }
        if (code.isNotEmpty) {
          out.add(
            HfBodySegment(
              HfBodyKind.code,
              code.join('\n'),
              title: title.isEmpty ? null : title,
            ),
          );
        }
      } else if (t.startsWith('>')) {
        if (kind != HfBodyKind.quote) flush();
        kind = HfBodyKind.quote;
        buf.add(t.substring(1).trimLeft());
      } else {
        if (kind != HfBodyKind.text) flush();
        kind = HfBodyKind.text;
        buf.add(line);
      }
    }
    flush();
    return out;
  }

  /// The block a code segment is drawn as (and described by).
  static HfCodeBlock codeOf(HfBodySegment s) =>
      HfCodeBlock(code: s.text, title: s.title);

  /// Everything the conversation lists, in order: the note on top, day and
  /// time separators, bubbles (numbered from 1), system notes (runs of two
  /// or more folded to one line, unless the highlighted message is in
  /// them) and task events.
  static List<HfConversationPart> partsOf(
    List<HfMessageData> messages, {
    String? highlightId,
    bool hasMoreAbove = false,
    DateTime? now,
  }) {
    final today = now ?? DateTime.now();
    final parts = <HfConversationPart>[];
    if (hasMoreAbove) parts.add(const HfMoreAbovePart());
    if (messages.isEmpty) {
      parts.add(const HfEmptyPart());
      return parts;
    }
    var n = 0;
    final run = <HfMessageData>[];
    void endRun() {
      if (run.length >= 2 && !run.any((m) => m.id == highlightId)) {
        parts.add(HfNoteGroupPart(List.of(run)));
      } else {
        for (final m in run) {
          parts.add(HfNotePart(m, highlighted: m.id == highlightId));
        }
      }
      run.clear();
    }

    HfMessageData? prev;
    HfMessagePart? last;
    for (final m in messages) {
      final sameDay =
          prev != null &&
          prev.time.year == m.time.year &&
          prev.time.month == m.time.month &&
          prev.time.day == m.time.day;
      HfSeparatorPart? separator;
      if (prev == null || !sameDay) {
        separator = HfSeparatorPart(dayLabel(m.time, today), day: true);
      } else if (m.time.difference(prev.time) >= gapSeparator) {
        separator = HfSeparatorPart(clock(m.time), day: false);
      }
      final plain =
          m.kind == HfMessageKind.system || m.kind == HfMessageKind.reminder;
      if (separator != null || !plain) endRun();
      if (separator != null) {
        parts.add(separator);
        last = null;
      }
      prev = m;
      switch (m.kind) {
        case HfMessageKind.chat:
          final before = last;
          final joins =
              before != null &&
              before.message.isMine == m.isMine &&
              before.message.isAgent == m.isAgent &&
              before.message.senderId == m.senderId &&
              before.message.senderName == m.senderName &&
              m.time.difference(before.message.time) < groupGap;
          last = HfMessagePart(
            m,
            ++n,
            head: !joins,
            highlighted: m.id == highlightId,
          );
          parts.add(last);
        case HfMessageKind.system || HfMessageKind.reminder:
          run.add(m);
          last = null;
        case HfMessageKind.taskEvent:
          parts.add(HfTaskEventPart(m, highlighted: m.id == highlightId));
          last = null;
      }
    }
    endRun();
    return parts;
  }

  /// The conversation as words, part by part; a numbered part carries its
  /// number in the first line ("第 3 条").
  static List<String> linesOf(
    Iterable<HfConversationPart> parts,
    HfDescribeEnv env,
  ) => [
    for (final p in parts) ...[
      for (final (i, l) in p.describe(env).lines.indexed)
        p is HfMessagePart && i == 0 ? '第 ${p.n} 条 $l' : l,
    ],
  ];

  List<HfConversationPart> get parts => partsOf(
    messages,
    highlightId: highlightId,
    hasMoreAbove: hasMoreAbove,
    now: now,
  );

  @override
  HfDescription describe(HfDescribeEnv env) =>
      HfDescription(linesOf(parts, env), block: true);

  @override
  State<HfConversation> createState() => _HfConversationState();
}

class _HfConversationState extends State<HfConversation> {
  final _target = GlobalKey();

  @override
  void initState() {
    super.initState();
    _reveal();
  }

  @override
  void didUpdateWidget(HfConversation old) {
    super.didUpdateWidget(old);
    if (old.highlightId != widget.highlightId) _reveal();
  }

  void _reveal() => SchedulerBinding.instance.addPostFrameCallback((_) {
    final c = _target.currentContext;
    if (mounted && c != null) revealInPage(c);
  });

  @override
  Widget build(BuildContext context) {
    final hf = HandsFree.of(context);
    final parts = widget.parts;
    final highlighted = parts.indexWhere((p) => p.highlighted);
    final target = highlighted >= 0
        ? highlighted
        : (widget.revealLatest && widget.messages.isNotEmpty
              ? parts.length - 1
              : -1);
    final children = <Widget>[];
    HfConversationPart? before;
    for (final (i, p) in parts.indexed) {
      if (before != null) {
        children.add(SizedBox(height: hf.sp(_gap(before, p))));
      }
      Widget w = _draw(p);
      if (i == target) w = KeyedSubtree(key: _target, child: w);
      children.add(w);
      before = p;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  /// The air between two neighbours, in s-units.
  static double _gap(HfConversationPart a, HfConversationPart b) {
    if (b is HfMessagePart && !b.head && a is HfMessagePart) return 6;
    if (a is HfSeparatorPart || a is HfMoreAbovePart) return 10;
    if (b is HfSeparatorPart) return 16;
    if (a is HfMessagePart || b is HfMessagePart) return 16;
    return 10;
  }

  Widget _draw(HfConversationPart p) => switch (p) {
    HfMoreAbovePart() => const _Note(HfMoreAbovePart.text),
    HfEmptyPart() => const _Note(HfEmptyPart.text),
    HfSeparatorPart() => _Separator(p.label),
    HfNotePart() => _Note(p.message.text, highlighted: p.highlighted),
    HfNoteGroupPart() => _Note(p.summary),
    HfTaskEventPart() => _TaskEvent(p.message, highlighted: p.highlighted),
    HfMessagePart() => _numbered(p),
  };

  Widget _numbered(HfMessagePart p) {
    final id = widget.focusPrefix == null ? null : '${widget.focusPrefix}#${p.n}';
    Widget w = _MessageRow(
      part: p,
      onTap: widget.onTapMessage,
      imageBuilder: widget.imageBuilder,
    );
    if (id != null) {
      if (widget.itemWrapper != null) w = widget.itemWrapper!(id, w);
      w = AgentFocusable(id: id, child: w);
    }
    return w;
  }
}

const _highlightFill = Color(0xfffff7d6);

/// A small centered line.
class _Note extends StatelessWidget {
  const _Note(this.text, {this.highlighted = false});
  final String text;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final hf = HandsFree.of(context);
    final current = highlighted || AgentSpotlight.isCurrent(context);
    final line = Text(
      text,
      textAlign: TextAlign.center,
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
      style: hf.type(HfType.meta, color: HfColors.inkMuted),
    );
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: hf.sp(24)),
        child: current
            ? DecoratedBox(
                decoration: BoxDecoration(
                  color: _highlightFill,
                  borderRadius: BorderRadius.circular(hf.sp(10)),
                  border: Border.all(color: HfColors.ink, width: hf.sp(4)),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: hf.sp(10),
                    vertical: hf.sp(4),
                  ),
                  child: line,
                ),
              )
            : line,
      ),
    );
  }
}

/// A day or a time between two groups, with a rule on each side.
class _Separator extends StatelessWidget {
  const _Separator(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    final hf = HandsFree.of(context);
    Widget rule() => Expanded(
      child: Container(height: hf.sp(2.5), color: HfColors.ink),
    );
    return Semantics(
      header: true,
      child: Row(
        children: [
          rule(),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: hf.sp(12)),
            child: Text(label, style: hf.type(HfType.body)),
          ),
          rule(),
        ],
      ),
    );
  }
}

/// A task as a chip: "#12" on ink, the title, the status in its colour and
/// who has it.
class _TaskChip extends StatelessWidget {
  const _TaskChip(this.task, {this.highlighted = false});
  final HfTaskChipData task;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final hf = HandsFree.of(context);
    final current = highlighted || AgentSpotlight.isCurrent(context);
    final tone = hfTaskTone(task.status ?? '');
    final radius = BorderRadius.circular(hf.sp(12));
    final status = task.statusLabel, claimant = task.claimantLabel;
    return DecoratedBox(
      key: const ValueKey('hf-task-chip'),
      decoration: BoxDecoration(
        color: current ? _highlightFill : HfColors.card,
        borderRadius: radius,
        boxShadow: [
          BoxShadow(color: HfColors.of(tone), offset: Offset(0, hf.sp(4))),
        ],
      ),
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(color: HfColors.ink, width: hf.sp(current ? 5 : 2.5)),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: hf.sp(10),
            vertical: hf.sp(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (task.number != null) ...[
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: hf.sp(7),
                        vertical: hf.sp(1),
                      ),
                      decoration: BoxDecoration(
                        color: HfColors.ink,
                        borderRadius: BorderRadius.circular(hf.sp(6)),
                      ),
                      child: Text(
                        '#${task.number}',
                        style: hf.type(HfType.meta, color: Colors.white),
                      ),
                    ),
                    SizedBox(width: hf.sp(8)),
                  ],
                  Flexible(
                    child: Text(
                      task.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: hf.type(HfType.body),
                    ),
                  ),
                ],
              ),
              if (status != null || claimant != null)
                Padding(
                  padding: EdgeInsets.only(top: hf.sp(6)),
                  child: Wrap(
                    spacing: hf.sp(8),
                    runSpacing: hf.sp(4),
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (status != null)
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: hf.sp(8),
                            vertical: hf.sp(1),
                          ),
                          decoration: BoxDecoration(
                            color: HfColors.of(tone),
                            borderRadius: BorderRadius.circular(hf.sp(8)),
                            border: Border.all(
                              color: HfColors.ink,
                              width: hf.sp(2),
                            ),
                          ),
                          child: Text(status, style: hf.type(HfType.meta)),
                        ),
                      if (claimant != null)
                        Text(
                          claimant,
                          style: hf.type(HfType.meta, color: HfColors.inkSoft),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// What happened to a task, as a line, with the task as a chip under it.
class _TaskEvent extends StatelessWidget {
  const _TaskEvent(this.message, {this.highlighted = false});
  final HfMessageData message;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final hf = HandsFree.of(context);
    final task = message.task;
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: hf.sp(16)),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: hf.sp(hf.phone ? 340 : 520)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (message.text.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(bottom: hf.sp(6)),
                  child: Text(
                    message.text,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: hf.type(HfType.meta, color: HfColors.inkMuted),
                  ),
                ),
              if (task != null) _TaskChip(task, highlighted: highlighted),
            ],
          ),
        ),
      ),
    );
  }
}

/// One bubble with its avatar, name and number.
class _MessageRow extends StatelessWidget {
  const _MessageRow({
    required this.part,
    required this.onTap,
    required this.imageBuilder,
  });
  final HfMessagePart part;
  final void Function(int n, HfMessageData message)? onTap;
  final HfImageBuilder? imageBuilder;

  static const _avatar = 40.0;

  @override
  Widget build(BuildContext context) {
    final hf = HandsFree.of(context);
    final m = part.message;
    final mine = m.isMine;
    final current = part.highlighted || AgentSpotlight.isCurrent(context);
    final tag = SizedBox(
      width: hf.sp(30),
      child: Align(
        alignment: Alignment.topCenter,
        // The number is the message's own, like the one on a row's bar.
        child: KeyedSubtree(
          key: const ValueKey('hf-row-bar'),
          child: HfBadge(part.n, tone: HfTone.sticker, small: true),
        ),
      ),
    );
    final avatar = SizedBox(
      width: hf.sp(_avatar),
      child: part.head && !mine
          ? HfAvatar(name: m.senderName, size: _avatar)
          : null,
    );
    Widget content = LayoutBuilder(
      builder: (context, box) {
        final room =
            box.maxWidth -
            (mine ? 0 : hf.sp(_avatar + 10)) -
            hf.sp(30 + 8);
        final bubbleMax = room * (hf.phone ? .96 : .72);
        return Row(
          mainAxisAlignment: mine
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (mine) ...[tag, SizedBox(width: hf.sp(8))],
            if (!mine) ...[avatar, SizedBox(width: hf.sp(10))],
            Flexible(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: bubbleMax),
                child: Column(
                  crossAxisAlignment: mine
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    if (part.head) _Header(m),
                    _Bubble(
                      message: m,
                      current: current,
                      imageBuilder: imageBuilder,
                    ),
                  ],
                ),
              ),
            ),
            if (!mine) ...[SizedBox(width: hf.sp(8)), tag],
          ],
        );
      },
    );
    content = Semantics(
      container: true,
      button: onTap != null && hf.interactive,
      label: '第 ${part.n} 条',
      child: content,
    );
    final tap = onTap;
    if (tap != null && hf.interactive) {
      content = MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => tap(part.n, m),
          child: content,
        ),
      );
    }
    return content;
  }
}

/// The name, the Agent badge and the time over a group.
class _Header extends StatelessWidget {
  const _Header(this.message);
  final HfMessageData message;

  @override
  Widget build(BuildContext context) {
    final hf = HandsFree.of(context);
    final m = message;
    final time = Text(
      HfConversation.clock(m.time),
      style: hf.type(HfType.meta, color: HfColors.inkMuted),
    );
    return Padding(
      padding: EdgeInsets.only(bottom: hf.sp(5), left: hf.sp(4), right: hf.sp(4)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              m.isMine ? '我' : m.senderName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: hf.type(HfType.body),
            ),
          ),
          if (m.isAgent) ...[
            SizedBox(width: hf.sp(8)),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: hf.sp(8),
                vertical: hf.sp(1),
              ),
              decoration: BoxDecoration(
                color: HfColors.ink,
                borderRadius: BorderRadius.circular(hf.sp(6)),
              ),
              child: Text(
                'Agent',
                maxLines: 1,
                style: hf.type(HfType.meta, color: Colors.white),
              ),
            ),
          ],
          SizedBox(width: hf.sp(8)),
          time,
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.message,
    required this.current,
    required this.imageBuilder,
  });
  final HfMessageData message;
  final bool current;
  final HfImageBuilder? imageBuilder;

  @override
  Widget build(BuildContext context) {
    final hf = HandsFree.of(context);
    final m = message;
    final radius = BorderRadius.circular(hf.sp(16));
    final shadow = m.isMine
        ? HfTone.sticker
        : m.isAgent
        ? HfTone.progress
        : HfTone.info;
    final fill = current
        ? _highlightFill
        : (m.isMine ? HfColors.cream : HfColors.card);
    final soft = hf.type(HfType.meta, color: HfColors.inkMuted);
    final body = <Widget>[];

    if (m.deleted) {
      body.add(
        Text(
          HfConversation.deletedText,
          style: hf.type(HfType.body, color: HfColors.inkMuted),
        ),
      );
    } else {
      if (m.quote != null) body.add(_Quote(m.quote!.author, m.quote!.text));
      for (final s in HfConversation.bodyOf(m.text)) {
        body.add(switch (s.kind) {
          HfBodyKind.text => AgentMarkText(s.text, style: hf.type(HfType.body)),
          HfBodyKind.quote => _Quote(null, s.text),
          HfBodyKind.code => HfConversation.codeOf(s),
        });
      }
      for (final a in m.attachments) {
        body.add(
          a.isImage
              ? _ImageTile(a, imageBuilder)
              : _FileChip(a),
        );
      }
      if (m.task != null) body.add(_TaskChip(m.task!));
      if (m.reactions.isNotEmpty) {
        body.add(
          Wrap(
            spacing: hf.sp(6),
            runSpacing: hf.sp(6),
            children: [for (final r in m.reactions) _ReactionChip(r)],
          ),
        );
      }
      if (m.replyCount > 0) body.add(_RepliesPill(m.replyCount));
    }
    if (m.edited) {
      body.add(Text(HfConversation.editedText, style: soft));
    }

    return DecoratedBox(
      key: ValueKey('hf-bubble-${m.id}'),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: radius,
        boxShadow: [
          BoxShadow(color: HfColors.of(shadow), offset: Offset(0, hf.sp(5))),
        ],
      ),
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(color: HfColors.ink, width: hf.sp(current ? 5.5 : 3)),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: hf.sp(13),
            vertical: hf.sp(10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (i, w) in body.indexed) ...[
                if (i > 0) SizedBox(height: hf.sp(8)),
                w,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A quoted message or a quoted line: a rule at the left, the words in grey.
class _Quote extends StatelessWidget {
  const _Quote(this.author, this.text);
  final String? author;
  final String text;

  @override
  Widget build(BuildContext context) {
    final hf = HandsFree.of(context);
    return DecoratedBox(
      key: const ValueKey('hf-quote'),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: HfColors.ink, width: hf.sp(4)),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.only(left: hf.sp(8)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (author != null)
              Text(
                author!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: hf.type(HfType.meta, color: HfColors.inkMuted),
              ),
            Text(
              text,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: hf.type(HfType.body, color: HfColors.inkSoft),
            ),
          ],
        ),
      ),
    );
  }
}

/// A picture: the app's, or a tile with its name.
class _ImageTile extends StatelessWidget {
  const _ImageTile(this.image, this.builder);
  final HfAttachmentData image;
  final HfImageBuilder? builder;

  @override
  Widget build(BuildContext context) {
    final hf = HandsFree.of(context);
    final size = Size(hf.sp(220), hf.sp(140));
    final radius = BorderRadius.circular(hf.sp(10));
    return DecoratedBox(
      key: const ValueKey('hf-image'),
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: HfColors.ink, width: hf.sp(2.5)),
        color: HfColors.cream,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: builder != null
              ? builder!(context, image, size)
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.image_outlined,
                      size: hf.sp(40),
                      color: HfColors.inkSoft,
                    ),
                    SizedBox(height: hf.sp(4)),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: hf.sp(8)),
                      child: Text(
                        image.name,
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: hf.type(HfType.meta, color: HfColors.inkSoft),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// A file: icon, name, size.
class _FileChip extends StatelessWidget {
  const _FileChip(this.file);
  final HfAttachmentData file;

  @override
  Widget build(BuildContext context) {
    final hf = HandsFree.of(context);
    final size = file.sizeLabel;
    return DecoratedBox(
      key: const ValueKey('hf-file'),
      decoration: BoxDecoration(
        color: HfColors.cream,
        borderRadius: BorderRadius.circular(hf.sp(10)),
        border: Border.all(color: HfColors.ink, width: hf.sp(2.5)),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: hf.sp(10), vertical: hf.sp(6)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.insert_drive_file_outlined,
              size: hf.sp(26),
              color: HfColors.inkSoft,
            ),
            SizedBox(width: hf.sp(8)),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    file.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: hf.type(HfType.body),
                  ),
                  if (size != null)
                    Text(
                      size,
                      style: hf.type(HfType.meta, color: HfColors.inkMuted),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReactionChip extends StatelessWidget {
  const _ReactionChip(this.reaction);
  final HfReactionData reaction;

  @override
  Widget build(BuildContext context) {
    final hf = HandsFree.of(context);
    return Container(
      key: ValueKey(
        reaction.mine ? 'hf-reaction-mine' : 'hf-reaction',
      ),
      padding: EdgeInsets.symmetric(horizontal: hf.sp(8), vertical: hf.sp(2)),
      decoration: BoxDecoration(
        color: reaction.mine ? HfColors.sticker : HfColors.card,
        borderRadius: BorderRadius.circular(hf.sp(10)),
        border: Border.all(
          color: HfColors.ink,
          width: hf.sp(reaction.mine ? 3 : 2),
        ),
      ),
      child: Text(
        '${reaction.emoji} ${reaction.count}',
        style: hf.type(HfType.meta),
      ),
    );
  }
}

class _RepliesPill extends StatelessWidget {
  const _RepliesPill(this.count);
  final int count;

  @override
  Widget build(BuildContext context) {
    final hf = HandsFree.of(context);
    return Container(
      key: const ValueKey('hf-replies'),
      padding: EdgeInsets.symmetric(horizontal: hf.sp(10), vertical: hf.sp(3)),
      decoration: BoxDecoration(
        color: HfColors.card,
        borderRadius: BorderRadius.circular(hf.sp(10)),
        border: Border.all(color: HfColors.ink, width: hf.sp(2.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.forum_outlined, size: hf.sp(18), color: HfColors.ink),
          SizedBox(width: hf.sp(6)),
          Text(HfConversation.repliesLabel(count), style: hf.type(HfType.meta)),
        ],
      ),
    );
  }
}
