import 'package:flutter/material.dart';

import 'hf_conversation.dart';

/// A fixed, realistic conversation with one of everything: mixed people, an
/// Agent, a run of system notes, task events, a picture and a file, code, a
/// quote, reactions, a thread, an edited and a deleted message. For the demo
/// renders of [HfConversation] on a phone, a desktop and a TV. Fictional data.
class HfConversationSample extends StatelessWidget {
  const HfConversationSample({
    super.key,
    this.highlightId,
    this.hasMoreAbove = true,
    this.focusPrefix,
    this.onTapMessage,
    this.imageBuilder,
    this.messages,
  });

  /// The message the person opened the channel from (see [highlightIds]).
  final String? highlightId;
  final bool hasMoreAbove;
  final String? focusPrefix;
  final void Function(int n, HfMessageData message)? onTapMessage;
  final HfImageBuilder? imageBuilder;

  /// Replaces the sample list.
  final List<HfMessageData>? messages;

  /// "Today" of the sample: 2026-10-17, 15:00.
  static final now = DateTime(2026, 10, 17, 15);

  /// The ids of the sample, for choosing a [highlightId].
  static const highlightIds = [
    'm1',
    'm2',
    'n1',
    'n2',
    'n3',
    'e1',
    'e2',
    'm3',
    'm4',
    'm5',
    'm6',
    'm7',
    'm8',
    'm9',
    'm10',
    'm11',
  ];

  static const _kevin = 'u-kevin';
  static const _bo = 'u-bo';
  static const _mia = 'u-mia';
  static const _cindy = 'a-cindy';

  static DateTime _at(int dayBack, int h, int m) =>
      DateTime(2026, 10, 17 - dayBack, h, m);

  /// 16 items: 11 bubbles, 3 system notes (folded to one line), 2 task events.
  static List<HfMessageData> sample() => [
    HfMessageData(
      id: 'm1',
      senderId: _bo,
      senderName: 'Bo',
      time: _at(1, 17, 40),
      text: '明天前把登录页的新设计过一遍，附件是最新稿。',
      attachments: const [
        HfAttachmentData(
          id: 'a1',
          name: 'login-v3.png',
          isImage: true,
          bytes: 482113,
        ),
        HfAttachmentData(id: 'a2', name: 'login-spec.pdf', bytes: 1288490),
      ],
      reactions: const [HfReactionData('👍', 3, mine: true)],
    ),
    HfMessageData(
      id: 'm2',
      senderId: _cindy,
      senderName: 'Cindy',
      isAgent: true,
      time: _at(1, 17, 42),
      text: '收到，我先看交互部分，晚点给你反馈。',
      replyCount: 2,
    ),
    HfMessageData(
      id: 'n1',
      kind: HfMessageKind.system,
      time: _at(1, 17, 50),
      text: 'Mia 加入了频道',
    ),
    HfMessageData(
      id: 'n2',
      kind: HfMessageKind.system,
      time: _at(1, 17, 51),
      text: 'Cindy 把频道说明改成了「登录页改版」',
    ),
    HfMessageData(
      id: 'n3',
      kind: HfMessageKind.reminder,
      time: _at(1, 18, 0),
      text: '提醒：明天 10:00 设计评审',
    ),
    HfMessageData(
      id: 'e1',
      kind: HfMessageKind.taskEvent,
      time: _at(0, 9, 10),
      text: 'Bo 把消息转成了任务',
      task: const HfTaskChipData(number: 12, title: '登录页改版', status: 'todo'),
    ),
    HfMessageData(
      id: 'e2',
      kind: HfMessageKind.taskEvent,
      time: _at(0, 9, 12),
      text: 'Cindy 认领了任务',
      task: const HfTaskChipData(
        number: 12,
        title: '登录页改版',
        status: 'in_progress',
        claimant: 'Cindy',
      ),
    ),
    HfMessageData(
      id: 'm3',
      senderId: _kevin,
      senderName: 'Kevin',
      isMine: true,
      time: _at(0, 9, 30),
      text: '进度怎么样？',
      quote: const HfQuoteData(
        author: 'Bo',
        text: '明天前把登录页的新设计过一遍，附件是最新稿。',
        id: 'm1',
      ),
    ),
    HfMessageData(
      id: 'm4',
      senderId: _cindy,
      senderName: 'Cindy',
      isAgent: true,
      time: _at(0, 9, 31),
      text:
          '第一版已经好了，入口改成这样：\n'
          '```dart\n'
          'void main() {\n'
          '  runApp(const LoginPage());\n'
          '}\n'
          '```\n'
          '> 旧的跳转逻辑已经删掉了',
      reactions: const [HfReactionData('🎉', 2)],
      replyCount: 3,
    ),
    HfMessageData(
      id: 'm5',
      senderId: _cindy,
      senderName: 'Cindy',
      isAgent: true,
      time: _at(0, 9, 32),
      text: '还差你验收，确认后我就合并。',
      task: const HfTaskChipData(
        number: 12,
        title: '登录页改版',
        status: 'in_review',
        claimant: 'Cindy',
      ),
    ),
    HfMessageData(
      id: 'm6',
      senderId: _bo,
      senderName: 'Bo',
      time: _at(0, 10, 5),
      text: '我把第二点的说法改得更清楚了。',
      edited: true,
    ),
    HfMessageData(
      id: 'm7',
      senderId: _bo,
      senderName: 'Bo',
      time: _at(0, 10, 6),
      text: '发错了',
      deleted: true,
    ),
    HfMessageData(
      id: 'm8',
      senderId: _mia,
      senderName: 'Mia',
      time: _at(0, 14, 20),
      text: '下午 3 点碰一下，别忘了带设计稿。',
      reactions: const [
        HfReactionData('👀', 1, mine: true),
        HfReactionData('👍', 2),
      ],
    ),
    HfMessageData(
      id: 'm9',
      senderId: _kevin,
      senderName: 'Kevin',
      isMine: true,
      time: _at(0, 14, 21),
      text: '好的。',
    ),
    HfMessageData(
      id: 'm10',
      senderId: _kevin,
      senderName: 'Kevin',
      isMine: true,
      time: _at(0, 14, 22),
      text: '我会带上，顺便把验收意见一起讲。',
    ),
    HfMessageData(
      id: 'm11',
      senderId: _cindy,
      senderName: 'Cindy',
      isAgent: true,
      time: _at(0, 14, 40),
      text: '我把会议要点整理在文档里了，开完会我再更新。',
      attachments: const [
        HfAttachmentData(id: 'a3', name: '会议要点.md', bytes: 3200),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) => HfConversation(
    messages: messages ?? sample(),
    highlightId: highlightId,
    hasMoreAbove: hasMoreAbove,
    focusPrefix: focusPrefix,
    onTapMessage: onTapMessage,
    imageBuilder: imageBuilder,
    now: now,
  );
}
