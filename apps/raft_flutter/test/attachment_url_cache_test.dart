import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/attachment_url_cache.dart';
import 'package:raft_flutter/data/workspace_controller.dart';

class _Clock {
  DateTime now = DateTime.utc(2026, 10, 12, 12);
  void advance(Duration d) => now = now.add(d);
}

Map<String, dynamic> _body(String id, {String? expiresAt}) => {
  'url': 'https://storage.invalid/$id?sig=secret',
  'expiresAt': expiresAt,
};

void main() {
  group('AttachmentUrlCache lifetime', () {
    late _Clock clock;
    late AttachmentUrlCache cache;
    setUp(() {
      clock = _Clock();
      cache = AttachmentUrlCache(now: () => clock.now);
    });
    tearDown(() => cache.dispose());

    test('reuses a URL until shortly before the server expiry', () async {
      var fetches = 0;
      Future<dynamic> fetch() async {
        fetches++;
        return _body(
          'a',
          expiresAt: clock.now.add(const Duration(seconds: 300)).toIso8601String(),
        );
      }

      await cache.resolve('a', scope: 's', fetch: fetch);
      await cache.resolve('a', scope: 's', fetch: fetch);
      expect(fetches, 1);
      // 300 s signed, capped at 4 min of reuse: gone after that.
      clock.advance(const Duration(minutes: 4, seconds: 1));
      await cache.resolve('a', scope: 's', fetch: fetch);
      expect(fetches, 2);
    });

    test('dropping what is resolved forgets URLs but not a request on its way', () async {
      var fetches = 0;
      Future<dynamic> fetch() async {
        fetches++;
        return _body(
          'a',
          expiresAt: clock.now.add(const Duration(seconds: 300)).toIso8601String(),
        );
      }

      await cache.resolve('a', scope: 's', fetch: fetch);
      expect(cache.length, 1);
      final gate = Completer<dynamic>();
      final waiting = cache.resolve('b', scope: 's', fetch: () => gate.future);

      cache.dropResolved();
      expect(cache.length, 0);
      expect(cache.peek('a', scope: 's'), isNull);
      expect(cache.inFlightCount, 1);

      // The request on its way still answers, and is stored.
      gate.complete(_body('b', expiresAt: clock.now.add(const Duration(seconds: 300)).toIso8601String()));
      expect(await waiting, contains('/b?'));
      expect(cache.peek('b', scope: 's'), isNotNull);
      await cache.resolve('a', scope: 's', fetch: fetch);
      expect(fetches, 2, reason: 'signed again after the drop');
    });

    test('never serves a URL within the safety margin of its expiry', () async {
      var fetches = 0;
      Future<dynamic> fetch() async {
        fetches++;
        return _body(
          'a',
          expiresAt: clock.now.add(const Duration(seconds: 100)).toIso8601String(),
        );
      }

      await cache.resolve('a', scope: 's', fetch: fetch);
      clock.advance(const Duration(seconds: 56)); // 44 s left < 45 s margin
      expect(cache.peek('a', scope: 's'), isNull);
      await cache.resolve('a', scope: 's', fetch: fetch);
      expect(fetches, 2);
    });

    test('a URL that is already too old to reuse is not stored', () async {
      await cache.resolve(
        'a',
        scope: 's',
        fetch: () async => _body(
          'a',
          expiresAt: clock.now.add(const Duration(seconds: 20)).toIso8601String(),
        ),
      );
      expect(cache.length, 0);
    });

    test('reads the lifetime from an AWS signature when no expiry is sent', () async {
      var fetches = 0;
      String stamp(DateTime t) =>
          '${t.toUtc().toIso8601String().replaceAll(RegExp(r'[-:]'), '').split('.').first}Z';
      Future<dynamic> fetch() async {
        fetches++;
        return {
          'url':
              'https://s3.invalid/o?X-Amz-Date=${stamp(clock.now)}&X-Amz-Expires=120&X-Amz-Signature=x',
        };
      }

      await cache.resolve('a', scope: 's', fetch: fetch);
      clock.advance(const Duration(seconds: 50)); // 70 s left > margin
      await cache.resolve('a', scope: 's', fetch: fetch);
      expect(fetches, 1);
      clock.advance(const Duration(seconds: 30)); // 40 s left < margin
      await cache.resolve('a', scope: 's', fetch: fetch);
      expect(fetches, 2);
    });

    test('an unknown expiry is trusted for about a hundred seconds', () async {
      var fetches = 0;
      Future<dynamic> fetch() async {
        fetches++;
        return _body('a');
      }

      await cache.resolve('a', scope: 's', fetch: fetch);
      await cache.resolve('a', scope: 's', fetch: fetch);
      expect(fetches, 1);
      clock.advance(const Duration(seconds: 100));
      await cache.resolve('a', scope: 's', fetch: fetch);
      expect(fetches, 1);
      clock.advance(const Duration(seconds: 10));
      await cache.resolve('a', scope: 's', fetch: fetch);
      expect(fetches, 2);
    });

    test('dispositions are cached apart', () async {
      var fetches = 0;
      Future<dynamic> fetch() async {
        fetches++;
        return _body('a');
      }

      await cache.resolve('a', scope: 's', disposition: 'inline', fetch: fetch);
      await cache.resolve('a', scope: 's', disposition: '', fetch: fetch);
      expect(fetches, 2);
    });

    test('the cache is bounded', () async {
      final small = AttachmentUrlCache(now: () => clock.now, maxEntries: 3);
      for (var i = 0; i < 6; i++) {
        await small.resolve('a$i', scope: 's', fetch: () async => _body('a$i'));
      }
      expect(small.length, 3);
      expect(small.peek('a0', scope: 's'), isNull);
      expect(small.peek('a5', scope: 's'), isNotNull);
    });
  });

  group('AttachmentUrlCache identity and revocation', () {
    test('a different scope drops every held URL', () async {
      final cache = AttachmentUrlCache();
      await cache.resolve('a', scope: 'alice', fetch: () async => _body('a'));
      expect(cache.peek('a', scope: 'alice'), isNotNull);
      expect(cache.peek('a', scope: 'bob'), isNull);
      expect(cache.peek('a', scope: 'alice'), isNull, reason: 'not restored');
      cache.dispose();
    });

    test('channel revocation drops its URLs and keeps others', () async {
      final cache = AttachmentUrlCache();
      await cache.resolve('a', scope: 's', channelId: 'c1', fetch: () async => _body('a'));
      await cache.resolve('b', scope: 's', channelId: 'c2', fetch: () async => _body('b'));
      cache.invalidateChannel('c1');
      expect(cache.peek('a', scope: 's'), isNull);
      expect(cache.peek('b', scope: 's'), isNotNull);
      cache.dispose();
    });

    test('an answer that lands after revocation is not stored', () async {
      final cache = AttachmentUrlCache();
      final pending = Completer<dynamic>();
      final result = cache.resolve(
        'a',
        scope: 's',
        channelId: 'c1',
        fetch: () => pending.future,
      );
      cache.invalidateChannel('c1');
      pending.complete(_body('a'));
      await result; // the caller still gets it and applies its own check
      expect(cache.peek('a', scope: 's'), isNull);
      cache.dispose();
    });

    test('invalidate forgets a rejected URL', () async {
      final cache = AttachmentUrlCache();
      await cache.resolve('a', scope: 's', fetch: () async => _body('a'));
      cache.invalidate('a');
      expect(cache.peek('a', scope: 's'), isNull);
      cache.dispose();
    });

    test('a failed fetch is not remembered and the error is surfaced', () async {
      final cache = AttachmentUrlCache();
      var n = 0;
      Future<dynamic> fetch() async {
        if (n++ == 0) throw StateError('offline');
        return _body('a');
      }

      await expectLater(
        cache.resolve('a', scope: 's', fetch: fetch),
        throwsStateError,
      );
      expect(await cache.resolve('a', scope: 's', fetch: fetch), contains('/a'));
      cache.dispose();
    });

    test('a malformed answer is rejected', () async {
      final cache = AttachmentUrlCache();
      await expectLater(
        cache.resolve('a', scope: 's', fetch: () async => {'nope': 1}),
        throwsFormatException,
      );
      cache.dispose();
    });
  });

  group('AttachmentUrlCache request sharing', () {
    test('concurrent resolves share one request', () async {
      final cache = AttachmentUrlCache();
      var fetches = 0;
      final gate = Completer<dynamic>();
      Future<dynamic> fetch() {
        fetches++;
        return gate.future;
      }

      final all = [
        for (var i = 0; i < 5; i++) cache.resolve('a', scope: 's', fetch: fetch),
      ];
      expect(cache.inFlightCount, 1);
      gate.complete(_body('a'));
      final urls = await Future.wait(all);
      expect(fetches, 1);
      expect(urls.toSet().length, 1);
      expect(cache.inFlightCount, 0);
      cache.dispose();
    });

    test('a failure reaches every sharer and clears the slot', () async {
      final cache = AttachmentUrlCache();
      final gate = Completer<dynamic>();
      final a = cache.resolve('a', scope: 's', fetch: () => gate.future);
      final b = cache.resolve('a', scope: 's', fetch: () => gate.future);
      gate.completeError(StateError('boom'));
      await expectLater(a, throwsStateError);
      await expectLater(b, throwsStateError);
      expect(cache.inFlightCount, 0);
      cache.dispose();
    });
  });

  group('AttachmentUrlCache batching (no speculative signing)', () {
    AttachmentUrlCache make({int batch = 20}) =>
        AttachmentUrlCache(batchSize: batch);
    Future<dynamic> answer(List<String> ids) async => {
      'urls': [
        for (final id in ids) {'id': id, 'url': 'https://s.invalid/$id'},
      ],
    };
    Future<dynamic> noSingle() async => throw StateError('single route used');

    test('nothing is requested until a caller needs a URL', () async {
      final cache = make();
      var requests = 0;
      expect(cache.peek('a', scope: 's'), isNull);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(requests, 0);
      expect(cache.inFlightCount, 0);
      expect(cache.batchRequests, 0);
      // Needed tiles of one frame cost one batch request, then opens are free.
      final urls = await Future.wait([
        for (final id in ['a', 'b', 'c'])
          cache.resolveCoalesced(
            id,
            scope: 's',
            fetchMany: (ids) {
              requests++;
              return answer(ids);
            },
            fetch: noSingle,
          ),
      ]);
      expect(urls, hasLength(3));
      expect(requests, 1);
      var singles = 0;
      for (final id in ['a', 'b', 'c']) {
        await cache.resolve(id, scope: 's', fetch: () async {
          singles++;
          return _body(id);
        });
      }
      expect(singles, 0);
      cache.dispose();
    });

    test('a batch is bounded and the rest goes in further requests', () async {
      final cache = make(batch: 2);
      final requests = <List<String>>[];
      await Future.wait([
        for (final id in ['a', 'b', 'c', 'd', 'e'])
          cache.resolveCoalesced(
            id,
            scope: 's',
            fetchMany: (ids) {
              requests.add(ids);
              return answer(ids);
            },
            fetch: noSingle,
          ),
      ]);
      expect(requests.map((r) => r.length), [2, 2, 1]);
      cache.dispose();
    });

    test('revocation withdraws callers still gathering', () async {
      final cache = make();
      var requests = 0;
      final result = cache
          .resolveCoalesced(
            'a',
            scope: 's',
            channelId: 'c1',
            fetchMany: (ids) {
              requests++;
              return answer(ids);
            },
            fetch: noSingle,
          )
          .then<Object>((v) => v, onError: (Object e) => e);
      cache.invalidateChannel('c1');
      expect(await result, isA<FormatException>());
      expect(requests, 0);
      cache.dispose();
    });

    test('a URL already held is not requested again', () async {
      final cache = make();
      await cache.resolve('a', scope: 's', fetch: () async => _body('a'));
      var requests = 0;
      await cache.resolveCoalesced(
        'a',
        scope: 's',
        fetchMany: (ids) {
          requests++;
          return answer(ids);
        },
        fetch: noSingle,
      );
      expect(requests, 0);
      cache.dispose();
    });
  });

  group('WorkspaceController.attachmentUrl', () {
    test('one read serves every surface; revocation and sign-out drop it', () async {
      final client = _CountingClient()..user = RaftRecord({'id': 'alice'});
      client.selectServer('server');
      final w = WorkspaceController(client)
        ..server = RaftRecord({'id': 'server', 'role': 'owner'});
      addTearDown(() async {
        w.dispose();
        await client.dispose();
      });
      final urls = await Future.wait([
        w.attachmentMedia.url('f1', channelId: 'c1'),
        w.attachmentMedia.url('f1', channelId: 'c1'),
      ]);
      expect(urls.toSet().length, 1);
      await w.attachmentMedia.url('f1', channelId: 'c1');
      expect(client.urlReads, 1);
      // A one-shot download link is never retained.
      await w.attachmentMedia.url('f1', disposition: 'attachment', channelId: 'c1');
      await w.attachmentMedia.url('f1', disposition: 'attachment', channelId: 'c1');
      expect(client.urlReads, 3);
      client.emit('channel:removed', {'channelId': 'c1'});
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await w.attachmentMedia.url('f1', channelId: 'c1');
      expect(client.urlReads, 4, reason: 'revoked channel asks the server again');
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(client.batchReads, 0, reason: 'single reads only, no batch');
    });

    test('a signed-in identity change drops cached URLs', () async {
      final client = _CountingClient()..user = RaftRecord({'id': 'alice'});
      client.selectServer('server');
      final w = WorkspaceController(client)
        ..server = RaftRecord({'id': 'server', 'role': 'owner'});
      addTearDown(() async {
        w.dispose();
        await client.dispose();
      });
      await w.attachmentMedia.url('f1');
      client.user = RaftRecord({'id': 'bob'});
      w.notifyListeners();
      await w.attachmentMedia.url('f1');
      expect(client.urlReads, 2);
    });

    test('needed tiles share one batch; an open afterwards is free', () async {
      final client = _CountingClient()..user = RaftRecord({'id': 'alice'});
      client.selectServer('server');
      final w = WorkspaceController(client)
        ..server = RaftRecord({'id': 'server', 'role': 'owner'});
      addTearDown(() async {
        w.dispose();
        await client.dispose();
      });
      // Nothing is signed ahead of time.
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(client.batchReads + client.urlReads, 0);
      await Future.wait([
        for (final id in ['f1', 'f2', 'f3'])
          w.attachmentMedia.url(id, channelId: 'c1', coalesce: true),
      ]);
      expect(client.batchReads, 1);
      for (final id in ['f1', 'f2', 'f3']) {
        await w.attachmentMedia.url(id, channelId: 'c1');
      }
      expect(client.urlReads, 0, reason: 'opens reuse the signed URLs');
    });

    test('the preview gate is read once per scope window', () async {
      final client = _CountingClient()..user = RaftRecord({'id': 'alice'});
      client.selectServer('server');
      final w = WorkspaceController(client)
        ..server = RaftRecord({'id': 'server', 'role': 'owner'});
      addTearDown(() async {
        w.dispose();
        await client.dispose();
      });
      expect(await w.attachmentMedia.previewEnabled(), isTrue);
      expect(await w.attachmentMedia.previewEnabled(), isTrue);
      expect(client.gateReads, 1);
    });
  });

  group('AttachmentUrlCache request budget', () {
    Future<dynamic> answer(List<String> ids) async => {
      'urls': [for (final id in ids) {'id': id, 'url': 'https://s.invalid/$id'}],
    };

    test('coalesced callers share one batch request', () async {
      final cache = AttachmentUrlCache(
        coalesceDelay: const Duration(milliseconds: 10),
      );
      final requests = <List<String>>[];
      var singles = 0;
      final urls = await Future.wait([
        for (var i = 0; i < 30; i++)
          cache.resolveCoalesced(
            'img$i',
            scope: 's',
            fetchMany: (ids) {
              requests.add(ids);
              return answer(ids);
            },
            fetch: () async {
              singles++;
              return {'url': 'x'};
            },
          ),
      ]);
      expect(urls, hasLength(30));
      expect(requests, hasLength(1));
      expect(requests.single, hasLength(30));
      expect(singles, 0);
      // Held now: a second look is free.
      await cache.resolveCoalesced('img3', scope: 's', fetchMany: answer, fetch: () async => {});
      expect(requests, hasLength(1));
      cache.dispose();
    });

    test('an id the batch left out is asked singly; a failed batch falls back', () async {
      final cache = AttachmentUrlCache(
        coalesceDelay: const Duration(milliseconds: 5),
      );
      var singles = <String>[];
      Future<dynamic> single(String id) async {
        singles.add(id);
        return {'url': 'https://s.invalid/single-$id'};
      }

      final urls = await Future.wait([
        cache.resolveCoalesced(
          'a',
          scope: 's',
          fetchMany: (ids) async => {
            'urls': [
              {'id': 'a', 'url': 'https://s.invalid/a'},
            ],
          },
          fetch: () => single('a'),
        ),
        cache.resolveCoalesced(
          'b',
          scope: 's',
          fetchMany: (ids) async => {'urls': []},
          fetch: () => single('b'),
        ),
      ]);
      expect(urls, ['https://s.invalid/a', 'https://s.invalid/single-b']);
      expect(singles, ['b']);
      // A batch that fails outright (not rate limited) degrades to singles.
      singles = [];
      final fallback = await cache.resolveCoalesced(
        'c',
        scope: 's',
        fetchMany: (ids) async => throw StateError('route missing'),
        fetch: () => single('c'),
      );
      expect(fallback, 'https://s.invalid/single-c');
      cache.dispose();
    });

    test('a rate-limited coalesced batch reaches the callers without N singles', () async {
      final cache = AttachmentUrlCache(
        coalesceDelay: const Duration(milliseconds: 5),
      );
      var singles = 0;
      final results = await Future.wait([
        for (var i = 0; i < 10; i++)
          cache
              .resolveCoalesced(
                'img$i',
                scope: 's',
                fetchMany: (ids) async => throw const RaftApiException(
                  'Too many',
                  status: 429,
                  retryAfter: Duration(seconds: 3),
                ),
                fetch: () async {
                  singles++;
                  return {'url': 'x'};
                },
              )
              .then<Object>((v) => v, onError: (Object e) => e),
      ]);
      expect(results.every((r) => r is RaftApiException), isTrue);
      expect(singles, 0, reason: 'singles would hit the same closed limiter');
      cache.dispose();
    });

    test('rejecting one URL does not discard the answers of other ids', () async {
      final cache = AttachmentUrlCache();
      final gate = Completer<void>();
      Future<dynamic> slow(List<String> ids) async {
        await gate.future;
        return answer(ids);
      }

      final a = cache.resolveCoalesced('a', scope: 's', fetchMany: slow, fetch: () async => {});
      final b = cache.resolveCoalesced('b', scope: 's', fetchMany: slow, fetch: () async => {});
      await Future<void>.delayed(const Duration(milliseconds: 40));
      // A transfer rejected some other attachment's URL while the batch is out.
      cache.invalidate('zzz');
      cache.invalidate('a');
      gate.complete();
      await Future.wait([a, b]);
      expect(cache.peek('b', scope: 's'), 'https://s.invalid/b');
      expect(cache.peek('a', scope: 's'), isNull, reason: 'the rejected one');
      cache.dispose();
    });
  });
}

class _CountingClient extends RaftClient {
  _CountingClient()
    : super(
        origin: 'https://example.invalid',
        sessionStore: MemorySessionStore(),
      );
  final stream = StreamController<RaftEvent>.broadcast(sync: true);
  @override
  Stream<RaftEvent> get events => stream.stream;
  void emit(String name, dynamic payload) =>
      stream.add(RaftEvent(name, payload));
  int urlReads = 0, batchReads = 0, gateReads = 0;
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    if (path.endsWith('/attachment-preview/enabled')) {
      gateReads++;
      return {'enabled': true};
    }
    urlReads++;
    return {
      'url': 'https://storage.invalid$path?n=$urlReads',
      'expiresAt': DateTime.now().add(const Duration(seconds: 300)).toIso8601String(),
    };
  }

  @override
  Future<dynamic> post(String path, {dynamic data}) async {
    batchReads++;
    return {
      'urls': [
        for (final id in (data as Map)['attachmentIds'] as List)
          {'id': id, 'url': 'https://storage.invalid/batch/$id', 'expiresAt': null},
      ],
    };
  }
}
