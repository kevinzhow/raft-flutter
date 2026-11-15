import 'dart:convert';

import 'package:raft_client/raft_client.dart';

import '../data/resource_row_reconcile.dart';
import '../data/resource_snapshot_cache.dart';
import '../data/server_page_window.dart';
import '../data/server_saved_window.dart';
import '../data/workspace_controller.dart';
import 'saved_sidebar_entry.dart';

/// Identity of the workspace Saved page: section `saved`, no channel.
String savedPageIdentity(WorkspaceController controller) => jsonEncode([
  controller.client.origin,
  controller.client.generation,
  controller.client.user?.id,
  controller.client.serverId,
  controller.server?.id,
  controller.server?.string('role'),
  'saved',
  null,
]);

const _channelAccessKeys = [
  'isPrivate',
  'visibility',
  'accessLevel',
  'membership',
  'capabilities',
  'channelCapabilities',
  'guestAccessEnabled',
  'readOnlyReason',
  'parentChannelId',
  'serverId',
  'role',
];

Map<String, dynamic> _channelFacts(RaftChannel channel) => {
  'id': channel.id,
  'type': channel.type,
  'joined': channel.joined,
  'archived': channel.archived,
  for (final key in _channelAccessKeys)
    if (channel.json.containsKey(key)) key: channel.json[key],
};

/// Channels whose saved rows can no longer be shown.
///
/// Same rule as the mounted page: removed from the directory, denied by
/// capability, or a private conversation the principal left.
Set<String> savedLostChannels(
  WorkspaceController controller,
  Map<String, Map<String, dynamic>> previous,
) {
  final all = [...controller.channels, ...controller.dms];
  final next = {for (final channel in all) channel.id: _channelFacts(channel)};
  final lost = <String>{};
  for (final MapEntry(key: id, value: before) in previous.entries) {
    final after = next[id];
    RaftChannel? current;
    for (final channel in all) {
      if (channel.id == id) {
        current = channel;
        break;
      }
    }
    if (after == null) {
      lost.add(id);
    } else if (!rowDeepEquals(before, after) &&
        (!controller.can('viewChannel', resource: current) ||
            savedPrivateLike(after) &&
                before['joined'] == true &&
                after['joined'] != true)) {
      lost.add(id);
    }
  }
  return lost;
}

/// The workspace Saved page borrows the session window and does not read slot
/// `saved`. A window from another identity is dropped.
ResourceSnapshot? takeServerSavedPage(
  ResourceSnapshotCache cache,
  String identity,
) {
  return takeServerPage<ResourceSnapshot>(
    cache,
    serverSavedPage,
    identity,
    accept: (snapshot) => !snapshot.enabledActivity,
  );
}

/// Holds [snapshot] on the session window and stops writing slot `saved`.
void keepServerSavedPage(
  WorkspaceController controller,
  ResourceSnapshot snapshot,
) {
  final cache = controller.resourceSnapshots;
  cache.remove('saved');
  Set<String> lost(Map<String, Map<String, dynamic>> previous) =>
      savedLostChannels(controller, previous);
  String? server() => controller.client.serverId;
  String identity() => savedPageIdentity(controller);
  final window = holdServerPage(
    cache,
    serverSavedPage,
    ServerSavedWindow(
      client: controller.client,
      events: controller.client.events,
      snapshot: snapshot,
      serverId: server,
      identity: identity,
      lostChannels: lost,
    ),
    bind: (held) => _bindSavedStore(controller, held),
    release: (held) => _unbindSavedStore(controller, held),
  );
  if (window.attached > 0) window.detach();
}

final _savedStoreListeners = Expando<void Function()>('saved count listener');

void _bindSavedStore(WorkspaceController controller, ServerSavedWindow window) {
  if (_savedStoreListeners[window] != null) return;
  final store = SavedCountStore.of(controller);
  final known = store.savedIds.toSet();
  void onStore() {
    final next = store.savedIds;
    if (window.disposed || window.attached != 0 || !window.sameIdentity) {
      known
        ..clear()
        ..addAll(next);
      return;
    }
    for (final id in known.difference(next)) {
      window.removeMessage(id);
    }
    for (final id in next.difference(known)) {
      window.noteSaved(id);
    }
    known
      ..clear()
      ..addAll(next);
  }

  _savedStoreListeners[window] = onStore;
  store.addListener(onStore);
}

void _unbindSavedStore(WorkspaceController controller, ServerSavedWindow window) {
  final listener = _savedStoreListeners[window];
  if (listener == null) return;
  _savedStoreListeners[window] = null;
  SavedCountStore.of(controller).removeListener(listener);
}

typedef SavedUnsave = ({
  List<Map<String, dynamic>> rows,
  List<Map<String, dynamic>> savedActivityItems,
  int? totalCount,
  int savedActivityTotal,
});

int _place(int index, int length) {
  if (index < 0) return 0;
  if (index > length) return length;
  return index;
}

/// Source savedStore `unsaveMessage` for the mounted page.
///
/// The row, the totals and the badge move at once. A failed request restores
/// them. The page reloads after a success.
Future<void> unsaveSavedRow({
  required bool Function() accepts,
  required Map<String, dynamic> row,
  required List<Map<String, dynamic>> Function() readRows,
  required List<Map<String, dynamic>> Function() readSavedActivityItems,
  required int? Function() readTotalCount,
  required int Function() readSavedActivityTotal,
  required bool Function() activitySaved,
  required void Function(SavedUnsave next) apply,
  required SavedCountStore store,
  required Future<void> Function() refreshUnread,
  required Future<void> Function() reload,
  required void Function(Object cause) fail,
}) async {
  if (!accepts()) return;
  final id = row['messageId'];
  if (id is! String) return;
  final current = readRows();
  final index = current.indexWhere((item) => item['messageId'] == id);
  final held = index < 0 ? null : current[index];
  final heldTotal = readTotalCount();
  final heldSaved = readSavedActivityTotal();
  final removes = held != null;
  List<Map<String, dynamic>> without(List<Map<String, dynamic>> list) => [
    for (final item in list)
      if (item['messageId'] != id) item,
  ];
  apply((
    rows: without(current),
    savedActivityItems: without(readSavedActivityItems()),
    totalCount: removes && heldTotal != null
        ? savedBoundedCount(heldTotal - 1)
        : heldTotal,
    savedActivityTotal: removes ? savedBoundedCount(heldSaved - 1) : heldSaved,
  ));
  try {
    await store.setSaved(id, false);
    if (!accepts()) return;
    await refreshUnread();
    if (!accepts()) return;
    await reload();
  } catch (error) {
    if (!accepts()) return;
    final live = readRows();
    final restored =
        held != null && !live.any((item) => item['messageId'] == id)
        ? (List<Map<String, dynamic>>.of(live)
            ..insert(_place(index, live.length), held))
        : live;
    apply((
      rows: restored,
      savedActivityItems: activitySaved()
          ? List<Map<String, dynamic>>.of(restored)
          : readSavedActivityItems(),
      totalCount: heldTotal,
      savedActivityTotal: heldSaved,
    ));
    fail(error);
  }
}
