import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/resource_filters.dart';
import 'package:raft_flutter/features/resource_view.dart';
import 'package:raft_flutter/features/search_continuation.dart';
import 'package:raft_ui/raft_ui.dart';

typedef _Request = ({Map<String, dynamic> query, Completer<dynamic> response});

class _Workspace extends WorkspaceController {
  _Workspace(super.client);
  final requests = <_Request>[];
  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) async {
    if (path == '/messages/search') {
      final response = Completer<dynamic>();
      requests.add((query: {...?query}, response: response));
      return response.future;
    }
    if (path.endsWith('/members')) return [];
    if (path == '/agents') return [];
    if (path.endsWith('/machines')) return [];
    return {};
  }
}

Map<String, dynamic> hit(String id, String text) => {
  'id': id,
  'channelId': 'c',
  'channelName': 'general',
  'channelType': 'channel',
  'senderId': 'u',
  'senderType': 'user',
  'senderName': 'Ada',
  'content': text,
  'createdAt': '2026-10-20T10:00:00.000Z',
};

void main() {
  late RaftClient client;
  late _Workspace w;
  setUp(() {
    client = RaftClient(
      origin: 'https://fixture.invalid',
      sessionStore: MemorySessionStore(),
    )..user = RaftRecord({'id': 'owner', 'name': 'Owner'});
    client.selectServer('s');
    w = _Workspace(client)
      ..server = RaftRecord({'id': 's', 'role': 'owner'})
      ..channels = [
        RaftChannel({'id': 'c', 'name': 'general', 'joined': true}),
      ];
  });
  tearDown(() async {
    w.dispose();
    await client.dispose();
  });

  Future<void> search(WidgetTester tester, Map<String, dynamic> first) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: ResourceView(
            controller: w,
            section: 'search',
            restoreSearchState: false,
            onMessage: (_, _) async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'topic');
    await tester.pump(const Duration(milliseconds: 210));
    expect(w.requests, hasLength(1));
    w.requests.single.response.complete(first);
    await tester.pumpAndSettle();
  }

  Future<void> answer(WidgetTester tester, Object? value) async {
    w.requests.last.response.complete(value);
    await tester.pumpAndSettle();
  }

  testWidgets('a search that read only part says so and continues from the '
      'server cursor', (tester) async {
    await search(tester, {
      'results': [],
      'hasMore': false,
      'incomplete': true,
      'nextCursor': 'cursor-1',
      'searchedThrough': '2026-09-01T10:00:00.000Z',
    });
    expect(find.text('No matches yet'), findsOneWidget);
    expect(find.textContaining('Searched messages back to'), findsOneWidget);
    expect(find.text('No results for "topic"'), findsNothing);
    expect(find.text('Continue searching'), findsOneWidget);
    expect(find.text('Load More'), findsNothing);

    await tester.tap(find.text('Continue searching'));
    await tester.pump();
    // The same cursor, no offset: an offset would restart from the newest.
    expect(w.requests, hasLength(2));
    expect(w.requests.last.query['cursor'], 'cursor-1');
    expect(w.requests.last.query.containsKey('offset'), isFalse);
    expect(w.requests.last.query['q'], 'topic');
    // In flight: the button reads Loading… and cannot be pressed again.
    expect(find.text('Loading…'), findsOneWidget);
    await tester.tap(find.text('Loading…'));
    await tester.pump();
    expect(w.requests, hasLength(2));

    await answer(tester, {
      'results': [hit('m1', 'the topic is here')],
      'hasMore': false,
    });
    expect(find.textContaining('the topic is here'), findsWidgets);
    expect(find.text('No matches yet'), findsNothing);
    expect(find.text('Continue searching'), findsNothing);
    expect(find.text('Load More'), findsNothing);
  });

  testWidgets('hits and an incomplete search: note and Continue searching '
      'below the results, until the walk is complete', (tester) async {
    await search(tester, {
      'results': [hit('m1', 'first topic')],
      'hasMore': false,
      'incomplete': true,
      'nextCursor': 'cursor-1',
    });
    expect(find.textContaining('first topic'), findsWidgets);
    expect(
      find.text('Only part of the messages has been searched so far.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Continue searching'));
    await tester.pump();
    expect(w.requests.last.query['cursor'], 'cursor-1');
    // Still short of a full page: another cursor, the list keeps growing.
    await answer(tester, {
      'results': [hit('m2', 'second topic')],
      'hasMore': false,
      'incomplete': true,
      'nextCursor': 'cursor-2',
      'searchedThrough': '2026-08-01T10:00:00.000Z',
    });
    expect(find.textContaining('first topic'), findsWidgets);
    expect(find.textContaining('second topic'), findsWidgets);
    expect(find.textContaining('Searched messages back to'), findsOneWidget);
    await tester.tap(find.text('Continue searching'));
    await tester.pump();
    expect(w.requests.last.query['cursor'], 'cursor-2');
    await answer(tester, {
      'results': [hit('m3', 'third topic')],
      'hasMore': false,
    });
    expect(find.textContaining('third topic'), findsWidgets);
    expect(find.text('Continue searching'), findsNothing);
    expect(find.byKey(const Key('search-incomplete-note')), findsNothing);
  });

  testWidgets('a complete page pages by cursor too; without one it pages by '
      'offset', (tester) async {
    await search(tester, {
      'results': [hit('m1', 'first topic'), hit('m2', 'another topic')],
      'hasMore': true,
      'nextCursor': 'walk-1',
    });
    // Not incomplete: the plain label, no note.
    expect(find.text('Load More'), findsOneWidget);
    expect(find.text('Continue searching'), findsNothing);
    expect(find.byKey(const Key('search-incomplete-note')), findsNothing);
    await tester.tap(find.text('Load More'));
    await tester.pump();
    expect(w.requests.last.query['cursor'], 'walk-1');
    expect(w.requests.last.query.containsKey('offset'), isFalse);
    await answer(tester, {
      'results': [hit('m3', 'third topic')],
      'hasMore': true,
    });
    // The server gave no cursor this time: back to an offset past what shows.
    await tester.tap(find.text('Load More'));
    await tester.pump();
    expect(w.requests.last.query.containsKey('cursor'), isFalse);
    expect(w.requests.last.query['offset'], 3);
    await answer(tester, {'results': [], 'hasMore': false});
    expect(find.text('Load More'), findsNothing);
  });

  testWidgets('a failed continuation keeps the results, warns and retries '
      'with the same cursor', (tester) async {
    await search(tester, {
      'results': [hit('m1', 'first topic')],
      'hasMore': false,
      'incomplete': true,
      'nextCursor': 'cursor-1',
    });
    await tester.tap(find.text('Continue searching'));
    await tester.pump();
    w.requests.last.response.completeError(const RaftApiException('boom'));
    await tester.pumpAndSettle();
    expect(find.text('Could not load more results.'), findsOneWidget);
    expect(find.textContaining('first topic'), findsWidgets);
    expect(find.byKey(const Key('search-incomplete-note')), findsNothing);
    expect(find.text('Retry'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(w.requests.last.query['cursor'], 'cursor-1');
    await answer(tester, {
      'results': [hit('m2', 'second topic')],
      'hasMore': false,
    });
    expect(find.text('Could not load more results.'), findsNothing);
    expect(find.textContaining('second topic'), findsWidgets);
    expect(find.text('Continue searching'), findsNothing);
  });

  group('request state', () {
    test('a view keeps its continuation while the relative window moves', () {
      var range = '7d';
      final continuations = SearchContinuations(() => range);
      String view(String clock) => ResourceFilters.viewKey('/messages/search', {
        'q': 'x',
        'limit': 20,
        'offset': 0,
        'sort': 'recent',
        'after': clock,
        'before': clock,
      });
      expect(
        continuations.accept(view('t1'), {
          'nextCursor': 'k',
          'incomplete': true,
          'searchedThrough': '2026-09-01T10:00:00.000Z',
        }),
        isTrue,
      );
      // The clock moved: the same view.
      expect(continuations.of(view('t2')).cursor, 'k');
      expect(
        continuations.of(view('t2')).searchedThrough,
        DateTime.utc(2026, 9, 1, 10),
      );
      // Another range is another view.
      range = '30d';
      expect(continuations.of(view('t2')).cursor, isNull);
      range = '7d';
      // A complete answer without a cursor ends the continuation.
      expect(continuations.accept(view('t3'), {'results': []}), isFalse);
      expect(continuations.of(view('t3')).cursor, isNull);
    });

    test('only an appended page of a view with a cursor leaves the offset', () {
      final filters = ResourceFilters()..searchSort = 'recent';
      Map<String, dynamic> first() => filters.search('topic')!;
      expect(first()['offset'], 0);
      expect(first().containsKey('cursor'), isFalse);
      final view = ResourceFilters.viewKey('/messages/search', first());
      filters.morePages('search', view, {
        'results': [],
        'hasMore': false,
        'incomplete': true,
        'nextCursor': 'k1',
      });
      // The next page of this view; the first page never carries a cursor.
      final next = filters.search('topic', offset: 20, append: true)!;
      expect(next['cursor'], 'k1');
      expect(next.containsKey('offset'), isFalse);
      expect(first().containsKey('cursor'), isFalse);
      // Another query has no continuation: offset paging as before.
      final other = filters.search('other', offset: 20, append: true)!;
      expect(other['offset'], 20);
      expect(other.containsKey('cursor'), isFalse);
      // Other sections never read the continuation.
      expect(filters.morePages('saved', view, {'hasMore': true}), isTrue);
      expect(filters.morePages('saved', view, {'hasMore': false}), isFalse);
    });
  });
}
