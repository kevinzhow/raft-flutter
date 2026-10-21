import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/features/composer_directory.dart';
import 'package:raft_flutter/features/external_identity.dart';
import 'package:raft_flutter/features/message_presentation.dart';
import 'package:raft_flutter/features/resource_search.dart';
import 'package:raft_ui/raft_ui.dart';

import 'message_context_transition_test.dart' show row;
import 'message_presentation_test.dart' show fixture;

void main() {
  test('external-mention profile locations keep the projection key', () {
    final mention = RaftProfileLocation.parse('external-mention:c1:proj-1')!;
    expect(mention.kind, RaftProfileKind.external);
    expect(
      (mention.channelId, mention.id, mention.isMention),
      ('c1', 'proj-1', true),
    );
    expect(mention.toString(), 'external-mention:c1:proj-1');
    final author = RaftProfileLocation.parse('external:c1:m1')!;
    expect(author.isMention, isFalse);
    expect(author.toString(), 'external:c1:m1');
    expect(RaftProfileLocation.parse('external-mention:c1'), isNull);
    expect(RaftProfileLocation.parse('external-mention:c1:p:x'), isNull);
  });

  testWidgets('a restored mention profile reads the channel roster', (t) async {
    final (w, api) = (await t.runAsync(() => fixture('member')))!;
    addTearDown(w.dispose);
    api.routes['GET /channels/c1/members'] = (_) => {
      'humans': [],
      'agents': [],
      'externalMembers': [
        {
          'id': 'proj-1',
          'provider': 'slack',
          'displayName': 'Ada Slack',
          'actorKind': 'human',
          'workspaceName': 'Synthetic workspace',
        },
      ],
    };
    Widget source(String id) => MaterialApp(
      home: ExternalProfileSource(
        key: ValueKey(id),
        controller: w,
        messageId: id,
        channelId: 'c1',
        isMention: true,
        builder: (author) =>
            Text('${author['displayName']}|${author['isMention']}'),
        fallback: (failed) => Text(failed ? 'failed' : 'loading'),
      ),
    );
    Future<void> show(String id) => t.runAsync(() async {
      await t.pumpWidget(source(id));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await show('proj-1');
    await t.pump();
    expect(find.text('Ada Slack|true'), findsOneWidget);
    expect(
      api.calls.where((c) => c.path == '/channels/c1/members'),
      hasLength(1),
    );
    expect(
      api.calls.where((c) => c.path.startsWith('/messages/context')),
      isEmpty,
    );
    // A mention whose roster entry is gone closes the panel (Web), but only
    // while the address still names it.
    w.navigation.navigateProfile(
      w.location.withQuery({'profile': 'external-mention:c1:gone'}),
    );
    expect(w.location.profile?.id, 'gone');
    await show('gone');
    await t.pump();
    expect(w.location.profile, isNull);
    w.navigation.navigateProfile(
      w.location.withQuery({'profile': 'external-mention:c1:other'}),
    );
    await show('gone2');
    await t.pump();
    expect(w.location.profile?.id, 'other');
  });

  testWidgets('a mention with no roster entry still reads as a mention', (
    t,
  ) async {
    final (w, _) = (await t.runAsync(() => fixture('member')))!;
    addTearDown(w.dispose);
    final presentation = MessagePresentation(
      controller: w,
      message: RaftMessage({
        'id': 'm1',
        'channelId': 'c1',
        'senderType': 'user',
        'content': 'Hello @ada-slack',
        'mentions': [
          {'type': 'external', 'id': 'proj-9', 'name': 'ada-slack'},
        ],
      }),
      onExternalLink: (_) {},
    );
    expect(
      presentation.references.single.href,
      'raft-ref://mention/external/proj-9',
    );
    final appearance = presentation.appearance(
      'raft-ref://mention/external/proj-9',
    )!;
    expect(appearance.kind, RaftReferenceKind.mention);
    expect(appearance.hoverCard, isNotNull);
    await t.pumpWidget(
      MaterialApp(
        home: Builder(builder: (context) => appearance.hoverCard!(context)),
      ),
    );
    expect(find.text('ada-slack'), findsOneWidget);
  });

  test('mention rows name the source server of remote roster people', () {
    String? label(
      Map<String, dynamic> value, {
      bool roster = true,
      bool agent = false,
    }) => mentionServerLabel(
      value,
      currentServerId: 's1',
      roster: roster,
      agent: agent,
    );
    expect(
      label({'serverId': 's2', 'serverName': 'Acme', 'serverSlug': 'a'}),
      'Acme',
    );
    expect(label({'serverId': 's2', 'serverSlug': 'acme'}), 'acme');
    expect(label({'serverId': 's1', 'serverName': 'Home'}), isNull);
    expect(label({'serverName': 'No server id'}), isNull);
    // A directory agent carries its label as given; a directory human none.
    expect(label({'serverName': 'Dir'}, roster: false, agent: true), 'Dir');
    expect(label({'serverName': 'Dir'}, roster: false), isNull);
  });

  testWidgets('Slack rows carry the exchange icon and the source server', (
    t,
  ) async {
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(RaftFamily.elegant),
        home: Scaffold(
          body: Column(
            children: [
              const Spacer(),
              RaftComposer(
                suggestions: const [
                  RaftComposerSuggestion(
                    avatar: SizedBox.square(dimension: 20),
                    type: 'external',
                    id: 'proj-1',
                    name: 'ada-slack',
                    title: 'Ada Slack',
                    detail: 'Slack',
                  ),
                  RaftComposerSuggestion(
                    avatar: SizedBox.square(dimension: 20),
                    type: 'user',
                    id: 'u2',
                    name: 'remote-ann',
                    title: 'Ann',
                    serverLabel: 'Acme HQ',
                  ),
                ],
                onSend: (_) async => false,
              ),
            ],
          ),
        ),
      ),
    );
    await t.enterText(find.byType(TextField), '@');
    await t.pumpAndSettle();
    final glyphs = t
        .widgetList<RaftIcon>(find.byType(RaftIcon))
        .where((icon) => icon.glyph == RaftGlyph.arrowLeftRight);
    expect(glyphs, hasLength(1));
    expect(glyphs.single.size, 10);
    expect(find.text('Acme HQ'), findsOneWidget);
    expect(
      t
          .widget<RaftTooltip>(
            find.ancestor(
              of: find.text('Acme HQ'),
              matching: find.byType(RaftTooltip),
            ),
          )
          .message,
      'Source server: Acme HQ',
    );
    // The label is part of what a query matches.
    await t.enterText(find.byType(TextField), '@acme');
    await t.pumpAndSettle();
    expect(find.text('Ann'), findsOneWidget);
    expect(find.text('Ada Slack'), findsNothing);
  });

  for (final (width, capped) in [(1000.0, true), (520.0, false)]) {
    testWidgets(
      'description and source server split the row like Web at $width',
      (t) async {
        t.view.physicalSize = Size(width, 700);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(RaftFamily.elegant),
            home: Scaffold(
              body: Column(
                children: [
                  const Spacer(),
                  RaftComposer(
                    suggestions: [
                      RaftComposerSuggestion(
                        avatar: const SizedBox.square(dimension: 20),
                        type: 'user',
                        id: 'u2',
                        name: 'ann',
                        title: 'Ann',
                        detail: 'd' * 120,
                        serverLabel: 'S' * 60,
                      ),
                    ],
                    onSend: (_) async => false,
                  ),
                ],
              ),
            ),
          ),
        );
        await t.enterText(find.byType(TextField), '@');
        await t.pumpAndSettle();
        final server = t.getSize(
          find.byKey(const ValueKey('mention-source-server')),
        );
        final description = t.getSize(find.textContaining('dddd'));
        // flex-1 basis-0 on both: an even split, unless the server hits its
        // 10rem cap, which hands the rest to the description.
        if (capped) {
          expect(server.width, 160);
          expect(description.width, greaterThan(server.width));
          // The description took the rest: the capped server sits 6px from
          // the @handle instead of leaving its half of the row blank.
          expect(
            t.getTopLeft(find.text('@ann')).dx -
                t
                    .getTopRight(
                      find.byKey(const ValueKey('mention-source-server')),
                    )
                    .dx,
            closeTo(6, 0.5),
          );
        } else {
          expect(server.width, lessThan(160));
          expect(server.width, closeTo(description.width, 1));
        }
      },
    );
  }

  test('search source labels name a DM by its peer', () {
    final dms = [
      {'id': 'dm1', 'peerDisplayName': 'Bob Builder', 'peerName': 'bob'},
      {'id': 'dm2', 'peerName': 'carol'},
    ];
    String label(Map<String, dynamic> row) => searchSourceLabel(row, dms);
    expect(
      label({'channelType': 'dm', 'channelId': 'dm1', 'channelName': 'raw'}),
      '@Bob Builder',
    );
    expect(
      label({'channelType': 'dm', 'channelId': 'dm2', 'channelName': 'raw'}),
      '@carol',
    );
    expect(
      label({'channelType': 'dm', 'channelId': 'dm9', 'channelName': 'raw'}),
      '@raw',
    );
    expect(
      label({
        'channelType': 'thread',
        'parentChannelType': 'dm',
        'parentChannelId': 'dm1',
        'parentChannelName': 'raw',
      }),
      '@Bob Builder',
    );
    expect(label({'channelType': 'channel', 'channelName': 'ops'}), '#ops');
  });

  testWidgets('thread parent lookup asks for no surrounding window', (t) async {
    final (w, api) = (await t.runAsync(() => fixture('member')))!;
    addTearDown(w.dispose);
    w.messageDomain.ledger.switchServer('s1');
    api.routes['GET /messages/context/parent'] = (_) => {
      'messages': [row('parent', 'c1', 1)],
    };
    api.routes['GET /messages/channel/thread-1'] = (_) => {'messages': []};
    await t.runAsync(() async {
      await w.openThreadIdentity(
        parentChannelId: 'c1',
        parentMessageId: 'parent',
        initialThreadChannelId: 'thread-1',
        navigate: false,
      );
      for (var i = 0; i < 40 && w.messageDomain.threadParentLoading; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
    });
    final call = api.calls.firstWhere(
      (c) => c.path == '/messages/context/parent',
    );
    expect(call.queryParameters, {'channelId': 'c1', 'before': 0, 'after': 0});
  });
}
