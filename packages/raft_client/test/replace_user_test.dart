import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:raft_client/raft_client.dart';
import 'package:test/test.dart';

class _Adapter implements HttpClientAdapter {
  int requests = 0;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? body,
    Future<void>? cancellation,
  ) async {
    requests++;
    final value = options.path == '/auth/login'
        ? {
            'accessToken': 'fixture-access',
            'refreshToken': 'fixture-refresh',
            'user': {'id': 'alice', 'avatarUrl': null},
          }
        : <String, Object?>{};
    return ResponseBody.fromString(
      jsonEncode(value),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test(
    'replaceUser adopts an account route\'s answer with no request',
    () async {
      final adapter = _Adapter();
      final store = MemorySessionStore();
      final client = RaftClient(
        origin: 'https://replace-user.invalid',
        sessionStore: store,
        transport: Dio()..httpClientAdapter = adapter,
      );
      addTearDown(client.dispose);
      await client.login('alice', 'fixture');
      final before = adapter.requests;
      final events = <String>[];
      final sub = client.events.listen((e) => events.add(e.name));
      await client.replaceUser({
        'id': 'alice',
        'avatarUrl': 'pixel-human:v1:sky.3.curly.brown.grin.none.none',
      });
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();
      expect(
        client.user?.string('avatarUrl'),
        'pixel-human:v1:sky.3.curly.brown.grin.none.none',
      );
      expect(
        adapter.requests,
        before,
        reason: 'Web sets the user from the PUT',
      );
      expect(events, contains('account:updated'));
      final saved = await store.read('https://replace-user.invalid');
      expect(
        (saved?.cachedUser)?['avatarUrl'],
        'pixel-human:v1:sky.3.curly.brown.grin.none.none',
      );
    },
  );

  test('replaceUser does nothing once signed out', () async {
    final client = RaftClient(
      origin: 'https://replace-user.invalid',
      sessionStore: MemorySessionStore(),
      transport: Dio()..httpClientAdapter = _Adapter(),
    );
    addTearDown(client.dispose);
    await client.replaceUser({'id': 'ghost'});
    expect(client.user, isNull);
  });
}
