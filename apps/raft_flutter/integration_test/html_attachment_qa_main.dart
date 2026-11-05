// Isolated native renderer acceptance entry. It starts no AppRoot, account,
// session store, notification worker or production connection.
import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview_platform_interface/flutter_inappwebview_platform_interface.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_system_webview/raft_system_webview.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/attachment_html_preview.dart';
import 'package:raft_flutter/platform/attachment_html.dart';
import 'package:raft_flutter/platform/attachment_html_desktop.dart';
import 'package:raft_flutter/platform/attachment_html_desktop_environment.dart';
import 'package:raft_flutter/platform/attachment_html_webview.dart';
import 'package:raft_ui/raft_ui.dart';

part 'html_attachment_qa_navigation.dart';

const _csp =
    "default-src 'none'; sandbox allow-scripts; "
    "script-src 'unsafe-inline'; style-src 'unsafe-inline'; img-src data: blob:; "
    "connect-src 'none'; object-src 'none'; base-uri 'none'; "
    "form-action 'none'; worker-src 'none'";

const _document = '''<!doctype html><meta charset="utf-8">
<title>Raft isolated HTML QA</title>
<style>body{font:20px sans-serif;padding:32px;background:#f8fafc;color:#172554}
h1{background:#d9f99d;padding:12px}button{font-size:22px;padding:12px}
canvas{border:2px solid #172554;display:block;margin-top:20px}</style>
<h1>CSS and script preview</h1><p>This is a local fixture with no account.</p>
<button id="increment" onclick="count.textContent=Number(count.textContent)+1">Increment</button>
<strong id="count">0</strong><canvas id="chart" width="320" height="120"></canvas>
<p><input id="file" type="file"> <a id="external" href="https://example.com">External link</a></p>
<p><a id="externalBlank" target="_blank" href="https://example.com/blank">External blank link</a></p>
<p><a id="namedFrame" target="qaChild" href="https://example.com/named">Named frame link</a></p>
<iframe name="qaChild" title="Forbidden target" srcdoc="<p>Child target</p>" style="width:240px;height:36px"></iframe>
<p><button id="scriptPopup" onclick="window.open('https://example.com/script-popup','_blank')">Script popup</button></p>
<form action="https://example.com/post" method="post"><button id="post" type="submit">POST navigation</button></form>
<script>
window.qaLastClick=null;window.qaScriptNavigationFired=0;
window.qaPointerEvents=[];window.qaScriptNavigationRequested=false;
for(const type of ['pointerdown','mousedown','pointerup','mouseup','click']){
  document.addEventListener(type,event=>{
    const target=event.target.closest('button,input,a');
    if(target){
      qaPointerEvents.push({type,id:target.id,trusted:event.isTrusted,
        button:event.button,buttons:event.buttons});
      if(qaPointerEvents.length>24)qaPointerEvents.shift();
    }
  },true);
}
// This timer belongs to document loading, not a host JavaScript evaluation.
// A native evaluation may carry user-gesture authority; a timer created by
// that API cannot establish a document-owned scripted-navigation negative.
window.setInterval(()=>{
  if(!window.qaScriptNavigationRequested)return;
  window.qaScriptNavigationRequested=false;
  window.qaScriptNavigationFired++;
  location.assign('https://example.com/');
},50);
document.addEventListener('click',event=>{
  const target=event.target.closest('button,input,a');
  if(target)window.qaLastClick={id:target.id,trusted:event.isTrusted};
},true);
const ctx=chart.getContext('2d');ctx.fillStyle='#1e40af';ctx.fillRect(0,0,320,120);
window.qaNetwork='pending';fetch('/qa-exfil').then(()=>qaNetwork='allowed',()=>qaNetwork='blocked');
window.qaStorage='allowed';try{localStorage.setItem('qa','1')}catch(_){qaStorage='blocked'}
</script>''';

PlatformInAppWebViewController? _controller;
SystemWebViewController? _systemController;

Future<Object?> _evaluateDocument(String source) {
  final system = _systemController;
  if (system != null) return system.evaluate(source);
  final windows = _controller;
  if (windows != null) return windows.evaluateJavascript(source: source);
  throw StateError('The QA renderer is not open.');
}

final _requests = <Map<String, Object?>>[];
final _externalRequests = <String>[];
final _cleanupResults = <Map<String, Object?>>[];
bool _loaded = false, _environmentDisposed = false;
String? _failure, _profile;
late WorkspaceController _workspace;

Dio _directTransport() => Dio()
  ..httpClientAdapter = IOHttpClientAdapter(
    createHttpClient: () => HttpClient()..findProxy = (_) => 'DIRECT',
  );

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!attachmentHtmlDesktopSupported) {
    throw StateError('This entry requires the registered desktop renderer.');
  }
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final uri = Uri.parse(
    'http://127.0.0.1:${server.port}/api/attachments/qa/html-preview?previewToken=qa',
  );
  server.listen((request) async {
    if (request.uri.path == '/api/attachments/qa/html-preview-url') {
      _requests.add({
        'path': request.uri.path,
        'authorization': request.headers.value('authorization') != null,
      });
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({'url': uri.toString()}));
    } else if (request.uri.path == '/api/attachments/qa/html-preview') {
      _requests.add({
        'path': request.uri.path,
        'cookie': request.headers.value('cookie'),
      });
      request.response.headers
        ..contentType = ContentType.html
        ..set('Content-Security-Policy', _csp)
        ..set('Cache-Control', 'no-store')
        ..set('Set-Cookie', 'qa_preview=fixture; HttpOnly; SameSite=Strict');
      request.response.write(_document);
    } else if (request.uri.path == '/qa/script-navigation' &&
        request.method == 'POST') {
      await _attemptQaScriptNavigation(request);
    } else if (request.uri.path == '/qa/status') {
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(await _snapshot()));
    } else {
      _requests.add({'path': request.uri.path});
      request.response.statusCode = HttpStatus.forbidden;
    }
    await request.response.close();
  });
  final dio = _directTransport();
  final verified = await AttachmentHtmlLoader(dio: dio)
      .verify(uri, cancel: CancelToken(), authorized: () => true);
  if (!verified) {
    throw StateError('The local fixture sandbox was not verified.');
  }
  final client = RaftClient(
    origin: uri.origin,
    sessionStore: MemorySessionStore(),
    transport: _directTransport(),
  )..selectServer('qa');
  _workspace = WorkspaceController(client)
    ..server = RaftRecord({'id': 'qa', 'role': 'guest'});
  registerExtension(
    'ext.raft.htmlQa.snapshot',
    (_, _) async =>
        ServiceExtensionResponse.result(jsonEncode(await _snapshot())),
  );
  debugPrint('[raft-html-qa] status=http://127.0.0.1:${server.port}/qa/status');
  runApp(
    MaterialApp(
      theme: raftTheme(),
      home: _QaPage(uri: uri),
    ),
  );
}

Future<Map<String, Object?>> _snapshot() async {
  dynamic document;
  final system = _systemController;
  if ((_controller != null || system != null) && _loaded) {
    try {
      document = await _evaluateDocument('''JSON.stringify({
        title:document.title,counter:Number(document.querySelector('#count').textContent),
        headingBackground:getComputedStyle(document.querySelector('h1')).backgroundColor,
        canvasPixel:Array.from(document.querySelector('#chart').getContext('2d').getImageData(1,1,1,1).data),
        appBridge:typeof window.flutter_inappwebview,
        nativeBridge:typeof window.__raftTrustedClick,
        network:window.qaNetwork,storage:window.qaStorage,origin:self.origin,
        lastClick:window.qaLastClick,scriptNavigationFired:window.qaScriptNavigationFired,
        pointerEvents:window.qaPointerEvents,
        fileCount:document.querySelector('#file').files.length
      })''');
      if (document is String) document = jsonDecode(document);
    } catch (_) {
      document = {'readback': 'unavailable'};
    }
  }
  Map<Object?, Object?>? nativeState;
  if (system != null) {
    try {
      nativeState = await system.inspect();
    } catch (_) {
      nativeState = {'retired': true};
    }
  }
  return {
    'loaded': _loaded,
    'failure': _failure,
    'document': document,
    'systemNativeState': nativeState,
    'nativeViewFocus': [
      if (nativeState != null)
        {'id': nativeState['id'], 'hasFocus': nativeState['focused']},
    ],
    'profile': _profile,
    'selectedInteractive': attachmentHtmlWebViewSupported,
    'environmentDisposed': _environmentDisposed,
    'cleanupResults': List.of(_cleanupResults),
    'requests': List.of(_requests),
    'externalRequests': List.of(_externalRequests),
    'navigationObserverReady': _navigationObserverReady,
    'inputContract': 'Actual first native pointer Down/Up/click remain trusted, ordered and single; Flutter does not synthesize GTK pointer input.',
    'navigationObserverFailure': _navigationObserverFailure,
    'navigationRequests': List.of(_navigationRequests),
    'scriptNavigationAttempts': _scriptNavigationAttempts,
  };
}

class _QaPage extends StatefulWidget {
  const _QaPage({required this.uri});
  final Uri uri;
  @override
  State<_QaPage> createState() => _QaPageState();
}

class _QaPageState extends State<_QaPage> {
  bool open = true;
  int generation = 0;

  Future<DesktopHtmlEnvironment> environment(TargetPlatform target) async {
    final value = await DesktopHtmlEnvironment.create(target);
    _profile = value.directory?.path;
    _environmentDisposed = false;
    return _QaEnvironment(value);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        Row(
          children: [
            TextButton(
              onPressed: () => setState(() {
                _controller = null;
                _systemController = null;
                _loaded = false;
                open = false;
              }),
              child: const Text('Close preview'),
            ),
            TextButton(
              onPressed: open
                  ? null
                  : () => setState(() {
                      _failure = null;
                      generation++;
                      open = true;
                    }),
              child: const Text('Reopen preview'),
            ),
            const Text('Isolated HTML renderer QA — no account'),
          ],
        ),
        Expanded(
          child: open
              ? HtmlAttachmentPreviewDialog(
                  key: ValueKey(generation),
                  controller: _workspace,
                  metadata: const {
                    'id': 'qa',
                    'filename': 'isolated-report.html',
                  },
                  authorized: () => open,
                  onClose: () => setState(() {
                    _controller = null;
                    _systemController = null;
                    _loaded = false;
                    open = false;
                  }),
                  onDownload: () async {},
                  openExternal: (uri) async {
                    _externalRequests.add(uri.toString());
                    return true;
                  },
                  loader: AttachmentHtmlLoader(dio: _directTransport()),
                  page: true,
                  webViewBuilder: (_, uri, events) =>
                      DesktopAttachmentHtmlWebView(
                        uri: uri,
                        environmentFactory: environment,
                        onControllerCreated: (controller) {
                          _controller = controller;
                          unawaited(_watchQaNavigation(controller));
                        },
                        onSystemControllerCreated: (controller) {
                          _systemController = controller;
                          _profile = null;
                          _environmentDisposed = false;
                          _navigationObserverReady = true;
                          controller.events.listen((event) {
                            if (_systemController != controller) return;
                            if (event['type'] == 'navigation') {
                              _navigationRequests.add({
                                'url': event['url'],
                                'reason': event['authority'],
                              });
                            }
                          });
                        },
                        onSystemDisposed: () {
                          _environmentDisposed = true;
                          _cleanupResults.add({
                            'backend': 'system-webkitgtk',
                            'completed': true,
                            'profile': null,
                          });
                        },
                        events: AttachmentHtmlWebViewEvents(
                          onNavigation: events.onNavigation,
                          onProgress: events.onProgress,
                          onLoaded: () {
                            _loaded = true;
                            events.onLoaded();
                            debugPrint('[raft-html-qa] loaded');
                          },
                          onFailed: (reason) {
                            _loaded = false;
                            _failure = reason;
                            events.onFailed(reason);
                            debugPrint('[raft-html-qa] failed:$reason');
                          },
                        ),
                      ),
                )
              : const Center(child: Text('Preview closed')),
        ),
      ],
    ),
  );
}

class _QaEnvironment extends DesktopHtmlEnvironment {
  _QaEnvironment(this.delegate)
    : super(platform: delegate.platform, directory: delegate.directory);
  final DesktopHtmlEnvironment delegate;
  @override
  Future<void> dispose() async {
    final timer = Stopwatch()..start();
    String? failure;
    try {
      await delegate.dispose();
      if (_profile == directory?.path) _environmentDisposed = true;
    } catch (error) {
      failure = error.runtimeType.toString();
      rethrow;
    } finally {
      _cleanupResults.add({
        'profile': directory?.path,
        'elapsedMs': timer.elapsedMilliseconds,
        'completed': failure == null,
        'failure': failure,
      });
    }
  }
}
