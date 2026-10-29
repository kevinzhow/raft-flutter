/// Invalidates committed reads synchronously when a purge is requested.
/// Pending purges also reject reads that start before the disk deletion runs.
class CacheReadVersions {
  int _revision = 0;
  bool _closed = false;
  final _versions = <Object, ({int revision, int pending})>{};

  int get ticket => _revision;

  /// Build queued-work guards outside the async read's body-bearing frame.
  bool Function() validator(
    int ticket,
    String origin,
    String principal,
    String server,
    Iterable<String> channels,
  ) =>
      () => current(ticket, origin, principal, server, channels);

  void Function() invalidateAccount(String origin, String principal) =>
      _invalidate((origin, principal));
  void Function() invalidateServer(
    String origin,
    String principal,
    String server,
  ) => _invalidate((origin, principal, server));
  void Function() invalidateChannel(
    String origin,
    String principal,
    String server,
    String channel,
  ) => _invalidate((origin, principal, server, channel));

  void Function() _invalidate(Object key) {
    if (_closed) return () {};
    _versions[key] = (
      revision: ++_revision,
      pending: (_versions[key]?.pending ?? 0) + 1,
    );
    var completed = false;
    return () {
      if (completed || _closed) return;
      completed = true;
      _versions[key] = (
        revision: ++_revision,
        pending: _versions[key]!.pending - 1,
      );
    };
  }

  bool current(
    int ticket,
    String origin,
    String principal,
    String server,
    Iterable<String> channels,
  ) {
    if (_closed) return false;
    return <Object>[
      (origin, principal),
      (origin, principal, server),
      for (final channel in channels) (origin, principal, server, channel),
    ].every((key) {
      final held = _versions[key];
      return held == null || held.pending == 0 && held.revision <= ticket;
    });
  }

  void close() {
    _closed = true;
    _versions.clear();
  }
}
