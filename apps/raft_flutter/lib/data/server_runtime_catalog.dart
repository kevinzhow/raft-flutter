import 'package:flutter/foundation.dart';

import '../features/agent_runtime_catalog.dart' show runtimeInfos;

/// One runtime this server offers (`ServerRuntimeCatalogEntry` of
/// packages/shared): after the server's runtime switches, not machine-specific.
@immutable
class ServerRuntimeCatalogEntry {
  const ServerRuntimeCatalogEntry({
    required this.id,
    required this.deprecated,
    required this.experimental,
    required this.oarOnly,
  });
  final String id;
  final bool? deprecated;
  final bool experimental, oarOnly;
}

/// `GET /servers/:id/runtimes` (docs/contracts/server-runtime-catalog.md).
@immutable
class ServerRuntimeCatalog {
  const ServerRuntimeCatalog(this.runtimes);
  final List<ServerRuntimeCatalogEntry> runtimes;

  /// Web `Array.isArray(data?.runtimes) ? data : null`: anything else is "no
  /// catalog" (a server too old to serve one).
  static ServerRuntimeCatalog? parse(Object? body) {
    final rows = body is Map ? body['runtimes'] : null;
    if (rows is! List) return null;
    return ServerRuntimeCatalog([
      for (final row in rows.whereType<Map>())
        if (row['id'] is String)
          ServerRuntimeCatalogEntry(
            id: row['id'] as String,
            deprecated: row['deprecated'] is bool
                ? row['deprecated'] as bool
                : null,
            experimental: row['experimental'] == true,
            oarOnly: row['oarOnly'] == true,
          ),
    ]);
  }
}

/// Web `isRuntimeDeprecatedOnServer`: the catalog's answer, else (no catalog,
/// or a runtime it does not list) the bundled one.
bool isRuntimeDeprecatedOnServer(
  String runtimeId,
  ServerRuntimeCatalog? catalog,
) {
  final entry = catalog?.runtimes
      .where((runtime) => runtime.id == runtimeId)
      .firstOrNull;
  if (entry?.deprecated case final deprecated?) return deprecated;
  return runtimeInfos.where((r) => r.id == runtimeId).firstOrNull?.deprecated ??
      false;
}
