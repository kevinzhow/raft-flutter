import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/features/message_presentation.dart';
import 'package:raft_ui/raft_ui.dart';

import 'message_presentation_test.dart' show fixture, host;

void main() {
  testWidgets(
    'messageReferencePatterns and useRefNavigation open the qualified task',
    (tester) async {
      final (workspace, api) = (await tester.runAsync(() => fixture('owner')))!;
      addTearDown(workspace.dispose);
      workspace.channels = [
        workspace.channel!,
        RaftChannel({'id': 'design-id', 'name': 'design', 'type': 'channel'}),
      ];
      workspace.dms = [
        RaftChannel({
          'id': 'human-dm',
          'name': 'Twin',
          'type': 'dm',
          'peerType': 'user',
        }),
        RaftChannel({
          'id': 'agent-dm',
          'name': 'Twin',
          'type': 'dm',
          'peerType': 'agent',
        }),
      ];
      final opened = <String>[];
      for (final (text, channel) in [
        ('#design:#7', 'design-id'),
        ('dm:@Twin~agent:#7', 'agent-dm'),
      ]) {
        api.routes['GET /tasks/channel/$channel/number/7'] = (_) => {
          'task': {
            'id': '$channel-task',
            'channelId': channel,
            'number': 7,
            'conversationAnchored': true,
          },
        };
        final presentation = MessagePresentation(
          controller: workspace,
          message: RaftMessage({
            'id': 'm1',
            'channelId': 'c1',
            'content': text,
          }),
          taskByNumber: (_) => {'id': 'wrong-task'},
          onOpenTask: (task) => opened.add(task['id'] as String),
          onExternalLink: (_) {},
        );
        await tester.pumpWidget(
          host(Builder(builder: (context) => presentation.body(context))),
        );
        final chip = find.text(text, findRichText: true);
        expect(chip, findsOneWidget);
        await tester.tap(chip);
        await tester.pumpAndSettle();
        expect(opened.lastOrNull, '$channel-task', reason: text);
      }
    },
  );

  testWidgets('useRefNavigation opens a legacy task in its Tasks tab', (
    tester,
  ) async {
    final (workspace, api) = (await tester.runAsync(() => fixture('owner')))!;
    addTearDown(workspace.dispose);
    final destination = RaftChannel({
      'id': 'design-id',
      'name': 'design',
      'type': 'channel',
      'joined': true,
    });
    workspace.channels = [workspace.channel!, destination];
    api.routes['GET /messages/channel/design-id'] = (_) => {'messages': []};
    workspace.navigation.navigate(
      RaftLocation.at(
        serverSlug: workspace.location.serverSlug,
        route: RaftRoute.channel,
        entityId: 'c1',
        query: const {'profile': 'human:other'},
      ),
    );
    api.routes['GET /tasks/channel/design-id/number/7'] = (_) => {
      'task': {
        'id': 'legacy',
        'channelId': destination.id,
        'number': 7,
        'isLegacy': true,
      },
    };
    final presentation = MessagePresentation(
      controller: workspace,
      message: RaftMessage({
        'id': 'm1',
        'channelId': 'c1',
        'content': '#design:#7',
      }),
      onOpenTask: (task) {
        workspace.navigation.navigateTask(
          workspace.location.withQuery({
            'legacyTask': '${task['channelId']}:${task['id']}',
          }),
        );
      },
      onExternalLink: (_) {},
    );
    await tester.pumpWidget(
      host(Builder(builder: (context) => presentation.body(context))),
    );
    await tester.tap(find.text('#design:#7', findRichText: true));
    await tester.pumpAndSettle();
    expect(workspace.location.entityId, destination.id);
    expect(workspace.channel?.id, destination.id);
    expect(workspace.location.chatTab, 'tasks');
    expect(workspace.location.profile, isNull);
    expect('${workspace.location.legacyTask}', 'design-id:legacy');
    expect(workspace.navigation.visit(workspace.navigation.index - 1), isTrue);
    expect(workspace.location.chatTab, 'tasks');
    expect(workspace.location.legacyTask, isNull);
  });

  for (final (label, payload) in [
    ('missing', <String, dynamic>{}),
    ('null', <String, dynamic>{'task': null}),
  ]) {
    testWidgets('a qualified task ref whose task is $label opens nothing', (
      tester,
    ) async {
      final (workspace, api) = (await tester.runAsync(() => fixture('owner')))!;
      addTearDown(workspace.dispose);
      workspace.channels = [
        workspace.channel!,
        RaftChannel({'id': 'design-id', 'name': 'design', 'type': 'channel'}),
      ];
      api.routes['GET /tasks/channel/design-id/number/7'] = (_) => payload;
      final opened = <Map<String, dynamic>>[];
      final presentation = MessagePresentation(
        controller: workspace,
        message: RaftMessage({
          'id': 'm1',
          'channelId': 'c1',
          'content': '#design:#7',
        }),
        onOpenTask: opened.add,
        onExternalLink: (_) {},
      );
      await tester.pumpWidget(
        host(
          RaftToastHost(
            child: Builder(builder: (context) => presentation.body(context)),
          ),
        ),
      );
      await tester.tap(find.text('#design:#7', findRichText: true));
      await tester.pumpAndSettle();
      expect(opened, isEmpty);
      expect(find.textContaining('Unable to open'), findsNothing);
    });

    testWidgets('a task mention dialog whose task is $label closes', (
      tester,
    ) async {
      final (workspace, api) = (await tester.runAsync(() => fixture('owner')))!;
      addTearDown(workspace.dispose);
      workspace.channels = [
        workspace.channel!,
        RaftChannel({'id': 'design-id', 'name': 'design', 'type': 'channel'}),
      ];
      api.routes['GET /tasks/channel/design-id/number/7'] = (_) => payload;
      final presentation = MessagePresentation(
        controller: workspace,
        message: RaftMessage({
          'id': 'm1',
          'channelId': 'c1',
          'content': '#design:#7',
        }),
        onExternalLink: (_) {},
      );
      await tester.pumpWidget(
        host(
          RaftToastHost(
            child: Builder(builder: (context) => presentation.body(context)),
          ),
        ),
      );
      await tester.tap(find.text('#design:#7', findRichText: true));
      await tester.pumpAndSettle();
      expect(find.textContaining('task #7'), findsNothing);
      expect(
        find.text('Unable to open source. It may be unavailable or deleted.'),
        findsOneWidget,
      );
    });
  }
}
