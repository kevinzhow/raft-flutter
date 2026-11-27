// A scripted /me/account/deletion server (v1.24.0 routes/accountDeletion.ts)
// for the Delete Account page tests: GET answers [checklist] (or [readFailure]
// while set), POST answers the next entry of [postAnswers], the rest answers
// like the real routes.
import 'package:raft_client/raft_client.dart';

RaftApiException deletionRefusal(
  int status,
  String code, {
  Map<String, Object?> extra = const {},
}) => RaftApiException.response(
  code,
  status: status,
  body: {'error': code, 'code': code, ...extra},
);

Map<String, Object?> deletionServer(String id, [String? name]) => {
  'id': id,
  'name': name ?? id,
  'slug': id,
};

class AccountDeletionServerClient extends RaftClient {
  AccountDeletionServerClient()
    : super(
        origin: 'https://fixture.invalid',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'me', 'email': 'me@example.invalid'});
  }

  /// GET's body.
  Map<String, Object?> checklist = {
    'status': 'none',
    'soleOwnerServers': <Object?>[],
    'soleMemberServers': <Object?>[],
    'paidServersEndingAtPeriodEnd': <Object?>[],
    'agents': <Object?>[],
    'computers': <Object?>[],
    'graceDays': 30,
  };

  /// The GET answers this failure while set.
  int? readFailure;

  /// What POST answers, in order: a map (200) or an exception; the last one
  /// repeats.
  final postAnswers = <Object>[];

  /// Each member list of `GET /servers/:id/members`.
  final members = <String, List<Map<String, Object?>>>{};

  /// A failure for one route, by 'METHOD path'.
  final failures = <String, RaftApiException>{};
  final calls =
      <({String method, String path, dynamic data, String? server})>[];
  int logouts = 0;

  /// Agents the person asked Raft to remind (the server then reports when the
  /// next reminder is allowed).
  final notified = <String>{};

  List<({String method, String path, dynamic data, String? server})> to(
    String method,
    String path,
  ) => [
    for (final c in calls)
      if (c.method == method && c.path == path) c,
  ];

  int reads() => to('GET', '/me/account/deletion').length;

  @override
  Future<void> logout({
    Future<Session?>? revocationSession,
    SessionEndReason reason = SessionEndReason.userRequested,
  }) async {
    logouts++;
  }

  Future<dynamic> answer(
    String method,
    String path,
    dynamic data,
    String? server,
  ) async {
    calls.add((method: method, path: path, data: data, server: server));
    if (failures['$method $path'] case final failure?) throw failure;
    switch ((method, path)) {
      case ('GET', '/me/account/deletion'):
        if (readFailure case final status?) {
          throw deletionRefusal(status, 'boom');
        }
        return {
          ...checklist,
          'computers': [
            for (final c in checklist['computers'] as List)
              {
                ...(c as Map).cast<String, Object?>(),
                'agents': [
                  for (final a in c['agents'] as List)
                    notified.contains((a as Map)['id'])
                        ? {
                            ...a.cast<String, Object?>(),
                            'ownerNotifiedAt': '2026-11-18T10:00:00.000Z',
                            'ownerNextNotifyAt': '2099-01-01T00:00:00.000Z',
                          }
                        : a,
                ],
              },
          ],
        };
      case ('POST', '/me/account/deletion'):
        final next = postAnswers.length > 1
            ? postAnswers.removeAt(0)
            : postAnswers.single;
        if (next is Exception) throw next;
        return next;
      case ('POST', '/me/account/deletion/email-code'):
        return {'sent': true, 'expiresAt': '2099-01-01T00:00:00.000Z'};
      case ('POST', '/me/account/deletion/notify-agent-owners'):
        notified.addAll(((data as Map)['agentIds'] as List).cast<String>());
        return {
          'notified': [
            for (final id in data['agentIds'] as List)
              {'agentId': id, 'notifiedAt': '2026-11-18T10:00:00.000Z'},
          ],
          'skipped': <Object?>[],
        };
    }
    if (method == 'GET' && path.endsWith('/members') && server != null) {
      return members[server] ?? <Object?>[];
    }
    return {'ok': true};
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
  }) => answer(method, path, data, null);

  @override
  Future<dynamic> getForAccount(String path, {Map<String, dynamic>? query}) =>
      answer('GET', path, null, null);

  @override
  Future<dynamic> getForServer(
    String server,
    String path, {
    Map<String, dynamic>? query,
  }) => answer('GET', path, null, server);

  @override
  Future<dynamic> requestForServer(
    String method,
    String server,
    String path, {
    dynamic data,
  }) => answer(method, path, data, server);
}
