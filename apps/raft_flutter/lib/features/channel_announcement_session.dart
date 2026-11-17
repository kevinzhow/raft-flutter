import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart' show RaftUserError;

import '../data/device_preferences.dart';
import '../data/feature_flag_client_facts.dart';
import '../data/workspace_controller.dart';
import 'channel_announcement_store.dart';

class ChannelAnnouncementSession extends ChangeNotifier {
  ChannelAnnouncementSession._(this.w)
    : store = ChannelAnnouncementStore(
        (id) => w.query('/channels/$id/announcement'),
      ) {
    store.addListener(_storeChanged);
    w.addListener(_changed);
    _events = w.client.events.listen(_event);
    w.services.disposeWithSession(dispose);
    _changed();
  }

  static final _owners = Expando<ChannelAnnouncementSession>();
  static ChannelAnnouncementSession of(WorkspaceController w) {
    final source = w.presentationSource;
    if (source != null) return of(source);
    return _owners[w] ??= ChannelAnnouncementSession._(w);
  }

  static const flagKey = RaftFeatureFlags.channelAnnouncement;
  final WorkspaceController w;
  final ChannelAnnouncementStore store;
  StreamSubscription<RaftEvent>? _events;
  String? _scope;
  int _ticket = 0;
  int epoch = 0;
  bool _ended = false;
  bool enabled = false;
  String? _settingsTarget;
  Future<void> ready = Future.value();

  String get _authority => jsonEncode([
    w.client.origin,
    w.client.generation,
    w.client.user?.id,
    w.server?.id,
    w.server?.string('role'),
    w.server?.json['permissions'],
  ]);

  List<Object?> get _memoryScope => [
    w.client.origin,
    w.client.user?.id,
    w.server?.id,
    w.server?.string('role'),
  ];

  void _storeChanged() {
    if (!_ended) notifyListeners();
  }

  void _changed({bool reevaluate = false}) {
    if (_ended || w.services.isDisposed()) return;
    final authority = _authority;
    if (authority == _scope && !reevaluate) return;
    if (authority != _scope) {
      _scope = authority;
      _settingsTarget = null;
      epoch++;
      enabled =
          w.server != null &&
          w.client.user != null &&
          (FeatureFlagMemory.read(_memoryScope, flagKey) ?? false);
      store.reset();
    }
    final server = w.server;
    if (server != null && w.client.user != null) {
      ready = _evaluate(authority, ++_ticket, server.id);
    }
  }

  Future<void> _evaluate(String authority, int ticket, String server) async {
    try {
      final result = await w.client.post(
        '/feature-flags/evaluate',
        data: featureFlagEvaluateBody(keys: const [flagKey], serverId: server),
      );
      if (_ended || authority != _authority || ticket != _ticket) return;
      final rows = result is Map ? result['evaluations'] : null;
      if (rows is! List) return;
      final matches = rows
          .whereType<Map>()
          .where((row) => row['key'] == flagKey)
          .toList();
      if (matches.length != 1 || matches.single['enabled'] is! bool) return;
      _setEnabled(matches.single['enabled'] as bool);
    } catch (error) {
      if (!_ended &&
          authority == _authority &&
          ticket == _ticket &&
          error is RaftApiException &&
          [401, 403].contains(error.status)) {
        _setEnabled(false);
      }
    }
  }

  void _setEnabled(bool value) {
    FeatureFlagMemory.write(_memoryScope, {flagKey: value});
    if (value == enabled) return;
    enabled = value;
    if (value) {
      notifyListeners();
    } else {
      store.reset();
    }
  }

  Future<void> load(String id) => enabled ? store.load(id) : Future.value();

  void requestSettings(String id) {
    _settingsTarget = id;
    notifyListeners();
  }

  bool takeSettingsTarget(String id) {
    if (_settingsTarget != id) return false;
    _settingsTarget = null;
    return true;
  }

  Future<void> setAnnouncement(String id, String? artifactId) async {
    final authority = _authority;
    final result = await w.command(
      'PATCH',
      '/channels/$id',
      data: {'announcement': artifactId},
    );
    if (_ended || authority != _authority) return;
    if (result is! Map || !result.containsKey('announcement')) {
      throw const RaftUserError(
        'The channel announcement could not be confirmed.',
      );
    }
    final row = w.channelById(id);
    if (row != null && result['id'] == id) {
      w.channelRepository.consumeRealtime('channel:updated', {
        'name': row.name,
        ...Map<String, dynamic>.from(result),
      });
    }
    store.accept(id, result['announcement']);
  }

  void _event(RaftEvent event) {
    final payload = event.payload;
    if (event.name == 'server:updated' || event.name == 'connected') {
      _changed(reevaluate: true);
    } else if (event.name == 'server:features-changed' &&
        payload is Map &&
        payload['serverId'] == w.server?.id) {
      final keys = payload['keys'];
      if (keys is! List || keys.contains(flagKey)) _changed(reevaluate: true);
    } else if (payload is Map) {
      final current = w.channel?.id;
      if (event.name == 'activity:changed' &&
          current != null &&
          store.forChannel(current) != null &&
          payload['serverId'] == w.server?.id) {
        unawaited(load(current));
        return;
      }
      final row = payload['channel'];
      final id =
          payload['channelId'] ??
          payload['id'] ??
          (row is Map ? row['id'] : null);
      if (id is! String) return;
      if (event.name == 'channel:removed' ||
          event.name == 'channel:authority-updated') {
        store.forget(id);
      } else if (event.name == 'channel:updated' && id == w.channel?.id) {
        unawaited(load(id));
      }
    }
  }

  @override
  void dispose() {
    if (_ended) return;
    _ended = true;
    w.removeListener(_changed);
    unawaited(_events?.cancel());
    store.removeListener(_storeChanged);
    store.dispose();
    super.dispose();
  }
}
