import 'agent_runtime_catalog.dart';

/// Runtimes Web v1.21.12 marks `deprecated` that the generated catalog (built
/// from the pinned v1.21.2 shared package) still lists as current: Copilot CLI
/// ("deprecated for new agents ... hidden from create/switch/setup selectors
/// and detection display"). Regenerating the catalog at v1.21.12 emits the flag
/// itself; drop this set then.
const _deprecatedBeforePinBump = {'copilot'};

/// `getRuntimeDisplayName(id)`: the product name, else the id itself.
String runtimeDisplayNameOf(String id) =>
    runtimeInfos.where((r) => r.id == id).firstOrNull?.name ?? id;

/// `isRuntimeDeprecated(id)`.
bool isRuntimeDeprecated(String id) =>
    _deprecatedBeforePinBump.contains(id) ||
    (runtimeInfos.where((r) => r.id == id).firstOrNull?.deprecated ?? false);
