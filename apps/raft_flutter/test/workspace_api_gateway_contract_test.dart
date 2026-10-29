import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';

typedef _Read = Future<dynamic> Function(String, {Map<String, dynamic>? query});
typedef _Command = Future<dynamic> Function(String, String, dynamic);

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://example.invalid',
        sessionStore: MemorySessionStore(),
      );

  final reads = <(String, Map<String, dynamic>?)>[];
  final commands = <(String, String, dynamic)>[];
  _Read? read;
  _Command? write;
  int closed = 0;

  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) {
    reads.add((path, query));
    return read?.call(path, query: query) ?? Future<dynamic>.value({});
  }

  @override
  Future<dynamic> request(
    String method,
    String path, {
    dynamic data,
    Map<String, dynamic>? query,
    bool authorized = true,
    bool retried = false,
    UploadCancellation? cancellation,
    void Function(int, int)? onSendProgress,
    Map<String, dynamic>? headers,
    bool acceptServerExit = false,
    Duration? receiveTimeout,
    bool workspaceScoped = true,
  }) {
    commands.add((method, path, data));
    return write?.call(method, path, data) ?? Future<dynamic>.value({});
  }

  @override
  Future<void> dispose() async {
    closed++;
    await super.dispose();
  }
}

class _Workspace extends WorkspaceController {
  _Workspace(super.client, {_Workspace? source})
    : super(presentationSource: source, ownsClient: false);

  _Read? read;
  _Command? write;
  final reads = <String>[];
  int unreadRefreshes = 0;
  Future<void> Function()? refresh;
  bool closed = false;

  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) {
    reads.add(path);
    return read?.call(path, query: query) ?? super.query(path, query: query);
  }

  @override
  Future<dynamic> command(String method, String path, {dynamic data}) =>
      write?.call(method, path, data) ??
      super.command(method, path, data: data);

  @override
  Future<void> refreshUnread() async {
    unreadRefreshes++;
    await refresh?.call();
  }

  @override
  void dispose() {
    closed = true;
    super.dispose();
  }
}

class _Fixture {
  _Fixture() {
    client.user = RaftRecord({'id': 'alice'});
    client.selectServer('s1');
    root = _Workspace(client);
    pages.add(root);
    addTearDown(() async {
      for (final gate in gates) {
        if (!gate.isCompleted) gate.complete({});
      }
      for (final page in pages.reversed) {
        if (!page.closed) page.dispose();
      }
      await client.dispose();
    });
  }

  final client = _Client();
  late final _Workspace root;
  final pages = <_Workspace>[];
  final gates = <Completer<dynamic>>[];

  Completer<dynamic> hold() {
    final gate = Completer<dynamic>();
    gates.add(gate);
    return gate;
  }

  _Workspace borrow() {
    final page = _Workspace(client, source: root);
    pages.add(page);
    return page;
  }

  void changeIdentity(String kind) {
    switch (kind) {
      case 'generation':
        client.selectServer('temporary');
        client.selectServer('s1');
      case 'principal':
        client.user = RaftRecord({'id': 'bob'});
      case 'server':
        client.serverId = 's2';
    }
  }
}

void main() {
  test(
    'ordinary queries stay independent and return the original response',
    () async {
      final f = _Fixture(), gate = f.hold();
      f.client.read = (_, {query}) => gate.future;
      final first = f.root.query('/items'), second = f.root.query('/items');
      expect(f.client.reads, hasLength(2));
      final response = {
        'items': [1],
      };
      gate.complete(response);
      expect(identical(await first, response), isTrue);
      expect(identical(await second, response), isTrue);
    },
  );

  test(
    'shared reads sort parameters, copy results and forget settled values',
    () async {
      final f = _Fixture(), gate = f.hold();
      f.client.read = (_, {query}) => gate.future;
      final first = f.root.sharedQuery('/items', query: {'b': 2, 'a': 1});
      final second = f.root.sharedQuery('/items', query: {'a': 1, 'b': 2});
      expect(f.client.reads, hasLength(1));
      final original = {
        'rows': [
          {'value': 1},
        ],
      };
      gate.complete(original);
      final a = await first, b = await second;
      a['rows'][0]['value'] = 99;
      expect(b, original);
      expect(original['rows']![0]['value'], 1);
      expect(identical(a, b), isFalse);
      await f.root.sharedQuery('/items', query: {'a': 1, 'b': 2});
      expect(f.client.reads, hasLength(2));
    },
  );

  test(
    'a failed shared read reaches both callers and a retry starts fresh',
    () async {
      final f = _Fixture(), gate = f.hold();
      f.client.read = (_, {query}) => gate.future;
      final first = f.root.sharedQuery('/items');
      final second = f.root.sharedQuery('/items');
      final failure = StateError('Fixture read failed');
      final errors = [
        expectLater(first, throwsA(same(failure))),
        expectLater(second, throwsA(same(failure))),
      ];
      gate.completeError(failure);
      await Future.wait(errors);
      f.client.read = (_, {query}) async => {'retried': true};
      expect(await f.root.sharedQuery('/items'), {'retried': true});
      expect(f.client.reads, hasLength(2));
    },
  );

  test('a synchronous query override failure leaves no pending read', () async {
    final f = _Fixture();
    final failure = StateError('Fixture synchronous failure');
    f.root.read = (_, {query}) => throw failure;
    expect(() => f.root.sharedQuery('/items'), throwsA(same(failure)));
    f.root.read = (_, {query}) async => ['retry'];
    expect(await f.root.sharedQuery('/items'), ['retry']);
    expect(f.root.reads, ['/items', '/items']);
    expect(f.client.reads, isEmpty);
  });

  test(
    'source and borrowed query overrides keep independent pending reads',
    () async {
      final f = _Fixture(), source = f.hold(), borrowed = f.hold();
      final page = f.borrow();
      f.root.read = (_, {query}) => source.future;
      page.read = (_, {query}) => borrowed.future;
      final rootRead = f.root.sharedQuery('/items');
      final pageRead = page.sharedQuery('/items');
      final pageReadAgain = page.sharedQuery('/items');
      expect(f.root.reads, ['/items']);
      expect(page.reads, ['/items']);
      expect(f.client.reads, isEmpty);
      source.complete({'owner': 'source'});
      borrowed.complete({'owner': 'page'});
      expect(await rootRead, {'owner': 'source'});
      expect(await pageRead, {'owner': 'page'});
      expect(await pageReadAgain, {'owner': 'page'});
    },
  );

  test(
    'inherited borrowed queries join source reads and survive page disposal',
    () async {
      final f = _Fixture(), gate = f.hold();
      final page = f.borrow(), sibling = f.borrow();
      f.client.read = (_, {query}) => gate.future;
      final fromPage = page.query('/items');
      final fromSibling = sibling.sharedQuery('/items');
      final fromRoot = f.root.sharedQuery('/items');
      expect(f.client.reads, hasLength(1));
      page.dispose();
      expect(f.client.closed, 0);
      gate.complete({
        'value': [1],
      });
      final a = await fromPage, b = await fromSibling, c = await fromRoot;
      a['value'].add(2);
      expect(b, {
        'value': [1],
      });
      expect(c, {
        'value': [1],
      });
      expect(f.client.closed, 0);
    },
  );

  for (final identity in ['generation', 'principal', 'server']) {
    test(
      'pending shared reads are separated after $identity changes',
      () async {
        final f = _Fixture(), old = f.hold(), next = f.hold();
        f.client.read = (_, {query}) =>
            f.client.reads.length == 1 ? old.future : next.future;
        final first = f.root.sharedQuery('/items');
        f.changeIdentity(identity);
        final second = f.root.sharedQuery('/items');
        expect(f.client.reads, hasLength(2));
        old.complete({'request': 'old'});
        next.complete({'request': 'new'});
        expect(await first, {'request': 'old'});
        expect(await second, {'request': 'new'});
      },
    );

    test(
      'a saved command from the old $identity cannot revise the new scope',
      () async {
        final f = _Fixture(), gate = f.hold();
        f.client.write = (_, _, _) => gate.future;
        var notifications = 0;
        f.root.addListener(() => notifications++);
        final command = f.root.command(
          'POST',
          '/channels/saved',
          data: {'id': 'm'},
        );
        expect(f.root.savedRevision, 0);
        f.changeIdentity(identity);
        gate.complete({'saved': true});
        expect(await command, {'saved': true});
        expect(f.root.savedRevision, 0);
        expect(notifications, 0);
      },
    );
  }

  test(
    'accepted saved add/remove commands notify after the response',
    () async {
      final f = _Fixture(), gate = f.hold();
      f.client.write = (_, _, _) => gate.future;
      var notifications = 0;
      f.root.addListener(() => notifications++);
      final data = {'messageId': 'm'};
      final pending = f.root.command('POST', '/channels/saved', data: data);
      expect(f.root.savedRevision, 0);
      expect(notifications, 0);
      final response = {'saved': true};
      gate.complete(response);
      expect(identical(await pending, response), isTrue);
      expect(f.root.savedRevision, 1);
      expect(notifications, 1);
      expect(identical(f.client.commands.single.$3, data), isTrue);
      await f.root.command('DELETE', '/channels/saved/m');
      expect(f.root.savedRevision, 2);
      expect(notifications, 2);
      expect(f.root.unreadRefreshes, 0);
    },
  );

  test(
    'read-affecting commands wait for the existing unread refresh override',
    () async {
      final f = _Fixture(), response = f.hold(), refresh = f.hold();
      final started = Completer<void>();
      f.client.write = (_, _, _) => response.future;
      f.root.refresh = () async {
        started.complete();
        await refresh.future;
      };
      var completed = false;
      final command = f.root
          .command('POST', '/channels/c/read?source=fixture')
          .then((value) {
            completed = true;
            return value;
          });
      expect(f.root.unreadRefreshes, 0);
      response.complete({'ok': true});
      await started.future;
      expect(f.root.unreadRefreshes, 1);
      expect(completed, isFalse);
      refresh.complete(null);
      expect(await command, {'ok': true});
      expect(completed, isTrue);
    },
  );

  test(
    'borrowed commands still dispatch through the source command override',
    () async {
      final f = _Fixture(), gate = f.hold();
      final page = f.borrow();
      final seen = <(String, String, dynamic)>[];
      f.root.write = (method, path, data) {
        seen.add((method, path, data));
        return gate.future;
      };
      final data = {'messageId': 'm'};
      final pending = page.command('POST', '/channels/saved', data: data);
      expect(seen.single.$1, 'POST');
      expect(seen.single.$2, '/channels/saved');
      expect(identical(seen.single.$3, data), isTrue);
      expect(f.client.commands, isEmpty);
      gate.complete('intercepted');
      expect(await pending, 'intercepted');
      expect(page.savedRevision, 0);
      expect(f.root.savedRevision, 0);
    },
  );

  test('failed commands do not revise saved rows or refresh unread', () async {
    final f = _Fixture();
    final failure = StateError('Fixture command failed');
    f.client.write = (_, _, _) => Future<dynamic>.error(failure);
    var notifications = 0;
    f.root.addListener(() => notifications++);
    for (final path in ['/channels/saved', '/channels/c/read']) {
      await expectLater(f.root.command('POST', path), throwsA(same(failure)));
    }
    expect(f.root.savedRevision, 0);
    expect(f.root.unreadRefreshes, 0);
    expect(notifications, 0);
  });

  test('a borrowed command wraps synchronous source override failures in its future', () async {
    final f = _Fixture(), page = f.borrow();
    final failure = StateError('Fixture synchronous command failure');
    f.root.write = (_, _, _) => throw failure;
    Future<dynamic>? pending;
    expect(() => pending = page.command('POST', '/items'), returnsNormally);
    await expectLater(pending, throwsA(same(failure)));
    expect(f.client.commands, isEmpty);
  });

  test(
    'the public copy helper preserves leaf objects and stringifies map keys',
    () {
      final leaf = Object();
      final original = {
        1: [
          {'leaf': leaf},
        ],
      };
      final copy = WorkspaceController.copyDecoded(original);
      expect(copy.keys, ['1']);
      expect(identical(copy['1'][0]['leaf'], leaf), isTrue);
      copy['1'].clear();
      expect(original[1], hasLength(1));
    },
  );
}
