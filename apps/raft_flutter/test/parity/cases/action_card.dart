import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/data/workspace_entity_directory.dart';
import 'package:raft_flutter/features/message_presentation.dart';
import 'package:raft_ui/raft_ui.dart';

import '../../fallback_text_style.dart';
import '../parity_harness.dart';
import 'thread_messages/chat_stage.dart' show ParityRaftClient;

const _official = [
  'expired-agent',
  'mcp-connect',
  'agent-create',
  'agent-migrate',
];
const _variants = [
  ..._official,
  'question-single',
  'question-single-other',
  'question-single-undo',
  'question-multi',
  'question-confirm',
  'question-answered',
  'channel-done',
];

final _fixture = jsonDecode(
  File('../../tool/parity-ext/fixtures/action-cards-v124.json')
      .readAsStringSync(),
) as Map<String, dynamic>;

ParityCase _actionCardCase(String name) {
  late WorkspaceController workspace;
  late RaftMessage message;
  final fixtureName = switch (name) {
    'question-single-other' || 'question-single-undo' => 'question-single',
    _ => name,
  };
  return ParityCase(
    widgets: const [
      'raft_flutter:MessagePresentation',
      'raft_flutter:MessageActionCard',
      'raft_ui:RaftSpecActionCard',
    ],
    settle: name == 'question-single-undo'
        ? Duration.zero
        : const Duration(milliseconds: 350),
    build: (ctx) {
      final server = RaftRecord(
        Map<String, dynamic>.from(_fixture['server'] as Map),
      );
      final channel = RaftChannel(
        Map<String, dynamic>.from(_fixture['channel'] as Map),
      );
      final mcp = Map<String, dynamic>.from(_fixture['mcp'] as Map);
      final client = ParityRaftClient(
        {
          'GET /agents': (_) => [_fixture['agent']],
          'GET /servers/${server.id}/members': (_) => _fixture['members'],
          'GET /servers/${server.id}/machines': (_) => {
            'machines': [_fixture['computer']],
          },
          'GET /mcp/servers/${mcp['mcpServerId']}/connection-authorization': (
            _,
          ) => mcp,
        },
        user: Map<String, dynamic>.from(_fixture['user'] as Map),
      )..selectServer(server.id);
      workspace = WorkspaceController(client)
        ..server = server
        ..channel = channel
        ..channels = [channel];
      ctx.onDispose(workspace.dispose);
      message = RaftMessage({
        'id': _fixture['messageId'],
        'channelId': channel.id,
        'serverId': server.id,
        'senderType': 'agent',
        'senderId': (_fixture['agent'] as Map)['id'],
        'messageType': 'chat',
        'content': '',
        'actionMetadata': (_fixture['cards'] as Map)[fixtureName],
      });
      return Material(
        type: MaterialType.transparency,
        child: Builder(
          builder: (context) {
            final tokens = RaftTokens.of(context);
            final ui = tokens.ui;
            return ColoredBox(
              color: ui.layerCanvas,
              child: Align(
                alignment: Alignment.topLeft,
                child: ctx.target(
                  SizedBox(
                    width: ctx.width,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 12,
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: ui.fillMuted,
                              shape: BoxShape.circle,
                            ),
                          ),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  spacing: 8,
                                  children: [
                                    RaftCssText(
                                      'Scout',
                                      style: tokens.scale(
                                        RaftTypeScale.callout,
                                        weight: FontWeight.w600,
                                        color: ui.foreground,
                                      ),
                                    ),
                                    RaftCssText(
                                      '09:41',
                                      style: tokens.scale(
                                        RaftTypeScale.caption,
                                        color: ui.foregroundHint,
                                      ),
                                    ),
                                  ],
                                ),
                                ListenableBuilder(
                                  listenable: workspace.entityDirectory,
                                  builder: (context, _) => MessagePresentation(
                                    controller: workspace,
                                    message: message,
                                    onExternalLink: (_) {},
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
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
      await Future.wait([
        for (final kind in WorkspaceEntityKind.values)
          workspace.entityDirectory.refresh(kind),
      ]);
      await tester.pump();
      final target = switch (name) {
        'expired-agent' => find.byKey(
          const ValueKey('action-card-toggle-details'),
        ),
        'question-single-other' => find.textContaining('Other').first,
        'question-single-undo' => find.text('Tuesday'),
        _ => null,
      };
      if (target != null) {
        await tester.tap(target);
        await tester.pump();
      }
      if (name == 'question-single-undo') {
        expect(find.text('Undo'), findsOneWidget);
      }
      expectNoFallbackTextStyle(name);
    },
  );
}

final Map<String, ParityCase> actionCardCases = {
  for (final name in _official)
    'components.action-card.$name': _actionCardCase(name),
};

final Map<String, ParityCase> extActionCardCases = {
  for (final name in _variants)
    for (final platform in ['desktop', 'phone'])
      for (final theme in ['brutal', 'elegant-dark'])
        'components.action-card-v124.$name.$platform.$theme': _actionCardCase(
          name,
        ),
};
