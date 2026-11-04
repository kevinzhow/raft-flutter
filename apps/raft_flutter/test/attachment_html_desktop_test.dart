import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview_platform_interface/flutter_inappwebview_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/platform/attachment_html_desktop.dart';
import 'package:raft_flutter/platform/attachment_html_desktop_environment.dart';
import 'package:raft_flutter/platform/attachment_html_desktop_policy.dart';
import 'package:raft_flutter/platform/attachment_html_webview.dart';

class _Controller extends PlatformInAppWebViewController {
  _Controller()
    : super.implementation(
        const PlatformInAppWebViewControllerCreationParams(id: 'qa'),
      );
  final calls = <String>[];
  bool failProtocol = false;
  @override
  Future<void> loadUrl({
    required URLRequest urlRequest,
    Uri? iosAllowingReadAccessTo,
    WebUri? allowingReadAccessTo,
  }) async {
    expect(urlRequest.headers, isNull);
    calls.add('load:${urlRequest.url}');
  }

  @override
  Future<dynamic> callDevToolsProtocolMethod({
    required String methodName,
    Map<String, dynamic>? parameters,
  }) async {
    expect(parameters, {'enabled': true});
    calls.add('cdp:$methodName');
    if (failProtocol) return null;
    return <String, dynamic>{};
  }

  @override
  Future<void> stopLoading() async => calls.add('stop');
}

class _NativeView extends PlatformInAppWebViewWidget {
  _NativeView(super.params) : super.implementation();
  final controller = _Controller();
  bool created = false, disposed = false;
  @override
  Widget build(BuildContext context) {
    if (!created) {
      created = true;
      params.onWebViewCreated?.call(controller);
    }
    return const SizedBox(key: ValueKey('native-desktop-html'));
  }

  @override
  T controllerFromPlatform<T>(PlatformInAppWebViewController controller) =>
      controller as T;
  @override
  void dispose() => disposed = true;
}

class _DesktopPlatform extends InAppWebViewPlatform {
  _DesktopPlatform({this.failProtocol = false});
  final bool failProtocol;
  _NativeView? view;
  @override
  PlatformInAppWebViewWidget createPlatformInAppWebViewWidget(
    PlatformInAppWebViewWidgetCreationParams params,
  ) {
    view = _NativeView(params);
    view!.controller.failProtocol = failProtocol;
    return view!;
  }
}

class _PendingEnvironment extends DesktopHtmlEnvironment {
  bool disposed = false;
  @override
  Future<void> dispose() async => disposed = true;
}

void main() {
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  for (final platform in [TargetPlatform.linux, TargetPlatform.windows]) {
    test('registered $platform renderer enables interactive HTML previews', () {
      debugDefaultTargetPlatformOverride = platform;
      InAppWebViewPlatform.instance = _DesktopPlatform();

      expect(attachmentHtmlWebViewSupported, isTrue);
    });
  }

  final uri = Uri.parse(
    'https://api.example/api/attachments/a/html-preview?previewToken=qa',
  );
  AttachmentHtmlWebViewEvents events({
    void Function()? onLoaded,
    void Function(String)? onFailed,
  }) => AttachmentHtmlWebViewEvents(
    onNavigation: (_) => false,
    onLoaded: onLoaded ?? () {},
    onFailed: onFailed ?? (_) {},
  );

  test(
    'desktop settings isolate the document without removing script rendering',
    () {
      final settings = DesktopHtmlPolicy(uri, events()).settings;
      expect(settings.javaScriptEnabled, isTrue);
      expect(settings.incognito, isTrue);
      expect(settings.javaScriptBridgeEnabled, isFalse);
      expect(settings.javaScriptBridgeOriginAllowList, isEmpty);
      expect(settings.pluginScriptsOriginAllowList, isEmpty);
      expect(settings.allowFileAccess, isFalse);
      expect(settings.allowContentAccess, isFalse);
      expect(settings.allowUniversalAccessFromFileURLs, isFalse);
      expect(settings.domStorageEnabled, isFalse);
      expect(settings.isInspectable, isFalse);
    },
  );

  test(
    'only preview navigation or a parent-approved user gesture can leave blank',
    () {
      final requested = <String>[];
      final policy = DesktopHtmlPolicy(
        uri,
        AttachmentHtmlWebViewEvents(
          onNavigation: (url) {
            requested.add(url);
            return false;
          },
          onLoaded: () {},
          onFailed: (_) {},
        ),
      );
      NavigationAction action(
        String url, {
        bool frame = true,
        bool gesture = false,
      }) => NavigationAction(
        request: URLRequest(url: WebUri(url)),
        isForMainFrame: frame,
        hasGesture: gesture,
      );
      expect(
        policy.navigation(action(uri.toString())),
        NavigationActionPolicy.ALLOW,
      );
      expect(
        policy.navigation(action(uri.toString(), frame: false)),
        NavigationActionPolicy.CANCEL,
      );
      policy.started = true;
      expect(
        policy.navigation(action('https://external.example')),
        NavigationActionPolicy.CANCEL,
      );
      expect(requested, isEmpty);
      expect(
        policy.navigation(action('https://external.example', gesture: true)),
        NavigationActionPolicy.CANCEL,
      );
      expect(requested, ['https://external.example']);
      policy.closed = true;
      expect(
        policy.navigation(action(uri.toString())),
        NavigationActionPolicy.CANCEL,
      );
      expect(
        policy.navigation(action('about:blank')),
        NavigationActionPolicy.ALLOW,
      );
    },
  );

  test(
    'documents cannot request device permissions, local files or downloads',
    () async {
      final params = DesktopHtmlPolicy(uri, events()).params(onCreated: (_) {});
      final controller = _Controller();
      final permission = await params.onPermissionRequest!(
        controller,
        PermissionRequest(origin: WebUri('https://api.example')),
      );
      expect(permission?.action, PermissionResponseAction.DENY);
      final file = await params.onShowFileChooser!(
        controller,
        ShowFileChooserRequest(
          acceptTypes: const [],
          isCaptureEnabled: false,
          mode: ShowFileChooserRequestMode.OPEN,
        ),
      );
      expect(file?.handledByClient, isTrue);
      expect(file?.filePaths, isNull);
      final download = await params.onDownloadStarting!(
        controller,
        DownloadStartRequest(
          url: WebUri('https://external.example'),
          contentLength: 12,
        ),
      );
      expect(download?.action, DownloadStartResponseAction.CANCEL);
      expect(
        await params.onCreateWindow!(
          controller,
          CreateWindowAction(
            request: URLRequest(url: WebUri('https://external.example')),
            isForMainFrame: true,
            windowId: 1,
          ),
        ),
        isFalse,
      );
    },
  );

  test('blank, unrelated loads and late callbacks cannot report document completion', () {
    var loaded = 0, failed = 0;
    final policy = DesktopHtmlPolicy(
      uri,
      events(onLoaded: () => loaded++, onFailed: (_) => failed++),
    )..started = true;
    final params = policy.params(onCreated: (_) {}), controller = _Controller();
    params.onLoadStop!(controller, WebUri('about:blank'));
    params.onLoadStop!(controller, WebUri('https://other.example'));
    expect(loaded, 0);
    params.onLoadStop!(controller, WebUri(uri.toString()));
    params.onLoadStop!(controller, WebUri(uri.toString()));
    expect(loaded, 1);
    policy.closed = true;
    params.onReceivedError!(
      controller,
      WebResourceRequest(url: WebUri(uri.toString()), isForMainFrame: true),
      WebResourceError(
        description: 'late',
        type: WebResourceErrorType.HOST_LOOKUP,
      ),
    );
    expect(failed, 0);
  });

  for (final platform in [TargetPlatform.linux, TargetPlatform.windows]) {
    testWidgets(
      '$platform renderer loads only after lockdown and releases on close',
      (tester) async {
        debugDefaultTargetPlatformOverride = platform;
        try {
          final native = _DesktopPlatform();
          InAppWebViewPlatform.instance = native;
          await tester.pumpWidget(
            MaterialApp(
              home: DesktopAttachmentHtmlWebView(
                uri: uri,
                events: events(),
                environmentFactory: (_) async => DesktopHtmlEnvironment(),
              ),
            ),
          );
          await tester.pump();
          final view = native.view!;
          expect(
            find.byKey(const ValueKey('native-desktop-html')),
            findsOneWidget,
          );
          expect(view.params.initialUrlRequest, isNull);
          expect(view.params.onShowFileChooser, isNotNull);
          expect(view.controller.calls, [
            if (platform == TargetPlatform.windows)
              'cdp:Page.setInterceptFileChooserDialog',
            'load:$uri',
          ]);
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          expect(view.controller.calls.last, 'stop');
          expect(view.disposed, isTrue);
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      },
    );
  }

  testWidgets('unsupported Windows hardening does not fetch the document', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      final native = _DesktopPlatform(failProtocol: true);
      InAppWebViewPlatform.instance = native;
      final failed = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: DesktopAttachmentHtmlWebView(
            uri: uri,
            events: events(onFailed: failed.add),
            environmentFactory: (_) async => DesktopHtmlEnvironment(),
          ),
        ),
      );
      await tester.pump();
      expect(failed, ['the preview could not be isolated']);
      expect(native.view!.controller.calls, [
        'cdp:Page.setInterceptFileChooserDialog',
      ]);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(native.view!.disposed, isTrue);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('closing during environment creation disposes the late profile', (
    tester,
  ) async {
    final ready = Completer<DesktopHtmlEnvironment>();
    final pending = _PendingEnvironment();
    await tester.pumpWidget(
      MaterialApp(
        home: DesktopAttachmentHtmlWebView(
          uri: uri,
          events: events(),
          environmentFactory: (_) => ready.future,
        ),
      ),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    ready.complete(pending);
    await tester.pump();
    expect(pending.disposed, isTrue);
  });
}
