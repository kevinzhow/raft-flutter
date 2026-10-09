import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'search_memory.dart';

/// Source layout/mobileAppBadge.ts: a per-human, per-device "until seen" flag.
/// Origin is the browser localStorage boundary; workspace switches preserve it.
/// This stores one local boolean, never server data or authentication material.
class SourceMobileAppBadge extends ChangeNotifier {
  SourceMobileAppBadge({SearchMemoryStorage? storage})
    : storage = storage ?? PreferencesSearchMemoryStorage();
  final SearchMemoryStorage storage;
  String? key;
  bool hasAttention = false, closed = false;
  int revision = 0;
  Future<void> writes = Future.value();

  static String storageKey(String origin, String principal) =>
      'raft:mobile-app:seen:${jsonEncode([origin, principal])}';

  Future<void> bind(String origin, String? principal) async {
    if (closed) return;
    final next = principal == null || principal.isEmpty
        ? null
        : storageKey(origin, principal);
    if (next == key) return;
    key = next;
    final ticket = ++revision;
    hasAttention = false;
    notifyListeners();
    if (next == null) return;
    String? seen;
    try {
      seen = await storage.read(next);
    } catch (_) {
      // Source optional localStorage failures fall back to unseen.
    }
    if (closed || ticket != revision || next != key) return;
    hasAttention = seen != '1';
    notifyListeners();
  }

  /// Only opening the actual Mobile App resource consumes its announcement.
  bool markSeen(String? captured) {
    if (closed || captured == null || captured != key) return false;
    revision++;
    hasAttention = false;
    notifyListeners();
    writes = writes.then((_) async {
      try {
        await storage.write(captured, '1');
      } catch (_) {
        // The current session still remembers the actual open.
      }
    });
    return true;
  }

  @override
  void dispose() {
    closed = true;
    revision++;
    super.dispose();
  }
}
