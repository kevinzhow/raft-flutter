import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:raft_ui/raft_ui.dart'
    show RaftbenchReader, RaftbenchReaderPanel;

/// "Agent access" (Web `ReaderAccess.tsx`): `GET /raftbench/readers` when the
/// section mounts, `PUT /raftbench/readers/:agentId` for one grant or revoke
/// at a time, then a re-read. A failed read or write is one error line.
///
/// Owned by the hosted panel, so it lives and dies with the account / server
/// the panel belongs to.
class RaftbenchReaderController extends ChangeNotifier
    implements RaftbenchReaderPanel {
  RaftbenchReaderController({required this.request, required this.current});

  final Future<dynamic> Function(String method, String path, {Object? data})
  request;

  /// False once the account or server the section was mounted for changed.
  final bool Function() current;

  @override
  List<RaftbenchReader> readers = const [];
  @override
  bool failed = false, busy = false;
  int _seq = 0;
  bool _disposed = false;

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() async {
    final seq = ++_seq;
    try {
      final raw = await request('GET', '/raftbench/readers');
      if (seq != _seq || _disposed || !current()) return;
      readers = RaftbenchReader.parseList(raw);
      failed = false;
    } catch (_) {
      if (seq != _seq || _disposed || !current()) return;
      readers = const [];
      failed = true;
    }
    _changed();
  }

  @override
  Future<void> toggle(RaftbenchReader reader) async {
    if (busy || _disposed || !current()) return;
    busy = true;
    failed = false;
    _changed();
    try {
      await request(
        'PUT',
        '/raftbench/readers/${reader.agentId}',
        data: {'enabled': !reader.enabled},
      );
      unawaited(load());
    } catch (_) {
      if (!_disposed) failed = true;
    } finally {
      busy = false;
      _changed();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _seq++;
    super.dispose();
  }
}
