import 'dart:convert';

import 'package:sqlite3/sqlite3.dart' show SqliteException;
import 'package:drift/isolate.dart' show DriftRemoteException;
import 'package:raft_client/raft_client.dart' show RaftApiException;

import 'history_capacity.dart';
import 'message_history.dart' show HistoryReadRetired;

enum LocalErrorOperation {
  deviceWrite,
  historyPage,
  liveMessage,
  resumeCursor,
  resumeReplay,
}

enum LocalErrorNotice {
  saveFailed('Local changes could not be saved on this device.'),
  retired('Local history changed while loading. Try again.'),
  full(
    'Device message storage is full. Increase the message history limit in Storage settings.',
  ),
  syncFailed('Message history could not be synced.');

  const LocalErrorNotice(this.message);
  final String message;
}

/// An allowlisted sample: never retains an exception, SQL, arguments, account
/// identity, message content, URLs or absolute paths. Independent of the failing
/// database; bounded in memory for this app run, with no automatic upload.
class LocalErrorSample {
  LocalErrorSample._(this.notice, this.fields);
  final LocalErrorNotice notice;
  final Map<String, Object?> fields;
}

class LocalErrorDiagnostics {
  LocalErrorDiagnostics({this.capacity = 20, DateTime Function()? clock})
    : assert(capacity > 0),
      _clock = clock ?? DateTime.now;

  static final shared = LocalErrorDiagnostics();
  final int capacity;
  final DateTime Function() _clock;
  final _samples = <LocalErrorSample>[];
  final _transitions = <Map<String, Object?>>[];
  String platform = 'unknown';
  int _sequence = 0;

  List<LocalErrorSample> get samples => List.unmodifiable(_samples);

  String capture(
    Object cause,
    StackTrace trace, {
    LocalErrorOperation operation = LocalErrorOperation.deviceWrite,
  }) {
    final notice = cause is HistoryReadRetired
        ? LocalErrorNotice.retired
        : cause is HistoryCapacityExceeded
        ? LocalErrorNotice.full
        : cause is RaftApiException
        ? LocalErrorNotice.syncFailed
        : LocalErrorNotice.saveFailed;
    record(cause, trace, operation: operation, notice: notice);
    return notice.message;
  }

  void lifecycle(String state) {
    if (!const {
          'resumed',
          'inactive',
          'hidden',
          'paused',
          'detached',
        }.contains(state) ||
        _transitions.lastOrNull?['state'] == state) {
      return;
    }
    _transitions.add({
      'state': state,
      'at': _clock().toUtc().toIso8601String(),
    });
    if (_transitions.length > 8) _transitions.removeAt(0);
  }

  LocalErrorSample record(
    Object cause,
    StackTrace trace, {
    required LocalErrorOperation operation,
    required LocalErrorNotice notice,
  }) {
    // Copy only package source locations. Native paths and stack function names
    // are deliberately excluded, even when an exception embeds private data.
    var source = cause;
    final remoteFrames = <String>[];
    // NativeDatabase.createInBackground wraps even a typed SQLite exception.
    // Inspect the typed cause, never the wrapper's toString (it contains SQL).
    for (var i = 0; i < 4 && source is DriftRemoteException; i++) {
      final remote = source.remoteStackTrace;
      if (remote != null) remoteFrames.addAll(_frames(remote));
      source = source.remoteCause;
    }
    final fields = <String, Object?>{
      'code': notice == LocalErrorNotice.syncFailed
          ? 'message-history.syncFailed'
          : 'local-storage.${notice.name}',
      'operation': operation.name,
      'type': _type(source),
      if (!identical(source, cause)) 'wrapperType': _type(cause),
      if (source is SqliteException) ...{
        'sqliteResultCode': source.resultCode,
        'sqliteExtendedCode': source.extendedResultCode,
      },
      if (source case RaftApiException(status: final int status)
          when status >= 100 && status <= 599)
        'httpStatus': status,
      'frames': _frames(trace),
      if (remoteFrames.isNotEmpty)
        'remoteFrames': remoteFrames.toSet().take(12).toList(),
      'lifecycle': [for (final e in _transitions) Map<String, Object?>.of(e)],
    };
    final now = _clock().toUtc().toIso8601String();
    final previous = _samples.lastOrNull;
    if (previous != null &&
        previous.fields['fingerprint'] == jsonEncode(fields)) {
      previous.fields['lastAt'] = now;
      previous.fields['count'] = (previous.fields['count'] as int) + 1;
      return previous;
    }
    final sample = LocalErrorSample._(notice, {
      'id': 'local-storage-${++_sequence}',
      ...fields,
      'fingerprint': jsonEncode(fields),
      'firstAt': now,
      'lastAt': now,
      'count': 1,
    });
    _samples.add(sample);
    if (_samples.length > capacity) _samples.removeAt(0);
    return sample;
  }

  static List<String> _frames(StackTrace trace) => RegExp(
    r'package:(?:raft_flutter|raft_sync|drift|sqlite3)/[a-zA-Z0-9_/.-]+\.dart:\d+(?::\d+)?',
  ).allMatches(trace.toString()).take(12).map((m) => m[0]!).toList();

  static String _type(Object cause) {
    final type = cause.runtimeType.toString();
    return RegExp(r'^[a-zA-Z][a-zA-Z0-9_]{0,79}$').hasMatch(type)
        ? type
        : 'UnknownError';
  }

  LocalErrorSample? forNotice(String message) =>
      _samples.reversed.where((e) => e.notice.message == message).firstOrNull;

  String export({LocalErrorSample? sample}) {
    return const JsonEncoder.withIndent('  ').convert({
      'format': 'raft-local-error-v1',
      'appVersion': const String.fromEnvironment(
        'RAFT_APP_VERSION',
        defaultValue: 'development',
      ),
      'commit': const String.fromEnvironment('RAFT_COMMIT_SHA'),
      'buildNumber': const String.fromEnvironment('RAFT_BUILD_NUMBER'),
      'platform': platform,
      'lifecycle': [for (final e in _transitions) Map<String, Object?>.of(e)],
      'retention': 'current app run; latest $capacity samples',
      'samples': [
        for (final e in sample == null ? _samples : [sample])
          {...e.fields}..remove('fingerprint'),
      ],
    });
  }
}
