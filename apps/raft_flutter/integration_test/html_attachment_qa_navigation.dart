part of 'html_attachment_qa_main.dart';

final _navigationRequests = <Map<String, Object?>>[];
bool _navigationObserverReady = false;
String? _navigationObserverFailure;
int _scriptNavigationAttempts = 0;

Future<void> _watchQaNavigation(
  PlatformInAppWebViewController controller,
) async {
  _navigationObserverReady = false;
  _navigationObserverFailure = null;
  if (!Platform.isWindows) return;
  try {
    await controller.callDevToolsProtocolMethod(methodName: 'Page.enable');
    await controller.addDevToolsProtocolEventListener(
      eventName: 'Page.frameRequestedNavigation',
      callback: (dynamic data) {
        if (_controller != controller || data is! Map) return;
        _navigationRequests.add({
          'url': data['url'],
          'reason': data['reason'],
          'disposition': data['disposition'],
        });
      },
    );
    if (_controller == controller) _navigationObserverReady = true;
  } catch (_) {
    if (_controller == controller) {
      _navigationObserverFailure = 'Native navigation observation unavailable';
    }
  }
}

Future<void> _attemptQaScriptNavigation(HttpRequest request) async {
  request.response.headers.contentType = ContentType.json;
  final controller = _controller;
  if (controller == null || !_loaded || !_navigationObserverReady) {
    request.response.statusCode = HttpStatus.conflict;
    request.response.write(jsonEncode({'scheduled': false}));
    return;
  }
  // No pointer/keyboard gesture. The same destination is also used by the real
  // link, so running this after a click detects reuse of stale trusted metadata.
  final result = await controller.evaluateJavascript(
    source: '''window.setTimeout(() => {
      location.assign('https://example.com/');
    }, 25); 'scheduled';''',
  );
  _scriptNavigationAttempts++;
  request.response.statusCode = HttpStatus.accepted;
  request.response.write(
    jsonEncode({
      'scheduled': true,
      'attempt': _scriptNavigationAttempts,
      'target': 'https://example.com/',
      'evaluation': result,
    }),
  );
}
