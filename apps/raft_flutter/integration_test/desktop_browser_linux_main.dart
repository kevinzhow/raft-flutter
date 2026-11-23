import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/app_root_router.dart';
import 'package:raft_flutter/features/channel_side_area.dart';
import 'package:raft_flutter/features/channel_side_cards.dart';
import 'package:raft_flutter/features/channel_side_store.dart';
import 'package:raft_flutter/features/channel_side_web_preview.dart';
import 'package:raft_flutter/features/desktop_browser_native_page.dart';
import 'package:raft_flutter/features/desktop_browser_panel.dart';
import 'package:raft_flutter/features/desktop_browser_session.dart';
import 'package:raft_flutter/features/desktop_browser_tabs.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_flutter/platform/app_services.dart';
import 'package:raft_ui/raft_ui.dart';

import '../test/support/web_preview_fixture.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final base = Uri.parse('http://127.0.0.1:${server.port}/');
  final unavailable = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final failedPage = base.replace(port: unavailable.port, path: '/recover');
  await unavailable.close();
  server.listen((request) async {
    final path = request.uri.path;
    stdout.writeln('REQUEST $path cookie=${request.cookies.isNotEmpty}');
    if (path == '/tone.wav') {
      _serveTone(request);
    } else if (path.endsWith('.bin') || path == '/download') {
      request.response.headers.contentType = ContentType.binary;
      request.response.headers.set('Content-Disposition', 'attachment');
      request.response.write('download');
    } else if (path == '/round2' || path == '/navigation') {
      request.response.headers.contentType = ContentType.html;
      request.response.write('''
        <!doctype html><meta charset="utf-8"><title>Fixture $path</title>
        <style>
          body{font:20px sans-serif;margin:24px}
          input,button,a,audio{display:block;margin:0 0 12px}
        </style>
        <input placeholder="Remembered text"
          oninput="document.title = 'Remembered ' + this.value">
        <a id="download" href="/clicked.bin" download>Download attribute</a>
        <a href="/attachment.bin">Download attachment</a>
        <audio autoplay loop controls src="/tone.wav"></audio>
        <button onclick="document.querySelector('audio').play()">Play fixture tone</button>
        <script>
          document.querySelector('input').addEventListener('keydown', event => {
            if (event.key === 'Escape') document.title = 'Page Escape';
            if (event.ctrlKey && event.key.toLowerCase() === 'z') {
              document.title = 'Page Ctrl+Z';
            }
          });
          document.querySelector('audio').addEventListener('playing', () => {
            fetch('/audio-playing');
          });
          if (location.pathname === '/round2') {
            setTimeout(() => {
              const link = document.createElement('a');
              link.href = '/timer.bin';
              link.download = '';
              document.body.append(link);
              link.click();
            }, 1200);
          }
        </script>
        ''');
    } else {
      request.response.headers.contentType = ContentType.html;
      if (path == '/') request.response.cookies.add(Cookie('fixture', 'yes'));
      request.response.write('''
        <!doctype html><meta charset="utf-8"><title>Fixture $path</title>
        <style>
          body{font:20px sans-serif;margin:24px}
          a,button{display:block;margin-bottom:12px}
        </style>
        <h1>Fixture $path</h1>
        <a id="second" href="/second">Go to second</a>
        <a id="popup" href="/popup" target="_blank">Open popup</a>
        <a id="blocked" href="http://localhost:${server.port}/blocked">Blocked host</a>
        <a id="credentials" href="http://name:pass@127.0.0.1:${server.port}/credentials">Blocked credentials</a>
        <a id="download" href="/download">Download</a>
        <input placeholder="Remembered text"
          oninput="document.title = 'Remembered ' + this.value">
        <a href="/frames">Open frame fixture</a>
        <a href="data:text/html,%3Ctitle%3ENon-web%20top%20frame%3C%2Ftitle%3E">Open non-web document</a>
        <a href="/attribute-download" download>Download a document</a>
        <button onclick="window.open('/script-popup')">Open script popup</button>
        ${path == '/frames' ? _frames : ''}
        ''');
    }
    await request.response.close();
  });
  if (Platform.environment['RAFT_BROWSER_ROUND2'] == '1') {
    final projection =
        Platform.environment['RAFT_BROWSER_ROUND2_PROJECTION'] == '1';
    await _sideArea(base.replace(path: '/round2'), projection: projection);
    return;
  }
  if (Platform.environment['RAFT_BROWSER_SIDE_SMOKE'] == '1') {
    await _sideArea(base);
    return;
  }
  final tabs = DesktopBrowserTabs()
    ..open(
      'fixture',
      Platform.environment['RAFT_BROWSER_ROUND2'] == 'direct'
          ? base.replace(path: '/round2')
          : base,
    );
  var session = DesktopBrowserSession();
  tabs.addListener(() {
    final state = tabs.forConversation('fixture')?.active.page;
    stdout.writeln('TAB $state');
  });
  final router = RaftAppRouter(
    onLocation: (_) async {},
    onRootBack: () async => false,
    observers: [],
    home: (_) => Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 600,
            child: DesktopBrowserPanel(
              tabs: tabs,
              conversation: 'fixture',
              raftHosts: const {'localhost'},
              openExternal: (url) => stdout.writeln('EXTERNAL ${url.path}'),
              pageBuilder: (context, tab, visible, events) =>
                  DesktopBrowserNativePage(
                    tab: tab,
                    visible: visible,
                    events: events,
                    raftHosts: const {'localhost'},
                    session: session,
                  ),
            ),
          ),
          Builder(
            builder: (context) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RaftButton(
                  label: 'Open browser',
                  onPressed: () => tabs.open(
                    'fixture',
                    base.replace(path: '/session-check'),
                  ),
                ),
                RaftButton(
                  label: 'Reset account',
                  onPressed: () {
                    tabs.clear();
                    session.dispose();
                    session = DesktopBrowserSession();
                    tabs.open('fixture', base.replace(path: '/account-check'));
                  },
                ),
                RaftButton(
                  label: 'Navigate to failure',
                  onPressed: () {
                    final tab = tabs.forConversation('fixture')!.active;
                    tabs.navigate('fixture', tab.id, failedPage);
                  },
                ),
                RaftButton(
                  label: 'Open menu',
                  onPressed: () => showRaftMessageContextMenu<void>(
                    context: context,
                    anchor: const Offset(120, 185),
                    builder: (menu) => RaftMessageContextMenu(
                      onDismiss: () => Navigator.of(menu).pop(),
                      sections: [
                        [
                          RaftMessageContextMenuItem(
                            label: 'Above the native page',
                            icon: const RaftIcon(RaftGlyph.globe),
                            onPressed: () {
                              stdout.writeln('MENU ACTIVATED');
                              Navigator.of(menu).pop();
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                RaftButton(
                  label: 'Make failed address available',
                  onPressed: () async {
                    final recovered = await HttpServer.bind(
                      InternetAddress.loopbackIPv4,
                      failedPage.port,
                    );
                    recovered.listen((request) async {
                      stdout.writeln('RECOVERY REQUEST');
                      request.response.headers.contentType = ContentType.html;
                      request.response.write(
                        '<!doctype html><title>Recovered</title><h1>Recovered</h1>',
                      );
                      await request.response.close();
                    });
                    stdout.writeln('RECOVERY READY');
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
  runApp(MaterialApp.router(theme: raftTheme(), routerDelegate: router));
}

Future<void> _sideArea(Uri base, {bool projection = false}) async {
  final (workspace, adapter) = await webPreviewFixture(
    flag: false,
    os: 'linux',
    desktopBrowser: true,
    tasks: projection,
    voiceOver: ValueNotifier(false),
  );
  final original = workspace.channel!;
  final other = RaftChannel({'id': 'c2', 'name': 'Other', 'joined': true});
  workspace.channels = [original, other];
  if (projection) {
    adapter.routes['GET /channels/c1/messages'] = (_) => [];
    adapter.routes['GET /channels/c2/messages'] = (_) => [];
    workspace.section = 'chat';
    ChannelSideCards.toggle(workspace, ChannelSideCard.tasks);
  }
  final tabs = WebPreviewStore.of(workspace).browserTabs;
  tabs.addListener(() {
    stdout.writeln('TAB ${tabs.forConversation(original.id)?.active.page}');
  });
  final opened = openWebPreviewBeside(
    workspace,
    base.toString(),
    conversationId: original.id,
  );
  stdout.writeln(
    'READY $opened ${workspace.section} ${workspace.location.uri}',
  );
  final switcher = RaftButton(
    label: 'Switch conversation',
    onPressed: () {
      final next = workspace.channel == original ? other : original;
      workspace.channel = next;
      if (projection) workspace.section = 'chat';
      workspace.notifyListeners();
      stdout.writeln('SWITCH ${next.id}');
    },
  );
  final router = RaftAppRouter(
    onLocation: (_) async {},
    onRootBack: () async => false,
    observers: [],
    home: (_) => Scaffold(
      body: projection
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                switcher,
                Expanded(
                  child: WorkspaceView(
                    controller: workspace,
                    appearance: const RaftAppearance(),
                    onAppearance: (_) async {},
                    onLogout: () async {},
                  ),
                ),
              ],
            )
          : ChannelSideArea(
              controller: workspace,
              child: Align(alignment: Alignment.topLeft, child: switcher),
            ),
    ),
  );
  runApp(
    AppServicesScope(
      services: const AppServices.updatesDisabledForTestOrPreview(),
      child: MaterialApp.router(theme: raftTheme(), routerDelegate: router),
    ),
  );
}

Uint8List _tone() {
  const sampleRate = 8000;
  const samples = sampleRate;
  final wave = ByteData(44 + samples * 2);
  wave.setUint32(0, 0x52494646);
  wave.setUint32(4, wave.lengthInBytes - 8, Endian.little);
  wave.setUint32(8, 0x57415645);
  wave.setUint32(12, 0x666d7420);
  wave.setUint32(16, 16, Endian.little);
  wave.setUint16(20, 1, Endian.little);
  wave.setUint16(22, 1, Endian.little);
  wave.setUint32(24, sampleRate, Endian.little);
  wave.setUint32(28, sampleRate * 2, Endian.little);
  wave.setUint16(32, 2, Endian.little);
  wave.setUint16(34, 16, Endian.little);
  wave.setUint32(36, 0x64617461);
  wave.setUint32(40, samples * 2, Endian.little);
  for (var sample = 0; sample < samples; sample++) {
    wave.setInt16(
      44 + sample * 2,
      (math.sin(2 * math.pi * 440 * sample / sampleRate) * 8000).round(),
      Endian.little,
    );
  }
  return wave.buffer.asUint8List();
}

final _wave = _tone();

void _serveTone(HttpRequest request) {
  final response = request.response;
  response.headers.contentType = ContentType('audio', 'wav');
  response.headers.set('Accept-Ranges', 'bytes');
  final range = RegExp(r'^bytes=(\d+)-(\d*)$')
      .firstMatch(request.headers.value(HttpHeaders.rangeHeader) ?? '');
  if (range == null) {
    response.contentLength = _wave.length;
    response.add(_wave);
    return;
  }
  final start = int.parse(range.group(1)!);
  final end = math.min(
    int.tryParse(range.group(2)!) ?? _wave.length - 1,
    _wave.length - 1,
  );
  if (start > end) {
    response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
    response.headers.set('Content-Range', 'bytes */${_wave.length}');
    return;
  }
  response.statusCode = HttpStatus.partialContent;
  response.headers.set('Content-Range', 'bytes $start-$end/${_wave.length}');
  response.contentLength = end - start + 1;
  response.add(Uint8List.sublistView(_wave, start, end + 1));
}

const _frames = '''
<script>
  const seen = new Set();
  addEventListener('message', ({data}) => {
    seen.add(data);
    document.title = [...seen].sort().join(',');
  });
  for (const kind of ['blob', 'data', 'srcdoc']) {
    const frame = document.createElement('iframe');
    const html = '<script>parent.postMessage("' + kind + '","*")<\\/script>';
    if (kind === 'srcdoc') frame.srcdoc = html;
    if (kind === 'blob') frame.src = URL.createObjectURL(new Blob([html], {type:'text/html'}));
    if (kind === 'data') frame.src = 'data:text/html,' + encodeURIComponent(html);
    document.body.append(frame);
  }
  const blank = document.createElement('iframe');
  blank.srcdoc = '<title>Before blank</title>';
  blank.onload = () => {
    if (blank.contentDocument.URL === 'about:srcdoc') {
      blank.contentWindow.location.href = 'about:blank';
    } else if (blank.contentDocument.URL === 'about:blank') {
      parent.postMessage('blank', '*');
    }
  };
  document.body.append(blank);
</script>
''';
