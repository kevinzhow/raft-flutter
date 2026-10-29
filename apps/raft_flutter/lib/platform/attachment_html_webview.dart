import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart'
    show PlatformWebViewController;
import 'package:webview_flutter_android/webview_flutter_android.dart';
// ignore: implementation_imports
import 'package:webview_flutter_android/src/android_webkit.g.dart'
    as android_webview;

import 'attachment_html_webview_data.dart';

/// Callbacks from the preview WebView to its owner. The WebView never gets a
/// JavaScript channel, so nothing in the uploaded document can reach the app.
class AttachmentHtmlWebViewEvents {
  const AttachmentHtmlWebViewEvents({
    required this.onNavigation,
    required this.onLoaded,
    required this.onFailed,
    this.onProgress,
  });

  /// Main-frame navigation other than the first load. True lets the WebView
  /// navigate; the owner opens approved links externally and returns false.
  final bool Function(String url) onNavigation;
  final VoidCallback onLoaded;
  final void Function(String reason) onFailed;

  /// Page-load progress, 0..100 (the WebView reports no byte counts).
  final void Function(int percent)? onProgress;
}

typedef AttachmentHtmlWebViewBuilder =
    Widget Function(
      BuildContext context,
      Uri uri,
      AttachmentHtmlWebViewEvents events,
    );

/// True where a platform WebView implementation is registered (Android, iOS
/// and macOS use webview_flutter's WebView / WKWebView; Linux and Windows have
/// no first-party implementation and use the static preview).
bool get attachmentHtmlWebViewSupported => WebViewPlatform.instance != null;

/// Loads the server's isolated `/html-preview` document directly, exactly as
/// the web client's sandboxed iframe does. No `loadHtmlString` / `data:` URL is
/// involved, so there is no size ceiling beyond what the system WebView
/// itself streams. The document's own CSP (`sandbox allow-scripts`, no
/// connect-src) applies to the top-level load, giving it an opaque origin.
class AttachmentHtmlWebView extends StatefulWidget {
  const AttachmentHtmlWebView({
    super.key,
    required this.uri,
    required this.events,
    this.dataFor,
  });
  final Uri uri;

  /// Test seam for the cookie/storage lock-down.
  final AttachmentHtmlWebData Function(WebViewController)? dataFor;
  final AttachmentHtmlWebViewEvents events;
  @override
  State<AttachmentHtmlWebView> createState() => _AttachmentHtmlWebViewState();
}

class _AttachmentHtmlWebViewState extends State<AttachmentHtmlWebView> {
  late final WebViewController controller;
  static final blank = Uri.parse('about:blank').toString();
  late final AttachmentHtmlWebData data;
  bool loadedReported = false, closed = false;

  @override
  void initState() {
    super.initState();
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            // The blank page that unloads the document on close must pass:
            // WKWebView asks the delegate about programmatic loads too.
            if (closed) {
              return request.url == blank
                  ? NavigationDecision.navigate
                  : NavigationDecision.prevent;
            }
            if (!request.isMainFrame) return NavigationDecision.prevent;
            if (request.url == widget.uri.toString() ||
                widget.events.onNavigation(request.url)) {
              return NavigationDecision.navigate;
            }
            return NavigationDecision.prevent;
          },
          onProgress: (percent) {
            if (!closed && !loadedReported) {
              widget.events.onProgress?.call(percent);
            }
          },
          onPageFinished: (_) {
            if (closed || loadedReported) return;
            loadedReported = true;
            widget.events.onLoaded();
          },
          onHttpError: (error) {
            if (!closed && error.request?.uri == widget.uri) {
              widget.events.onFailed(
                'the server answered ${error.response?.statusCode ?? 'with an error'}',
              );
            }
          },
          onWebResourceError: (error) {
            // Blocked or failing subresources (hostile or offline images) are
            // the document's own business; only the page itself is an error.
            if (!closed && (error.isForMainFrame ?? false)) {
              widget.events.onFailed(error.description);
            }
          },
        ),
      );
    // macOS WKWebView has no opaque flag: webview_flutter_wkwebview throws
    // UnimplementedError from setBackgroundColor there (asynchronously, so it
    // escapes to the root error boundary). The page paints its own canvas.
    if (defaultTargetPlatform != TargetPlatform.macOS) {
      unawaited(
        controller
            // ds-allow: the document's own canvas; the web iframe is bg-white
            .setBackgroundColor(Colors.white)
            .catchError((Object _) {}),
      );
    }
    // The document is hostile input: no local files or content providers.
    if (controller.platform case final AndroidWebViewController android) {
      unawaited(android.setAllowFileAccess(false));
      unawaited(android.setAllowContentAccess(false));
    }
    data = widget.dataFor?.call(controller) ?? attachmentHtmlWebData(controller);
    unawaited(start());
  }

  Future<void> start() async {
    try {
      // No cookie, storage or cache from an earlier preview may reach the
      // first request, and the page may not keep any.
      await data.lockDown();
    } catch (_) {
      if (!closed) widget.events.onFailed('the preview could not be isolated');
      return;
    }
    if (!closed) await controller.loadRequest(widget.uri);
  }

  @override
  void dispose() {
    // Unload the document first: its scripts, timers, media and network stop
    // when about:blank replaces it. The delegate (closed) lets only that one
    // navigation through and ignores every later event of the old page.
    closed = true;
    unawaited(
      controller
          .loadRequest(Uri.parse(blank))
          .then((_) => data.purge(), onError: (_) => data.purge()),
    );
    destroyAndroidWebView(controller.platform);
    super.dispose();
  }

  /// How long the platform view needs to leave the view hierarchy before the
  /// native WebView is destroyed.
  static const destroyDelay = Duration(milliseconds: 750);

  /// webview_flutter keeps the native Android `WebView` (its renderer, DOM and
  /// GPU memory, tens of MB for a heavy page) until Dart garbage collection
  /// reaches the controller; closing the preview did not return that memory.
  /// `WebView.destroy()` frees it once the view is detached. The plugin does
  /// not expose the call, so the pigeon proxy is reached through its instance
  /// manager (pinned by pubspec.lock).
  @visibleForTesting
  static void destroyAndroidWebView(
    PlatformWebViewController platform, {
    Duration delay = destroyDelay,
    Future<void> Function(int identifier)? destroy,
  }) {
    if (platform is! AndroidWebViewController) return;
    final id = platform.webViewIdentifier;
    Timer(delay, () {
      Future<void> run() async {
        if (destroy != null) return destroy(id);
        final view = android_webview.PigeonInstanceManager.instance
            .getInstanceWithWeakReference<android_webview.WebView>(id);
        await view?.destroy();
        if (!kReleaseMode) {
          debugPrint('[raft-memory] WebView $id destroyed: ${view != null}');
        }
      }

      unawaited(
        run().catchError((Object error) {
          if (!kReleaseMode) {
            debugPrint('[raft-memory] WebView $id destroy failed: $error');
          }
        }),
      );
    });
  }

  @override
  Widget build(BuildContext context) =>
      WebViewWidget(controller: controller);
}
