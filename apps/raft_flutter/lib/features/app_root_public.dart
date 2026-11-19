import 'package:flutter/widgets.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/device_display_preferences.dart';
import '../data/public_server_route.dart';
import 'artifacts/artifact_public_page.dart';
import 'public_server_view.dart';

String? artifactSignInPurpose(Uri location, String origin, bool dismissed) =>
    dismissed && publicArtifactRoute(location, origin) != null
    ? 'Sign in to open this Artifact'
    : null;

Widget? signedOutPublicPage({
  required Uri location,
  required String origin,
  required RaftClient Function() client,
  required DeviceDisplayPreferences appearance,
  required ValueChanged<RaftAppearance> onAppearance,
  required void Function({String? mode}) dismiss,
}) {
  if (publicArtifactRoute(location, origin) case final artifact?) {
    return ArtifactPublicPage(
      key: ValueKey(artifact),
      client: client(),
      id: artifact,
      onBack: dismiss,
      onSignIn: () => dismiss(mode: 'login'),
    );
  }
  if (publicRoute(location) case final route?) {
    return PublicServerView(
      key: ValueKey('public-${route.slug}-anonymous'),
      client: client(),
      slug: route.slug,
      appearance: appearance.value,
      onAppearance: onAppearance,
      displayLanguage: appearance.displayLanguage,
      initialChannelId: route.channelId,
      onSignIn: () => dismiss(mode: 'login'),
      onRegister: () => dismiss(mode: 'register'),
      onUnavailable: dismiss,
    );
  }
  return null;
}
