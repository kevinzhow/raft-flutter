import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import 'private_route_guard.dart';
import 'sender_avatar_projection.dart';

/// Lazy, transient autocomplete authority. Private/joint surfaces use only
/// their current membership projection; resource references require the real
/// server flag before either computers or installed apps are requested.
class ComposerDirectory extends ChangeNotifier {
  ComposerDirectory(this.w) {
    w.addListener(changed);
    changed();
  }
  final WorkspaceController w;
  String? scope;
  bool ended = false, requested = false;
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
    final next = workspaceAuthority(w);
    if (scope == next) return;
    scope = next;
    requested = false;
    people = [];
    notifyListeners();
  }

  void request(String prefix) {
    if (prefix != '@' || requested || w.channel == null || w.server == null) {
      return;
    }
    requested = true;
    load(scope!);
  }

  Future<void> load(String authority) async {
    bool current() =>
        !ended && scope == authority && workspaceAuthority(w) == authority;
    final entries = <String, RaftComposerSuggestion>{};
    final memberIds = <String>{};
    void add(dynamic raw, String type, {bool roster = false}) {
      if (raw is! List) return;
      for (final value in raw.whereType<Map>()) {
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
        if (roster) memberIds.add(key);
        final previous = entries[key];
        final source = projectSenderAvatar(
          origin: w.client.origin,
          senderId: id,
          senderType: type,
          agents: type == 'agent'
              ? [Map<String, dynamic>.from(value)]
              : const [],
          members: type == 'user'
              ? [
                  {...Map<String, dynamic>.from(value), 'userId': id},
                ]
              : const [],
          currentUser: w.client.user?.json,
        );
        entries[key] = RaftComposerSuggestion(
          type: type,
          id: id,
          name: name,
          title: value['displayName'] as String? ?? previous?.title,
          detail: value['description'] as String? ?? previous?.detail,
          inChannel: roster || memberIds.contains(key),
          avatar: _avatar(name, type, source),
          mutedAvatar: _avatar(name, type, source, muted: true),
        );
      }
    }

    try {
      final roster = await w.query('/channels/${w.channel!.id}/members');
      if (!current()) return;
      if (roster is Map) {
        add(roster['humans'], 'user', roster: true);
        add(roster['agents'], 'agent', roster: true);
      }
    } catch (_) {
      /* A failed roster never expands private channel authority. */
    }
    if (!current()) return;
    if (!['private', 'joint'].contains(w.channel!.type)) {
      final user = w.client.user;
      if (user != null) {
        add([
          {...user.json, 'id': user.id},
        ], 'user');
      }
      if (w.can('viewMembers')) {
        try {
          final out = await w.query('/servers/${w.server!.id}/members');
          if (!current()) return;
          add(out is List ? out : out['members'], 'user');
        } catch (_) {}
      }
      if (w.can('viewAgents')) {
        try {
          final out = await w.query('/agents');
          if (!current()) return;
          add(out is List ? out : out['agents'], 'agent');
        } catch (_) {}
      }
    }
    if (!current()) return;
    people = entries.values.toList();
    notifyListeners();
    try {
      final flags = await w.client.post(
        '/feature-flags/evaluate',
        data: {
          'keys': ['composer_resource_references_v0'],
          'serverId': w.server!.id,
          'platform': defaultTargetPlatform == TargetPlatform.android
              ? 'mobile'
              : 'web',
        },
      );
      if (!current() ||
          flags is! Map ||
          flags['evaluations'] is! List ||
          !(flags['evaluations'] as List).whereType<Map>().any(
            (f) =>
                f['key'] == 'composer_resource_references_v0' &&
                f['enabled'] == true,
          )) {
        return;
      }
      if (w.can('viewMachines')) {
        final out = await w.query('/servers/${w.server!.id}/machines');
        if (!current()) return;
        final raw = out is List ? out : out['machines'];
        for (final row in (raw as List? ?? []).whereType<Map>()) {
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
      }
      final apps = await w.query('/servers/${w.server!.id}/apps');
      if (!current()) return;
      for (final row
          in (apps is Map ? apps['apps'] as List? ?? [] : const [])
              .whereType<Map>()) {
        if (row['appId'] is! String) continue;
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
      if (!current()) return;
      people = entries.values.toList();
      notifyListeners();
    } catch (_) {
      /* Enabled but unreadable resources do not become suggestions. */
    }
  }

  static String _label(String s) =>
      s.replaceAll('\\', '\\\\').replaceAll('[', r'\[').replaceAll(']', r'\]');
  @override
  void dispose() {
    ended = true;
    people = [];
    w.removeListener(changed);
    super.dispose();
  }
}

/// Web MentionCandidateAvatar: `AvatarSlot context="compact-list"`; muted
/// (not in channel) is `!border-black/40 opacity-60`.
Widget _avatar(
  String name,
  String type,
  SenderAvatarProjection source, {
  bool muted = false,
}) {
  final agent = type == 'agent';
  final avatar = RaftAvatar(
    name: name,
    size: 20,
    kind: agent ? RaftAvatarKind.agent : RaftAvatarKind.human,
    mountedContext: RaftMountedAvatarContext.compactList,
    content: RaftAvatarContent(
      name: name,
      kind: agent ? RaftAvatarContentKind.agent : RaftAvatarContentKind.human,
      uploadedUrl: source.uploadedUrl,
      gravatarUrl: source.gravatarUrl,
      pixelKey: source.pixelKey,
      fallback: RaftMountedAvatarFallback(
        avatarContext: RaftMountedAvatarContext.compactList,
        gravatar: source.gravatarUrl != null,
        identity: agent
            ? RaftMountedAvatarIdentity.agent
            : RaftMountedAvatarIdentity.human,
      ),
    ),
  );
  return muted ? Opacity(opacity: .6, child: avatar) : avatar;
}
