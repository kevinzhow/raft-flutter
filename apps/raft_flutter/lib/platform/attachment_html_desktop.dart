import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_inappwebview_platform_interface/flutter_inappwebview_platform_interface.dart';

import 'attachment_html_desktop_environment.dart';
import 'attachment_html_linux.dart';

import 'package:raft_system_webview/raft_system_webview.dart';

import 'attachment_html_geometry.dart';
import 'attachment_html_desktop_policy.dart';
import 'attachment_html_webview_events.dart';

bool get attachmentHtmlDesktopSupported =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.windows &&
            InAppWebViewPlatform.instance != null);

/// Inline system WebKitGTK / WebView2 renderer; mobile keeps its system WebView.
class DesktopAttachmentHtmlWebView extends StatefulWidget {
  const DesktopAttachmentHtmlWebView({
    super.key,
    required this.uri,
    required this.events,
    this.environmentFactory = DesktopHtmlEnvironment.create,
    this.onControllerCreated,
    this.onSystemControllerCreated,
    this.onSystemDisposed,
  });

  final Uri uri;
  final AttachmentHtmlWebViewEvents events;
  final Future<DesktopHtmlEnvironment> Function(TargetPlatform)
  environmentFactory;
  @visibleForTesting
  final void Function(PlatformInAppWebViewController)? onControllerCreated;
  @visibleForTesting
  final void Function(SystemWebViewController)? onSystemControllerCreated;
  @visibleForTesting
  final VoidCallback? onSystemDisposed;

  @override
  State<DesktopAttachmentHtmlWebView> createState() => _DesktopHtmlState();
}

class _DesktopHtmlState extends State<DesktopAttachmentHtmlWebView> {
  late final policy = DesktopHtmlPolicy(
    widget.uri,
    AttachmentHtmlWebViewEvents(
      onNavigation: widget.events.onNavigation,
      onFailed: widget.events.onFailed,
      onProgress: widget.events.onProgress,
      onLoaded: () {
        final current = geometry;
        if (current != null) widget.events.onGeometryReady?.call(current);
        widget.events.onLoaded();
      },
    ),
  );
  AttachmentHtmlGeometryController? geometry;
  DesktopHtmlEnvironment? environment;
  PlatformInAppWebViewWidget? view;
  PlatformInAppWebViewController? controller;

  @override
  void initState() {
    super.initState();
    if (defaultTargetPlatform == TargetPlatform.linux) return;
    // Plugin diagnostics can include signed preview URLs; don't log them.
    PlatformInAppWebViewController.debugLoggingSettings.enabled = false;
    PlatformWebViewEnvironment.debugLoggingSettings.enabled = false;
    unawaited(start());
  }

  Future<void> start() async {
    try {
      final created = await widget.environmentFactory(defaultTargetPlatform);
      if (policy.closed) {
        await created.dispose();
        return;
      }
      environment = created;
      final params = policy.params(
        environment: created.platform,
        onCreated: (controller) => unawaited(attach(controller)),
      );
      final renderer = PlatformInAppWebViewWidget(params);
      if (!policy.closed) setState(() => view = renderer);
    } catch (_) {
      if (!policy.closed) {
        widget.events.onFailed('the preview could not be isolated');
      }
    }
  }

  Future<void> attach(PlatformInAppWebViewController value) async {
    controller = value;
    try {
      if (defaultTargetPlatform == TargetPlatform.windows) {
        // WebView2 has no file-chooser delegate. Intercept it before the first
        // document loads; if unsupported, do not display untrusted HTML.
        final result = await value.callDevToolsProtocolMethod(
          methodName: 'Page.setInterceptFileChooserDialog',
          parameters: {'enabled': true},
        );
        if (result is! Map || result.containsKey('error')) {
          throw StateError('The renderer could not block file selection.');
        }
      }
      if (policy.closed) return;
      geometry = AttachmentHtmlGeometryController(
        uri: widget.uri,
        evaluate: (source) => value.evaluateJavascript(source: source),
        currentUri: () async =>
            Uri.tryParse((await value.getUrl())?.toString() ?? ''),
        allowed: () => !policy.closed && policy.loaded,
      );
      widget.onControllerCreated?.call(value);
      policy.started = true;
      await value.loadUrl(
        urlRequest: URLRequest(url: WebUri(widget.uri.toString())),
      );
    } catch (_) {
      if (!policy.closed) {
        widget.events.onFailed('the preview could not be isolated');
      }
    }
  }

  Future<void> close() async {
    try {
      await controller?.stopLoading();
    } catch (_) {
      // Disposal must still release the renderer after a crashed process.
    } finally {
      view?.dispose();
      try {
        await environment?.dispose();
      } catch (_) {
        // The private profile has no account credentials. Don't retain the
        // view or let asynchronous cleanup escape to the UI error handler.
      }
    }
  }

  @override
  void dispose() {
    policy.closed = true;
    geometry?.dispose();
    unawaited(close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      defaultTargetPlatform == TargetPlatform.linux
      ? LinuxAttachmentHtmlWebView(
          uri: widget.uri,
          events: widget.events,
          onControllerCreated: widget.onSystemControllerCreated,
          onDisposed: widget.onSystemDisposed,
        )
      : view?.build(context) ?? const SizedBox.expand();
}
