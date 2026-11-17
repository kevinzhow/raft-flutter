// The /me/account/deletion* calls (server v1.24.0 routes/accountDeletion.ts;
// Web features/settings/account/accountDeletionApi.ts): what each sends, how
// the status and the refusals are read.
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:raft_client/raft_client.dart';
import 'package:test/test.dart';

const _id = '0a1b2c3d-1111-4222-8333-444455556666';

class _Adapter implements HttpClientAdapter {
  final calls = <RequestOptions>[];
  final answers = <String, (int, Object?)>{};

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    calls.add(options);
    final (status, body) =
        answers['${options.method} ${options.path}'] ?? (200, {'ok': true});
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Future<(RaftClient, _Adapter)> _client() async {
  final store = MemorySessionStore();
  await store.write(
    'https://example.invalid',
    Session(accessToken: 'a', refreshToken: 'r', cachedUser: {'id': 'me'}),
  );
  final adapter = _Adapter();
  adapter.answers['GET /auth/me'] = (200, {'id': 'me'});
  final client = RaftClient(
    origin: 'https://example.invalid',
    sessionStore: store,
    transport: Dio()..httpClientAdapter = adapter,
  );
  addTearDown(client.dispose);
  await client.restore(cachedFirst: true);
  // The cached account is confirmed in the background first.
  await client.sessionValidated;
  client.serverId = 'srv';
  adapter.calls.clear();
  return (client, adapter);
}

Future<RaftApiException> _refused(Future<Object?> call) async {
  try {
    await call;
  } on RaftApiException catch (error) {
    return error;
  }
  throw StateError('expected a refusal');
}

void main() {
  test(
    'the status reads the lists that are there and leaves the rest absent',
    () {
      final none = AccountDeletionStatus.parse({
        'status': 'none',
        'subscriptionRestoration': 'restored',
      });
      expect(none.scheduled, isFalse);
      expect(none.subscriptionRestoration, SubscriptionRestoration.restored);
      // An older server sends none of the lists: they stay absent, not empty.
      expect(none.checklist.soleOwnerServers, isNull);
      expect(none.checklist.agents, isNull);
      expect(none.checklist.computers, isNull);
      expect(none.checklist.graceDays, isNull);
      expect(none.checklist.soleMemberServers, isEmpty);

      final scheduled = AccountDeletionStatus.parse({
        'status': 'scheduled',
        'requestId': _id,
        'requestedAt': '2026-11-18T10:00:00.000Z',
        'scheduledFor': '2026-12-18T10:00:00.000Z',
        'subscriptionCancellationUnconfirmed': true,
        'graceDays': 30,
      });
      expect(scheduled.scheduled, isTrue);
      expect(scheduled.requestId, _id);
      expect(scheduled.subscriptionCancellationUnconfirmed, isTrue);
      expect(scheduled.checklist.graceDays, 30);
    },
  );

  test('only a UUID counts as a request id, and anything else is refused', () {
    final status = AccountDeletionStatus.parse({
      'status': 'scheduled',
      'requestId': 'not-a-uuid',
      'scheduledFor': '2026-12-18T10:00:00.000Z',
    });
    expect(status.requestId, isNull);
    expect(
      () => AccountDeletionStatus.parse({'status': 'scheduled'}),
      throwsA(isA<RaftApiException>()),
    );
    expect(
      () => AccountDeletionStatus.parse({'status': 'maybe'}),
      throwsA(isA<RaftApiException>()),
    );
  });

  test('computers separate the person\'s agents from other people\'s', () {
    final status = AccountDeletionStatus.parse({
      'status': 'none',
      'computers': [
        {
          'id': 'c1',
          'name': 'Laptop',
          'server': {'id': 's1', 'name': 'Studio', 'slug': 'studio'},
          'agents': [
            {'id': 'a1', 'name': 'Scout'},
            {
              'id': 'b1',
              'name': 'Rex',
              'ownedByMe': false,
              'owner': {'id': 'u9', 'name': 'Bo'},
              'ownerNextNotifyAt': '2026-11-19T10:00:00.000Z',
              'personalAssistant': true,
            },
          ],
        },
      ],
    });
    final others = accountDeletionOthersAgents(status.checklist);
    expect(others.map((a) => a.id), ['b1']);
    expect(others.single.owner?.name, 'Bo');
    expect(others.single.personalAssistant, isTrue);
    expect(others.single.computer.name, 'Laptop');
    // An older server doesn't say whose it is: then it is the person's.
    expect(status.checklist.computers!.single.agents.first.ownedByMe, isTrue);
  });

  test(
    'the request carries the proof it was given and the confirmed list',
    () async {
      final (client, adapter) = await _client();
      adapter.answers['POST /me/account/deletion'] = (
        200,
        {'status': 'scheduled', 'scheduledFor': '2026-12-18T10:00:00.000Z'},
      );
      await client.requestAccountDeletion(AccountDeletionProof.none);
      await client.requestAccountDeletion(AccountDeletionProof.password('pw'));
      await client.requestAccountDeletion(
        AccountDeletionProof.emailCode('123456'),
      );
      await client.requestAccountDeletion(
        AccountDeletionProof.secondFactor(const StepUpAnswer.code('654321')),
        forceAgentIds: ['b1', 'b2'],
      );
      expect(adapter.calls.map((c) => c.data), [
        <String, Object?>{},
        {'password': 'pw'},
        {'emailCode': '123456'},
        {
          'secondFactor': {'code': '654321'},
          'forceAgentIds': ['b1', 'b2'],
        },
      ]);
    },
  );

  test(
    'Cancel Deletion is bound to the request and reads what billing did',
    () async {
      final (client, adapter) = await _client();
      adapter.answers['DELETE /me/account/deletion/requests/$_id'] = (
        200,
        {'status': 'none', 'subscriptionNotResumed': true},
      );
      expect(
        await client.cancelAccountDeletion(_id),
        SubscriptionRestoration.notRestored,
      );
      expect(adapter.calls.single.path, '/me/account/deletion/requests/$_id');
      // A body that does not say "none" is not a cancellation.
      adapter.answers['DELETE /me/account/deletion/requests/$_id'] = (
        200,
        {'status': 'scheduled'},
      );
      await expectLater(
        client.cancelAccountDeletion(_id),
        throwsA(isA<RaftApiException>()),
      );
      await expectLater(
        client.cancelAccountDeletion(''),
        throwsA(isA<RaftApiException>()),
      );
    },
  );

  test('the refusals the request turns into steps', () async {
    final (client, adapter) = await _client();
    Future<AccountDeletionRefusal?> refusal(int status, Object body) async {
      adapter.answers['POST /me/account/deletion'] = (status, body);
      return AccountDeletionRefusal.of(
        await _refused(
          client.requestAccountDeletion(AccountDeletionProof.none),
        ),
      );
    }

    final reauth = await refusal(403, {
      'code': 'reauth_required',
      'error': 'x',
      'methods': ['passkey', 'totp'],
    });
    expect(
      ((reauth as AccountDeletionReauthRefused).reauth
              as AccountDeletionSecondFactor)
          .methods,
      [SecondFactorMethod.passkey, SecondFactorMethod.totp],
    );
    expect(
      (await refusal(403, {
        'code': 'reauth_required',
        'error': 'x',
        'methods': ['password'],
      }) as AccountDeletionReauthRefused).reauth,
      isA<AccountDeletionPassword>(),
    );
    expect(
      (await refusal(409, {
        'code': 'email_code_not_available',
        'error': 'x',
        'methods': ['email_code'],
      }) as AccountDeletionReauthRefused).reauth,
      isA<AccountDeletionEmailCode>(),
    );
    final sole = await refusal(409, {
      'code': 'sole_owner_servers',
      'error': 'x',
      'servers': [
        {'id': 's1', 'name': 'Studio', 'slug': 'studio', 'memberCount': 3},
      ],
    });
    expect((sole as AccountDeletionSoleOwner).servers.single.memberCount, 3);
    final agents = await refusal(409, {
      'code': 'others_agents_on_computers',
      'error': 'x',
      'agents': [
        {
          'id': 'b1',
          'name': 'Rex',
          'server': {'id': 's1', 'name': 'Studio', 'slug': 'studio'},
          'computer': {'id': 'c1', 'name': 'Laptop'},
          'owner': {'id': 'u9', 'name': 'Bo'},
        },
      ],
    });
    final listed = (agents as AccountDeletionOthersAgentsRefused).agents;
    expect(listed.single.computer.name, 'Laptop');
    expect(listed.single.server.slug, 'studio');
    expect(
      await refusal(403, {'code': 'session_family_required', 'error': 'x'}),
      isA<AccountDeletionSignInAgain>(),
    );
    expect(await refusal(500, {'error': 'boom'}), isNull);
  });

  test(
    'hand-over and archive are addressed to the server they are about',
    () async {
      final (client, adapter) = await _client();
      adapter.answers['GET /servers/s1/members'] = (
        200,
        [
          {'userId': 'me', 'name': 'me', 'role': 'owner'},
          {
            'userId': 'u2',
            'name': 'ana',
            'displayName': 'Ana',
            'role': 'member',
          },
          {'userId': 'u3', 'name': 'gus', 'role': 'guest'},
          {'userId': 'u4', 'name': 'cy', 'displayName': ' ', 'role': 'admin'},
        ],
      );
      final candidates = await client.accountDeletionTransferCandidates(
        's1',
        'me',
      );
      expect(candidates.map((c) => (c.userId, c.name)), [
        ('u2', 'Ana'),
        ('u4', 'cy'),
      ]);
      expect(adapter.calls.single.headers['X-Server-Id'], 's1');
      adapter.calls.clear();
      await client.makeServerOwner('s1', 'u2');
      await client.archiveAgentForDeletion('s1', 'a1');
      expect(
        [
          for (final c in adapter.calls)
            (c.method, c.path, jsonEncode(c.data), c.headers['X-Server-Id']),
        ],
        [
          ('PATCH', '/servers/s1/members/u2', '{"role":"owner"}', 's1'),
          ('DELETE', '/agents/a1', '{"workspace":"keep"}', 's1'),
        ],
      );
    },
  );
}
