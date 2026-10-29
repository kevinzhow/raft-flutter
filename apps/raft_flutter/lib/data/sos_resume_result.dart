/// The `resume-all-agents` response as Web `SOSDialog` reads it: only the
/// per-agent `results` matter. Every row whose `ok` is falsy is an agent the
/// resume did not reach; a response without such rows (including an old
/// ok-only server or an unreadable body) counts as complete.
class SosResumeResult {
  SosResumeResult._(this.missed);

  /// Agents the resume did not reach, with the server's `reason`.
  final List<({String agentId, String? reason})> missed;

  /// A retry names only these agents, so the others are not sent the guidance
  /// again.
  List<String> get retryAgentIds => [for (final m in missed) m.agentId];

  /// Still starting (`start_in_flight`): try again shortly.
  int get starting => missed.where((m) => m.reason == 'start_in_flight').length;

  /// Not reached for any other reason.
  int get failed => missed.length - starting;

  factory SosResumeResult.parse(Object? value) {
    final rows = value is Map ? value['results'] : null;
    return SosResumeResult._([
      for (final row in rows is List ? rows : const [])
        if (row is Map && !_truthy(row['ok']) && row['agentId'] is String)
          (
            agentId: row['agentId'] as String,
            reason: row['reason'] is String ? row['reason'] as String : null,
          ),
    ]);
  }

  /// JavaScript truthiness of a decoded JSON value.
  static bool _truthy(Object? v) =>
      v != null && v != false && v != 0 && v != '' && v != 0.0;
}
