import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

/// Download responses reported by Android's WebView, not a JavaScript API
/// exposed to the document. Session cookies never leave this active binding.
class ArtifactDownloadRequest {
  const ArtifactDownloadRequest({
    required this.url,
    required this.filename,
    required this.mimeType,
    this.cookie = '',
    this.userAgent = '',
    this.rejected = false,
  });
  final String url, filename, mimeType, cookie, userAgent;
  final bool rejected;
}

abstract class ArtifactDownloadBinding {
  Future<void> dispose();
}

typedef ArtifactDownloadBinder = Future<ArtifactDownloadBinding?> Function(
  WebViewController controller,
  Uri origin,
  void Function(ArtifactDownloadRequest) onDownload,
);

/// Public native WebView identifiers let the host replace only the Artifact
/// view's DownloadListener, after the plugin's navigation delegate is ready.
class ArtifactDownloadBridge implements ArtifactDownloadBinding {
  ArtifactDownloadBridge._(this.webViewId, this.bindingId);
  static const channel = MethodChannel('app.raft/artifact-downloads');
  static final _bindings =
      <
        String,
        ({int viewId, void Function(ArtifactDownloadRequest) callback})
      >{};
  static int _serial = 0;
  final int webViewId;
  final String bindingId;

  static Future<ArtifactDownloadBinding?> connect(
    WebViewController controller,
    Uri origin,
    void Function(ArtifactDownloadRequest) onDownload,
  ) async {
    final platform = controller.platform;
    if (platform is! AndroidWebViewController) return null;
    return attach(
      webViewId: platform.webViewIdentifier,
      origin: origin,
      onDownload: onDownload,
    );
  }

  /// Also used by local transport tests to exercise actual channel delivery.
  static Future<ArtifactDownloadBridge> attach({
    required int webViewId,
    required Uri origin,
    required void Function(ArtifactDownloadRequest) onDownload,
  }) async {
    final binding = ArtifactDownloadBridge._(
      webViewId,
      '${DateTime.now().microsecondsSinceEpoch}-${++_serial}',
    );
    _bindings[binding.bindingId] = (viewId: webViewId, callback: onDownload);
    channel.setMethodCallHandler((call) async {
      if (call.method != 'download' || call.arguments is! Map) return;
      final args = call.arguments as Map;
      final target = _bindings[args['bindingId']];
      if (target == null || args['webViewId'] != target.viewId) return;
      final id = args['bindingId'];
      // Each callback is tied to the view as well as its current binding.
      if (id is! String) return;
      target.callback(
        ArtifactDownloadRequest(
          url: args['url'] is String ? args['url'] as String : '',
          filename: args['filename'] is String
              ? args['filename'] as String
              : 'download',
          mimeType: args['mimeType'] is String
              ? args['mimeType'] as String
              : 'application/octet-stream',
          cookie: args['cookie'] is String ? args['cookie'] as String : '',
          userAgent: args['userAgent'] is String
              ? args['userAgent'] as String
              : '',
          rejected: args['error'] != null,
        ),
      );
    });
    try {
      await channel.invokeMethod<void>('attach', {
        'webViewId': webViewId,
        'bindingId': binding.bindingId,
        'origin': origin.origin,
      });
      return binding;
    } catch (_) {
      _bindings.remove(binding.bindingId);
      rethrow;
    }
  }

  @override
  Future<void> dispose() async {
    if (_bindings.remove(bindingId) == null) return;
    try {
      await channel.invokeMethod<void>('detach', {
        'webViewId': webViewId,
        'bindingId': bindingId,
      });
    } on PlatformException {
      // Engine teardown may detach the native view first.
    } on MissingPluginException {
      // No native engine remains.
    }
  }
}
