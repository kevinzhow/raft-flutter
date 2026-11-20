import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/message_presentation.dart';
import 'package:raft_flutter/features/message_link_unavailable.dart';
import 'package:raft_ui/raft_ui.dart';

import '../parity_harness.dart';
import 'thread_messages/chat_stage.dart' show ParityRaftClient;

final _fixture = jsonDecode(
  File('../../tool/parity-ext/fixtures/app-links.json').readAsStringSync(),
) as Map<String, dynamic>;

const _states = [
  'block-chip',
  'consent',
  'consent-failed',
  'loading',
  'undo',
  'unavailable',
];

final Map<String, ParityCase> extAppLinkCases = {
  for (final platform in ['desktop', 'phone'])
    for (final state in _states)
      for (final theme in ['brutal', 'elegant-dark'])
        'components.app-links.$state.$platform.$theme': _case(state),
};

ParityCase _case(String state) => ParityCase(
  widgets: const [
    'raft_flutter:MessagePresentation',
    'raft_flutter:AppLinkMessageView',
    'raft_ui:RaftAppLinkCard',
  ],
  settle: const Duration(milliseconds: 160),
  build: (ctx) {
    if (state == 'unavailable') {
      return Align(
        alignment: Alignment.topLeft,
        child: ctx.target(
          SizedBox(
            key: const ValueKey('app-link-parity-frame'),
            width: (ctx.props['frameWidth'] as num).toDouble(),
            height: ctx.height,
            child: Material(
              type: MaterialType.transparency,
              child: MessageLinkUnavailable(onBack: () {}),
            ),
          ),
        ),
      );
    }
    final block = state == 'block-chip' || state == 'undo';
    final messageId = _fixture['messageId'] as String;
    final channel = RaftChannel({
      'id': _fixture['channelId'],
      'name': 'Fixture channel',
      'joined': true,
    });
    final server = RaftRecord({'id': _fixture['serverId'], 'role': 'member'});
    var allowed = false;
    final pending = Completer<Object>();
    final client = ParityRaftClient(
      {
        'POST /feature-flags/evaluate': (_) => {
          'evaluations': [
            {'key': 'interactive_link_cards', 'enabled': true},
          ],
        },
        'POST /messages/$messageId/link-cards/read': (_) =>
            allowed ? pending.future : _fixture[block ? 'answer' : 'prompt'],
        'POST /integrations/clients/tickets/link-preview-consent': (_) {
          if (state == 'consent-failed') {
            throw const RaftApiException('Fixture failure', status: 500);
          }
          allowed = true;
          return {'app': _fixture['app']};
        },
        'POST /link-cards/execute': (_) =>
            throw StateError('Parity fixture must not execute a card'),
      },
      user: {'id': _fixture['viewerId']},
    )..selectServer(server.id);
    final workspace = WorkspaceController(client)
      ..server = server
      ..channel = channel
      ..channels = [channel];
    ctx.onDispose(workspace.dispose);
    final message = RaftMessage({
      'id': messageId,
      'channelId': channel.id,
      'serverId': server.id,
      'senderType': 'human',
      'content': "See ${_fixture['url']}",
    });
    return Material(
      type: MaterialType.transparency,
      child: RaftToastHost(
        child: Builder(
          builder: (context) => Align(
            alignment: Alignment.topLeft,
            child: ctx.target(
              SizedBox(
                key: const ValueKey('app-link-parity-frame'),
                width: (ctx.props['frameWidth'] as num).toDouble(),
                height: ctx.height,
                child: ColoredBox(
                  color: RaftTokens.of(context).ui.layerCanvas,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: MessagePresentation(
                        controller: workspace,
                        message: message,
                        fontSize: RaftMessageSizeTier.md.bodySizeFor(
                          RaftTokens.of(context),
                        ),
                        onExternalLink: (_) {},
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  },
  interact: (tester, _) async {
    if (state == 'unavailable') {
      expect(
        find.byKey(const ValueKey('message-link-unavailable-back')),
        findsOneWidget,
      );
      return;
    }
    if (state == 'block-chip' || state == 'undo') {
      expect(find.text('Printer ticket'), findsOneWidget);
      expect(find.text('Ticket 123'), findsOneWidget);
      if (state == 'undo') {
        await tester.tap(find.text('Resolve'));
        await tester.pump();
        expect(find.text('Runs when the countdown ends'), findsOneWidget);
        expect(find.text('Undo'), findsOneWidget);
      }
      return;
    }
    final allow = find.text('Allow');
    expect(allow, findsOneWidget);
    if (state == 'consent') return;
    await tester.tap(allow);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    if (state == 'consent-failed') {
      expect(find.text('Retry'), findsOneWidget);
    } else {
      expect(find.bySemanticsLabel('Loading link preview'), findsOneWidget);
    }
  },
);
