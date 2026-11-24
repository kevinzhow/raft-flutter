import 'dart:convert';

import 'package:raft_client/raft_client.dart';

import 'conversation_window.dart';

/// Persisted rows are a bounded accepted tail/history window, never an
/// authorization grant or a permalink window. Authorization is checked by the
/// controller before hydration; origin/principal/workspace are database keys.
const messageWindowLimit = 500;

final _permissionsAuthorityCache = Expando<String>(
  'server permissions authority',
);

String serverPermissionsAuthority(dynamic permissions) {
  if (permissions is Map || permissions is List) {
    return _permissionsAuthorityCache[permissions as Object] ??=
        _canonicalAuthority(permissions);
  }
  return _canonicalAuthority(permissions);
}

String _canonicalAuthority(Object? value) {
  final out = StringBuffer();
  void write(Object? v) {
    if (v == null) {
      out.write('n;');
    } else if (v is bool || v is num) {
      out.write('v:$v;');
    } else if (v is String) {
      out.write('s:${v.length}:$v;');
    } else if (v is List) {
      out.write('l:${v.length}:[');
      for (final item in v) {
        write(item);
      }
      out.write(']');
    } else if (v is Map) {
      out.write('m:${v.length}:{');
      for (final entry in v.entries) {
        write(entry.key);
        write(entry.value);
      }
      out.write('}');
    } else {
      out.write('o:$v;');
    }
  }

  write(value);
  return out.toString();
}

MessageWindowAuthority? resolveMessageWindowAuthority(
  String navigationAuthority,
  int generation,
  String replyToken,
  RaftRecord server,
  RaftChannel resource,
  AcceptedMessageWindow? accepted,
) {
  final authority = messageWindowAuthority(
    server.string('role'),
    resource.json,
  );
  if (accepted != null && !accepted.matches(authority, replyToken)) {
    return null;
  }
  return (
    navigationAuthority,
    generation,
    replyToken,
    authority,
    serverPermissionsAuthority(server.json['permissions']),
  );
}

String messageWindowAuthority(String? role, Map<String, dynamic> channel) =>
    jsonEncode([
      role,
      channel['id'],
      channel['type'],
      channel['joined'],
      channel['channelCapabilities'],
    ]);

List<Map<String, dynamic>> acceptedWindowRows(dynamic value, String id) {
  if (value is! List || value.length > messageWindowLimit) return const [];
  final result = <Map<String, dynamic>>[];
  final ids = <String>{};
  for (final raw in value) {
    if (raw is! Map ||
        raw['id'] is! String ||
        raw['channelId'] != id ||
        BigInt.tryParse('${raw['seq']}') == null ||
        !ids.add(raw['id'])) {
      return const [];
    }
    result.add(Map<String, dynamic>.from(raw));
  }
  return result;
}

/// The refreshed first page is authoritative over its own range. Preserve only
/// already accepted older history, so deleted rows inside the refreshed page do
/// not survive by union and a stale context cannot extend the live window.
Set<String> reconcileTailWindow(
  Iterable<Map<String, dynamic>> retained,
  Iterable<Map<String, dynamic>> page,
) {
  final fresh = page.toList();
  if (fresh.isEmpty) return {};
  final first = fresh
      .map((row) => BigInt.tryParse('${row['seq']}'))
      .whereType<BigInt>()
      .fold<BigInt?>(null, (a, b) => a == null || b < a ? b : a);
  return {
    if (first != null)
      for (final row in retained)
        if (BigInt.tryParse('${row['seq']}') case final seq?)
          if (seq < first) row['id'] as String,
    for (final row in fresh) row['id'] as String,
  };
}

/// Boundary facts for one accepted window. A null contextNewer is a tail.
class AcceptedMessageWindow {
  AcceptedMessageWindow(
    this.authority,
    this.hasMore,
    this.token,
    this.historyLimited,
    this.contextNewer,
  );
  final String authority, token;
  final bool hasMore, historyLimited;
  final bool? contextNewer;
  AcceptedMessageWindow withContext(bool? value) =>
      AcceptedMessageWindow(authority, hasMore, token, historyLimited, value);

  bool matches(String? authority, String? token) =>
      this.authority == authority && this.token == token;
}
