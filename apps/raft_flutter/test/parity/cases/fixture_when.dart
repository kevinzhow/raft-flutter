// A fixture route answer may differ by query string:
// `{"$when": [{"query": {"dirPath": "notes"}, "answer": A}], "$default": B}`.
// tool/parity-ext/run applies the same rule to the React provider's routes, so
// both providers answer one path (the agent workspace listing: root vs a
// folder) identically.
Object? resolveFixtureWhen(Object? answer, Map<String, dynamic>? query) {
  if (answer is! Map || answer['\$when'] is! List) return answer;
  for (final rule in (answer['\$when'] as List).whereType<Map>()) {
    final expected = (rule['query'] as Map?) ?? const {};
    if (expected.entries.every((e) => '${query?[e.key]}' == '${e.value}')) {
      return rule['answer'];
    }
  }
  return answer['\$default'];
}
