import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/platform/attachment_html_webview.dart';
import 'package:raft_flutter/platform/attachment_html_webview_data.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

/// Records what the preview does to its platform WebView, in order.
final log = <String>[];
NavigationRequestCallback? onNavigationRequest;
ProgressCallback? onProgressCallback;

class _Platform extends WebViewPlatform {
  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) => _Controller(params);
  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) => _Delegate(params);
  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
    PlatformWebViewWidgetCreationParams params,
  ) => _Widget(params);
}

class _Controller extends PlatformWebViewController {
  _Controller(super.params) : super.implementation();
  @override
  Future<void> setJavaScriptMode(JavaScriptMode javaScriptMode) async =>
      log.add('js:$javaScriptMode');
  @override
  Future<void> setBackgroundColor(Color color) async {
    // Mirrors webview_flutter_wkwebview: macOS has no opaque flag.
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      throw UnimplementedError('opaque is not implemented on macOS');
    }
    log.add('background');
  }
  @override
  Future<void> setPlatformNavigationDelegate(
    PlatformNavigationDelegate handler,
  ) async {}
  @override
  Future<void> loadRequest(LoadRequestParams params) async =>
      log.add('load:${params.uri}');
}

class _Delegate extends PlatformNavigationDelegate {
  _Delegate(super.params) : super.implementation();
  @override
  Future<void> setOnNavigationRequest(
    NavigationRequestCallback callback,
  ) async => onNavigationRequest = callback;
  @override
  Future<void> setOnProgress(ProgressCallback callback) async =>
      onProgressCallback = callback;
  @override
  Future<void> setOnPageFinished(PageEventCallback callback) async {}
  @override
  Future<void> setOnHttpError(HttpResponseErrorCallback callback) async {}
  @override
  Future<void> setOnWebResourceError(
    WebResourceErrorCallback callback,
  ) async {}
}

class _Widget extends PlatformWebViewWidget {
  _Widget(super.params) : super.implementation();
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _Data implements AttachmentHtmlWebData {
  @override
  Future<void> lockDown() async => log.add('lockDown');
  @override
  Future<void> purge() async => log.add('purge');
}

void main() {
  setUpAll(() => WebViewPlatform.instance = _Platform());
  setUp(() {
    log.clear();
    onNavigationRequest = null;
    onProgressCallback = null;
  });

  final uri = Uri.parse('https://api.example/api/attachments/a/html-preview?previewToken=t');
  Widget view(AttachmentHtmlWebViewEvents events) => MaterialApp(
    home: AttachmentHtmlWebView(
      uri: uri,
      events: events,
      dataFor: (_) => _Data(),
    ),
  );

  testWidgets('cookies, storage and cache are locked down before the first request', (tester) async {
    await tester.pumpWidget(
      view(
        AttachmentHtmlWebViewEvents(
          onNavigation: (_) => false,
          onLoaded: () {},
          onFailed: (_) {},
        ),
      ),
    );
    await tester.pump();
    expect(log.indexOf('lockDown'), isNonNegative);
    expect(log.indexOf('load:$uri'), greaterThan(log.indexOf('lockDown')));
  });

  testWidgets('closing unloads the document through about:blank, then purges, and ignores the old page', (tester) async {
    var navigations = 0, failures = 0, loaded = 0;
    await tester.pumpWidget(
      view(
        AttachmentHtmlWebViewEvents(
          onNavigation: (_) {
            navigations++;
            return true;
          },
          onLoaded: () => loaded++,
          onFailed: (_) => failures++,
        ),
      ),
    );
    await tester.pump();
    final request = onNavigationRequest!;
    expect(
      await request(NavigationRequest(url: uri.toString(), isMainFrame: true)),
      NavigationDecision.navigate,
    );
    log.clear();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    // The blank page must be allowed even though the preview is closed:
    // WKWebView asks the delegate about programmatic loads as well.
    expect(
      await request(NavigationRequest(url: 'about:blank', isMainFrame: true)),
      NavigationDecision.navigate,
    );
    // Nothing else may start after close (a script redirecting the old page).
    for (final url in [uri.toString(), 'https://example.com/', 'file:///etc/passwd']) {
      expect(
        await request(NavigationRequest(url: url, isMainFrame: true)),
        NavigationDecision.prevent,
        reason: url,
      );
    }
    expect([navigations, failures, loaded], [0, 0, 0]);
    await tester.pump();
    expect(log, ['load:about:blank', 'purge']);
  });

  testWidgets('macOS never sets a background colour (WKWebView has no opaque flag)', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      await tester.pumpWidget(
        view(
          AttachmentHtmlWebViewEvents(
            onNavigation: (_) => false,
            onLoaded: () {},
            onFailed: (_) {},
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(log, isNot(contains('background')));
      expect(log, contains('load:$uri'));
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('page-load progress reaches the owner until the page finished or the preview closed', (tester) async {
    final percents = <int>[];
    await tester.pumpWidget(
      view(
        AttachmentHtmlWebViewEvents(
          onNavigation: (_) => false,
          onLoaded: () {},
          onFailed: (_) {},
          onProgress: percents.add,
        ),
      ),
    );
    await tester.pump();
    onProgressCallback!(0);
    onProgressCallback!(40);
    onProgressCallback!(100);
    expect(percents, [0, 40, 100]);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    onProgressCallback!(60);
    expect(percents, [0, 40, 100], reason: 'the closed page reports nothing');
  });
}
