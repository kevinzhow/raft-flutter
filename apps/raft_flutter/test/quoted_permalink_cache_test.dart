import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/raft_permalink.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/quoted_message_preview.dart';
import 'package:raft_flutter/features/quoted_permalink_cache.dart';
import 'package:raft_ui/raft_ui.dart';

import 'message_presentation_test.dart' show MessageAdapter, fixture;

/// A quoted message link that resolved once shows its card in the first frame
/// of every later mount (scroll, channel switch) and refreshes behind it.
void main() {
  const link = RaftPermalink(
    routeKind: 'channel',
    serverSlug: 'acme',
    channelId: 'c1',
    messageId: 'target',
  );
  const path = '/messages/context/target';
  Map<String, dynamic> context(String content) => {
    'messages': [
      {
        'id': 'target',
        'channelId': 'c1',
        'senderId': 'bob',
        'senderType': 'user',
        'senderName': 'Bob',
        'content': content,
        'createdAt': '2026-06-22T02:10:00.000Z',
      },
    ],
  };
  int requests(MessageAdapter a) => a.calls.where((c) => c.path == path).length;
  final skeleton = find.byKey(const Key('quoted-message-skeleton'));
  final card = find.byKey(const Key('quoted-message-card'));
  Finder text(String s) => find.textContaining(s, findRichText: true);

  Future<(WorkspaceController, MessageAdapter)> setUp(WidgetTester t) async {
    final (w, a) = (await t.runAsync(() => fixture('owner')))!;
    addTearDown(w.dispose);
    w.server = RaftRecord({'id': 's1', 'role': 'owner', 'slug': 'acme'});
    return (w, a);
  }

  Future<void> mount(WidgetTester t, WorkspaceController w) async {
    await t.pumpWidget(const SizedBox());
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: QuotedMessagePermalinkPreview(
            controller: w,
            permalink: link,
            avatar: (_) => const SizedBox.square(dimension: 20),
            subtitle: (_) => null,
            formatTimestamp: (_) => 'Jun 22, 02:10',
            onOpen: (_) {},
            onUnavailable: () {},
          ),
        ),
      ),
    );
  }

  testWidgets('a second mount shows the card in its first frame', (t) async {
    final (w, a) = await setUp(t);
    a.routes['GET $path'] = (_) => context('Gates are green');
    await mount(t, w);
    expect(skeleton, findsOneWidget);
    await t.pumpAndSettle();
    expect(text('Gates are green'), findsOneWidget);
    expect(requests(a), 1);

    final hang = Completer<dynamic>();
    a.routes['GET $path'] = (_) => hang.future;
    await mount(t, w);
    expect(skeleton, findsNothing);
    expect(card, findsOneWidget);
    expect(text('Gates are green'), findsOneWidget);
    await t.pumpAndSettle();
    expect(requests(a), 1, reason: 'fresh for a minute: no request');
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('an edited target updates after the background refresh', (
    t,
  ) async {
    final (w, a) = await setUp(t);
    final cache = QuotedPermalinkCache.of(w);
    var now = DateTime.utc(2026, 11, 17, 9);
    cache.now = () => now;
    a.routes['GET $path'] = (_) => context('First draft');
    await mount(t, w);
    await t.pumpAndSettle();
    expect(text('First draft'), findsOneWidget);

    now = now.add(QuotedPermalinkCache.refreshAfter);
    a.routes['GET $path'] = (_) => context('Edited text');
    await mount(t, w);
    expect(text('First draft'), findsOneWidget);
    expect(skeleton, findsNothing);
    await t.runAsync(() => Future<void>.delayed(Duration.zero));
    await t.pumpAndSettle();
    expect(text('Edited text'), findsOneWidget);
    expect(requests(a), 2);

    a.routes['GET $path'] = (_) => {'messages': []};
    now = now.add(QuotedPermalinkCache.refreshAfter);
    await mount(t, w);
    await t.pumpAndSettle();
    expect(card, findsNothing, reason: 'deleted target drops the card');
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('a server switch empties the cache', (t) async {
    final (w, a) = await setUp(t);
    a.routes['GET $path'] = (_) => context('Gates are green');
    await mount(t, w);
    await t.pumpAndSettle();
    w.client.selectServer('s2');
    a.routes['GET $path'] = (_) => context('Another server');
    await mount(t, w);
    expect(skeleton, findsOneWidget);
    expect(text('Gates are green'), findsNothing);
    await t.pumpAndSettle();
    expect(text('Another server'), findsOneWidget);
    expect(requests(a), 2);
    await t.pumpWidget(const SizedBox());
  });
}
