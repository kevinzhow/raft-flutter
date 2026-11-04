import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:raft_client/raft_client.dart';
import 'package:test/test.dart';

class _AccountAdapter implements HttpClientAdapter {
  final entered = Completer<void>();
  final answer = Completer<void>();
  String? serverHeader;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? body,
    Future<void>? cancellation,
  ) async {
    final Object value;
    if (options.path == '/auth/login') {
      value = {
        'accessToken': 'fixture-access',
        'refreshToken': 'fixture-refresh',
        'user': {'id': 'alice'},
      };
    } else if (options.path.startsWith('/integration-invites/')) {
      serverHeader = options.headers['X-Server-Id'] as String?;
      entered.complete();
      await answer.future;
      value = {'name': 'Account-owned invitation'};
    } else {
      value = <String, Object?>{};
    }
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
  for (final signOut in [false, true]) {
    test(signOut ? 'account read rejects a response completed after sign out' : 'account read survives workspace selection without leaking its header', () async {
      final adapter = _AccountAdapter();
      final client = RaftClient(
        origin: 'https://account-read.invalid',
        sessionStore: MemorySessionStore(),
        transport: Dio()..httpClientAdapter = adapter,
      );
      addTearDown(client.dispose);
      await client.login('alice', 'fixture');
      client.selectServer('alpha');
      final account = client.authenticationGeneration;
      final workspace = client.generation;
      final pending = client.getForAccount('/integration-invites/fixture');
      await adapter.entered.future;
      if (signOut) {
        final rejected = expectLater(pending, throwsA(isA<RaftApiException>()));
        await client.logout();
        adapter.answer.complete();
        await rejected;
        expect(client.user, isNull);
      } else {
        client.selectServer('beta');
        adapter.answer.complete();
        expect(await pending, {'name': 'Account-owned invitation'});
        expect(client.authenticationGeneration, account);
        expect(client.generation, isNot(workspace));
      }
      expect(adapter.serverHeader, isNull);
    });
  }
}
