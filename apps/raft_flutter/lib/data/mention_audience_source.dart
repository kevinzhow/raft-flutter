import 'package:raft_client/raft_client.dart';

typedef MentionAudienceAnswer = ({
  List<Map<String, dynamic>> candidates,
  bool capped,
});

class MentionAudienceSource {
  const MentionAudienceSource(this.client);

  final RaftClient client;

  MentionAudienceQuery conversation(String channelId) => MentionAudienceQuery._(
    client,
    {'kind': 'conversation', 'channelId': channelId},
  );

  MentionAudienceQuery object({
    required String app,
    required String kind,
    required String id,
  }) => MentionAudienceQuery._(client, {
    'kind': 'object',
    'app': app,
    'objectKind': kind,
    'objectId': id,
  });
}

class MentionAudienceQuery {
  const MentionAudienceQuery._(this._client, this._audience);

  final RaftClient _client;
  final Map<String, String> _audience;

  Future<MentionAudienceAnswer> search(String query) async {
    final answer = await _client.post(
      '/mentions/audience',
      data: {
        'audience': _audience,
        'q': String.fromCharCodes(query.trim().runes.take(64)),
      },
    );
    if (answer is! Map || answer['candidates'] is! List) {
      throw const FormatException('Invalid mention audience response');
    }
    return (
      candidates: [
        for (final row in (answer['candidates'] as List).whereType<Map>())
          if ((row['type'] == 'user' || row['type'] == 'agent') &&
              row['id'] is String &&
              (row['id'] as String).isNotEmpty &&
              row['name'] is String &&
              (row['name'] as String).isNotEmpty)
            Map<String, dynamic>.from(row),
      ],
      capped: answer['capped'] == true,
    );
  }
}
