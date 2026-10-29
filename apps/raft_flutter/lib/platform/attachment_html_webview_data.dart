import 'dart:async';

import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
// The public Android API cannot reach WebSettings; the same instance lookup
// webview_flutter_android's own cookie manager uses.
// ignore: implementation_imports
import 'package:webview_flutter_android/src/android_webkit.g.dart'
    show PigeonInstanceManager, WebView;
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

/// Keeps an uploaded document's WebView as isolated from the app and from
/// other previews as Web's sandboxed iframe: the sandbox gives the document an
/// opaque origin with no cookie, storage or cache carry-over. The native
/// WebViews are not opaque-origin by default, so the preview's cookies,
/// storage and cache are locked down before the document loads and purged
/// when the preview goes away.
abstract class AttachmentHtmlWebData {
  /// Runs and completes before the first request of a preview.
  Future<void> lockDown();

  /// Runs after the preview is closed.
  Future<void> purge();
}

AttachmentHtmlWebData attachmentHtmlWebData(WebViewController controller) =>
    switch (controller.platform) {
      final AndroidWebViewController android => _AndroidWebData(android),
      final WebKitWebViewController webKit => _DarwinWebData(
        webKit,
        WebKitWebViewCookieManager(
          const PlatformWebViewCookieManagerCreationParams(),
        ),
      ),
      _ => const _NoWebData(),
    };

class _NoWebData implements AttachmentHtmlWebData {
  const _NoWebData();
  @override
  Future<void> lockDown() async {}
  @override
  Future<void> purge() async {}
}

/// Android: CookieManager is process-wide and the app has no other WebView, so
/// the platform channel switches cookies off entirely (neither sent nor
/// stored) and clears the jar and web storage; third-party cookies and DOM
/// storage are also off for this instance, and the HTTP cache is cleared.
class _AndroidWebData implements AttachmentHtmlWebData {
  _AndroidWebData(this.controller);
  final AndroidWebViewController controller;
  static const channel = MethodChannel('app.raft/html-preview-privacy');

  @override
  Future<void> lockDown() async {
    await channel.invokeMethod<void>('lockDown');
    await AndroidWebViewCookieManager(
      const PlatformWebViewCookieManagerCreationParams(),
    ).setAcceptThirdPartyCookies(controller, false);
    final webView = PigeonInstanceManager.instance
        .getInstanceWithWeakReference<WebView>(controller.webViewIdentifier);
    await webView?.settings.setDomStorageEnabled(false);
    await controller.clearCache();
  }

  @override
  Future<void> purge() async {
    try {
      await controller.clearCache();
    } catch (_) {
      // The view may already be gone; the channel purge below still runs.
    }
    await channel.invokeMethod<void>('purge');
  }
}

/// iOS/macOS: webview_flutter_wkwebview always uses WKWebView's default
/// (persistent) website data store and exposes no non-persistent one. The app
/// has no other WKWebView, so the default store holds only preview data:
/// cookies, local storage and caches are cleared before the document loads and
/// again after the preview closes. Within one open preview the document's own
/// cookies can exist; the CSP sandbox (opaque origin) denies it script access.
class _DarwinWebData implements AttachmentHtmlWebData {
  _DarwinWebData(this.controller, this.cookies);
  final WebKitWebViewController controller;
  final WebKitWebViewCookieManager cookies;

  Future<void> clear() async {
    await cookies.clearCookies();
    await controller.clearLocalStorage();
    await controller.clearCache();
  }

  @override
  Future<void> lockDown() => clear();

  @override
  Future<void> purge() async {
    try {
      await clear();
    } catch (_) {
      // Best effort after dispose; the next preview clears again before load.
    }
  }
}
