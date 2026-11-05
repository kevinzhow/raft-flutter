// A synthetic, account-free inline/layout/input prototype. Build it with the
// ordinary App runner using --target=<absolute path to this file>. It starts
// no AppRoot, account storage, production API or external browser.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:raft_system_webview/raft_system_webview.dart';
import 'package:raft_ui/raft_ui.dart';

const _csp =
    "default-src 'none'; sandbox allow-scripts; script-src 'unsafe-inline'; "
    "style-src 'unsafe-inline'; img-src data:; connect-src 'none'; "
    "object-src 'none'; base-uri 'none'; form-action 'none'; worker-src 'none'";
const _document =
    '''<!doctype html><meta charset="utf-8"><title>System view prototype</title>
<style>body{font:20px sans-serif;margin:24px;background:#fff;color:#172554}
button{font-size:24px;padding:12px}canvas{display:block;margin-top:20px}</style>
<h1>System WebKitGTK inline report</h1>
<button id="increment" onclick="count.textContent=Number(count.textContent)+1">Increment</button>
<strong id="count">0</strong><canvas id="chart" width="320" height="100"></canvas>
<p><input id="file" type="file"></p><div style="height:900px">Scrollable content</div>
<script>const c=chart.getContext('2d');c.fillStyle='#1e40af';c.fillRect(0,0,320,100);
window.pointerLog=[];for(const type of ['pointerdown','pointerup','click']){
document.addEventListener(type,e=>pointerLog.push({type,trusted:e.isTrusted,buttons:e.buttons}),true)}
window.storage='allowed';try{localStorage.setItem('qa','1')}catch(_){storage='blocked'}
</script>''';
final _state = <String, Object?>{
  'loaded': false,
  'closed': true,
  'opens': 0,
  'errors': 0,
};
SystemWebViewController? _active;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final uri = Uri.parse('http://127.0.0.1:${server.port}/preview');
  unawaited(() async {
    await for (final request in server) {
      if (request.uri.path == '/preview') {
        request.response.headers.contentType = ContentType.html;
        request.response.headers.set('Content-Security-Policy', _csp);
        request.response.write(_document);
      } else if (request.uri.path == '/status') {
        Object? document;
        if (_state['loaded'] == true && _active != null) {
          try {
            document = await _active!.evaluate(
              'JSON.stringify({counter:Number(count.textContent),storage,pointerLog,canvas:Array.from(chart.getContext("2d").getImageData(1,1,1,1).data)})',
            );
          } catch (_) {
            document = 'evaluation-failed';
          }
        }
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode({..._state, 'document': document}));
      } else {
        request.response.statusCode = 404;
      }
      await request.response.close();
    }
  }());
  debugPrint(
    '[system-webview-prototype] status=http://127.0.0.1:${server.port}/status',
  );
  runApp(
    MaterialApp(
      theme: raftTheme(),
      home: _Prototype(uri: uri),
    ),
  );
}

class _Prototype extends StatefulWidget {
  const _Prototype({required this.uri});
  final Uri uri;
  @override
  State<_Prototype> createState() => _PrototypeState();
}

class _PrototypeState extends State<_Prototype> {
  SystemWebViewController? controller;
  StreamSubscription<Map<Object?, Object?>>? subscription;
  bool loaded = false, opening = false;
  int generation = 0;
  double width = 600;
  final popover = MenuController();
  final popoverAnchor = GlobalKey();
  @override
  void initState() {
    super.initState();
    unawaited(open());
  }

  Future<void> open() async {
    if (opening || controller != null) return;
    final ticket = ++generation;
    setState(() => opening = true);
    try {
      final created = await SystemWebViewController.create();
      if (!mounted || ticket != generation) {
        await created.dispose();
        return;
      }
      controller = created;
      _active = created;
      _state['closed'] = false;
      _state['opens'] = (_state['opens'] as int) + 1;
      subscription = created.events.listen((event) {
        if (!mounted || ticket != generation) return;
        if (event['type'] == 'loaded') {
          _state['loaded'] = true;
          setState(() => loaded = true);
        }
        if (event['type'] == 'failed') {
          _state['errors'] = (_state['errors'] as int) + 1;
        }
      });
      setState(() => opening = false);
      await created.load(widget.uri);
    } catch (_) {
      if (mounted) {
        _state['errors'] = (_state['errors'] as int) + 1;
        setState(() => opening = false);
      }
    }
  }

  Future<void> close() async {
    generation++;
    final old = controller;
    controller = null;
    _active = null;
    loaded = false;
    opening = false;
    _state['loaded'] = false;
    await subscription?.cancel();
    subscription = null;
    await old?.dispose();
    _state['closed'] = true;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    unawaited(close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        Wrap(
          children: [
            RaftButton(
              label: 'Close renderer',
              onPressed: () => unawaited(close()),
            ),
            RaftButton(
              label: 'Open renderer',
              onPressed: () => unawaited(open()),
            ),
            RaftButton(
              label: 'Resize',
              onPressed: () => setState(() => width = width == 600 ? 360 : 600),
            ),
            RaftTooltip(
              message: 'This canonical tooltip must cover native content.',
              delay: Duration.zero,
              child: RaftPopoverAnchor(
                controller: popover,
                anchorKey: popoverAnchor,
                builder: (context, controller, child) => RaftButton(
                  key: popoverAnchor,
                  label: 'Popover',
                  onPressed: () => controller.isOpen
                      ? controller.close()
                      : controller.open(),
                ),
                popup: RaftPopoverSurface(
                  child: SizedBox(
                    width: 280,
                    height: 180,
                    child: Center(
                      child: RaftButton(
                        label: 'Dismiss popover',
                        onPressed: () => popover.close(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            RaftButton(
              label: 'Modal',
              onPressed: () => showRaftDialog<void>(
                context: context,
                builder: (context) => RaftDialog(
                  title: 'Native pane must be hidden',
                  content: const Text(
                    'No native pixels or clicks may cover this dialog.',
                  ),
                  actions: [
                    RaftButton(
                      label: 'Dismiss',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        Expanded(
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              child: ClipRect(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Center(
                      child: Text(
                        loaded ? '' : 'Loading isolated system view…',
                      ),
                    ),
                    if (controller case final current?)
                      SystemWebView(
                        controller: current,
                        visible: loaded,
                        occlusion: RaftNativeSurfaceOcclusion.forView(context),
                        isOccluded: RaftNativeSurfaceOcclusion.forView(context)
                            .overlaps,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
