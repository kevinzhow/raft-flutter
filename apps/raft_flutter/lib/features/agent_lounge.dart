// Agent Lounge v0 (Web v1.24 components/agent/agentLounge.ts): the one public
// conversation per agent where the server's members talk with that agent. On
// the wire it is a public channel named `<agent>-lounge` that carries
// `loungeAgentId`; the app always names it after its agent: "{Name}'s
// Lounge", never the raw channel name.
//
// Everything here is gated by the server's `agent_lounge_v0` flag, and a Guest
// never gets it (the server answers 403 for them anyway).
import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/device_preferences.dart';
import '../data/feature_flag_client_facts.dart';
import '../data/workspace_controller.dart';
import 'agent_metadata_projection.dart' show agentRowName;
import 'private_route_guard.dart' show workspaceAuthority;

/// `agent_lounge_v0`, evaluated once per server identity and remembered on the
/// device so the next launch's first frame already has its final layout
/// (Web `useServerFeatureFlag(AGENT_LOUNGE_FLAG_KEY)`: loading or unknown is
/// off). A transient failure keeps the accepted value; a 401/403 turns it off.
///
/// Web evaluates it once for the server in its flag store, not per panel: the
/// workspace shell calls [evaluate] once; every other reader (the profile, the
/// headers) only reads the remembered or evaluated value and sends nothing.
class AgentLoungeFlag extends ChangeNotifier {
  AgentLoungeFlag._(this.w) {
    w.addListener(_changed);
    _events = w.client.events.listen((event) {
      if (_evaluating &&
          (event.name == 'server:updated' || event.name == 'connected')) {
        _changed(reevaluate: true);
      }
    });
    w.services.disposeWithSession(dispose);
    _changed();
  }

  static final _owners = Expando<AgentLoungeFlag>();

  /// The flag of [w]'s presentation (created on first use).
  static AgentLoungeFlag of(WorkspaceController w) =>
      _owners[w] ??= AgentLoungeFlag._(w);

  static const key = RaftFeatureFlags.agentLounge;

  final WorkspaceController w;
  StreamSubscription<RaftEvent>? _events;
  String? _scope;
  int _request = 0;
  bool _ended = false;
  bool _enabled = false;
  bool _evaluating = false;

  /// Starts evaluating the flag for the server (idempotent). Called by the
  /// workspace shell, the one place that owns the server's flags.
  void evaluate() {
    if (_evaluating || _ended) return;
    _evaluating = true;
    _scope = null;
    _changed();
  }

  /// The server has Lounges on (Web `useServerFeatureFlag(...).enabled`).
  bool get flagEnabled => _enabled;

  /// Flag on and the viewer is not a Guest (Web `useAgentLoungeEnabled`).
  bool get enabled => _enabled && w.server?.string('role') != 'guest';

  String get _authority => jsonEncode([
    w.client.origin,
    w.client.generation,
    w.client.user?.id,
    w.server?.id,
  ]);

  List<Object?> get _memoryScope => [
    w.client.origin,
    w.client.user?.id,
    w.server?.id,
    w.server?.string('role'),
  ];

  bool _remembered() => w.server != null && w.client.user != null
      ? FeatureFlagMemory.read(_memoryScope, key) ?? false
      : false;

  void _changed({bool reevaluate = false}) {
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
      if (remembered != _enabled) {
        _enabled = remembered;
        notifyListeners();
      }
    }
    final server = w.server;
    if (_evaluating && server != null && w.client.user != null) {
      unawaited(_load(next, ticket, server.id));
    }
  }

  Future<void> _load(String authority, int ticket, String server) async {
    try {
      final value = await w.client.post(
        '/feature-flags/evaluate',
        data: featureFlagEvaluateBody(keys: const [key], serverId: server),
      );
      if (_ended || authority != _authority || ticket != _request) return;
      final rows = value is Map ? value['evaluations'] : null;
      if (rows is! List) return;
      final matches = rows
          .whereType<Map>()
          .where((row) => row['key'] == key)
          .toList(growable: false);
      if (matches.length != 1) return;
      final enabled = matches.single['enabled'];
      if (enabled is bool) _accept(enabled);
    } catch (error) {
      // Unknown is not permission: only a denial turns the flag off.
      if (!_ended &&
          authority == _authority &&
          ticket == _request &&
          error is RaftApiException &&
          [401, 403].contains(error.status)) {
        _accept(false);
      }
    }
  }

  void _accept(bool enabled) {
    FeatureFlagMemory.write(_memoryScope, {key: enabled});
    if (enabled == _enabled) return;
    _enabled = enabled;
    notifyListeners();
    // Surfaces that rebuild on the controller (the profile, the headers) pick
    // the new state up with it.
    if (!w.services.isDisposed()) w.notifyListeners();
  }

  void _retire() {
    if (_ended) return;
    _ended = true;
    ++_request;
    w.removeListener(_changed);
    unawaited(_events?.cancel());
    _events = null;
  }

  @override
  void dispose() {
    _retire();
    super.dispose();
  }
}

/// Whether an agent offers a Lounge: not a deleted agent, and not someone's
/// personal assistant (it works for one person; a room for the whole server
/// makes no sense for it). Web `agentOffersLounge`.
bool agentOffersLounge(Map<String, dynamic> agent) =>
    agent['deletedAt'] == null && agent['assistantOwnerUserId'] == null;

/// The viewer may open [agent]'s Lounge from where it is shown: the server has
/// Lounges on, the viewer is not a Guest and the agent offers one.
bool canOpenAgentLounge(WorkspaceController w, Map<String, dynamic> agent) =>
    AgentLoungeFlag.of(w).enabled && agentOffersLounge(agent);

/// A channel row that is an agent's Lounge (Web `isLoungeChannel`).
bool isLoungeChannel(RaftChannel? channel) => channel?.loungeAgentId != null;

/// The agent's name from a Lounge's own row when the directory does not have
/// it (Web `agentNameFromLoungeChannel`): the channel is `<agent>-lounge`.
String _agentNameFromLoungeChannel(String channelName) =>
    channelName.replaceFirst(RegExp(r'-lounge$'), '');

/// The name a Lounge is shown under: its agent's display name, else the
/// agent's name from the channel name (Web `useLoungeAgentName`).
String loungeAgentName(WorkspaceController w, RaftChannel channel) {
  final agent = w.services.entityDirectory.agent(channel.loungeAgentId ?? '');
  if (agent != null) return agentRowName(agent);
  return _agentNameFromLoungeChannel(channel.name);
}

/// "{Name}'s Lounge" (`agent.lounge.title`).
String loungeTitle(
  BuildContext context,
  WorkspaceController w,
  RaftChannel channel,
) => raftFormat(context, "{name}'s Lounge", {
  'name': loungeAgentName(w, channel),
});

/// The channel row POST /agents/:id/lounge answers, as the workspace keeps it
/// (Web `openLounge`): the answer's own `joined` / `canPost` win over the row's,
/// and the row always names its agent, even from a server that left
/// `loungeAgentId` off it.
RaftChannel? loungeRowFromOpenAnswer(Object? answer, String agentId) {
  if (answer is! Map || answer['channel'] is! Map) return null;
  final row = Map<String, dynamic>.from(answer['channel'] as Map);
  if (row['id'] is! String || (row['id'] as String).isEmpty) return null;
  final joined = answer['joined'], canPost = answer['canPost'];
  return RaftChannel({
    ...row,
    'loungeAgentId': row['loungeAgentId'] ?? agentId,
    'joined': ?(joined is bool ? joined : null),
    'canPost': ?(canPost is bool ? canPost : null),
  });
}

final _opening = Expando<Map<String, Future<bool>>>();

/// Opens an agent's Lounge (POST /agents/:id/lounge makes it the first time)
/// and goes to it (Web `useOpenAgentLounge`). A failure says so in a toast and
/// stays where it is. Concurrent opens of one agent share one request.
Future<bool> openAgentLounge(
  BuildContext context,
  WorkspaceController w,
  String agentId,
) {
  final held = (_opening[w] ??= {});
  final pending = held[agentId];
  if (pending != null) return pending;
  final request = (() async {
    final scope = workspaceAuthority(w);
    final RaftChannel row;
    try {
      final row0 = loungeRowFromOpenAnswer(
        await w.client.post('/agents/$agentId/lounge'),
        agentId,
      );
      if (row0 == null) throw const RaftApiException('No Lounge in the answer');
      row = row0;
    } catch (_) {
      if (context.mounted && scope == workspaceAuthority(w)) {
        showRaftToast(context, "Couldn't open the Lounge. Try again.");
      }
      return false;
    }
    if (scope != workspaceAuthority(w)) return false;
    // The row lives with the workspace's own, joined to its realtime room.
    w.putSharedChannelRow(row);
    w.client.joinChannel(row.id);
    w.closeProfile();
    w.closeThread();
    await w.jumpToMessage(row.id, null);
    return true;
  })();
  held[agentId] = request;
  return request.whenComplete(() => held.remove(agentId));
}
