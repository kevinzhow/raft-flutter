import 'dart:io';

import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/app_root_router.dart';
import 'package:raft_flutter/features/channel_side_area.dart';
import 'package:raft_flutter/features/channel_side_web_preview.dart';
import 'package:raft_flutter/features/desktop_browser_native_page.dart';
import 'package:raft_flutter/features/desktop_browser_panel.dart';
import 'package:raft_flutter/features/desktop_browser_session.dart';
import 'package:raft_flutter/features/desktop_browser_tabs.dart';
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
    if (path == '/download') {
      request.response.headers.contentType = ContentType.binary;
      request.response.headers.set('Content-Disposition', 'attachment');
      request.response.write('download');
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
  if (Platform.environment['RAFT_BROWSER_SIDE_SMOKE'] == '1') {
    await _sideArea(base);
    return;
  }
  final tabs = DesktopBrowserTabs()..open('fixture', base);
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

Future<void> _sideArea(Uri base) async {
  final (workspace, _) = await webPreviewFixture(
    flag: false,
    os: 'linux',
    desktopBrowser: true,
    voiceOver: ValueNotifier(false),
  );
  final original = workspace.channel!;
  final other = RaftChannel({'id': 'c2', 'name': 'Other', 'joined': true});
  workspace.channels = [original, other];
  final tabs = WebPreviewStore.of(workspace).browserTabs;
  tabs.addListener(() {
    stdout.writeln('TAB ${tabs.forConversation(original.id)?.active.page}');
  });
  openWebPreviewBeside(workspace, base.toString(), conversationId: original.id);
  final router = RaftAppRouter(
    onLocation: (_) async {},
    onRootBack: () async => false,
    observers: [],
    home: (_) => Scaffold(
      body: ChannelSideArea(
        controller: workspace,
        child: Align(
          alignment: Alignment.topLeft,
          child: RaftButton(
            label: 'Switch conversation',
            onPressed: () {
              final next = workspace.channel == original ? other : original;
              workspace.channel = next;
              workspace.notifyListeners();
              stdout.writeln('SWITCH ${next.id}');
            },
          ),
        ),
      ),
    ),
  );
  runApp(MaterialApp.router(theme: raftTheme(), routerDelegate: router));
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
