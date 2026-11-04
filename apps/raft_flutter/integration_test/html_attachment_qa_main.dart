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
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/attachment_html_preview.dart';
import 'package:raft_flutter/platform/attachment_html.dart';
import 'package:raft_flutter/platform/attachment_html_desktop.dart';
import 'package:raft_flutter/platform/attachment_html_desktop_environment.dart';
import 'package:raft_flutter/platform/attachment_html_webview.dart';
import 'package:raft_ui/raft_ui.dart';

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
<p><input id="file" type="file"> <a href="https://example.com">External link</a></p>
<script>
const ctx=chart.getContext('2d');ctx.fillStyle='#1e40af';ctx.fillRect(0,0,320,120);
window.qaNetwork='pending';fetch('/qa-exfil').then(()=>qaNetwork='allowed',()=>qaNetwork='blocked');
window.qaStorage='allowed';try{localStorage.setItem('qa','1')}catch(_){qaStorage='blocked'}
</script>''';

PlatformInAppWebViewController? _controller;
final _requests = <Map<String, Object?>>[];
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
  final controller = _controller;
  if (controller != null && _loaded) {
    try {
      document = await controller.evaluateJavascript(
        source: '''JSON.stringify({
        title:document.title,counter:Number(document.querySelector('#count').textContent),
        headingBackground:getComputedStyle(document.querySelector('h1')).backgroundColor,
        canvasPixel:Array.from(document.querySelector('#chart').getContext('2d').getImageData(1,1,1,1).data),
        appBridge:typeof window.flutter_inappwebview,
        network:window.qaNetwork,storage:window.qaStorage,origin:self.origin
      })''',
      );
      if (document is String) document = jsonDecode(document);
    } catch (_) {
      document = {'readback': 'unavailable'};
    }
  }
  return {
    'loaded': _loaded,
    'failure': _failure,
    'document': document,
    'profile': _profile,
    'selectedInteractive': attachmentHtmlWebViewSupported,
    'environmentDisposed': _environmentDisposed,
    'requests': List.of(_requests),
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
                    _loaded = false;
                    open = false;
                  }),
                  onDownload: () async {},
                  loader: AttachmentHtmlLoader(dio: _directTransport()),
                  page: true,
                  webViewBuilder: (_, uri, events) =>
                      DesktopAttachmentHtmlWebView(
                        uri: uri,
                        environmentFactory: environment,
                        onControllerCreated: (controller) =>
                            _controller = controller,
                        events: AttachmentHtmlWebViewEvents(
                          onNavigation: events.onNavigation,
                          onProgress: events.onProgress,
                          onLoaded: () {
                            _loaded = true;
                            events.onLoaded();
                            debugPrint('[raft-html-qa] loaded');
                          },
                          onFailed: (reason) {
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
    await delegate.dispose();
    _environmentDisposed = true;
  }
}
