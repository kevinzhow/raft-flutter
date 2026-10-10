import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'search_memory.dart';

/// Device-local disclosure choices. The record contains booleans only, scoped
/// to API origin/account/workspace; names, messages and directory rows stay out.
class SidebarDisclosureStore extends ChangeNotifier {
  SidebarDisclosureStore({SearchMemoryStorage? storage})
    : storage = storage ?? PreferencesSearchMemoryStorage();
  final SearchMemoryStorage storage;
  final Map<String, bool> collapsed = {};
  String? key, authority;
  int revision = 0;
  bool closed = false;
  Future<void> writes = Future.value();

  Future<void> bind({
    required String origin,
    required String? principal,
    required String? server,
    required String scope,
  }) async {
    final nextKey = principal == null || server == null
        ? null
        : 'raft:sidebar-disclosure:${jsonEncode([origin, principal, server])}';
    if (key == nextKey && authority == scope) return;
    key = nextKey;
    authority = scope;
    final ticket = ++revision;
    collapsed.clear();
    if (nextKey == null) {
      notifyListeners();
      return;
    }
    // Preloaded preferences answer in the same frame, so a collapsed section
    // is never rendered expanded first.
    final Object sync = storage;
    if (sync is SynchronousSearchMemoryStorage && sync.ready) {
      String? stored;
      try {
        stored = sync.readSync(nextKey);
      } catch (_) {}
      _adopt(stored);
      notifyListeners();
      return;
    }
    notifyListeners();
    String? raw;
    try {
      raw = await storage.read(nextKey);
    } catch (_) {
      return;
    }
    if (closed || ticket != revision || key != nextKey || authority != scope) {
      return;
    }
    _adopt(raw);
    notifyListeners();
  }

  void _adopt(String? raw) {
    try {
      final value = raw == null ? null : jsonDecode(raw);
      if (value is Map) {
        for (final entry in value.entries.take(256)) {
          if (entry.key is String &&
              (entry.key as String).length <= 128 &&
              entry.value is bool) {
            collapsed[entry.key as String] = entry.value as bool;
          }
        }
      }
    } catch (_) {
      // Malformed optional device preferences retain expanded defaults.
    }
  }

  bool setExpanded(String scope, String group, bool expanded) {
    if (closed || key == null || authority != scope || group.length > 128) {
      return false;
    }
    revision++;
    collapsed[group] = !expanded;
    final captured = key!;
    final encoded = jsonEncode(collapsed);
    writes = writes.then((_) async {
      try {
        await storage.write(captured, encoded);
      } catch (_) {
        // The accepted local choice remains usable without storage.
      }
    });
    notifyListeners();
    return true;
  }

  @override
  void dispose() {
    closed = true;
    revision++;
    super.dispose();
  }
}
