import 'dart:async';

import 'package:flutter/foundation.dart';

class ChannelAnnouncement {
  const ChannelAnnouncement({
    required this.artifactId,
    required this.title,
    required this.version,
    required this.updatedAt,
    required this.updatedBy,
    required this.seen,
    this.note,
    this.excerpt,
  });

  final String artifactId, title, updatedAt;
  final int version;
  final Map<String, dynamic> updatedBy;
  final bool seen;
  final String? note, excerpt;

  static ChannelAnnouncement? parse(Object? value) {
    if (value is! Map ||
        value['artifactId'] is! String ||
        value['title'] is! String ||
        value['version'] is! int ||
        value['updatedAt'] is! String ||
        value['updatedBy'] is! Map ||
        value['seen'] is! bool) {
      return null;
    }
    return ChannelAnnouncement(
      artifactId: value['artifactId'] as String,
      title: value['title'] as String,
      version: value['version'] as int,
      updatedAt: value['updatedAt'] as String,
      updatedBy: Map<String, dynamic>.from(value['updatedBy'] as Map),
      seen: value['seen'] as bool,
      note: value['note'] is String ? value['note'] as String : null,
      excerpt: value['excerpt'] is String ? value['excerpt'] as String : null,
    );
  }
}

class ChannelAnnouncementStore extends ChangeNotifier {
  ChannelAnnouncementStore(this._fetch);

  final Future<dynamic> Function(String channelId) _fetch;
  final _values = <String, ChannelAnnouncement?>{};
  final _versions = <String, int>{};
  final _pending = <String, Future<void>>{};
  int _epoch = 0;
  bool _disposed = false;

  ChannelAnnouncement? forChannel(String id) => _values[id];

  void accept(String id, Object? value) {
    if (_disposed) return;
    _versions[id] = (_versions[id] ?? 0) + 1;
    _values[id] = ChannelAnnouncement.parse(value);
    notifyListeners();
  }

  Future<void> load(String id) {
    final existing = _pending[id];
    if (existing != null) return existing;
    final epoch = _epoch;
    final version = _versions[id] ?? 0;
    late final Future<void> request;
    request = (() async {
      try {
        final result = await _fetch(id);
        if (_disposed || epoch != _epoch || version != (_versions[id] ?? 0)) {
          return;
        }
        if (result is Map && result.containsKey('announcement')) {
          final value = result['announcement'];
          if (value == null || ChannelAnnouncement.parse(value) != null) {
            accept(id, value);
          }
        }
      } catch (_) {
        // Keep the last accepted announcement on a failed refresh.
      } finally {
        if (identical(_pending[id], request)) _pending.remove(id);
      }
    })();
    _pending[id] = request;
    return request;
  }

  void reset() {
    if (_disposed) return;
    _epoch++;
    _pending.clear();
    _versions.clear();
    _values.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _epoch++;
    super.dispose();
  }
}
