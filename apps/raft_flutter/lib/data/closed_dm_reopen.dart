/// Sidebar.tsx `reopenDm` on a route change: opening a closed DM (the Message
/// button, a notification, a link) takes it out of the server-synced
/// `hiddenDmIds` again. Only a change of the open conversation counts; the one
/// already open when the sidebar mounts is a restored page, which Web leaves
/// as it was.
class ClosedDmReopen {
  String? _seen;
  bool _primed = false;

  /// [openDmId]: the DM that is the open conversation, if any. Returns the
  /// `hiddenDmIds` to write when that DM was closed, else null.
  List<String>? sync(String? openDmId, List<String> hidden) {
    final first = !_primed;
    _primed = true;
    if (openDmId == _seen) return null;
    _seen = openDmId;
    if (openDmId == null || first || !hidden.contains(openDmId)) return null;
    return [
      for (final id in hidden)
        if (id != openDmId) id,
    ];
  }
}
