import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_inappwebview_linux/flutter_inappwebview_linux.dart';
import 'package:flutter_inappwebview_platform_interface/flutter_inappwebview_platform_interface.dart';

import 'attachment_html_desktop_environment.dart';
import 'attachment_html_desktop_policy.dart';
import 'attachment_html_webview_events.dart';

bool get attachmentHtmlDesktopSupported =>
    !kIsWeb &&
    const {
      TargetPlatform.linux,
      TargetPlatform.windows,
    }.contains(defaultTargetPlatform) &&
    InAppWebViewPlatform.instance != null;

/// Inline WPE/WebView2 renderer; mobile keeps its existing system WebView.
class DesktopAttachmentHtmlWebView extends StatefulWidget {
  const DesktopAttachmentHtmlWebView({
    super.key,
    required this.uri,
    required this.events,
    this.environmentFactory = DesktopHtmlEnvironment.create,
    this.onControllerCreated,
  });

  final Uri uri;
  final AttachmentHtmlWebViewEvents events;
  final Future<DesktopHtmlEnvironment> Function(TargetPlatform)
  environmentFactory;
  @visibleForTesting
  final void Function(PlatformInAppWebViewController)? onControllerCreated;

  @override
  State<DesktopAttachmentHtmlWebView> createState() => _DesktopHtmlState();
}

class _DesktopHtmlState extends State<DesktopAttachmentHtmlWebView> {
  late final policy = DesktopHtmlPolicy(widget.uri, widget.events);
  DesktopHtmlEnvironment? environment;
  PlatformInAppWebViewWidget? view;
  PlatformInAppWebViewController? controller;

  @override
  void initState() {
    super.initState();
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
      var params = policy.params(
        environment: created.platform,
        onCreated: (controller) => unawaited(attach(controller)),
      );
      if (defaultTargetPlatform == TargetPlatform.linux) {
        params = _LinuxHtmlParams(params);
      }
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
    unawaited(close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      view?.build(context) ?? const SizedBox.expand();
}

/// The pinned Linux adapter omits this newer callback while copying generic
/// creation params. Preserve it so a document cannot open a local file picker.
class _LinuxHtmlParams extends LinuxInAppWebViewWidgetCreationParams {
  _LinuxHtmlParams(this.source)
    : super.fromPlatformInAppWebViewWidgetCreationParams(source);
  final PlatformInAppWebViewWidgetCreationParams source;

  @override
  FutureOr<ShowFileChooserResponse?> Function(dynamic, ShowFileChooserRequest)?
  get onShowFileChooser => source.onShowFileChooser;
}
