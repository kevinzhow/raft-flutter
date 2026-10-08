import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/source_feedback_store.dart';

const first = '11111111-1111-4111-8111-111111111111';
const second = '22222222-2222-4222-8222-222222222222';
Map<String, dynamic> ticket(
  String id, {
  String status = 'open',
  bool unread = true,
}) => {
  'id': id,
  'kind': 'feedback',
  'status': status,
  'message': 'Fixture $id',
  'created_at': 1000,
  'updated_at': 2000,
  'unread': unread,
  'unread_count': unread ? 2 : 0,
  'attachment_count': 0,
  'comment_count': 2,
  'closure_reason': null,
};
Map<String, dynamic> page(
  List<Map<String, dynamic>> tickets, {
  String? cursor,
  int unread = 2,
}) => {'tickets': tickets, 'next_cursor': cursor, 'unread_total': unread};
Map<String, dynamic> reply(String id, int time, {String body = 'reply'}) => {
  'id': id,
  'author_type': 'staff',
  'body': body,
  'created_at': time,
};
Map<String, dynamic> detail(
  String id, {
  List<Map<String, dynamic>> comments = const [],
  String? cursor,
  int unread = 0,
}) => {
  'ticket': ticket(id, unread: false),
  'comments': comments,
  'attachments': [],
  'next_comment_cursor': cursor,
  'unread_total': unread,
};

void main() {
  test('source first-line title and minimum unread badge preserve full detail body', () {
    final raw = ticket(first)..['message'] = 'Title 中文\nPrivate body 日本語';
    raw['unread_count'] = 0;
    final value = SourceFeedbackTicket.parse(raw);
    expect(value.title, 'Title 中文');
    expect(value.message, 'Title 中文\nPrivate body 日本語');
    expect(value.unread, isTrue);
    expect(value.badgeCount, 1);
    expect(value.badgeLabel, '1');
    raw['unread_count'] = 120;
    final large = SourceFeedbackTicket.parse(raw);
    expect(large.badgeCount, 120);
    expect(large.badgeLabel, '99+');
  });
  test(
    'detail read-through GET invalidates an older list count and unread flags',
    () async {
      var scope = 'origin|alice|server|owner|generation1|window1';
      final stale = Completer<dynamic>();
      final counts = <int>[], calls = <(String, Map<String, dynamic>?)>[];
      var lists = 0;
      final store = SourceFeedbackStore(
        authority: () => scope,
        onUnreadChanged: counts.add,
        get: (path, {query}) async {
          calls.add((path, query));
          if (path == '/product-feedback/tickets') {
            return ++lists == 1 ? page([ticket(first)]) : stale.future;
          }
          return detail(first);
        },
      );
      await store.loadList();
      final old = store.loadList();
      await store.openTicket(first);
      expect(store.unreadTotal, 0);
      expect(store.tickets.single.unread, isFalse);
      stale.complete(page([ticket(first)], unread: 9));
      await old;
      expect(store.unreadTotal, 0);
      expect(store.tickets.single.unreadCount, 0);
      expect(counts, [2, 0]);
      expect(calls.last.$1, '/product-feedback/tickets/$first');
      expect(calls.last.$2, {'comment_limit': 100});
      scope = 'logged-out';
      store.dispose();
    },
  );

  for (final change in [
    'origin',
    'principal',
    'server',
    'role',
    'generation',
    'window',
  ]) {
    test(
      'immediate $change authority reset clears private state and rejects pending GET',
      () async {
        String? scope = 'initial';
        final pending = Completer<dynamic>(), counts = <int>[];
        var calls = 0;
        final store = SourceFeedbackStore(
          authority: () => scope,
          onUnreadChanged: counts.add,
          get: (_, {query}) async =>
              ++calls == 1 ? page([ticket(first)]) : pending.future,
        );
        await store.loadList();
        final loading = store.openTicket(first);
        scope = 'changed-$change';
        store.syncAuthority();
        expect(store.tickets, isEmpty);
        expect(store.selectedId, isNull);
        expect(store.unreadTotal, isNull);
        pending.complete(detail(first, unread: 8));
        await loading;
        expect(store.detail, isNull);
        expect(store.comments, isEmpty);
        expect(counts, [2]);
        store.dispose();
      },
    );
  }

  test(
    'cursor paging deduplicates IDs; comments order by createdAt then ID',
    () async {
      final calls = <(String, Map<String, dynamic>?)>[];
      var lists = 0, details = 0;
      final store = SourceFeedbackStore(
        authority: () => 'current',
        get: (path, {query}) async {
          calls.add((path, query));
          if (path == '/product-feedback/tickets') {
            return ++lists == 1
                ? page([ticket(first)], cursor: 'list-next')
                : page([ticket(first), ticket(second, status: 'closed')]);
          }
          return ++details == 1
              ? detail(
                  first,
                  comments: [reply('b', 3), reply('a', 2)],
                  cursor: 'comment-next',
                )
              : detail(
                  first,
                  comments: [
                    reply('a', 2, body: 'updated'),
                    reply('c', 3),
                  ],
                );
        },
      );
      await store.loadList();
      await store.loadList(more: true);
      expect(store.tickets.map((t) => t.id), [first, second]);
      expect(calls[1].$1, '/product-feedback/tickets');
      expect(calls[1].$2, {'limit': 20, 'cursor': 'list-next'});
      store.setFilter(SourceFeedbackFilter.open);
      expect(store.visibleTickets.map((t) => t.id), [first]);
      store.setFilter(SourceFeedbackFilter.resolved);
      expect(store.visibleTickets.map((t) => t.id), [second]);
      await store.openTicket(first);
      await store.loadDetail(more: true);
      expect(store.comments.map((c) => c.id), ['a', 'b', 'c']);
      expect(store.comments.first.body, 'updated');
      expect(calls.last.$1, '/product-feedback/tickets/$first');
      expect(calls.last.$2, {
        'comment_limit': 100,
        'comment_cursor': 'comment-next',
      });
      expect(store.nextCommentCursor, isNull);
      store.dispose();
    },
  );

  test('error retry preserves the exact failed list cursor and never reports empty success', () async {
    var call = 0;
    final queries = <Map<String, dynamic>?>[];
    final store = SourceFeedbackStore(
      authority: () => 'current',
      get: (_, {query}) async {
        queries.add(query);
        call++;
        if (call == 1) return page([ticket(first)], cursor: 'next');
        if (call == 2) {
          throw const SourceFeedbackFailure(SourceFeedbackError.unavailable);
        }
        return page([ticket(second)]);
      },
    );
    await store.loadList();
    await store.loadList(more: true);
    expect(store.listError, SourceFeedbackError.unavailable);
    expect(store.tickets.single.id, first);
    await store.loadList(retry: true);
    expect(queries[2], {'limit': 20, 'cursor': 'next'});
    expect(store.tickets.length, 2);
    expect(store.listError, isNull);
    store.dispose();
  });

  test('detail back rejects late response', () async {
    final pending = Completer<dynamic>(), counts = <int>[];
    final store = SourceFeedbackStore(
      authority: () => 'current',
      onUnreadChanged: counts.add,
      get: (_, {query}) => pending.future,
    );
    final old = store.openTicket(first);
    store.back();
    pending.complete(detail(first));
    await old;
    expect(store.selectedId, isNull);
    expect(counts, isEmpty);
    store.dispose();
    expect(store.tickets, isEmpty);
    expect(store.comments, isEmpty);
  });

  test('replacement ticket selection rejects the older detail and its unread callback', () async {
    final oldResult = Completer<dynamic>(), newResult = Completer<dynamic>();
    final counts = <int>[];
    final store = SourceFeedbackStore(
      authority: () => 'current',
      onUnreadChanged: counts.add,
      get: (path, {query}) =>
          path.endsWith(first) ? oldResult.future : newResult.future,
    );
    final old = store.openTicket(first), current = store.openTicket(second);
    newResult.complete(detail(second));
    await current;
    oldResult.complete(detail(first, unread: 9));
    await old;
    expect(store.detail?.id, second);
    expect(counts, [0]);
    store.dispose();
  });

  test(
    'dispose clears private projection and rejects in-flight callbacks',
    () async {
      final pending = Completer<dynamic>(), counts = <int>[];
      final store = SourceFeedbackStore(
        authority: () => 'current',
        onUnreadChanged: counts.add,
        get: (_, {query}) => pending.future,
      );
      final loading = store.openTicket(first);
      store.dispose();
      pending.complete(detail(first));
      await loading;
      expect(store.detail, isNull);
      expect(counts, isEmpty);
    },
  );

  test('unauthorized clears private projection and prevents pending detail from reviving it', () async {
    final pending = Completer<dynamic>();
    var lists = 0;
    final store = SourceFeedbackStore(
      authority: () => 'current',
      get: (path, {query}) async {
        if (path != '/product-feedback/tickets') return pending.future;
        if (++lists == 1) return page([ticket(first)]);
        throw const SourceFeedbackFailure(SourceFeedbackError.unauthorized);
      },
    );
    await store.loadList();
    final old = store.openTicket(first);
    await store.loadList();
    expect(store.tickets, isEmpty);
    expect(store.listError, SourceFeedbackError.unauthorized);
    pending.complete(detail(first));
    await old;
    expect(store.detail, isNull);
    store.dispose();
  });
}
