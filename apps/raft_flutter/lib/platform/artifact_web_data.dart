import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Clears what the in-app artifact browser kept: cookies (the artifact site's
/// session), local storage and the HTTP cache. The WebView shares one store
/// for the whole app, so this runs wherever the app ends its own session
/// (`purgeAccountCaches`: sign-out, an account switch, a session the server
/// ended): the next person must not inherit the previous person's
/// raft-artifacts.com session. Never throws; there is nothing to clear where the
/// platform has no WebView (Linux, Windows).
Future<void> clearArtifactWebData() => artifactWebDataClearer();

/// Replaced by tests that count the calls.
@visibleForTesting
Future<void> Function() artifactWebDataClearer =
    debugPlatformArtifactWebDataClearer;

/// The real clearer (tests put it back).
@visibleForTesting
Future<void> debugPlatformArtifactWebDataClearer() => _clearPlatformWebData();

Future<void> _clearPlatformWebData() async {
  if (WebViewPlatform.instance == null) return;
  try {
    await WebViewCookieManager().clearCookies();
  } on Object catch (error) {
    debugPrint('[artifact-web-data] cookies not cleared: ${error.runtimeType}');
  }
  try {
    // Storage and cache belong to a WebView, not to a manager: a controller
    // that never shows a page reaches the same store.
    final controller = WebViewController();
    await controller.clearLocalStorage();
    await controller.clearCache();
  } on Object catch (error) {
    debugPrint('[artifact-web-data] storage not cleared: ${error.runtimeType}');
  }
}
