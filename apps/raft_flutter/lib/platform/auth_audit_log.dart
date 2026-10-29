import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:raft_client/raft_client.dart';

/// A local ring buffer of sign-in diagnostics: every sign-out with its reason
/// and every credential failure that kept the session. It holds no token,
/// password, email address or response body (see [sanitizeAuditDetail]) and
/// never leaves the device unless the user copies it into a report.
///
/// The foreground and background workers append to one file (small appends are
/// atomic); the foreground trims it to [capacity] lines when it opens.
class AuthAuditLog implements SessionAuditSink {
  AuthAuditLog({this.file, this.capacity = 200, DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  /// The process-wide log, backed by the app support directory.
  static final AuthAuditLog shared = AuthAuditLog();

  /// A fresh in-memory log for tests.
  @visibleForTesting
  static AuthAuditLog memory({int capacity = 200}) =>
      AuthAuditLog(capacity: capacity);

  final File? file;
  final int capacity;
  final DateTime Function() _clock;
  final List<SessionAuditEvent> _ring = [];
  Future<void> _io = Future<void>.value();
  Future<File?>? _resolved;
  bool _opened = false;

  List<SessionAuditEvent> get events => List.unmodifiable(_ring);

  Future<File?> _file() => _resolved ??= () async {
    if (file != null) return file;
    if (!_persistent) return null;
    try {
      final dir = await getApplicationSupportDirectory();
      return File(p.join(dir.path, 'auth-audit.jsonl'));
    } catch (_) {
      return null;
    }
  }();

  /// Loads the persisted entries (once) and trims the file to [capacity].
  Future<void> open() => _io = _io.then((_) async {
    if (_opened) return;
    _opened = true;
    try {
      final target = await _file();
      if (target == null || !await target.exists()) return;
      final loaded = <SessionAuditEvent>[];
      for (final line in await target.readAsLines()) {
        try {
          loaded.add(
            SessionAuditEvent.fromJson(
              Map<String, dynamic>.from(jsonDecode(line) as Map),
            ),
          );
        } catch (_) {
          // A torn or foreign line is skipped, never fatal.
        }
      }
      final merged = [...loaded, ..._ring]
        ..sort((a, b) => a.at.compareTo(b.at));
      _ring
        ..clear()
        ..addAll(
          merged.length > capacity
              ? merged.sublist(merged.length - capacity)
              : merged,
        );
      if (loaded.length > capacity) {
        await target.writeAsString(
          '${_ring.map((e) => jsonEncode(e.toJson())).join('\n')}\n',
        );
      }
    } catch (_) {
      // Diagnostics are best effort.
    }
  });

  @override
  void record(SessionAuditEvent event) {
    try {
      _ring.add(event);
      if (_ring.length > capacity) {
        _ring.removeRange(0, _ring.length - capacity);
      }
      if (file == null && !_persistent) return;
      final line = '${jsonEncode(event.toJson())}\n';
      _io = _io.then((_) async {
        try {
          final target = await _file();
          await target?.writeAsString(line, mode: FileMode.append);
        } catch (_) {}
      });
    } catch (_) {
      // Never let diagnostics affect authentication.
    }
  }

  /// Only [shared] persists by default; test instances stay in memory unless a
  /// [file] is given.
  bool get _persistent => identical(this, shared);

  /// Records an app-level event (not raised by [RaftClient]).
  void note(String kind, String reason, {String? detail}) => record(
    SessionAuditEvent(
      kind,
      reason,
      detail: detail == null ? null : sanitizeAuditDetail(detail),
      at: _clock().toUtc(),
    ),
  );

  /// The text a user pastes into a feedback report, newest last.
  Future<String> export({String? appVersion}) async {
    await open();
    await _io;
    final out = StringBuffer('Raft sign-in diagnostics');
    if (appVersion != null) out.write(' ($appVersion)');
    out.writeln(
      '\nPlatform: ${defaultTargetPlatform.name}. '
      'Entries: ${_ring.length}. No tokens or account data are included.',
    );
    if (_ring.isEmpty) out.writeln('No sign-in events recorded.');
    for (final e in _ring) {
      out.writeln(e);
    }
    return out.toString();
  }
}
