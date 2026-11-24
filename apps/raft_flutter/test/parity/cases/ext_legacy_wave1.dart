import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/data/workspace_entity_directory.dart';
import 'package:raft_flutter/features/forward_composer_page.dart';
import 'package:raft_flutter/features/message_presentation.dart';
import 'package:raft_ui/raft_ui.dart';

import '../../fallback_text_style.dart';
import '../parity_harness.dart';
import 'thread_messages/chat_stage.dart' show ParityRaftClient;

final _fixture = jsonDecode(
  File('../../tool/parity-ext/fixtures/legacy-wave1.json').readAsStringSync(),
) as Map<String, dynamic>;

WorkspaceController _workspace(ParityContext ctx) {
  final server = RaftRecord(
    Map<String, dynamic>.from(_fixture['server'] as Map),
  );
  final channels = [
    for (final raw in _fixture['channels'] as List)
      RaftChannel(Map<String, dynamic>.from(raw as Map)),
  ];
  final agents = [
    for (final raw in _fixture['agents'] as List)
      Map<String, dynamic>.from(raw as Map),
  ];
  final members = [
    for (final raw in _fixture['members'] as List)
      Map<String, dynamic>.from(raw as Map),
  ];
  final client = ParityRaftClient(
    {
      'GET /agents': (_) => agents,
      'GET /servers/${server.id}/members': (_) => members,
      'GET /servers/${server.id}/machines': (_) => {'machines': <Object>[]},
      'GET /channels/forward-targets': (_) => {'conversations': <Object>[]},
    },
    user: Map<String, dynamic>.from(_fixture['user'] as Map),
  )..selectServer(server.id);
  final w = WorkspaceController(client)
    ..server = server
    ..channel = channels.first
    ..channels = channels;
  ctx.onDispose(w.dispose);
  return w;
}

Widget _canvasBox(ParityContext ctx, Widget child) => Material(
  type: MaterialType.transparency,
  child: Builder(
    builder: (context) {
      final ui = RaftTokens.of(context).ui;
      final width = (ctx.props['boxWidth'] as num?)?.toDouble() ?? ctx.width;
      return ColoredBox(
        color: ui.layerCanvas,
        child: Align(
          alignment: Alignment.topLeft,
          child: ctx.target(
            Container(
              key: const ValueKey('wave1-frame'),
              width: width,
              color: ui.layerCanvas,
              padding: const EdgeInsets.all(16),
              child: child,
            ),
          ),
        ),
      );
    },
  ),
);

Widget _handoffAvatar(Map<String, dynamic> agent) {
  final name = '${agent['displayName'] ?? agent['name']}';
  final avatarUrl = agent['avatarUrl'] as String?;
  final pixelKey = avatarUrl != null && avatarUrl.startsWith('pixel:')
      ? avatarUrl.substring('pixel:'.length)
      : null;
  return RaftAvatar(
    name: name,
    kind: RaftAvatarKind.agent,
    mountedContext: RaftMountedAvatarContext.creatorLink,
    content: RaftAvatarContent(
      name: name,
      kind: RaftAvatarContentKind.agent,
      pixelKey: pixelKey,
    ),
  );
}

ParityCase _taskHandoffCase({required bool returned}) => ParityCase(
  widgets: const ['raft_ui:RaftTaskHandoffCard'],
  settle: const Duration(milliseconds: 100),
  build: (ctx) {
    final agents = _fixture['agents'] as List;
    final cindy = Map<String, dynamic>.from(agents[0] as Map);
    final martin = Map<String, dynamic>.from(agents[1] as Map);
    final handoff = _fixture['handoff'] as Map<String, dynamic>;
    final notice = handoff['notice'] as Map<String, dynamic>;
    return _canvasBox(
      ctx,
      RaftTaskHandoffCard(
        from: '@Cindy',
        to: '@Martin',
        fromAvatar: _handoffAvatar(cindy),
        toAvatar: _handoffAvatar(martin),
        reason: '${notice['reason']}',
        time: '${handoff['time']}',
        returnedLabel: returned ? 'Cindy took it back · 06:12' : null,
        semanticLabel: '@Cindy handed #19 to @Martin',
      ),
    );
  },
  interact: (tester, ctx) async {
    expectNoFallbackTextStyle('task-handoff');
  },
);

ParityCase _unknownActionCardCase({required bool open}) {
  late WorkspaceController w;
  return ParityCase(
    widgets: const [
      'raft_flutter:MessagePresentation',
      'raft_flutter:MessageActionCard',
      'raft_ui:RaftActionCard',
    ],
    settle: const Duration(milliseconds: 250),
    build: (ctx) {
      w = _workspace(ctx);
      final channel = w.channels.first;
      final agent = Map<String, dynamic>.from(
        (_fixture['agents'] as List).first as Map,
      );
      final message = RaftMessage({
        'id': 'msg-unknown-action-wave1',
        'channelId': channel.id,
        'serverId': w.server!.id,
        'senderType': 'agent',
        'senderId': agent['id'],
        'messageType': 'chat',
        'content': '',
        'actionMetadata': _fixture['unknownActionCard'],
      });
      return _canvasBox(
        ctx,
        ListenableBuilder(
          listenable: w.entityDirectory,
          builder: (context, _) => MessagePresentation(
            controller: w,
            message: message,
            onExternalLink: (_) {},
          ),
        ),
      );
    },
    interact: (tester, ctx) async {
      await Future.wait([
        for (final kind in WorkspaceEntityKind.values)
          w.entityDirectory.refresh(kind),
      ]);
      await tester.pump();
      if (open) {
        await tester.tap(
          find.byKey(const ValueKey('action-card-toggle-details')),
        );
        await tester.pumpAndSettle();
      }
      expectNoFallbackTextStyle('action-card');
    },
  );
}

ParityCase _quotedSkeletonCase() => ParityCase(
  widgets: const ['raft_ui:RaftQuotedMessageSkeleton'],
  settle: const Duration(milliseconds: 100),
  build: (ctx) => _canvasBox(ctx, const RaftQuotedMessageSkeleton()),
);

ParityCase _inlineAudioCase({required bool ready}) => ParityCase(
  widgets: const ['raft_ui:RaftInlineAudio'],
  settle: const Duration(milliseconds: 100),
  build: (ctx) {
    final audio = _fixture['audio'] as Map<String, dynamic>;
    return Material(
      type: MaterialType.transparency,
      child: Builder(
        builder: (context) {
          final ui = RaftTokens.of(context).ui;
          final width =
              (ctx.props['boxWidth'] as num?)?.toDouble() ?? ctx.width;
          return ColoredBox(
            color: ui.layerCanvas,
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: width,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: RaftInlineAudio(
                    filename: '${audio['filename']}',
                    state: ready
                        ? RaftInlineMediaState.ready
                        : RaftInlineMediaState.failed,
                    position: Duration.zero,
                    duration: Duration.zero,
                    volume: 1,
                    onDownload: () {},
                    onTogglePlay: () {},
                    onSeek: (_) {},
                    onVolume: (_) {},
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  },
  interact: (tester, ctx) async {
    expectNoFallbackTextStyle('inline-audio');
  },
);

ParityCase _forwardDesktopCase() {
  late WorkspaceController w;
  return ParityCase(
    widgets: const [
      'raft_flutter:ForwardComposerPage',
      'raft_ui:RaftForwardDesktopDialog',
    ],
    settle: const Duration(milliseconds: 300),
    build: (ctx) {
      w = _workspace(ctx);
      final msg = RaftMessage(
        Map<String, dynamic>.from(_fixture['forwardMessage'] as Map),
      );
      return Material(
        type: MaterialType.transparency,
        child: Builder(
          builder: (context) => ColoredBox(
            color: RaftTokens.of(context).ui.layerCanvas,
            child: ForwardComposerPage(
              controller: w,
              messages: [msg],
              desktop: true,
            ),
          ),
        ),
      );
    },
    interact: (tester, ctx) async {
      await Future.wait([
        for (final kind in WorkspaceEntityKind.values)
          w.entityDirectory.refresh(kind),
      ]);
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expectNoFallbackTextStyle('forward-desktop');
    },
  );
}

final Map<String, ParityCase> extLegacyWave1Cases = {
  for (final platform in const ['desktop', 'phone'])
    for (final suffix in const ['brutal', 'elegant-dark']) ...{
      'components.legacy-wave1.task-handoff.$platform.$suffix':
          _taskHandoffCase(returned: false),
      'components.legacy-wave1.task-handoff-returned.$platform.$suffix':
          _taskHandoffCase(returned: true),
      'components.legacy-wave1.action-card.$platform.$suffix':
          _unknownActionCardCase(open: false),
      'components.legacy-wave1.action-card-open.$platform.$suffix':
          _unknownActionCardCase(open: true),
      'components.legacy-wave1.quoted-skeleton.$platform.$suffix':
          _quotedSkeletonCase(),
      'components.legacy-wave1.inline-audio.$platform.$suffix':
          _inlineAudioCase(ready: true),
      'components.legacy-wave1.inline-audio-failed.$platform.$suffix':
          _inlineAudioCase(ready: false),
    },
  for (final suffix in const ['brutal', 'elegant-dark'])
    'components.legacy-wave1.forward-desktop.dialog.$suffix':
        _forwardDesktopCase(),
};
