import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart' show raftText;

import 'server_runtime_catalog_reads.dart';
import '../data/workspace_controller.dart';
import 'agent_runtime_catalog.dart';

/// `getRuntimeDisplayName(id)`: the product name, else the id itself.
String runtimeDisplayNameOf(String id) =>
    runtimeInfos.where((r) => r.id == id).firstOrNull?.name ?? id;

/// The bundled `isRuntimeDeprecated(id)`. Where a server answers
/// (`ServerRuntimeCatalogReads.deprecatedHere`, its runtime-options rows) its
/// answer wins: a runtime it offers again (Antigravity on OAR) is not
/// deprecated there.
bool isRuntimeDeprecated(String id) =>
    runtimeInfos.where((r) => r.id == id).firstOrNull?.deprecated ?? false;

/// `isRuntimeExperimental(id)`.
bool isRuntimeExperimental(String id) =>
    runtimeInfos.where((r) => r.id == id).firstOrNull?.experimental ?? false;

/// `formatRuntimeLabelWithStatus`: the product name plus the lifecycle status
/// for identity display (subtitles, badges, pickers). Prose that interpolates
/// a runtime into a sentence uses the bare [runtimeDisplayNameOf] instead.
///
/// [deprecated] is the server's answer (`deprecatedHere`, a runtime-options
/// row, its catalog); it defaults to the bundled flag, which is what an old
/// server decides by anyway.
String runtimeLabelWithStatus(
  BuildContext context,
  String runtime, {
  bool? deprecated,
}) {
  final name = runtimeDisplayNameOf(runtime);
  if (deprecated ?? isRuntimeDeprecated(runtime)) {
    return '$name${raftText(context, ' (deprecated)')}';
  }
  if (isRuntimeExperimental(runtime)) {
    return '$name${raftText(context, ' (experimental)')}';
  }
  return name;
}

/// `formatRuntimeLabelBesideBadge`: the name plus a deprecated suffix, without
/// the "(experimental)" text the Experimental badge says instead. Pair with
/// [runtimeShowsExperimentalBadge].
String runtimeLabelBesideBadge(
  BuildContext context,
  String runtime, {
  required bool deprecated,
}) {
  final name = runtimeDisplayNameOf(runtime);
  return deprecated ? '$name${raftText(context, ' (deprecated)')}' : name;
}

/// `runtimeShowsExperimentalBadge` (deprecated wins).
bool runtimeShowsExperimentalBadge(
  String runtime, {
  required bool deprecated,
}) => !deprecated && isRuntimeExperimental(runtime);

/// `runtimeAvailabilitySuffix` + `formatRuntimeAvailabilitySuffix`: what a
/// Computer lacks for a runtime, as text after the name. An in-process runtime
/// (no binary) the Computer does not list needs a newer Raft Computer; one with
/// a binary is not installed.
String runtimeAvailabilitySuffixText(
  BuildContext context,
  String runtime,
  Iterable<String> machineRuntimeIds,
) {
  final info = runtimeInfos.where((r) => r.id == runtime).firstOrNull;
  if (info == null) return '';
  if (!info.supported) return raftText(context, ' (coming soon)');
  if (machineRuntimeIds.contains(runtime)) return '';
  return info.binary.isEmpty
      ? raftText(context, ' (update required)')
      : raftText(context, ' (not installed)');
}

/// `getCreatableRuntimeOptions()` ids: supported and not deprecated by the
/// bundle. The create dialog no longer intersects with this (the server's
/// runtime-options rows decide); onboarding and the Computer list still read it.
final Set<String> creatableRuntimeIds = {
  for (final r in runtimeInfos)
    if (r.supported && !isRuntimeDeprecated(r.id)) r.id,
};

/// Web `useRuntimeDeprecatedHere()` for a State that labels runtimes:
/// [deprecatedHere] is the current server's answer (its runtime catalog, else
/// the bundled flag while that loads or on an old server), and the State
/// rebuilds once the shared catalog read settles, as the hook re-renders.
mixin RuntimeDeprecatedHereState<T extends StatefulWidget> on State<T> {
  /// The workspace whose server answers.
  WorkspaceController get runtimeCatalogWorkspace;

  ServerRuntimeCatalogReads? _catalogReads;

  void _catalogSettled() {
    if (mounted) setState(() {});
  }

  /// Whether [runtimeId] is deprecated on the current server. Starts the
  /// shared read when none is in flight (Web reads on mount).
  bool deprecatedHere(String runtimeId) {
    final reads = ServerRuntimeCatalogReads.of(runtimeCatalogWorkspace);
    if (!identical(reads, _catalogReads)) {
      _catalogReads?.removeListener(_catalogSettled);
      _catalogReads = reads..addListener(_catalogSettled);
    }
    return reads.deprecatedHere()(runtimeId);
  }

  @override
  void dispose() {
    _catalogReads?.removeListener(_catalogSettled);
    super.dispose();
  }
}
