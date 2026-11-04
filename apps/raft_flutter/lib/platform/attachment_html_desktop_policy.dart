import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview_platform_interface/flutter_inappwebview_platform_interface.dart';

import 'attachment_html_webview_events.dart';

/// The same server-isolated preview as the Web iframe, with no desktop
/// browser capabilities added to the uploaded document.
class DesktopHtmlPolicy {
  DesktopHtmlPolicy(this.uri, this.events);

  final Uri uri;
  final AttachmentHtmlWebViewEvents events;
  bool closed = false, started = false, loaded = false;

  bool owns(String? url) =>
      Uri.tryParse(url ?? '')?.replace(fragment: '') ==
      uri.replace(fragment: '');

  InAppWebViewSettings get settings => InAppWebViewSettings(
    incognito: true,
    javaScriptEnabled: true,
    javaScriptBridgeEnabled: false,
    javaScriptBridgeOriginAllowList: const {},
    pluginScriptsOriginAllowList: const {},
    domStorageEnabled: false,
    databaseEnabled: false,
    cacheEnabled: false,
    allowFileAccess: false,
    allowContentAccess: false,
    allowFileAccessFromFileURLs: false,
    allowUniversalAccessFromFileURLs: false,
    javaScriptCanOpenWindowsAutomatically: false,
    supportMultipleWindows: false,
    mediaPlaybackRequiresUserGesture: true,
    useShouldOverrideUrlLoading: true,
    isInspectable: false,
    disableContextMenu: true,
    allowModalDialogs: false,
  );

  NavigationActionPolicy navigation(NavigationAction action) {
    final url = action.request.url?.toString();
    if (closed) {
      return url == 'about:blank'
          ? NavigationActionPolicy.ALLOW
          : NavigationActionPolicy.CANCEL;
    }
    if (action.isForMainFrame != true ||
        url == null ||
        (action.request.method ?? 'GET').toUpperCase() != 'GET') {
      return NavigationActionPolicy.CANCEL;
    }
    if (url == uri.toString() || !started && url == 'about:blank') {
      return NavigationActionPolicy.ALLOW;
    }
    // Same-document fragments are harmless; external navigation must come
    // from a real gesture before the owner's URL policy can open a browser.
    final target = Uri.tryParse(url);
    final fragment = target?.replace(fragment: '') == uri.replace(fragment: '');
    // WebView2's pinned adapter serializes its native link classification,
    // derived from IsUserInitiated, rather than Android's hasGesture field.
    final gesture =
        action.hasGesture ??
        (defaultTargetPlatform == TargetPlatform.windows &&
            action.isRedirect != true &&
            action.navigationType == NavigationType.LINK_ACTIVATED);
    if ((fragment || gesture) && events.onNavigation(url)) {
      return NavigationActionPolicy.ALLOW;
    }
    return NavigationActionPolicy.CANCEL;
  }

  PlatformInAppWebViewWidgetCreationParams params({
    PlatformWebViewEnvironment? environment,
    required void Function(PlatformInAppWebViewController) onCreated,
  }) => PlatformInAppWebViewWidgetCreationParams(
    controllerFromPlatform: (controller) => controller,
    webViewEnvironment: environment,
    initialSettings: settings,
    // Start blank. The owner locks down the renderer before loading the URL.
    onWebViewCreated: (controller) => onCreated(controller),
    shouldOverrideUrlLoading: (_, action) => navigation(action),
    onLoadStop: (_, url) {
      if (closed || loaded || !started || !owns(url?.toString())) return;
      loaded = true;
      events.onLoaded();
    },
    onProgressChanged: (_, percent) {
      if (!closed && started && !loaded) events.onProgress?.call(percent);
    },
    onReceivedError: (_, request, error) {
      if (!closed &&
          request.isForMainFrame == true &&
          owns(request.url.toString())) {
        events.onFailed(error.description);
      }
    },
    onReceivedHttpError: (_, request, response) {
      if (!closed && request.url.toString() == uri.toString()) {
        events.onFailed('the server answered ${response.statusCode}');
      }
    },
    onCreateWindow: (_, _) => false,
    onPermissionRequest: (_, request) => PermissionResponse(
      resources: request.resources,
      action: PermissionResponseAction.DENY,
    ),
    onGeolocationPermissionsShowPrompt: (_, origin) =>
        GeolocationPermissionShowPromptResponse(
          origin: origin,
          allow: false,
          retain: false,
        ),
    onShowFileChooser: (_, _) => ShowFileChooserResponse(handledByClient: true),
    onReceivedHttpAuthRequest: (_, _) =>
        HttpAuthResponse(action: HttpAuthResponseAction.CANCEL),
    onReceivedServerTrustAuthRequest: (_, _) =>
        ServerTrustAuthResponse(action: ServerTrustAuthResponseAction.CANCEL),
    onReceivedClientCertRequest: (_, _) =>
        ClientCertResponse(action: ClientCertResponseAction.CANCEL),
    onDownloadStarting: (_, _) => DownloadStartResponse(
      handled: true,
      action: DownloadStartResponseAction.CANCEL,
    ),
    onJsAlert: (_, _) => JsAlertResponse(handledByClient: true),
    onJsConfirm: (_, _) => JsConfirmResponse(handledByClient: true),
    onJsPrompt: (_, _) => JsPromptResponse(handledByClient: true),
  );
}
