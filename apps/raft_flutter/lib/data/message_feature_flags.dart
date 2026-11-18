import 'package:raft_client/raft_client.dart';

import 'feature_flag_client_facts.dart';

class MessageFeatureFlags {
  MessageFeatureFlags._(this._client);

  static final _instances = Expando<MessageFeatureFlags>();

  static MessageFeatureFlags of(RaftClient client) =>
      _instances[client] ??= MessageFeatureFlags._(client);

  final RaftClient _client;
  (String, int, String?, String?)? _scope;
  Future<Set<String>>? _answer;

  Future<Set<String>> evaluate({bool refresh = false}) {
    final serverId = _client.serverId;
    if (serverId == null) return Future.value(const {});
    final scope = (
      _client.origin,
      _client.generation,
      _client.user?.id,
      serverId,
    );
    if (_scope != scope) {
      _scope = scope;
      _answer = null;
    }
    if (refresh) _answer = null;
    return _answer ??= _fetch(serverId);
  }

  Future<Set<String>> _fetch(String serverId) async {
    try {
      final response = await _client.post(
        '/feature-flags/evaluate',
        data: featureFlagEvaluateBody(
          keys: const [
            RaftFeatureFlags.taskV2Conversations,
            RaftFeatureFlags.agentReadProgress,
          ],
          serverId: serverId,
        ),
      );
      final rows = response is Map ? response['evaluations'] : null;
      return {
        if (rows is List)
          for (final row in rows)
            if (row case {'key': final String key, 'enabled': true}) key,
      };
    } catch (_) {
      return const {};
    }
  }
}
