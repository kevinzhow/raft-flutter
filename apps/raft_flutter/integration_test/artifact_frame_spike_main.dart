// WP-ART0 spike entrypoint (debug only): signs in to a local Raft v1.24 stack, asks the frame
// route for an Artifact, and shows it through Porthole in the platform WebView (Android, iOS,
// macOS), or the "Open in browser" fallback (Linux, Windows). A panel lists every bridge message
// and has buttons for find, theme, annotate and a forged-message probe.
//
//   tool/artifact-porthole-host: node build.mjs <raft-source v1.24 checkout> \
//     apps/raft_flutter/assets/artifacts/porthole_host.js
//   tool/flutter build apk --debug -t integration_test/artifact_frame_spike_main.dart \
//     --dart-define=ART0_API=http://localhost:13022 \
//     --dart-define=ART0_APP_ORIGIN=http://localhost:15194 \
//     --dart-define=ART0_CONTENT_DOMAIN=artifacts.localhost:18787 \
//     --dart-define=ART0_ARTIFACT=pt_<uuid> --dart-define=ART0_SERVER=<server uuid> \
//     --dart-define=ART0_LOGIN=<fixture email> --dart-define=ART0_PASSWORD=<fixture password>
//   (Android emulator: `adb reverse` the API and content ports; the app origin is never fetched.)
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/artifacts/artifact_frame_bridge.dart';
import 'package:raft_flutter/features/artifacts/artifact_frame_view.dart';
import 'package:raft_flutter/features/artifacts/artifact_open_in_browser.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:url_launcher/url_launcher.dart';

const api = String.fromEnvironment('ART0_API');
const appOrigin = String.fromEnvironment('ART0_APP_ORIGIN');
const contentDomain = String.fromEnvironment('ART0_CONTENT_DOMAIN');
const artifact = String.fromEnvironment('ART0_ARTIFACT');
const server = String.fromEnvironment('ART0_SERVER');
const login = String.fromEnvironment('ART0_LOGIN');
const password = String.fromEnvironment('ART0_PASSWORD');
const findQuery = String.fromEnvironment('ART0_FIND', defaultValue: 'porthole');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final client = RaftClient(origin: api, sessionStore: MemorySessionStore());
  await client.login(login, password);
  client.selectServer(server);
  final viewers = [
    for (final id in artifact.split(','))
      (id: id, data: Map<String, Object?>.from(await client.get('/artifacts/$id') as Map)),
  ];
  runApp(_Spike(client: client, viewers: viewers));
}

class _Spike extends StatefulWidget {
  const _Spike({required this.client, required this.viewers});
  final RaftClient client;
  final List<({String id, Map<String, Object?> data})> viewers;
  @override
  State<_Spike> createState() => _SpikeState();
}

class _SpikeState extends State<_Spike> {
  var frame = ArtifactFrameController();
  int index = 0;
  String get id => widget.viewers[index].id;
  final messenger = GlobalKey<ScaffoldMessengerState>();
  final navigator = GlobalKey<NavigatorState>();
  bool dark = false, panel = true;
  String probe = '';

  Map<String, Object?> get artifactData =>
      switch (widget.viewers[index].data['card']) {
        final Map<Object?, Object?> data => data.cast<String, Object?>(),
        _ => widget.viewers[index].data,
      };
  String get title => '${artifactData['title'] ?? id}';

  void next() => setState(() {
    index = (index + 1) % widget.viewers.length;
    frame = ArtifactFrameController();
    probe = '';
  });
  int get version => switch (artifactData['version']) {
    final int n => n,
    _ => 1,
  };

  void toast(String text) => messenger.currentState?.showSnackBar(
    SnackBar(content: Text(text), duration: const Duration(seconds: 2)),
  );

  late final host = ArtifactFrameHost(
    openLink: (uri) async {
      toast('openLink → $uri');
      return launchUrl(uri, mode: LaunchMode.externalApplication);
    },
    copyText: (text) async {
      await copyArtifactFrameText(text);
      toast('Copied');
      return true;
    },
    comments: (request) async {
      toast('comments.open → ${request['anchor'] ?? request}');
      return true;
    },
    confirm: (capability, args) async {
      final context = navigator.currentContext;
      if (context == null) return false;
      return showRaftAlertDialog(
        context: context,
        title: 'Open this link?',
        description: '$capability: ${args is Map ? args['url'] ?? args : args}',
        confirmLabel: 'Open',
      );
    },
  );

  Future<void> forge() async {
    // The content frame is cross-origin to the wrapper: it can't read the nonce. This posts on
    // the channel without one, the way content could (the channel is visible in every frame).
    await frame.evaluate(
      "window.RaftArtifactBridge.postMessage(JSON.stringify({type:'openLink',"
      "detail:{id:1,url:'https://example.com/forged'}}));'sent'",
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));
    setState(() => probe = 'forged → refused ${frame.refused}');
  }

  ArtifactFrameSupport get support =>
      artifactFrameSupportFor(Platform.operatingSystem);

  Widget _body(BuildContext context) => support == ArtifactFrameSupport.browser
        ? ArtifactOpenInBrowser(
            title: title,
            pageUrl: Uri.parse(
              '${artifactData['url'] ?? '$appOrigin/artifacts/$id'}',
            ),
            open: (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
          )
        : ArtifactFrameView(
            key: ValueKey(id),
            artifactId: id,
            version: version,
            title: title,
            appOrigin: Uri.parse(appOrigin),
            contentDomain: contentDomain,
            dark: dark,
            theme: artifactPageTheme(RaftTokens.of(context).colors),
            controller: frame,
            host: host,
            hostScript: () =>
                rootBundle.loadString('assets/artifacts/porthole_host.js'),
            locate: () => widget.client.post(
              '/artifacts/$id/frame',
              data: <String, Object?>{},
            ),
          );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigator,
      scaffoldMessengerKey: messenger,
      theme: raftTheme(),
      darkTheme: raftTheme(dark: true),
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Expanded(child: Builder(builder: _body)),
              if (support == ArtifactFrameSupport.webView)
                ListenableBuilder(
                  listenable: frame,
                  builder: (context, _) => _panel(context),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _panel(BuildContext context) {
    Widget button(String label, VoidCallback onTap) => Padding(
      padding: const EdgeInsets.only(right: 6),
      child: OutlinedButton(onPressed: onTap, child: Text(label)),
    );
    return Container(
      key: const ValueKey('art0-panel'),
      height: panel ? 210 : 44,
      color: dark ? const Color(0xFF1E1E1E) : const Color(0xFFF2F2F2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                button(panel ? 'hide' : 'log', () => setState(() => panel = !panel)),
                button('find', () => frame.find(findQuery)),
                button('next', () => frame.find(findQuery, direction: 'next')),
                button('clear', frame.clearFind),
                button('theme', () => setState(() => dark = !dark)),
                button('annotate', () => frame.annotations('start')),
                button('stop', () => frame.annotations('stop')),
                button('forge', forge),
                button('reload', frame.reload),
                button('next artifact', next),
              ],
            ),
          ),
          if (panel)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: SingleChildScrollView(
                  reverse: true,
                  child: Text(
                    [
                      'status=${frame.status.name}'
                          '${frame.blockedReason == null ? '' : ' (${frame.blockedReason})'}'
                          ' refused=${frame.refused} $probe',
                      'sandbox=${frame.compiled?['sandbox']} '
                          'matchesWeb=${frame.compiled?['sandboxMatchesWeb']}',
                      'find=${frame.lastFind}',
                      'received=${frame.received}',
                      ...frame.log.reversed.take(12).toList().reversed,
                    ].join('\n'),
                    style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
