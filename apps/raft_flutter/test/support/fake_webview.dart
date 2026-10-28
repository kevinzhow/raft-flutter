import 'package:flutter/widgets.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

/// A WebView platform that loads nothing: it records what the app asks the
/// WebView to do and lets a test play the page (navigation requests, finished
/// loads, URL changes) through the app's own navigation delegate.
class FakeWebView extends WebViewPlatform {
  /// Every `loadRequest`, in order.
  static final loads = <String>[];
  static final loadHeaders = <Map<String, String>>[];

  /// The URL the fake page shows (what `currentUrl()` answers).
  static String? shown;
  static final _history = <String>[];
  static int backCalls = 0;

  static void _show(String url) {
    if (_history.isEmpty || _history.last != url) _history.add(url);
    shown = url;
  }

  static NavigationRequestCallback? _onNavigationRequest;
  static PageEventCallback? _onPageFinished;
  static UrlChangeCallback? _onUrlChange;
  static WebResourceErrorCallback? _onError;
  static JavaScriptMode? javaScriptMode;

  /// `cookies`, `localStorage`, `cache`: what the app asked to clear.
  static final cleared = <String>[];

  static void reset() {
    loads.clear();
    loadHeaders.clear();
    shown = null;
    _history.clear();
    backCalls = 0;
    javaScriptMode = null;
    cleared.clear();
    _onNavigationRequest = null;
    _onPageFinished = null;
    _onUrlChange = null;
    _onError = null;
  }

  /// The WebView asked the app whether it may open [url] (a main-frame link,
  /// a redirect). True when it may.
  static Future<bool> navigate(String url, {bool mainFrame = true}) async {
    final decision = await _onNavigationRequest!(
      NavigationRequest(url: url, isMainFrame: mainFrame),
    );
    if (decision == NavigationDecision.navigate && mainFrame) _show(url);
    return decision == NavigationDecision.navigate;
  }

  /// A page finished loading.
  static void finish(String url) {
    shown = url;
    _onPageFinished!(url);
  }

  /// The URL changed without a navigation request (a platform that reports a
  /// redirect only after it started loading).
  static void urlChanged(String url) {
    shown = url;
    _onUrlChange!(UrlChange(url: url));
  }

  static void failMainFrame(String description) => _onError!(
    WebResourceError(
      errorCode: -2,
      description: description,
      isForMainFrame: true,
    ),
  );

  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) => _Controller(params);
  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) => _Delegate(params);
  @override
  PlatformWebViewCookieManager createPlatformCookieManager(
    PlatformWebViewCookieManagerCreationParams params,
  ) => _Cookies(params);
  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
    PlatformWebViewWidgetCreationParams params,
  ) => _Widget(params);
}

class _Controller extends PlatformWebViewController {
  _Controller(super.params) : super.implementation();
  @override
  Future<void> setJavaScriptMode(JavaScriptMode mode) async =>
      FakeWebView.javaScriptMode = mode;
  @override
  Future<void> setPlatformNavigationDelegate(
    PlatformNavigationDelegate handler,
  ) async {}
  @override
  Future<void> loadRequest(LoadRequestParams params) async {
    FakeWebView.loads.add(params.uri.toString());
    FakeWebView.loadHeaders.add(Map.of(params.headers));
    FakeWebView._show(params.uri.toString());
  }

  @override
  Future<bool> canGoBack() async => FakeWebView._history.length > 1;
  @override
  Future<void> goBack() async {
    FakeWebView.backCalls++;
    if (FakeWebView._history.length < 2) return;
    FakeWebView._history.removeLast();
    FakeWebView.finish(FakeWebView._history.last);
  }

  @override
  Future<String?> currentUrl() async => FakeWebView.shown;
  @override
  Future<void> clearLocalStorage() async =>
      FakeWebView.cleared.add('localStorage');
  @override
  Future<void> clearCache() async => FakeWebView.cleared.add('cache');
}

class _Cookies extends PlatformWebViewCookieManager {
  _Cookies(super.params) : super.implementation();
  @override
  Future<bool> clearCookies() async {
    FakeWebView.cleared.add('cookies');
    return true;
  }
}

class _Delegate extends PlatformNavigationDelegate {
  _Delegate(super.params) : super.implementation();
  @override
  Future<void> setOnNavigationRequest(
    NavigationRequestCallback callback,
  ) async => FakeWebView._onNavigationRequest = callback;
  @override
  Future<void> setOnPageFinished(PageEventCallback callback) async =>
      FakeWebView._onPageFinished = callback;
  @override
  Future<void> setOnUrlChange(UrlChangeCallback callback) async =>
      FakeWebView._onUrlChange = callback;
  @override
  Future<void> setOnProgress(ProgressCallback callback) async {}
  @override
  Future<void> setOnWebResourceError(WebResourceErrorCallback callback) async =>
      FakeWebView._onError = callback;
}

class _Widget extends PlatformWebViewWidget {
  _Widget(super.params) : super.implementation();
  @override
  Widget build(BuildContext context) =>
      const SizedBox.expand(key: ValueKey('fake-webview'));
}
