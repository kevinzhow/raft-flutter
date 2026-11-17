import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:raft_client/raft_client.dart';

import '../data/device_preferences.dart';
import '../data/feature_flag_client_facts.dart';
import '../data/workspace_controller.dart';
import 'message_task_actions.dart' show TaskV2ConversationsFlag;

/// The two server flags that decide the side area (Web `serverRaftFeatureFlags.ts`):
/// `task_v2_conversations_v0` (Tasks and Files open as cards beside the chat)
/// and `web_preview_v0` (a web page opens in the side area). Both default off
/// until evaluated. A missing or invalid answer keeps the last accepted value
/// instead of turning it off; only a 401/403 does.
///
/// One request per server identity for both keys, remembered on the device so
/// the next launch already has its final layout on the first frame; re-evaluated
/// on `server:updated` / `connected` like [ActivityRolloutFlags].
///
/// Web reads one flag store. `message_task_actions.dart` already evaluates
/// `task_v2_conversations_v0` on demand ([TaskV2ConversationsFlag]); that owner
/// is kept in step instead of asking twice: a true answer here is handed to it
/// (its menus then send no request of their own), and its own true (the server
/// answered `task_v2_use_create`, which is fresher than any evaluation) turns
/// [taskV2] on here.
class ChannelSideFlags extends ChangeNotifier {
  ChannelSideFlags._(this.w) : _menus = TaskV2ConversationsFlag.of(w) {
    w.addListener(changed);
    _menus.addListener(_menusChanged);
    _events = w.client.events.listen((event) {
      if (event.name == 'server:updated' || event.name == 'connected') {
        changed(reevaluate: true);
      }
    });
    w.services.disposeWithSession(dispose);
    changed();
  }

  static final _owners = Expando<ChannelSideFlags>();

  /// The flags of [w]'s presentation (created on first use).
  static ChannelSideFlags of(WorkspaceController w) =>
      _owners[w] ??= ChannelSideFlags._(w);

  static const taskV2Key = RaftFeatureFlags.taskV2Conversations;
  static const webPreviewKey = RaftFeatureFlags.webPreview;
  static const keys = [taskV2Key, webPreviewKey];

  final WorkspaceController w;
  final TaskV2ConversationsFlag _menus;
  StreamSubscription<RaftEvent>? _events;
  String? _scope;
  int _request = 0;
  bool _ended = false;
  Map<String, bool> _enabled = const {};

  /// Task v2: the channel's Tasks and Files open as cards beside the chat
  /// (and no Chat/Tasks/Files tab row). Off until evaluated.
  bool get taskV2 => _enabled[taskV2Key] ?? _menus.enabled;

  /// A web page may open in the side area. Off until evaluated.
  bool get webPreview => _enabled[webPreviewKey] ?? false;

  String get _authority => jsonEncode([
    w.client.origin,
    w.client.generation,
    w.client.user?.id,
    w.server?.id,
    w.server?.string('role'),
  ]);

  /// Device-stable identity of the last evaluation (no session generation).
  List<Object?> get _memoryScope => [
    w.client.origin,
    w.client.user?.id,
    w.server?.id,
    w.server?.string('role'),
  ];

  Map<String, bool> _remembered() => {
    for (final key in keys)
      if (w.server != null && w.client.user != null)
        key: ?FeatureFlagMemory.read(_memoryScope, key),
  };

  /// A new principal, server or role retires the evaluated flags at once; a
  /// re-evaluation under the same identity keeps them until the answer lands.
  void changed({bool reevaluate = false}) {
    if (_ended || w.services.isDisposed()) {
      _retire();
      return;
    }
    final next = _authority;
    final same = _scope == next;
    if (same && !reevaluate) return;
    _scope = next;
    final ticket = ++_request;
    if (!same) {
      final remembered = _remembered();
      if (!mapEquals(remembered, _enabled)) {
        _enabled = remembered;
        notifyListeners();
      }
    }
    final server = w.server;
    if (server != null && w.client.user != null) {
      unawaited(_load(next, ticket, server.id));
    }
  }

  /// Evaluates again now.
  void reevaluate() => changed(reevaluate: true);

  Future<void> _load(String authority, int ticket, String server) async {
    try {
      final value = await w.client.post(
        '/feature-flags/evaluate',
        data: featureFlagEvaluateBody(keys: keys, serverId: server),
      );
      if (_ended || authority != _authority || ticket != _request) return;
      final rows = value is Map ? value['evaluations'] : null;
      if (rows is! List) return;
      final accepted = <String, bool>{};
      // One evaluation per requested key. Missing, invalid or duplicate rows
      // are unknown; they must not replace an accepted value.
      for (final key in keys) {
        final matches = rows
            .whereType<Map>()
            .where((row) => row['key'] == key)
            .toList(growable: false);
        if (matches.length != 1) continue;
        final enabled = matches.single['enabled'];
        if (enabled is bool) accepted[key] = enabled;
      }
      _accept(accepted);
    } catch (error) {
      // Unknown is not permission: only a denial turns accepted flags off.
      if (!_ended &&
          authority == _authority &&
          ticket == _request &&
          error is RaftApiException &&
          [401, 403].contains(error.status)) {
        _accept({for (final key in keys) key: false});
      }
    }
  }

  void _accept(Map<String, bool> accepted) {
    if (accepted.isEmpty) return;
    FeatureFlagMemory.write(_memoryScope, accepted);
    final next = {..._enabled, ...accepted};
    if (!mapEquals(next, _enabled)) {
      _enabled = next;
      notifyListeners();
    }
    if (accepted[taskV2Key] == true) _menus.markEnabled();
  }

  /// The menus' owner heard `task_v2_use_create`: the flag is on, whatever an
  /// older evaluation said.
  void _menusChanged() {
    if (_ended || !_menus.enabled || _enabled[taskV2Key] == true) return;
    _enabled = {..._enabled, taskV2Key: true};
    notifyListeners();
  }

  void _retire() {
    if (_ended) return;
    _ended = true;
    ++_request;
    w.removeListener(changed);
    _menus.removeListener(_menusChanged);
    unawaited(_events?.cancel());
    _events = null;
  }

  @override
  void dispose() {
    _retire();
    super.dispose();
  }
}
