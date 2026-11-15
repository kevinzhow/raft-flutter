import 'package:flutter/foundation.dart';

import '../data/server_runtime_catalog.dart';
import '../data/workspace_controller.dart';

/// The shared per-server runtime catalog reads (Web `useServerRuntimeCatalog`
/// and `serverRuntimeCatalogCache`): a list names a runtime on each of its
/// rows and each row asks, so concurrent readers share one request and a
/// settled answer (a catalog, or null for an old server or any error) is
/// reused for a minute. The server answers per user: a sign-out or a switch of
/// workspace (the client's generation) starts from no reads.
class ServerRuntimeCatalogReads extends ChangeNotifier {
  ServerRuntimeCatalogReads._(this._w);

  static final _of = Expando<ServerRuntimeCatalogReads>(
    'server runtime catalog',
  );

  /// The reads of [workspace]; one per workspace session, disposed with it.
  static ServerRuntimeCatalogReads of(WorkspaceController workspace) =>
      _of[workspace] ??= _sessionReads(workspace);
  static ServerRuntimeCatalogReads _sessionReads(WorkspaceController w) {
    final reads = ServerRuntimeCatalogReads._(w);
    w.services.disposeWithSession(reads.dispose);
    return reads;
  }

  /// `CATALOG_REUSE_MS`.
  static const reuse = Duration(seconds: 60);

  /// Tests pin the clock.
  @visibleForTesting
  DateTime Function() now = DateTime.now;

  final WorkspaceController _w;
  final _reads = <String, _Read>{};
  int _generation = -1;
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  _Read? _reusable(String serverId) {
    final generation = _w.client.generation;
    if (generation != _generation) {
      _reads.clear();
      _generation = generation;
    }
    final existing = _reads[serverId];
    if (existing == null) return null;
    final settledAt = existing.settledAt;
    return settledAt == null || now().difference(settledAt) < reuse
        ? existing
        : null;
  }

  /// The settled answer, so a row built after the read renders it at once;
  /// null while it loads, for an old server and after any error.
  ServerRuntimeCatalog? settled(String? serverId) =>
      serverId == null ? null : _reusable(serverId)?.catalog;

  /// Reads (or joins the read of) this server's catalog. Never throws.
  Future<ServerRuntimeCatalog?> read(String serverId) {
    final existing = _reusable(serverId);
    if (existing != null) return existing.promise;
    final generation = _generation;
    final entry = _Read();
    Future<ServerRuntimeCatalog?> fetch() async {
      ServerRuntimeCatalog? catalog;
      try {
        catalog = ServerRuntimeCatalog.parse(
          await _w.query('/servers/$serverId/runtimes'),
        );
      } catch (_) {
        catalog = null;
      }
      entry.settledAt = now();
      entry.catalog = catalog;
      if (!_disposed && generation == _generation) notifyListeners();
      return catalog;
    }

    entry.promise = fetch();
    _reads[serverId] = entry;
    return entry.promise;
  }

  /// Web `useRuntimeDeprecatedHere()`: `(runtimeId) => deprecated` as the
  /// current server answers it; the bundled flag until the catalog arrives.
  /// Starts the shared read when none is in flight.
  bool Function(String runtimeId) deprecatedHere() {
    final serverId = _w.server?.id;
    if (serverId != null) read(serverId);
    final catalog = settled(serverId);
    return (runtimeId) => isRuntimeDeprecatedOnServer(runtimeId, catalog);
  }
}

class _Read {
  late Future<ServerRuntimeCatalog?> promise;
  DateTime? settledAt;
  ServerRuntimeCatalog? catalog;
}
