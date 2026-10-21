import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart' show raftText;

import 'agent_runtime_catalog.dart';

/// `getRuntimeDisplayName(id)`: the product name, else the id itself.
String runtimeDisplayNameOf(String id) =>
    runtimeInfos.where((r) => r.id == id).firstOrNull?.name ?? id;

/// `isRuntimeDeprecated(id)`.
bool isRuntimeDeprecated(String id) =>
    runtimeInfos.where((r) => r.id == id).firstOrNull?.deprecated ?? false;

/// `formatRuntimeLabelWithStatus`: the product name plus the lifecycle status
/// for identity display (subtitles, badges, pickers). Prose that interpolates
/// a runtime into a sentence uses the bare [runtimeDisplayNameOf] instead.
String runtimeLabelWithStatus(BuildContext context, String runtime) {
  final name = runtimeDisplayNameOf(runtime);
  return isRuntimeDeprecated(runtime)
      ? '$name${raftText(context, ' (deprecated)')}'
      : name;
}

/// `getCreatableRuntimeOptions()` ids: supported and not deprecated, the
/// runtimes a new agent can be created with (Web CreateAgentDialog intersects
/// the server's admission options with this set).
final Set<String> creatableRuntimeIds = {
  for (final r in runtimeInfos)
    if (r.supported && !isRuntimeDeprecated(r.id)) r.id,
};
