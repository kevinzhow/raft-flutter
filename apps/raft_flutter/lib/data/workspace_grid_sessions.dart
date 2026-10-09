import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:raft_client/raft_client.dart';

import 'workspace_controller.dart';

/// Source workspace thread tabs deduplicate by parent channel and message.
/// The tab owns replies independently of the retained channel editor.
class WorkspaceGridThreadRef {
  const WorkspaceGridThreadRef(this.channelId, this.parentMessageId);
  final String channelId;
  final String parentMessageId;
  String get id => 'thread:$channelId:$parentMessageId';
  String get messagePrefix =>
      parentMessageId.substring(0, parentMessageId.length.clamp(0, 8));
}

/// Independent accepted windows on the existing session. The root remains
/// the only socket/server/membership owner. No bootstrap or extra transport.
class WorkspaceGridSessions extends ChangeNotifier {
  WorkspaceGridSessions(this.parent) {
    parent.addListener(synchronize);
    parent.foregroundChanges.addListener(synchronize);
    scope = authority;
  }
  final WorkspaceController parent;
  final controllers = <String, WorkspaceController>{};
  final threadRefs = <String, WorkspaceGridThreadRef>{};
  final callbacks = <String, VoidCallback>{};
  final admitted = <String>{};
  final draftBaseline = <String, Map<String, String>>{};
  final draftRevisions = <String, int>{};
  final presentationOwner = Object();
  late String scope;
  bool ended = false;
  bool draftsChanged = false;

  String get authority => jsonEncode([
    identityHashCode(parent.client),
    parent.client.origin,
    parent.client.generation,
    parent.client.user?.id,
    parent.client.serverId,
    parent.server?.id,
    parent.server?.string('role'),
    parent.server?.json['permissions'],
  ]);

  RaftChannel? channel(String id) => [...parent.channels, ...parent.dms]
      .where((c) => c.id == id && parent.can('viewChannel', resource: c))
      .firstOrNull;

  String parentChannelId(String id) => threadRefs[id]?.channelId ?? id;

  WorkspaceController? openThread(
    String channelId,
    String parentMessageId, {
    String? initialThreadChannelId,
  }) {
    if (parentMessageId.trim().isEmpty) return null;
    final ref = WorkspaceGridThreadRef(channelId, parentMessageId);
    return _open(
      ref.id,
      threadRef: ref,
      initialThreadChannelId: initialThreadChannelId,
    );
  }

  WorkspaceController? open(String id) => _open(id);

  WorkspaceController? _open(
    String id, {
    WorkspaceGridThreadRef? threadRef,
    String? initialThreadChannelId,
  }) {
    if (ended ||
        authority != scope ||
        parent.client.user == null ||
        parent.server == null ||
        parent.server?.id != parent.client.serverId) {
      return null;
    }
    if (controllers.containsKey(id)) return controllers[id];
    final row = channel(threadRef?.channelId ?? id);
    if (row == null) return null;
    final child = WorkspaceController(
      parent.client,
      cache: parent.cache,
      ownsClient: false,
      entityDirectory: parent.entityDirectory,
    );
    child.server = parent.server;
    child.channel = row;
    child.servers = [...parent.servers];
    child.channels = [...parent.channels];
    child.dms = [...parent.dms];
    child.connected = parent.connected;
    child.syncCoreMessagesEnabled = parent.syncCoreMessagesEnabled;
    child.ledger.switchServer(parent.server!.id);
    child.drafts.addAll(parent.drafts);
    child.foreground = false;
    child.setConversationPresentation(
      presentationOwner,
      main: false,
      thread: false,
    );
    draftBaseline[id] = {...child.drafts};
    controllers[id] = child;
    if (threadRef != null) threadRefs[id] = threadRef;
    void changed() {
      if (ended || controllers[id] != child || authority != scope) return;
      transferDrafts(id, child);
      notifyListeners();
    }

    callbacks[id] = changed;
    child.addListener(changed);
    // Select after the caller's layout frame, not during its build. The child
    // window fences every result; retirement rejects all late acknowledgments.
    scheduleMicrotask(() {
      if (!ended && controllers[id] == child && scope == authority) {
        if (threadRef == null) {
          unawaited(child.selectChannel(row, autoRead: false));
        } else {
          // Source threadStore also admits an already accepted parent summary.
          // Task metadata alone never manufactures a reply-channel hint.
          unawaited(
            child.openThreadIdentity(
              parentChannelId: threadRef.channelId,
              parentMessageId: threadRef.parentMessageId,
              initialThreadChannelId: initialThreadChannelId,
              navigate: false,
            ),
          );
        }
      }
    });
    return child;
  }

  void transferDrafts(String id, WorkspaceController child) {
    if (scope != authority || ended) return;
    final baseline = draftBaseline[id]!;
    for (final entry in child.drafts.entries) {
      if (baseline[entry.key] == entry.value) continue;
      baseline[entry.key] = entry.value;
      parent.drafts[entry.key] = entry.value;
      // Cache write is scoped by the root's current principal/server. It does
      // not replace or clear another conversation's editor.
      if (parent.draftScope() == entry.key) {
        parent.saveDraft(entry.value);
      } else if (parent.draftScope(thread: true) == entry.key) {
        parent.saveDraft(entry.value, thread: true);
      }
      draftsChanged = true;
    }
  }

  /// A phone-width classic editor can change a draft while the grid is
  /// retained offstage. Import only when this child has not diverged from its
  /// last transferred draft; never overwrite an independently changed child.
  void restoreParentDrafts() {
    if (ended || scope != authority) return;
    for (final entry in controllers.entries) {
      final child = entry.value;
      final key = child.draftScope(thread: threadRefs.containsKey(entry.key));
      if (key == null) continue;
      final baseline = draftBaseline[entry.key]!;
      final current = child.drafts[key] ?? '';
      final stored = parent.drafts[key] ?? '';
      if (current != (baseline[key] ?? '') || current == stored) continue;
      child.drafts[key] = baseline[key] = stored;
      draftRevisions.update(entry.key, (n) => n + 1, ifAbsent: () => 1);
    }
  }

  void present(Set<String> ids) {
    admitted
      ..clear()
      ..addAll(ids);
    for (final entry in controllers.entries) {
      final visible = ids.contains(entry.key) && parent.foreground;
      // This is tab admission, not the child's folded main/thread owner.
      // Resuming the parent must not replace a folded main:false projection
      // with main:true before that child's next layout frame.
      // Do not call setForeground: it acknowledges immediately.
      entry.value.foreground = visible;
    }
  }

  void close(String id, {bool transfer = true}) {
    final child = controllers.remove(id);
    if (child == null) return;
    if (transfer && scope == authority) transferDrafts(id, child);
    child.removeListener(callbacks.remove(id)!);
    threadRefs.remove(id);
    draftBaseline.remove(id);
    draftRevisions.remove(id);
    // Retire the accepted private projection before detaching its listeners.
    // Owned dialogs/image leases see authority loss even though the shared
    // authenticated client intentionally remains alive for other panels.
    child.server = null;
    child.channel = null;
    child.threadParent = null;
    child.threadChannelId = null;
    child.drafts.clear();
    child.visibleIds.clear();
    child.ledger.switchServer(null);
    child.foreground = false;
    child.notifyListeners();
    child.dispose();
  }

  void synchronize() {
    if (ended) return;
    if (authority != scope) {
      // Invalidation clears, rather than transferring, private old drafts.
      scope = authority;
      for (final id in controllers.keys.toList()) {
        close(id, transfer: false);
      }
      notifyListeners();
      return;
    }
    for (final entry in controllers.entries.toList()) {
      final fresh = channel(parentChannelId(entry.key));
      final old = entry.value.channel;
      if (fresh == null ||
          fresh.joined != old?.joined ||
          !mapEquals(
            fresh.json['channelCapabilities'] is Map
                ? Map<String, dynamic>.from(fresh.json['channelCapabilities'])
                : null,
            old?.json['channelCapabilities'] is Map
                ? Map<String, dynamic>.from(old!.json['channelCapabilities'])
                : null,
          )) {
        close(entry.key);
        continue;
      }
      entry.value.server = parent.server;
      entry.value.channels = [...parent.channels];
      entry.value.dms = [...parent.dms];
      entry.value.connected = parent.connected;
    }
    present({...admitted});
    notifyListeners();
  }

  @override
  void dispose() {
    if (ended) return;
    parent.removeListener(synchronize);
    parent.foregroundChanges.removeListener(synchronize);
    for (final id in controllers.keys.toList()) {
      close(id);
    }
    ended = true;
    super.dispose();
  }
}
