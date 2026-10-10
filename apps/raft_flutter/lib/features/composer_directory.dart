import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import '../data/workspace_entity_directory.dart';
import 'agent_avatar_projection.dart';
import 'agent_metadata_projection.dart';
import 'message_agent_presentation.dart';
import 'private_route_guard.dart';
import 'sender_avatar_projection.dart';

/// One channel roster as returned by `/channels/:id/members`, together with
/// the channel authority it was read under.
class _ComposerRoster {
  const _ComposerRoster(this.channel, this.humans, this.agents);
  final Map<String, dynamic> channel;
  final List<Map<String, dynamic>> humans, agents;
}

Map<String, dynamic> _channelAuthority(RaftChannel channel) => {
  'type': channel.type,
  'joined': channel.joined,
  'channelCapabilities': channel.json['channelCapabilities'],
};

/// Server-scoped composer data shared by every composer over the same entity
/// directory (main chat, thread, borrowed editors): per-channel rosters and
/// the resource-reference flag/apps. Everything is cleared only when the
/// server-level identity ([directoryAuthority]) changes; a roster is dropped
/// when its channel authority is reduced. Revalidation keeps the accepted
/// roster until the replacement is accepted; stale responses are rejected.
class _ComposerShared extends ChangeNotifier {
  String? authority;
  int epoch = 0, revision = 0, _ticket = 0;
  final rosters = <String, _ComposerRoster>{};
  final _pending = <String, (int, Future<void>)>{};
  bool? resources;
  Future<void>? _resourcesPending;
  List<Map<String, dynamic>> apps = const [];

  /// Adopts [next]; returns true when the previous identity's data was cleared.
  bool sync(String next) {
    if (authority == next) return false;
    authority = next;
    epoch++;
    rosters.clear();
    _pending.clear();
    resources = null;
    _resourcesPending = null;
    apps = const [];
    revision++;
    return true;
  }

  void _changed() {
    revision++;
    notifyListeners();
  }

  /// Drops [channel]'s roster when its membership/capabilities were reduced
  /// since the roster was read. Returns true when an entry was dropped.
  bool validate(RaftChannel channel) {
    final roster = rosters[channel.id];
    if (roster == null ||
        !channelAuthorityReduced(roster.channel, _channelAuthority(channel))) {
      return false;
    }
    rosters.remove(channel.id);
    _pending.remove(channel.id);
    revision++;
    return true;
  }

  void drop(String channelId) {
    _pending.remove(channelId);
    if (rosters.remove(channelId) != null) _changed();
  }

  Future<void> loadRoster(WorkspaceController w, RaftChannel channel) {
    final authority = directoryAuthority(w);
    sync(authority);
    final id = channel.id;
    final existing = _pending[id];
    if (existing != null) return existing.$2;
    final epoch = this.epoch, ticket = ++_ticket;
    final readUnder = _channelAuthority(channel);
    bool current() =>
        epoch == this.epoch &&
        directoryAuthority(w) == authority &&
        _pending[id]?.$1 == ticket;
    late final Future<void> pending;
    pending = (() async {
      try {
        final roster = await w.query('/channels/$id/members');
        if (!current()) return;
        final live = w.channel?.id == id
            ? w.channel
            : w.channels.where((c) => c.id == id).firstOrNull;
        if (live != null &&
            channelAuthorityReduced(readUnder, _channelAuthority(live))) {
          return;
        }
        List<Map<String, dynamic>> rows(dynamic raw) => [
          for (final row in raw is List ? raw : const [])
            if (row is Map) Map<String, dynamic>.from(row),
        ];
        rosters[id] = _ComposerRoster(
          readUnder,
          rows(roster is Map ? roster['humans'] : null),
          rows(roster is Map ? roster['agents'] : null),
        );
        _changed();
      } catch (error) {
        /* A failed roster never expands private channel authority. */
        if (current() &&
            error is RaftApiException &&
            [401, 403, 404].contains(error.status)) {
          rosters.remove(id);
          _changed();
        }
      } finally {
        if (_pending[id]?.$1 == ticket) _pending.remove(id);
      }
    })();
    _pending[id] = (ticket, pending);
    return pending;
  }

  /// Source useServerFeatureFlag + installed apps: once per server identity.
  Future<void> loadResources(WorkspaceController w) {
    final authority = directoryAuthority(w);
    sync(authority);
    final server = w.server;
    if (server == null) return Future.value();
    final epoch = this.epoch;
    bool current() => epoch == this.epoch && directoryAuthority(w) == authority;
    return _resourcesPending ??= (() async {
      try {
        final flags = await w.client.post(
          '/feature-flags/evaluate',
          data: {
            'keys': ['composer_resource_references_v0'],
            'serverId': server.id,
            'platform': defaultTargetPlatform == TargetPlatform.android
                ? 'mobile'
                : 'web',
          },
        );
        if (!current()) return;
        final enabled =
            flags is Map &&
            flags['evaluations'] is List &&
            (flags['evaluations'] as List).whereType<Map>().any(
              (f) =>
                  f['key'] == 'composer_resource_references_v0' &&
                  f['enabled'] == true,
            );
        resources = enabled;
        if (!enabled) {
          _changed();
          return;
        }
        if (w.can('viewMachines')) {
          final computers = w.entityDirectory.state(
            WorkspaceEntityKind.computers,
          );
          if (!computers.loaded) {
            await w.entityDirectory.refresh(WorkspaceEntityKind.computers);
            if (!current()) return;
          }
        }
        _changed();
        final out = await w.query('/servers/${server.id}/apps');
        if (!current()) return;
        apps = [
          for (final row
              in (out is Map ? out['apps'] as List? ?? [] : const [])
                  .whereType<Map>())
            if (row['appId'] is String) Map<String, dynamic>.from(row),
        ];
        _changed();
      } catch (_) {
        /* Enabled but unreadable resources do not become suggestions. */
        if (current()) _resourcesPending = null;
      }
    })();
  }
}

final _sharedComposerData = Expando<_ComposerShared>('composer directory');

/// Autocomplete projection. People come from the shared, server-scoped entity
/// directory (Source agentStore/serverStore members) and are available at the
/// first frame; only the channel roster (Source useChannelMembers: in-channel
/// grouping and private/joint eligibility) is per channel. Rosters are read
/// when a channel is opened, cached per channel and revalidated in place, so
/// an open popup never reflows while data is replaced. Private/joint surfaces
/// use only their current membership projection; resource references require
/// the real server flag before either computers or installed apps are shown.
class ComposerDirectory extends ChangeNotifier {
  ComposerDirectory(this.w, {this.agentPresentation})
    : _shared = _sharedComposerData[w.entityDirectory] ??= _ComposerShared() {
    w.addListener(changed);
    w.entityDirectory.addListener(changed);
    _shared.addListener(changed);
    events = w.client.events.listen(event);
    changed();
  }
  final WorkspaceController w;
  final _ComposerShared _shared;
  StreamSubscription<RaftEvent>? events;

  /// Borrow the chat's existing authorized activity adapter; never owns it.
  final MessageAgentPresentation? agentPresentation;
  String? scope, channelId;
  Object? stamp;
  bool ended = false;
  List<RaftComposerSuggestion> people = [];
  List<RaftComposerSuggestion> get suggestions => [
    ...people,
    for (final c in w.channels)
      if (!c.archived && ['channel', 'private', 'joint'].contains(c.type))
        RaftComposerSuggestion(
          type: 'channel',
          id: c.id,
          name: c.name,
          detail: c.description.isEmpty ? null : c.description,
        ),
  ];

  void changed() {
    if (ended) return;
    final authority = directoryAuthority(w);
    _shared.sync(authority);
    scope = authority;
    final channel = w.server == null ? null : w.channel;
    if (channel != null) _shared.validate(channel);
    if (channel?.id != channelId) {
      channelId = channel?.id;
      // Source MessageInput/ChatPanel read the roster when the channel opens;
      // a visited channel shows its cached roster and revalidates in place.
      if (channel != null) {
        Timer.run(() {
          if (!ended && w.channel?.id == channel.id) {
            unawaited(_shared.loadRoster(w, w.channel!));
          }
        });
      }
    }
    final resources = _shared.resources == true;
    final computers = resources && w.can('viewMachines')
        ? w.entityDirectory.rows(WorkspaceEntityKind.computers)
        : const <Map<String, dynamic>>[];
    final next = (
      authority,
      channel?.id,
      channel?.type,
      w.client.user?.json['name'],
      w.entityDirectory.authorRevision,
      _shared.revision,
      resources,
      Object.hashAll([for (final c in computers) '${c['id']}:${c['name']}']),
    );
    if (next == stamp) return;
    stamp = next;
    people = channel == null ? [] : build(authority, channel, computers);
    notifyListeners();
  }

  void event(RaftEvent event) {
    if (ended) return;
    if (!['channel:members-updated', 'channel:removed'].contains(event.name)) {
      return;
    }
    final payload = event.payload;
    final id = payload is Map && payload['channelId'] is String
        ? payload['channelId'] as String
        : w.channel?.id;
    if (id == null) return;
    if (event.name == 'channel:removed') return _shared.drop(id);
    final channel = w.channel;
    if (channel?.id == id) unawaited(_shared.loadRoster(w, channel!));
    // Another cached channel revalidates when it is opened again.
  }

  /// Source MessageInput allCandidates: current user, server members, agents,
  /// then the channel roster (which only marks/extends existing entries).
  List<RaftComposerSuggestion> build(
    String authority,
    RaftChannel channel,
    List<Map<String, dynamic>> computers,
  ) {
    final entries = <String, RaftComposerSuggestion>{};
    final memberIds = <String>{};
    void add(Iterable<Map<String, dynamic>> raw, String type) {
      for (final value in raw) {
        final id = type == 'user'
            ? value['userId'] ?? value['id']
            : value['id'];
        final name = value['name'];
        if (id is! String ||
            name is! String ||
            value['deletedAt'] != null ||
            !RegExp(r'^[\p{L}\p{N}_-]+$', unicode: true).hasMatch(name)) {
          continue;
        }
        final key = '$type:$id';
        final previous = entries[key];
        final source = projectSenderAvatar(
          origin: w.client.origin,
          senderId: id,
          senderType: type,
          agents: type == 'agent' ? [value] : const [],
          members: type == 'user'
              ? [
                  {...value, 'userId': id},
                ]
              : const [],
          currentUser: w.client.user?.json,
        );
        final row = Map<String, dynamic>.of(value);
        entries[key] = RaftComposerSuggestion(
          type: type,
          id: id,
          name: name,
          title: value['displayName'] as String? ?? previous?.title,
          detail: value['description'] as String? ?? previous?.detail,
          inChannel: memberIds.contains(key),
          avatar: _ComposerCandidateAvatar(
            directory: this,
            authority: authority,
            name: name,
            type: type,
            source: source,
            row: row,
          ),
          mutedAvatar: _ComposerCandidateAvatar(
            directory: this,
            authority: authority,
            name: name,
            type: type,
            source: source,
            row: row,
            muted: true,
          ),
        );
      }
    }

    final roster = _shared.rosters[channel.id];
    if (roster != null) {
      for (final row in roster.humans) {
        final id = row['userId'] ?? row['id'];
        if (id is String) memberIds.add('user:$id');
      }
      for (final row in roster.agents) {
        if (row['id'] is String) memberIds.add('agent:${row['id']}');
      }
    }
    if (!['private', 'joint'].contains(channel.type)) {
      final user = w.client.user;
      if (user != null) {
        add([
          {...user.json, 'id': user.id},
        ], 'user');
      }
      add(w.entityDirectory.authorMembers, 'user');
      add(w.entityDirectory.authorAgents, 'agent');
    }
    if (roster != null) {
      add(roster.humans, 'user');
      add(roster.agents, 'agent');
    }
    if (_shared.resources == true) {
      for (final row in computers) {
        if (row['isComputer'] != true ||
            row['id'] is! String ||
            row['name'] is! String) {
          continue;
        }
        final name = row['name'] as String;
        entries['computer:${row['id']}'] = RaftComposerSuggestion(
          type: 'computer',
          id: row['id'],
          name: name,
          referenceText: '[@${_label(name)}](<computer:${row['id']}>)',
        );
      }
      for (final row in _shared.apps) {
        final name = row['displayName'] is String
            ? row['displayName'] as String
            : row['appId'] as String;
        entries['app:${row['appId']}'] = RaftComposerSuggestion(
          type: 'app',
          id: row['appId'],
          name: row['appId'],
          title: name,
          referenceText: '[@${_label(name)}](<app:${row['appId']}>)',
        );
      }
    }
    return entries.values.toList();
  }

  void request(String prefix) {
    if (ended || prefix != '@' || w.channel == null || w.server == null) {
      return;
    }
    final channel = w.channel!;
    if (!_shared.rosters.containsKey(channel.id)) {
      unawaited(_shared.loadRoster(w, channel));
    }
    if (_shared.resources == null) unawaited(_shared.loadResources(w));
  }

  static String _label(String s) =>
      s.replaceAll('\\', '\\\\').replaceAll('[', r'\[').replaceAll(']', r'\]');
  @override
  void dispose() {
    ended = true;
    people = [];
    events?.cancel();
    w.removeListener(changed);
    w.entityDirectory.removeListener(changed);
    _shared.removeListener(changed);
    super.dispose();
  }
}

/// Web MentionCandidateAvatar: `AvatarSlot context="compact-list"`; muted
/// (not in channel) is `!border-black/40 opacity-60`.
class _ComposerCandidateAvatar extends StatelessWidget {
  const _ComposerCandidateAvatar({
    required this.directory,
    required this.authority,
    required this.name,
    required this.type,
    required this.source,
    required this.row,
    this.muted = false,
  });
  final ComposerDirectory directory;
  final String authority, name, type;
  final SenderAvatarProjection source;
  final Map<String, dynamic> row;
  final bool muted;

  AgentAmbientDisplay? get display {
    final presentation = directory.agentPresentation;
    if (presentation != null) return presentation.display(row['id'] as String);
    final status = row['status'] is String
        ? row['status'] as String
        : 'offline';
    return resolveAgentAmbientDisplay(
      identity: AgentPresentationIdentity(
        id: row['id'] as String,
        status: status,
        runtime: row['runtime'] as String?,
        external: row['runtime'] == 'external',
        deleted: row['deletedAt'] != null,
        lastSeenAt: DateTime.tryParse('${row['lastSeenAt']}'),
      ),
      now: DateTime.now(),
      current: normalizeAgentSnapshotActivity(
        status: status,
        activity: row['activity'] as String?,
        activityKind: row['activityKind'] as String?,
        detailKind: row['detailKind'] as String?,
        detail: row['activityDetail'] is String
            ? row['activityDetail'] as String
            : '',
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: directory.agentPresentation ?? directory,
    builder: (context, _) {
      if (directory.ended ||
          directory.scope != authority ||
          directoryAuthority(directory.w) != authority) {
        return const RaftAvatarSpace();
      }
      return _avatar(
        name,
        type,
        source,
        muted: muted,
        presence: type == 'agent' && !muted
            ? agentAvatarPresence(display)
            : null,
      );
    },
  );
}

Widget _avatar(
  String name,
  String type,
  SenderAvatarProjection source, {
  bool muted = false,
  RaftAvatarPresence? presence,
}) {
  final agent = type == 'agent';
  final avatar = RaftAvatar(
    name: name,
    size: 20,
    kind: agent ? RaftAvatarKind.agent : RaftAvatarKind.human,
    mountedContext: RaftMountedAvatarContext.compactList,
    presence: presence,
    muted: muted,
    content: RaftAvatarContent(
      name: name,
      kind: agent ? RaftAvatarContentKind.agent : RaftAvatarContentKind.human,
      uploadedUrl: source.uploadedUrl,
      gravatarUrl: source.gravatarUrl,
      pixelKey: source.pixelKey,
      fallback: Opacity(
        opacity: muted && !agent ? .5 : 1,
        child: RaftMountedAvatarFallback(
          avatarContext: RaftMountedAvatarContext.compactList,
          gravatar: source.gravatarUrl != null,
          identity: agent
              ? RaftMountedAvatarIdentity.agent
              : RaftMountedAvatarIdentity.human,
        ),
      ),
    ),
  );
  return avatar;
}
