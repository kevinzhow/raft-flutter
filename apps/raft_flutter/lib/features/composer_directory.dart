import 'dart:async';

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
import 'external_mentions.dart';
import '../data/feature_flag_client_facts.dart';
import 'route_transition_gate.dart';

/// One channel roster as returned by `/channels/:id/members`, together with
/// the channel authority it was read under.
class _ComposerRoster {
  const _ComposerRoster(this.channel, this.humans, this.agents, this.externals);
  final Map<String, dynamic> channel;
  final List<Map<String, dynamic>> humans, agents, externals;
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
        final live = [
          ?w.channel,
          ...w.channels,
          ...w.dms,
        ].where((c) => c.id == id).firstOrNull;
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
          rows(roster is Map ? roster['externalMembers'] : null),
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
          data: featureFlagEvaluateBody(
            keys: ['composer_resource_references_v0'],
            serverId: server.id,
          ),
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
          final computers = w.services.entityDirectory.state(
            WorkspaceEntityKind.computers,
          );
          if (!computers.loaded) {
            await w.services.entityDirectory.refresh(
              WorkspaceEntityKind.computers,
            );
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

/// The channel roster the composer already read when the channel opened
/// (Source useChannelMembers prefetch), for surfaces that show it at their
/// first frame (the settings drawer's members strip). Null until read.
({List<Map<String, dynamic>> humans, List<Map<String, dynamic>> agents})?
cachedChannelRoster(WorkspaceController w, String channelId) {
  final roster =
      _sharedComposerData[w.services.entityDirectory]?.rosters[channelId];
  return roster == null ? null : (humans: roster.humans, agents: roster.agents);
}

/// Accepted channel-scoped provider members. Never uses the server directory.
List<Map<String, dynamic>> cachedExternalMembers(
  WorkspaceController w,
  String id,
) {
  if (w.server == null || w.server!.string('role') == 'guest') return const [];
  final shared = _sharedComposerData[w.services.entityDirectory];
  if (shared == null || shared.authority != directoryAuthority(w)) {
    return const [];
  }
  final source = w.threadChannelId == id
      ? w.messageDomain.threadSourceChannel?.id
      : id;
  final channel = w.channel?.id == source
      ? w.channel
      : w.channels.where((c) => c.id == source).firstOrNull ??
            w.dms.where((c) => c.id == source).firstOrNull;
  if (channel == null || shared.validate(channel)) return const [];
  return shared.rosters[channel.id]?.externals ?? const [];
}

/// Keeps a roster another surface just read (the channel members page) as the
/// shared per-channel copy, so the next surface that shows it (the members
/// page, the settings strip, the composer) paints it at its first frame.
/// Ignored when the channel is not in the workspace or its authority moved.
void rememberChannelRoster(
  WorkspaceController w,
  RaftChannel channel, {
  required List<Map<String, dynamic>> humans,
  required List<Map<String, dynamic>> agents,
  List<Map<String, dynamic>> externalMembers = const [],
}) {
  final shared = _sharedComposerData[w.services.entityDirectory] ??=
      _ComposerShared();
  shared.sync(directoryAuthority(w));
  shared.rosters[channel.id] = _ComposerRoster(
    _channelAuthority(channel),
    humans,
    agents,
    externalMembers,
  );
  shared._changed();
}

/// Autocomplete projection. People come from the shared, server-scoped entity
/// directory (Source agentStore/serverStore members) and are available at the
/// first frame; only the channel roster (Source useChannelMembers: in-channel
/// grouping and private/joint eligibility) is per channel. Rosters are read
/// when a channel is opened, cached per channel and revalidated in place, so
/// an open popup never reflows while data is replaced. Private/joint surfaces
/// use only their current membership projection; resource references require
/// the real server flag before either computers or installed apps are shown.
class ComposerDirectory extends ChangeNotifier {
  ComposerDirectory(this.w, {this.agentPresentation, this.thread = false})
    : _shared = _sharedComposerData[w.services.entityDirectory] ??=
          _ComposerShared() {
    w.addListener(changed);
    w.services.entityDirectory.addListener(changed);
    _shared.addListener(changed);
    events = w.client.events.listen(event);
    changed();
  }
  final WorkspaceController w;
  final _ComposerShared _shared;
  StreamSubscription<RaftEvent>? events;

  /// Web ThreadPanel `mentionChannelId={parentChannelId}`: a thread composer
  /// suggests from the thread's SOURCE channel (roster, private/joint
  /// eligibility, in-channel grouping), not from the channel the main pane
  /// has open, and ranks the thread's recent speakers first.
  final bool thread;

  /// The channel whose roster scopes these suggestions.
  RaftChannel? get scopeChannel =>
      thread ? w.messageDomain.threadSourceChannel : w.channel;

  /// Borrow the chat's existing authorized activity adapter; never owns it.
  final MessageAgentPresentation? agentPresentation;
  String? scope, channelId;
  Object? stamp, checked;
  bool ended = false;
  List<RaftComposerSuggestion> people = [];
  List<RaftComposerSuggestion> get suggestions => [
    ...people,
    for (final c in w.channels)
      // Web `channelAutocompleteCandidates`: archived channels stay listed
      // (`GET /channels?archived=include`) with an `archived` Badge.
      if (['channel', 'private', 'joint'].contains(c.type))
        RaftComposerSuggestion(
          type: 'channel',
          id: c.id,
          name: c.name,
          archived: c.archived,
          detail: c.description.isEmpty ? null : c.description,
        ),
  ];

  void changed() {
    if (ended) return;
    final authority = directoryAuthority(w);
    _shared.sync(authority);
    scope = authority;
    final channel = w.server == null ? null : scopeChannel;
    if (channel != null) _shared.validate(channel);
    if (channel?.id != channelId) {
      channelId = channel?.id;
      // Source MessageInput/ChatPanel read the roster when the channel opens;
      // a visited channel shows its cached roster and revalidates in place.
      if (channel != null) {
        // ignore: raft_lints/avoid_unreviewed_idle_work -- One-shot roster load after the channel changes; the callback starts a request and never re-arms.
        Timer.run(() {
          final current = scopeChannel;
          if (!ended && current?.id == channel.id) {
            unawaited(_shared.loadRoster(w, current!));
          }
        });
      }
    }
    final resources = _shared.resources == true;
    final recency = threadRecency(channel);
    // Agent presence patches leave every input below unchanged; skip copying
    // the computer rows for them.
    final inputs = (
      authority,
      channel?.id,
      channel?.type,
      w.client.user?.json['name'],
      w.services.entityDirectory.authorRevision,
      w.services.entityDirectory.computerRevision,
      _shared.revision,
      resources,
      w.can('viewMachines'),
      recency,
    );
    if (inputs == checked) return;
    checked = inputs;
    final computers = resources && w.can('viewMachines')
        ? w.services.entityDirectory.rows(WorkspaceEntityKind.computers)
        : const <Map<String, dynamic>>[];
    final next = (
      authority,
      channel?.id,
      channel?.type,
      w.client.user?.json['name'],
      w.services.entityDirectory.authorRevision,
      _shared.revision,
      resources,
      Object.hashAll([for (final c in computers) '${c['id']}:${c['name']}']),
      recency,
    );
    if (next == stamp) return;
    stamp = next;
    people = channel == null
        ? []
        : build(authority, channel, computers, recent: _recent);
    notifyListeners();
  }

  /// Web `buildRecentParticipantRanks`: sender ids of the thread's messages,
  /// newest speaker first. Only a thread over a non-DM channel prioritises
  /// them (ThreadPanel `isChannelThreadInput`). Returns a cheap change token.
  Object? threadRecency(RaftChannel? channel) {
    final id = w.threadChannelId;
    if (!thread || channel == null || channel.type == 'dm' || id == null) {
      _recent = const {};
      return null;
    }
    final token = (id, w.messageDomain.ledger.revision);
    if (token == _recencyToken) return token;
    _recencyToken = token;
    final ranks = <String, int>{};
    final rows = w.messageDomain.ledger.messages(id);
    for (var i = rows.length - 1; i >= 0; i--) {
      final sender = rows[i]['senderId'];
      if (sender is String && sender.isNotEmpty && !ranks.containsKey(sender)) {
        ranks[sender] = ranks.length;
      }
    }
    _recent = ranks;
    return token;
  }

  Map<String, int> _recent = const {};
  (String, int)? _recencyToken;

  void event(RaftEvent event) {
    if (ended) return;
    if (!['channel:members-updated', 'channel:removed'].contains(event.name)) {
      return;
    }
    final payload = event.payload;
    final id = payload is Map && payload['channelId'] is String
        ? payload['channelId'] as String
        : scopeChannel?.id;
    if (id == null) return;
    if (event.name == 'channel:removed') return _shared.drop(id);
    final channel = scopeChannel;
    if (channel?.id == id) unawaited(_shared.loadRoster(w, channel!));
    // Another cached channel revalidates when it is opened again.
  }

  /// Source MessageInput allCandidates: current user, server members, agents,
  /// then the channel roster (which only marks/extends existing entries).
  List<RaftComposerSuggestion> build(
    String authority,
    RaftChannel channel,
    List<Map<String, dynamic>> computers, {
    Map<String, int> recent = const {},
  }) {
    final entries = <String, RaftComposerSuggestion>{};
    final memberIds = <String>{};
    // Source MessageInput lists server humans without a description; only the
    // channel roster (and agents) carry one.
    void add(
      Iterable<Map<String, dynamic>> raw,
      String type, {
      bool describe = true,
    }) {
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
          detail: describe
              ? value['description'] as String? ?? previous?.detail
              : previous?.detail,
          inChannel: memberIds.contains(key),
          threadRank: recent[id],
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
        add(
          [
            {...user.json, 'id': user.id},
          ],
          'user',
          describe: false,
        );
      }
      add(w.services.entityDirectory.authorMembers, 'user', describe: false);
      add(w.services.entityDirectory.authorAgents, 'agent');
    }
    if (roster != null) {
      add(roster.humans, 'user');
      add(roster.agents, 'agent');
      for (final member in cachedExternalMembers(w, channel.id)) {
        final candidate = externalMentionSuggestion(w.client.origin, member);
        if (candidate != null) entries['external:${candidate.id}'] = candidate;
      }
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
    final channel = scopeChannel;
    if (ended || prefix != '@' || channel == null || w.server == null) {
      return;
    }
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
    w.services.entityDirectory.removeListener(changed);
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
        detailKind: agentRowDetailKind(row),
        detail: row['activityDetail'] is String
            ? row['activityDetail'] as String
            : '',
      ),
    );
  }

  @override
  Widget build(BuildContext context) => QuietListenableBuilder(
    // Live presence is signalled per agent; the presentation itself notifies
    // only whole-directory changes.
    listenable: switch (directory.agentPresentation) {
      final presentation? when type == 'agent' => Listenable.merge([
        presentation,
        presentation.presenceOf(row['id'] as String),
      ]),
      final presentation? => presentation,
      null => directory,
    },
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
