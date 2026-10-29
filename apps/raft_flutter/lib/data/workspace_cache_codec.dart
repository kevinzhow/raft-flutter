import 'dart:convert';
import 'dart:isolate';

// Bound the UI-side size check. Tiny preferences stay inline; large windows,
// directories and translation batches sanitize/encode/decode off the UI isolate.
const _inlineCharacters = 32 * 1024;
const _inlineNodes = 128;

bool _needsWorker(dynamic value) {
  var nodes = _inlineNodes;
  var characters = _inlineCharacters;
  bool visit(dynamic item) {
    if (--nodes < 0) return true;
    if (item is String) return (characters -= item.length) < 0;
    if (item is List) {
      if (item.length > nodes) return true;
      for (final child in item) {
        if (visit(child)) return true;
      }
    } else if (item is Map) {
      if (item.length * 2 > nodes) return true;
      for (final entry in item.entries) {
        if (visit(entry.key) || visit(entry.value)) return true;
      }
    }
    return false;
  }

  return visit(value);
}

/// Encodes a cache value, removing credentials and signed URLs before storage.
Future<String> encodeWorkspaceCache(dynamic value) async => _needsWorker(value)
    ? Isolate.run(() => _encode(value), debugName: 'raft-cache-encode')
    : _encode(value);

/// Decodes a persisted value without blocking the UI on large JSON documents.
Future<dynamic> decodeWorkspaceCache(String payload) async =>
    payload.length > _inlineCharacters
    ? Isolate.run(() => jsonDecode(payload), debugName: 'raft-cache-decode')
    : jsonDecode(payload);

/// Encodes a translation batch in one worker rather than spawning per row.
Future<List<String>> encodeWorkspaceTranslations(
  List<Map<String, dynamic>> entries,
) async => _needsWorker(entries)
    ? Isolate.run(() => _encodeEntries(entries), debugName: 'raft-cache-encode')
    : _encodeEntries(entries);

/// Decodes a translation batch in one worker, retaining persisted row order.
Future<List<Map<String, dynamic>>> decodeWorkspaceTranslations(
  List<String> payloads,
) async => _needsWorker(payloads)
    ? Isolate.run(
        () => _decodeEntries(payloads),
        debugName: 'raft-cache-decode',
      )
    : _decodeEntries(payloads);

String _encode(dynamic value) => jsonEncode(_cacheSafe(value));
List<String> _encodeEntries(List<Map<String, dynamic>> entries) => [
  for (final entry in entries) _encode(entry),
];
List<Map<String, dynamic>> _decodeEntries(List<String> payloads) => [
  for (final payload in payloads)
    if (jsonDecode(payload) case final Map value)
      Map<String, dynamic>.from(value),
];

final _signedQuery = RegExp(
  r'(?:[?&])(?:token|previewToken|bootstrapToken|refresh_token|api_key)=',
  caseSensitive: false,
);

dynamic _cacheSafe(dynamic value) {
  if (value is Map) {
    return {
      for (final e in value.entries)
        if (!{
          'accessToken',
          'refreshToken',
          'apiKey',
          'bootstrapToken',
          'previewToken',
          'providerSecret',
          'clientSecret',
          'authorization',
          'signedUrl',
          'downloadUrl',
          'uploadUrl',
        }.contains(e.key))
          e.key.toString(): _cacheSafe(e.value),
    };
  }
  if (value is List) return value.map(_cacheSafe).toList();
  if (value is String &&
      (value.contains('X-Amz-') ||
          value.contains('Signature=') ||
          value.contains('access_token=') ||
          _signedQuery.hasMatch(value))) {
    return null;
  }
  return value;
}

/// Compares the latest accepted body with its durable sanitized projection.
/// Other copies count toward memory, but do not override that latest body.
Future<List<({String id, int bytes, bool durable})>> inspectHistoryBodies(
  Map<String, List<Map<String, dynamic>>> versions,
  Map<String, String> stored,
) => Isolate.run(() {
  dynamic canonical(dynamic value) {
    if (value is Map) {
      final keys = value.keys.map((key) => '$key').toList()..sort();
      return {for (final key in keys) key: canonical(value[key])};
    }
    if (value is List) return value.map(canonical).toList();
    return value;
  }
  return [for (final entry in versions.entries) (
    id: entry.key,
    bytes: entry.value.fold<int>(0, (sum, row) => sum + utf8.encode(jsonEncode(row)).length),
    durable: stored[entry.key] != null &&
      jsonEncode(canonical(_cacheSafe(entry.value.first))) ==
      jsonEncode(canonical(jsonDecode(stored[entry.key]!))),
  )];
}, debugName: 'raft-history-memory-proof');
