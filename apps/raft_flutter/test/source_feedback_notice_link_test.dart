import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/source_feedback_store.dart';
import 'package:raft_flutter/features/feedback_ticket_link.dart';
import 'package:raft_flutter/features/source_feedback_view.dart';
import 'package:raft_ui/raft_ui.dart';

import 'source_feedback_store_test.dart' as fixture;

Map<String, dynamic> _degraded({Object? seconds = 5}) => {
  'tickets': [],
  'next_cursor': null,
  'unread_total': null,
  'degraded': true,
  'retry_after_seconds': ?seconds,
};

Widget _host(Widget child) => MaterialApp(
  theme: raftTheme(),
  builder: (context, child) => RaftToastHost(child: child!),
  home: Scaffold(body: child),
);

void main() {
  testWidgets(
    'degraded first page is retried (5s, then doubling), never shown as empty or an error',
    (t) async {
      final queries = <Map<String, dynamic>?>[];
      final answers = <dynamic>[
        _degraded(),
        _degraded(),
        fixture.page([fixture.ticket(fixture.first)]),
      ];
      final store = SourceFeedbackStore(
        authority: () => 'current',
        get: (_, {query}) async {
          queries.add(query);
          return answers.removeAt(0);
        },
      );
      addTearDown(store.dispose);
      unawaited(store.loadList());
      await t.pump();
      expect(queries.single, {'limit': 20, 'degraded_ok': 1});
      expect(store.listDegraded, isTrue);
      expect(store.listLoading, isTrue);
      expect(store.listError, isNull);
      expect(store.tickets, isEmpty);
      expect(store.unreadTotal, isNull);

      await t.pump(const Duration(seconds: 4, milliseconds: 900));
      expect(queries, hasLength(1));
      await t.pump(const Duration(milliseconds: 200));
      expect(queries, hasLength(2));
      expect(store.listDegraded, isTrue);
      // The second wait is twice the first.
      await t.pump(const Duration(seconds: 9));
      expect(queries, hasLength(2));
      await t.pump(const Duration(seconds: 2));
      expect(queries, hasLength(3));
      expect(store.listDegraded, isFalse);
      expect(store.listLoading, isFalse);
      expect(store.tickets.single.id, fixture.first);
      expect(store.unreadTotal, 2);
    },
  );

  testWidgets('a later page never asks for the degraded answer', (t) async {
    final queries = <Map<String, dynamic>?>[];
    final store = SourceFeedbackStore(
      authority: () => 'current',
      get: (_, {query}) async {
        queries.add(query);
        return fixture.page([
          fixture.ticket(fixture.first),
        ], cursor: queries.length == 1 ? 'next' : null);
      },
    );
    addTearDown(store.dispose);
    await store.loadList();
    await store.loadList(more: true);
    expect(queries[1], {'limit': 20, 'cursor': 'next'});
  });

  testWidgets('another account stops the retry: nothing is applied to it', (
    t,
  ) async {
    var scope = 'a', calls = 0;
    final store = SourceFeedbackStore(
      authority: () => scope,
      get: (_, {query}) async {
        calls++;
        return _degraded(seconds: 1);
      },
    );
    addTearDown(store.dispose);
    unawaited(store.loadList());
    await t.pump();
    expect(store.listDegraded, isTrue);
    scope = 'b';
    store.syncAuthority();
    expect(store.listDegraded, isFalse);
    await t.pump(const Duration(seconds: 3));
    expect(calls, 1);
    expect(store.listDegraded, isFalse);
  });

  testWidgets(
    'inbox: the degraded warning outranks the agent hint and clears with the real page',
    (t) async {
      final answers = <dynamic>[
        _degraded(),
        fixture.page([fixture.ticket(fixture.first)]),
      ];
      final store = SourceFeedbackStore(
        authority: () => 'current',
        get: (_, {query}) async => answers.removeAt(0),
      );
      addTearDown(store.dispose);
      await t.pumpWidget(_host(SourceFeedbackProjectionView(store: store)));
      unawaited(store.loadList());
      await t.pump();
      final degraded = find.byKey(
        const ValueKey('settings-feedback-list-degraded'),
      );
      final hint = find.byKey(const ValueKey('settings-feedback-agent-hint'));
      expect(degraded, findsOneWidget);
      expect(hint, findsNothing);
      expect(find.text('No feedback yet'), findsNothing);
      await t.pump(const Duration(seconds: 5));
      await t.pump();
      expect(degraded, findsNothing);
      expect(hint, findsOneWidget);
      expect(
        find.byKey(const ValueKey('feedback-ticket-${fixture.first}')),
        findsOneWidget,
      );
      await t.pumpWidget(const SizedBox());
    },
  );

  group('Copy link', () {
    late List<String> copied;
    late bool clipboardThrows;

    setUp(() {
      copied = [];
      clipboardThrows = false;
    });

    Future<void> open(WidgetTester t, {String? Function(String)? link}) async {
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            if (clipboardThrows) throw PlatformException(code: 'denied');
            copied.add((call.arguments as Map)['text'] as String);
          }
          return null;
        },
      );
      addTearDown(
        () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      var requests = 0;
      final store = SourceFeedbackStore(
        authority: () => 'current',
        get: (path, {query}) async {
          requests++;
          return path == '/product-feedback/tickets'
              ? fixture.page([fixture.ticket(fixture.first)])
              : fixture.detail(fixture.first);
        },
      );
      addTearDown(store.dispose);
      await store.loadList();
      await t.pumpWidget(
        _host(SourceFeedbackProjectionView(store: store, ticketLink: link)),
      );
      await t.tap(
        find.byKey(const ValueKey('feedback-ticket-${fixture.first}')),
      );
      await t.pumpAndSettle();
      requests = 0;
      addTearDown(
        () => expect(requests, 0, reason: 'copying makes no request'),
      );
    }

    final button = find.byKey(
      const ValueKey('settings-feedback-ticket-copy-link'),
    );

    testWidgets('copies the ticket link at once and says so', (t) async {
      await open(t, link: (id) => 'https://app.example/s/acme/t/$id');
      await t.tap(button);
      await t.pump();
      expect(copied, ['https://app.example/s/acme/t/${fixture.first}']);
      expect(find.text('Link copied.'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 10));
    });

    testWidgets('a refused clipboard says so', (t) async {
      clipboardThrows = true;
      await open(t, link: (id) => 'https://app.example/s/acme/t/$id');
      await t.tap(button);
      await t.pump();
      expect(copied, isEmpty);
      expect(find.text("Couldn't copy the link"), findsOneWidget);
      expect(find.text('Link copied.'), findsNothing);
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 10));
    });

    testWidgets('no server slug, no Copy link', (t) async {
      await open(t, link: (_) => null);
      expect(button, findsNothing);
      await t.pumpWidget(const SizedBox());
    });
  });

  test('ticket link: web origin, settings path, encoded id, slug required', () {
    final origin = Uri.parse('https://app.example.com/anything?x=1');
    expect(
      feedbackTicketUrl(origin: origin, slug: 'acme', ticketId: 'a b'),
      'https://app.example.com/s/acme/settings/feedback/ticket/a%20b',
    );
    expect(feedbackTicketUrl(origin: origin, slug: '', ticketId: 'x'), isNull);
    expect(
      feedbackTicketUrl(origin: origin, slug: null, ticketId: 'x'),
      isNull,
    );
  });
}
