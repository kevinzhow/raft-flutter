import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/mention_audience_source.dart';

class _Client extends RaftClient {
  _Client()
    : super(origin: 'https://example.test', sessionStore: MemorySessionStore());

  final requests = <(String, Object?)>[];

  @override
  Future<dynamic> post(String path, {dynamic data}) async {
    requests.add((path, data));
    return {
      'capped': true,
      'candidates': [
        {
          'type': 'user',
          'id': 'u1',
          'name': 'ada',
          'displayName': 'Ada',
          'guest': true,
        },
        {
          'type': 'agent',
          'id': 'a1',
          'name': 'helper',
          'avatarUrl': '/api/avatars/a1',
        },
        {'type': 'unknown', 'id': 'bad', 'name': 'hidden'},
      ],
    };
  }
}

void main() {
  test(
    'reads both audience kinds with scoped POST bodies and exposes the cap',
    () async {
      final client = _Client();
      addTearDown(client.dispose);
      final source = MentionAudienceSource(client);
      final answer = await source.conversation('channel-1').search('  Ada  ');
      await source
          .object(app: 'artifacts', kind: 'artifact', id: 'object-1')
          .search('');

      expect(client.requests.map((request) => request.$1), [
        '/mentions/audience',
        '/mentions/audience',
      ]);
      expect(client.requests.map((request) => request.$2), [
        {
          'audience': {'kind': 'conversation', 'channelId': 'channel-1'},
          'q': 'Ada',
        },
        {
          'audience': {
            'kind': 'object',
            'app': 'artifacts',
            'objectKind': 'artifact',
            'objectId': 'object-1',
          },
          'q': '',
        },
      ]);
      expect(answer.capped, isTrue);
      expect(answer.candidates.map((r) => r['id']), ['u1', 'a1']);
      expect(answer.candidates.first['guest'], isTrue);
      expect(answer.candidates.last['avatarUrl'], '/api/avatars/a1');
    },
  );
}
