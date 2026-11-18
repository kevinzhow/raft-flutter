import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../parity_harness.dart';
import 'thread_messages/chat_stage.dart';

const _variants = [
  'muted-channel',
  'stopped-following-thread',
  'many-narrow',
  'all-reachable',
];
const _suffixes = ['', '.dark', '.en', '.en.dark'];
const _prefix = 'components.thread.message.agent-read-line';

final Map<String, ParityCase> agentReadProgressCases = {
  for (final variant in _variants)
    for (final suffix in _suffixes)
      '$_prefix.$variant$suffix': ParityCase(
        widgets: const [
          'raft_flutter:RaftChatView',
          'raft_ui:RaftMessageReadFaces',
          'raft_ui:RaftMessageReadStatus',
        ],
        build: (ctx) => Builder(
          builder: (context) => Localizations.override(
            context: context,
            locale: ctx.props['lang'] == 'en'
                ? const Locale('en')
                : const Locale('zh', 'CN'),
            child: _stage(ctx, variant).build(),
          ),
        ),
        interact: (tester, ctx) async {
          await _stage(ctx, variant).alignRow(tester);
          final target = find.byKey(
            const ValueKey('message-wrapper-visual-read-own'),
          );
          final status = find.descendant(
            of: target,
            matching: find.byKey(const ValueKey('agent-read-status')),
          );
          expect(
            status,
            variant == 'all-reachable' ? findsNothing : findsOneWidget,
          );
          if (variant == 'many-narrow') {
            final english = ctx.props['lang'] == 'en';
            expect(
              find.descendant(
                of: status,
                matching: find.text(english ? 'Muted: 4 agents' : '+1'),
              ),
              findsOneWidget,
            );
          }
          expect(
            find.byKey(
              ValueKey('agent-read-face-${ParityIdentities(ctx).cindy['id']}'),
            ),
            findsOneWidget,
          );
        },
        notes:
            'Matches AgentReadLineCases.tsx at '
            '1d689caf34442247cab70580d7feac1b8c302d60.',
      ),
};

ChatStage _stage(ParityContext ctx, String variant) => stageFor(ctx, () {
  final ids = ParityIdentities(ctx);
  final design = ids.channel('design')['id'] as String;
  const threadId = 'thread-visual-read-line-parent';
  final inThread = variant == 'stopped-following-thread';
  final scope = inThread ? threadId : design;
  final en = ctx.props['lang'] == 'en';
  final cindy = _Agent(
    ids.cindy['id'],
    ids.cindy['displayName'],
    ids.cindy['avatar'],
  );
  final productUx = _Agent(
    ids.productUx['id'],
    ids.productUx['displayName'],
    'pixel:wizard',
  );
  const niko = _Agent('visual-read-agent-niko', 'Niko', 'pixel:fox');
  const lagoon = _Agent('visual-read-agent-lagoon', 'Lagoon', 'pixel:penguin');
  const jasper = _Agent('visual-read-agent-jasper', 'Jasper', 'pixel:owl');
  final earlier = en ? 'The release branch is cut.' : '发布分支已经切好了。';
  final own = inThread
      ? en
            ? 'Picking this back up: the CSV export still drops the last row.'
            : '接着说：CSV 导出还是会丢最后一行。'
      : en
      ? 'Can someone take the release checklist before 18:00?'
      : '谁能在 18:00 前接一下发布清单？';
  Map<String, dynamic> message(
    int seq,
    _Agent? agent,
    String content,
    String time,
  ) => {
    'id': agent == null ? 'visual-read-own' : 'visual-read-$seq',
    'seq': seq,
    'channelId': scope,
    'senderType': agent == null ? 'user' : 'agent',
    'senderId': agent?.id ?? ids.owner['id'],
    'senderName': agent?.name ?? ids.owner['displayName'],
    if (agent != null) 'senderAvatarUrl': agent.avatar,
    'content': content,
    'createdAt': '2026-06-22T$time:00.000Z',
  };
  final (prior, seq, frontiers) = switch (variant) {
    'muted-channel' => ([(niko, 41), (cindy, 42)], 43, {niko: 42, cindy: 43}),
    'stopped-following-thread' => (
      [(niko, 7), (cindy, 8)],
      9,
      {niko: 8, cindy: 9},
    ),
    'many-narrow' => (
      [(cindy, 20), (jasper, 21), (lagoon, 22), (niko, 23), (productUx, 24)],
      25,
      {cindy: 25, jasper: 21, lagoon: 22, niko: 23, productUx: 24},
    ),
    _ => ([(niko, 41)], 42, {niko: 42, cindy: 43}),
  };
  final reachable = variant == 'all-reachable';
  final stage = ChatStage(
    ctx,
    channelId: scope,
    rowWidth: variant == 'many-narrow' ? 288 : 374,
    rowOrigin: const Offset(16, 16),
    rowIds: ['visual-read-own', if (reachable) 'visual-read-43'],
    extraChannels: [
      if (inThread)
        {'id': threadId, 'name': 'Thread', 'type': 'thread', 'joined': true},
    ],
    threadParent: inThread
        ? {'id': 'visual-read-line-parent', 'channelId': design}
        : null,
    messages: [
      for (final (agent, seq) in prior) message(seq, agent, earlier, '02:10'),
      message(seq, null, own, '02:30'),
      if (reachable)
        message(
          43,
          cindy,
          en ? "On it. I'll post the checklist here." : '我来，清单稍后发在这里。',
          '02:35',
        ),
    ],
  );
  stage.client.routes['POST /feature-flags/evaluate'] = (_) => {
    'evaluations': [
      {'key': 'agent_read_progress_v0', 'enabled': true},
    ],
  };
  stage.client.routes['GET /agents'] = (_) => [
    ...ids.agents,
    for (final agent in [niko, lagoon, jasper])
      {
        'id': agent.id,
        'name': agent.name,
        'avatarUrl': agent.avatar,
        'status': 'active',
      },
  ];
  final detail = stage.client.routes['GET /channels/$scope']!(null) as Map;
  stage.client.routes['GET /channels/$scope'] = (_) => {
    ...detail,
    'peerReadStates': [
      for (final entry in frontiers.entries)
        {
          'peerKind': 'agent',
          'peerId': entry.key.id,
          'maxReadSeq': entry.value,
          if (inThread && entry.key == niko) 'stoppedFollowing': true,
          if (!inThread && entry.key != cindy) 'mutedChannel': true,
        },
    ],
  };
  return stage;
});

class _Agent {
  const _Agent(this.id, this.name, this.avatar);
  final String id, name, avatar;
}
