import 'package:flutter/widgets.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

/// A WebView platform for the Artifact frame: it records the wrapper page,
/// the scripts the app runs in it and its channel, and lets a test play the
/// page (WebKit's navigation request for the base URL, a later main-frame
/// navigation, the page finishing, channel messages from the host script or
/// from a content frame).
class FakeArtifactWebView extends WebViewPlatform {
  static String? html, baseUrl;
  static final scripts = <String>[];
  static final channels = <String, void Function(JavaScriptMessage)>{};
  static NavigationRequestCallback? _onNavigationRequest;
  static PageEventCallback? _onPageFinished;
  static JavaScriptMode? mode;
  static int controllers = 0;

  static void reset() {
    html = null;
    baseUrl = null;
    scripts.clear();
    channels.clear();
    _onNavigationRequest = null;
    _onPageFinished = null;
    mode = null;
    controllers = 0;
  }

  /// The WebView asks whether the main frame may open [url].
  static Future<bool> navigate(String url, {bool mainFrame = true}) async =>
      await _onNavigationRequest!(
        NavigationRequest(url: url, isMainFrame: mainFrame),
      ) ==
      NavigationDecision.navigate;

  static void finish(String url) => _onPageFinished!(url);

  /// A message on the page's channel, as any frame of the page may send one.
  static void post(String message) =>
      channels['RaftArtifactBridge']!(JavaScriptMessage(message: message));

  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) {
    controllers++;
    return _Controller(params);
  }

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) => _Delegate(params);

  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
    PlatformWebViewWidgetCreationParams params,
  ) => _Widget(params);

  @override
  PlatformWebViewCookieManager createPlatformCookieManager(
    PlatformWebViewCookieManagerCreationParams params,
  ) => _Cookies(params);
}

class _Controller extends PlatformWebViewController {
  _Controller(super.params) : super.implementation();

  @override
  Future<void> setJavaScriptMode(JavaScriptMode javaScriptMode) async =>
      FakeArtifactWebView.mode = javaScriptMode;

  @override
  Future<void> addJavaScriptChannel(JavaScriptChannelParams params) async =>
      FakeArtifactWebView.channels[params.name] = params.onMessageReceived;

  @override
  Future<void> setPlatformNavigationDelegate(
    PlatformNavigationDelegate handler,
  ) async {}

  @override
  Future<void> loadHtmlString(String html, {String? baseUrl}) async {
    FakeArtifactWebView.html = html;
    FakeArtifactWebView.baseUrl = baseUrl;
  }

  @override
  Future<void> runJavaScript(String javaScript) async =>
      FakeArtifactWebView.scripts.add(javaScript);

  @override
  Future<Object> runJavaScriptReturningResult(String javaScript) async => '';
}

class _Delegate extends PlatformNavigationDelegate {
  _Delegate(super.params) : super.implementation();

  @override
  Future<void> setOnNavigationRequest(
    NavigationRequestCallback onNavigationRequest,
  ) async => FakeArtifactWebView._onNavigationRequest = onNavigationRequest;

  @override
  Future<void> setOnPageFinished(PageEventCallback onPageFinished) async =>
      FakeArtifactWebView._onPageFinished = onPageFinished;

  @override
  Future<void> setOnPageStarted(PageEventCallback onPageStarted) async {}
  @override
  Future<void> setOnProgress(ProgressCallback onProgress) async {}
  @override
  Future<void> setOnWebResourceError(
    WebResourceErrorCallback onWebResourceError,
  ) async {}
  @override
  Future<void> setOnUrlChange(UrlChangeCallback onUrlChange) async {}
  @override
  Future<void> setOnHttpError(HttpResponseErrorCallback onHttpError) async {}
}

class _Widget extends PlatformWebViewWidget {
  _Widget(super.params) : super.implementation();
  @override
  Widget build(BuildContext context) =>
      const SizedBox.expand(key: ValueKey('fake-artifact-webview'));
}

class _Cookies extends PlatformWebViewCookieManager {
  _Cookies(super.params) : super.implementation();
  @override
  Future<bool> clearCookies() async => true;
}
