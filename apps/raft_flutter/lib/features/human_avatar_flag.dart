import '../data/feature_flag_client_facts.dart';
import '../data/workspace_controller.dart';
import 'management_support.dart';

/// `useServerFeatureFlag(HUMAN_AVATAR_BUILDER_FEATURE_FLAG_KEY).enabled` for
/// the current server: off with no current server (account setup before
/// joining one). The last value evaluated under this identity renders at
/// once; [evaluateHumanAvatarBuilder] refreshes it.
bool humanAvatarBuilderCached(WorkspaceController? w) =>
    w != null &&
    w.server != null &&
    (cachedServerFlag(w, RaftFeatureFlags.humanAvatarBuilder) ?? false);

/// One `POST /feature-flags/evaluate` for the builder flag; null when it
/// could not be asked (no server, or the request failed: the flag stays off,
/// as an unevaluated Web flag does).
Future<bool?> evaluateHumanAvatarBuilder(WorkspaceController? w) async {
  final server = w?.server?.id;
  if (w == null || server == null) return null;
  final identity = pageIdentity(w);
  try {
    final result = await w.command(
      'POST',
      '/feature-flags/evaluate',
      data: featureFlagEvaluateBody(
        keys: const [RaftFeatureFlags.humanAvatarBuilder],
        serverId: server,
      ),
    );
    final on =
        result is Map &&
        (result['evaluations'] as List? ?? []).whereType<Map>().any(
          (f) =>
              f['key'] == RaftFeatureFlags.humanAvatarBuilder &&
              f['enabled'] == true,
        );
    rememberServerFlag(w, RaftFeatureFlags.humanAvatarBuilder, on, identity);
    return on;
  } catch (_) {
    return null;
  }
}
